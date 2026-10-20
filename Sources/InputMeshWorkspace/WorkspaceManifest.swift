import Foundation

/// The portable, data-only contract. Never include credentials, environment
/// variables, unsaved buffers, diff contents, SSH keys or arbitrary commands.
public struct WorkspaceManifest: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public let schemaVersion: Int
    public let createdAt: Date
    public let sourceDeviceName: String
    public let repository: RepositorySnapshot
    public let resources: [WorkspaceResource]

    public init(createdAt: Date = Date(), sourceDeviceName: String,
                repository: RepositorySnapshot, resources: [WorkspaceResource] = []) throws {
        self.schemaVersion = Self.currentVersion
        self.createdAt = createdAt
        self.sourceDeviceName = String(sourceDeviceName.prefix(128))
        self.repository = repository
        self.resources = resources
        try validate()
    }

    public func validate() throws {
        guard schemaVersion == Self.currentVersion else { throw WorkspaceError.unsupportedSchema }
        guard !sourceDeviceName.isEmpty, sourceDeviceName.utf8.count <= 512 else { throw WorkspaceError.invalidManifest }
        guard resources.count <= 32, repository.headSHA.count == 40,
              repository.headSHA.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw WorkspaceError.invalidManifest
        }
        guard !repository.branch.isEmpty, repository.branch.count <= 250,
              !repository.branch.contains("\n"), !repository.branch.contains("\r") else {
            throw WorkspaceError.invalidManifest
        }
        try RepositoryAddress.validate(repository.origin)
        for resource in resources { try resource.validate() }
    }

    /// Decode with a conservative file limit before allocation and validate decoded values.
    public static func load(_ url: URL) throws -> WorkspaceManifest {
        guard url.isFileURL else { throw WorkspaceError.invalidManifest }
        // Never map/read an untrusted manifest in full before checking its size.
        // Read at most cap + 1 bytes, even if the file grows between stat and read.
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: 64 * 1024 + 1) ?? Data()
        guard data.count <= 64 * 1024 else { throw WorkspaceError.manifestTooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let value = try decoder.decode(Self.self, from: data)
        try value.validate()
        return value
    }

    public func write(to url: URL) throws {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let bytes = try encoder.encode(self)
        guard bytes.count <= 64 * 1024 else { throw WorkspaceError.manifestTooLarge }
        try bytes.write(to: url, options: .atomic)
    }
}

public struct RepositorySnapshot: Codable, Equatable, Sendable {
    public let origin: String
    public let branch: String
    public let headSHA: String
    public let hasUncommittedChanges: Bool
    public let hasUntrackedFiles: Bool

    public init(origin: String, branch: String, headSHA: String,
                hasUncommittedChanges: Bool, hasUntrackedFiles: Bool) {
        self.origin = origin
        self.branch = branch
        self.headSHA = headSHA
        self.hasUncommittedChanges = hasUncommittedChanges
        self.hasUntrackedFiles = hasUntrackedFiles
    }
}

public enum WorkspaceResource: Codable, Equatable, Sendable {
    case webURL(String)

    public func validate() throws {
        switch self {
        case .webURL(let value):
            guard value.utf8.count <= 2048, let url = URL(string: value),
                  url.scheme?.lowercased() == "https", url.host != nil,
                  url.user == nil, url.password == nil else { throw WorkspaceError.invalidResource }
        }
    }
}

public enum WorkspaceError: Error, Equatable, LocalizedError {
    case unsupportedSchema, invalidManifest, invalidResource, manifestTooLarge
    case invalidRepository, untrustedOrigin, gitFailed, unsafeDestination

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: return "Unsupported workspace manifest version."
        case .invalidManifest: return "Invalid workspace manifest."
        case .invalidResource: return "Only credential-free HTTPS resources are allowed."
        case .manifestTooLarge: return "Workspace manifest exceeds 64 KiB."
        case .invalidRepository: return "Choose an existing valid Git working tree."
        case .untrustedOrigin: return "Remote URL is missing or may contain credentials / unsafe transports."
        case .gitFailed: return "Git metadata command failed."
        case .unsafeDestination: return "Unsafe destination directory."
        }
    }
}

public enum RepositoryAddress {
    /// Only public-key SSH shorthand or HTTPS without embedded credentials.
    /// No clone/fetch operations are performed by the handoff workflow.
    public static func validate(_ text: String) throws {
        guard text.utf8.count <= 2048, !text.contains("\n"), !text.contains("\r"),
              !text.contains(" "), !text.contains("\\") else { throw WorkspaceError.untrustedOrigin }
        if text.hasPrefix("git@") {
            let remaining = text.dropFirst(4)
            let tokens = remaining.split(separator: ":", omittingEmptySubsequences: false)
            guard tokens.count == 2, !tokens[0].isEmpty, !tokens[1].isEmpty,
                  !tokens[0].contains("@"), !tokens[1].hasPrefix("/"),
                  !tokens[1].split(separator: "/").contains("..") else { throw WorkspaceError.untrustedOrigin }
            return
        }
        guard let url = URLComponents(string: text), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, !url.path.isEmpty, url.path != "/" else {
            throw WorkspaceError.untrustedOrigin
        }
    }

    public static func normalized(_ text: String) -> String {
        let stripped = text.hasSuffix(".git") ? String(text.dropLast(4)) : text
        if stripped.hasPrefix("git@") {
            let s = stripped.dropFirst(4)
            let components = s.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if components.count == 2 { return components[0].lowercased() + "/" + components[1] }
            return stripped
        }
        if let url = URLComponents(string: stripped), let host = url.host {
            // Do not conflate different server endpoints. HTTPS :443 is
            // intentionally equivalent to default HTTPS and git@host:path;
            // non-default HTTPS ports are always part of repository identity.
            let portSuffix = (url.port == nil || url.port == 443) ? "" : ":\(url.port!)"
            return host.lowercased() + portSuffix + url.percentEncodedPath
        }
        return stripped.lowercased()
    }
}

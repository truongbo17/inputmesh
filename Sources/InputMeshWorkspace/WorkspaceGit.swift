import Foundation

public protocol GitCommandRunning {
    func run(_ args: [String], at directory: URL) throws -> String
}

public struct SystemGitRunner: GitCommandRunning {
    public init() {}

    public func run(_ args: [String], at directory: URL) throws -> String {
        // No command string or shell expansion. Never invoke Git hook/config-sensitive actions.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null", "--no-pager"] + args
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        var data = Data()
        while true {
            let chunk = pipe.fileHandleForReading.readData(ofLength: 8192)
            if chunk.isEmpty { break }
            if data.count + chunk.count > 256 * 1024 {
                process.terminate()
                process.waitUntilExit()
                throw WorkspaceError.gitFailed
            }
            data.append(chunk)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else { throw WorkspaceError.gitFailed }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct GitWorkspaceInspector {
    private let runner: GitCommandRunning
    public init(runner: GitCommandRunning = SystemGitRunner()) { self.runner = runner }

    public func capture(at location: URL, deviceName: String,
                        resources: [WorkspaceResource] = []) throws -> WorkspaceManifest {
        let path = location.standardizedFileURL.resolvingSymlinksInPath()
        let root = try runner.run(["rev-parse", "--show-toplevel"], at: path)
        guard path.path == URL(fileURLWithPath: root).standardizedFileURL.resolvingSymlinksInPath().path else {
            // Prevent surprise capture from inside a nested Git repo or from /tmp aliases.
            throw WorkspaceError.invalidRepository
        }
        let origin = try runner.run(["config", "--get", "remote.origin.url"], at: path)
        try RepositoryAddress.validate(origin)
        let branch = try runner.run(["symbolic-ref", "--quiet", "--short", "HEAD"], at: path)
        guard !branch.isEmpty else { throw WorkspaceError.invalidRepository }
        let sha = try runner.run(["rev-parse", "--verify", "HEAD"], at: path).lowercased()
        let status = try runner.run(["status", "--porcelain=v1", "--untracked-files=normal"], at: path)
        let lines = status.split(separator: "\n", omittingEmptySubsequences: true)
        return try WorkspaceManifest(sourceDeviceName: deviceName,
              repository: RepositorySnapshot(origin: origin, branch: branch, headSHA: sha,
                   hasUncommittedChanges: lines.contains(where: { !$0.hasPrefix("??") }),
                   hasUntrackedFiles: lines.contains(where: { $0.hasPrefix("??") })), resources: resources)
    }
}

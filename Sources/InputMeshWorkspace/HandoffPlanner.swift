import Foundation

public enum HandoffBlocker: String, Codable, Sendable, Equatable, CaseIterable {
    case sourceHasChanges, sourceHasUntrackedFiles, differentRepository
    case destinationHasChanges, destinationHasUntrackedFiles
    case differentBranch, differentCommit
}

public struct HandoffPlan: Equatable, Sendable {
    public let blockers: [HandoffBlocker]
    public let repositoryPath: String
    public let resources: [WorkspaceResource]
    public var canOpen: Bool { blockers.isEmpty }
}

public struct HandoffPlanner {
    public init() {}

    /// Fail closed: never git checkout, git pull, git reset, or transfer working files.
    /// The caller may open the destination directory only if the immutable source and
    /// destination identity match exactly and both worktrees are clean.
    public func plan(source: WorkspaceManifest, destination: WorkspaceManifest,
                     targetFolder: URL) throws -> HandoffPlan {
        try source.validate()
        try destination.validate()
        guard targetFolder.isFileURL else { throw WorkspaceError.unsafeDestination }
        let a = source.repository, b = destination.repository
        var errors = [HandoffBlocker]()
        if a.hasUncommittedChanges { errors.append(.sourceHasChanges) }
        if a.hasUntrackedFiles { errors.append(.sourceHasUntrackedFiles) }
        if RepositoryAddress.normalized(a.origin) != RepositoryAddress.normalized(b.origin) {
            errors.append(.differentRepository)
        }
        if b.hasUncommittedChanges { errors.append(.destinationHasChanges) }
        if b.hasUntrackedFiles { errors.append(.destinationHasUntrackedFiles) }
        if a.branch != b.branch { errors.append(.differentBranch) }
        if a.headSHA != b.headSHA { errors.append(.differentCommit) }
        return HandoffPlan(blockers: errors, repositoryPath: targetFolder.standardizedFileURL.path,
                           resources: source.resources)
    }
}

public enum WorkspaceHandoff {
    /// Inspect again just before opening to limit stale-plan risk.
    public static func prepare(source: WorkspaceManifest, destinationFolder: URL,
                               deviceName: String = "Destination") throws -> HandoffPlan {
        let destination = try GitWorkspaceInspector().capture(at: destinationFolder, deviceName: deviceName)
        return try HandoffPlanner().plan(source: source, destination: destination,
                                        targetFolder: destinationFolder)
    }
}

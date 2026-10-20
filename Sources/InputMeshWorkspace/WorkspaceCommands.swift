import Foundation

public enum WorkspaceCommand {
    /// User-facing, explicit action. No network access, no filesystem mutation of Git repos.
    public static func capture(repository: URL, output: URL,
                               deviceName: String, resources: [WorkspaceResource] = []) throws -> WorkspaceManifest {
        let root = repository.standardizedFileURL.resolvingSymlinksInPath().path
        let target = output.standardizedFileURL.resolvingSymlinksInPath().path
        guard target != root && !target.hasPrefix(root + "/") else {
            // Exporting into the very repo we inspected would create an untracked
            // file after the clean-state check and make the manifest stale.
            throw WorkspaceError.unsafeDestination
        }
        let manifest = try GitWorkspaceInspector().capture(at: repository, deviceName: deviceName, resources: resources)
        try manifest.write(to: output)
        return manifest
    }

    public static func inspect(manifestURL: URL, destination: URL) throws -> HandoffPlan {
        try WorkspaceHandoff.prepare(source: WorkspaceManifest.load(manifestURL), destinationFolder: destination)
    }

    public static func continueOnThisDevice(manifestURL: URL, destination: URL) throws -> HandoffPlan {
        let plan = try inspect(manifestURL: manifestURL, destination: destination)
        guard plan.canOpen else { return plan }
        #if os(macOS)
        // Deliberately do not execute editor/terminal commands from manifest. Always invoke
        // a locally installed, allowlisted app and pass the user-chosen directory as an arg.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Visual Studio Code", "--", plan.repositoryPath]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw WorkspaceError.gitFailed }
        #endif
        return plan
    }
}

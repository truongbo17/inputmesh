import Foundation
import XCTest
@testable import InputMeshWorkspace

final class WorkspaceTests: XCTestCase {
    private let sha = String(repeating: "a", count: 40)
    private func manifest(origin: String = "https://github.com/example/project.git", branch: String = "main",
                          sha: String? = nil, dirty: Bool = false, untracked: Bool = false) throws -> WorkspaceManifest {
        try WorkspaceManifest(createdAt: Date(timeIntervalSince1970: 0), sourceDeviceName: "Mac A",
                              repository: .init(origin: origin, branch: branch, headSHA: sha ?? self.sha,
                                                hasUncommittedChanges: dirty, hasUntrackedFiles: untracked))
    }

    func testRoundTripJSON() throws {
        let m = try WorkspaceManifest(sourceDeviceName: "Mac A", repository: .init(
            origin: "https://github.com/example/project.git", branch: "main", headSHA: sha,
            hasUncommittedChanges: false, hasUntrackedFiles: false),
            resources: [.webURL("https://github.com/example/project/pull/3")])
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try m.write(to: tmp)
        let decoded = try WorkspaceManifest.load(tmp)
        XCTAssertEqual(m.schemaVersion, decoded.schemaVersion)
        XCTAssertEqual(m.repository, decoded.repository)
        XCTAssertEqual(m.resources, decoded.resources)
    }

    func testRejectBadManifestSchemasAndEmbeddedPasswords() throws {
        XCTAssertThrowsError(try manifest(origin: "https://admin:secret@github.com/example/project.git"))
        XCTAssertThrowsError(try manifest(origin: "file:///etc/passwd"))
        XCTAssertThrowsError(try manifest(origin: "http://github.com/x/y"))
        XCTAssertThrowsError(try manifest(origin: "git@github.com:/absolute"))
        XCTAssertNoThrow(try manifest(origin: "git@github.com:example/project.git"))
        XCTAssertThrowsError(try manifest(sha: "bad"))
    }

    func testRejectOversizeAndUnsafeResources() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        try Data(repeating: 42, count: 65537).write(to: temp)
        XCTAssertThrowsError(try WorkspaceManifest.load(temp))
        XCTAssertThrowsError(try WorkspaceManifest(sourceDeviceName: "A",
            repository: try manifest().repository, resources: [.webURL("file:///tmp/payload")]))
        XCTAssertThrowsError(try WorkspaceManifest(sourceDeviceName: "A",
            repository: try manifest().repository, resources: [.webURL("https://token:pwd@site.example/path")]))
    }

    func testSafeHandoffMatchingExistingCleanRepo() throws {
        let a = try manifest()
        let b = try manifest(origin: "git@github.com:example/project.git")
        let plan = try HandoffPlanner().plan(source: a, destination: b,
                                            targetFolder: URL(fileURLWithPath: "/tmp/project"))
        XCTAssertTrue(plan.canOpen)
        XCTAssertTrue(plan.blockers.isEmpty)
    }

    func testNeverChangesRepoIfSourceDirtyOrUntracked() throws {
        let b = try manifest()
        let a = try manifest(dirty: true, untracked: true)
        let plan = try HandoffPlanner().plan(source: a, destination: b, targetFolder: URL(fileURLWithPath: "/tmp"))
        XCTAssertFalse(plan.canOpen)
        XCTAssertEqual(plan.blockers, [.sourceHasChanges, .sourceHasUntrackedFiles])
    }

    func testRejectWrongRepoBranchAndSHA() throws {
        let a = try manifest()
        let b = try manifest(origin: "https://github.com/example/other.git", branch: "feature", sha: String(repeating: "b", count: 40))
        let plan = try HandoffPlanner().plan(source: a, destination: b, targetFolder: URL(fileURLWithPath: "/tmp"))
        XCTAssertEqual(plan.blockers, [.differentRepository, .differentBranch, .differentCommit])
    }

    func testRejectDirtyDestination() throws {
        let a = try manifest()
        let b = try manifest(dirty: true, untracked: true)
        let plan = try HandoffPlanner().plan(source: a, destination: b, targetFolder: URL(fileURLWithPath: "/tmp"))
        XCTAssertEqual(plan.blockers, [.destinationHasChanges, .destinationHasUntrackedFiles])
    }

    func testGitCaptureInRealTemporaryRepository() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inputmesh-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let runner = SystemGitRunner()
        _ = try runner.run(["init", "-q", "-b", "main"], at: dir)
        _ = try runner.run(["config", "user.email", "test@example.com"], at: dir)
        _ = try runner.run(["config", "user.name", "Test"], at: dir)
        _ = try runner.run(["remote", "add", "origin", "https://github.com/example/project.git"], at: dir)
        try "hello".write(to: dir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try runner.run(["add", "README.md"], at: dir)
        _ = try runner.run(["commit", "-qm", "init"], at: dir)
        let inspector = GitWorkspaceInspector()
        let clean = try inspector.capture(at: dir, deviceName: "Local")
        XCTAssertFalse(clean.repository.hasUncommittedChanges)
        XCTAssertFalse(clean.repository.hasUntrackedFiles)
        XCTAssertEqual(clean.repository.branch, "main")
        try "change".write(to: dir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "extra".write(to: dir.appendingPathComponent("scratch.txt"), atomically: true, encoding: .utf8)
        let dirty = try inspector.capture(at: dir, deviceName: "Local")
        XCTAssertTrue(dirty.repository.hasUncommittedChanges)
        XCTAssertTrue(dirty.repository.hasUntrackedFiles)
    }
    func testRepoPathIsCaseSensitiveAndCredentialsNeverSerialized() throws {
        let a = try manifest(origin: "https://github.com/Org/Project.git")
        let b = try manifest(origin: "git@github.com:org/project.git")
        let plan = try HandoffPlanner().plan(source: a, destination: b,
                                            targetFolder: URL(fileURLWithPath: "/tmp/project"))
        XCTAssertEqual(plan.blockers, [.differentRepository])
        let json = String(data: try JSONEncoder().encode(a), encoding: .utf8)!
        XCTAssertFalse(json.contains("token"))
        XCTAssertFalse(json.contains("password"))
    }

    func testInvalidResourceCannotBecomeExecutableInstruction() throws {
        let repo = try manifest().repository
        for candidate in ["file:///private/tmp/x", "javascript:alert(1)",
                          "https://guest:secret@example.com/work", "http://example.com/readme"] {
            XCTAssertThrowsError(try WorkspaceManifest(sourceDeviceName: "Mac",
                  repository: repo, resources: [.webURL(candidate)]), candidate)
        }
    }

    func testCapturedManifestDoesNotIncludeSourceAbsolutePath() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inputmesh-confidential-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let runner = SystemGitRunner()
        _ = try runner.run(["init", "-q", "-b", "main"], at: dir)
        _ = try runner.run(["config", "user.email", "test@example.com"], at: dir)
        _ = try runner.run(["config", "user.name", "Test"], at: dir)
        _ = try runner.run(["remote", "add", "origin", "https://github.com/example/demo.git"], at: dir)
        try "a".write(to: dir.appendingPathComponent("safe.txt"), atomically: true, encoding: .utf8)
        _ = try runner.run(["add", "safe.txt"], at: dir)
        _ = try runner.run(["commit", "-qm", "init"], at: dir)
        let manifestURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: manifestURL) }
        XCTAssertThrowsError(try WorkspaceCommand.capture(
            repository: dir, output: dir.appendingPathComponent("handoff.json"), deviceName: "Host"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("handoff.json").path))
        _ = try WorkspaceCommand.capture(repository: dir, output: manifestURL, deviceName: "Host")
        let payload = try String(contentsOf: manifestURL, encoding: .utf8)
        XCTAssertFalse(payload.contains(dir.path))
        XCTAssertFalse(payload.contains("safe.txt"))
    }

}

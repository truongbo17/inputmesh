import Foundation
import InputMeshCore
import InputMeshMacOS
import InputMeshWorkspace
#if os(macOS)
import ApplicationServices
#endif

@main
struct InputMeshCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        do {
            if args.count == 6 && args[0] == "workspace" && args[1] == "capture" &&
                args[2] == "--repo" && args[4] == "--out" {
                let manifest = try WorkspaceCommand.capture(
                    repository: URL(fileURLWithPath: args[3], isDirectory: true),
                    output: URL(fileURLWithPath: args[5]),
                    deviceName: Host.current().localizedName ?? "This device")
                print("Captured \(manifest.repository.branch) @ \(manifest.repository.headSHA). No working files copied.")
                if manifest.repository.hasUncommittedChanges || manifest.repository.hasUntrackedFiles {
                    print("CAUTION: Source has uncommitted/untracked files. Restore will be BLOCKED.")
                }
            } else if args.count == 6 && args[0] == "workspace" &&
                        (args[1] == "inspect" || args[1] == "continue") &&
                        args[2] == "--manifest" && args[4] == "--repo" {
                let shouldOpen = args[1] == "continue"
                let manifest = URL(fileURLWithPath: args[3])
                let destination = URL(fileURLWithPath: args[5], isDirectory: true)
                let plan = try (shouldOpen
                    ? WorkspaceCommand.continueOnThisDevice(manifestURL: manifest, destination: destination)
                    : WorkspaceCommand.inspect(manifestURL: manifest, destination: destination))
                if plan.canOpen {
                    print("OK: matching clean repository, same branch and commit.")
                    #if os(macOS)
                    if shouldOpen { print("Requested to open repository in VS Code.") }
                    #else
                    if shouldOpen { print("Opening VS Code is supported only on macOS. No changes performed.") }
                    #endif
                } else {
                    print("BLOCKED: \(plan.blockers.map { $0.rawValue }.joined(separator: ", "))")
                    exit(3)
                }
            } else if args == ["--doctor"] {
                #if os(macOS)
                print("Platform: macOS")
                print("Accessibility granted: \(AXIsProcessTrusted() ? "yes" : "no")")
                print("Workspace capture uses local Git only. No remote control services are active.")
                #else
                print("Platform: Linux; portable workspace metadata commands supported.")
                #endif
            } else if args == ["--probe"] {
                #if os(macOS)
                try InputProbe().run()
                #else
                fputs("Native input probe requires macOS.\n", stderr)
                exit(2)
                #endif
            } else if args == ["--help"] || args.isEmpty {
                print("""
                InputMesh Workspace Handoff · local-first preview
                inputmesh workspace capture --repo /path/to/repo --out /path/to/handoff.json
                inputmesh workspace inspect --manifest /path/to/handoff.json --repo /path/to/target/repo
                inputmesh workspace continue --manifest /path/to/handoff.json --repo /path/to/target/repo
                inputmesh --doctor | --probe | --help

                SAFETY: manifest is metadata ONLY. Transfer it through your preferred trusted
                method. Git must already exist on the target; no clone/pull/reset/checkouts
                or unsaved-buffer transfer. 'continue' opens an existing matching clean
                repository in VS Code on macOS; no commands are executed from the manifest.
                """)
            } else {
                fputs("Unknown arguments. Use --help.\n", stderr)
                exit(2)
            }
        } catch {
            fputs("InputMesh error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

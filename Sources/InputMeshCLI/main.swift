import Foundation
import InputMeshCore
import InputMeshMacOS
#if os(macOS)
import ApplicationServices
#endif

@main
struct InputMeshCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.contains("--help") || args.isEmpty {
            print("""
            InputMesh Sprint 0 native feasibility tool
            Usage:
              inputmesh --doctor    Check local macOS prerequisites
              inputmesh --probe     Passive input capture (counts only; no key contents)
              inputmesh --help      Print this help
            IMPORTANT: This is NOT a working multi-device controller yet.
            """)
            return
        }
        #if os(macOS)
        if args == ["--doctor"] {
            print("Platform: macOS")
            print("Accessibility granted: \(AXIsProcessTrusted() ? "yes" : "no")")
            print("Input Monitoring: must be verified via --probe and System Settings")
            print("No network connections made by this command.")
        } else if args == ["--probe"] {
            do { try InputProbe().run() }
            catch { fputs("Probe failed: \(error.localizedDescription)\n", stderr); exit(1) }
        } else {
            fputs("Unknown arguments. Use --help.\n", stderr)
            exit(2)
        }
        #else
        fputs("Native input diagnostic requires macOS. Pure core tests run on Linux.\n", stderr)
        exit(1)
        #endif
    }
}

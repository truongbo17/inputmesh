// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InputMesh",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "InputMeshCore", targets: ["InputMeshCore"]),
        .library(name: "InputMeshPlatform", targets: ["InputMeshPlatform"]),
        .library(name: "InputMeshMacOS", targets: ["InputMeshMacOS"]),
        .executable(name: "inputmesh", targets: ["InputMeshCLI"])
    ],
    targets: [
        .target(name: "InputMeshCore", exclude: ["README.md"]),
        .target(name: "InputMeshPlatform", dependencies: ["InputMeshCore"]),
        .target(name: "InputMeshMacOS", dependencies: ["InputMeshCore", "InputMeshPlatform"]),
        .executableTarget(name: "InputMeshCLI", dependencies: ["InputMeshCore", "InputMeshMacOS"]),
        .testTarget(name: "InputMeshCoreTests", dependencies: ["InputMeshCore"]),
        .testTarget(name: "InputMeshPlatformTests", dependencies: ["InputMeshCore", "InputMeshPlatform"])
    ],
    swiftLanguageModes: [.v5]
)

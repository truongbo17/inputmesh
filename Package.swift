// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [
    .library(name: "InputMeshCore", targets: ["InputMeshCore"]),
    .library(name: "InputMeshPlatform", targets: ["InputMeshPlatform"]),
    .library(name: "InputMeshMacOS", targets: ["InputMeshMacOS"]),
    .executable(name: "inputmesh", targets: ["InputMeshCLI"])
]
var targets: [Target] = [
    .target(name: "InputMeshCore", exclude: ["README.md"]),
    .target(name: "InputMeshPlatform", dependencies: ["InputMeshCore"]),
    .target(name: "InputMeshMacOS", dependencies: ["InputMeshCore", "InputMeshPlatform"]),
    .executableTarget(name: "InputMeshCLI", dependencies: ["InputMeshCore", "InputMeshMacOS"]),
    .testTarget(name: "InputMeshCoreTests", dependencies: ["InputMeshCore"]),
    .testTarget(name: "InputMeshPlatformTests", dependencies: ["InputMeshCore", "InputMeshPlatform"])
]

#if os(macOS)
products.append(.executable(name: "InputMeshDesktop", targets: ["InputMeshDesktop"]))
targets.append(.executableTarget(name: "InputMeshDesktop", dependencies: ["InputMeshCore", "InputMeshPlatform", "InputMeshMacOS"]))
#endif

let package = Package(
    name: "InputMesh",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets,
    swiftLanguageModes: [.v5]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeJig",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FreeJig", targets: ["FreeJig"])],
    targets: [
        .target(name: "FreeJigCore"),
        .executableTarget(name: "FreeJig", dependencies: ["FreeJigCore"]),
        .testTarget(name: "FreeJigCoreTests", dependencies: ["FreeJigCore"])
    ]
)

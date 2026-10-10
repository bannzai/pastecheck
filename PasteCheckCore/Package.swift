// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PasteCheckCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PasteCheckCore", targets: ["PasteCheckCore"]),
    ],
    targets: [
        .target(name: "PasteCheckCore"),
        .testTarget(name: "PasteCheckCoreTests", dependencies: ["PasteCheckCore"]),
    ]
)

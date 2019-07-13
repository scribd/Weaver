// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Weaver",
    platforms: [
       .macOS(.v10_13)
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.23.0"),
        .package(url: "https://github.com/kylef/Commander.git", from: "0.8.0"),
        .package(url: "https://github.com/kylef/Stencil.git", from: "0.12.1"),
        .package(url: "https://github.com/SwiftGen/StencilSwiftKit.git", from: "2.6.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "2.0.0"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "0.9.0")
    ],
    targets: [
        .target(name: "WeaverCodeGen", dependencies: ["SourceKittenFramework", "Stencil", "StencilSwiftKit"]),
        .testTarget(name: "WeaverCodeGenTests", dependencies: ["WeaverCodeGen"]),
        .target(name: "WeaverCommand", dependencies: ["PathKit", "Commander", "Rainbow", "Yams", "WeaverCodeGen"])
    ]
)

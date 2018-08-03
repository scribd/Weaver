// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Weaver",
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.21.0"),
        .package(url: "https://github.com/kylef/Commander.git", from: "0.6.0"),
        .package(url: "https://github.com/kylef/Stencil.git", from: "0.11.0"),
        .package(url: "https://github.com/SwiftGen/StencilSwiftKit.git", from: "2.5.0")
    ],
    targets: [
        .target(name: "WeaverCodeGen", dependencies: ["SourceKittenFramework", "Stencil", "StencilSwiftKit"]),
        .testTarget(name: "WeaverCodeGenTests", dependencies: ["WeaverCodeGen"]),
        .target(name: "WeaverCommand", dependencies: ["Commander", "WeaverCodeGen"])
    ]
)

// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Weaver",
    products: [
        .library(name: "Weaver", targets: ["Weaver"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.19.1"),
        .package(url: "https://github.com/kylef/Commander.git", from: "0.6.0"),
        .package(url: "https://github.com/kylef/Stencil.git", from: "0.10.1")
    ],
    targets: [
        .target(name: "Weaver"),
        .testTarget(name: "WeaverTests", dependencies: ["Weaver"]),
        .target(name: "WeaverCodeGen", dependencies: ["SourceKittenFramework", "Stencil", "Weaver"]),
        .testTarget(name: "WeaverCodeGenTests", dependencies: ["WeaverCodeGen"]),
        .target(name: "WeaverCommand", dependencies: ["Commander", "WeaverCodeGen"])
    ]
)

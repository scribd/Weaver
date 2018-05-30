// swift-tools-version:4.1
import PackageDescription

let package = Package(
    name: "WeaverDI",
    products: [
        .library(name: "WeaverDI", targets: ["WeaverDI"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.19.1"),
        .package(url: "https://github.com/kylef/Commander.git", from: "0.6.0"),
        .package(url: "https://github.com/kylef/Stencil.git", from: "0.10.1")
    ],
    targets: [
        .target(name: "WeaverDI"),
        .testTarget(name: "WeaverDITests", dependencies: ["WeaverDI"]),
        .target(name: "WeaverCodeGen", dependencies: ["SourceKittenFramework", "Stencil", "WeaverDI"]),
        .testTarget(name: "WeaverCodeGenTests", dependencies: ["WeaverCodeGen"]),
        .target(name: "WeaverCommand", dependencies: ["Commander", "WeaverCodeGen"])
    ]
)
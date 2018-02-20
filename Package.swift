// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "BeaverDI",
    products: [
        .library(name: "BeaverDI", targets: ["BeaverDI"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.19.1"),
        .package(url: "https://github.com/kylef/Commander.git", from: "0.6.0")
    ],
    targets: [
        .target(name: "BeaverDI"),
        .testTarget(name: "BeaverDITests"),
        .target(name: "BeaverDICodeGen", dependencies: ["SourceKittenFramework"]),
        .testTarget(name: "BeaverDICodeGenTests"),
        .target(name: "BeaverDICommand", dependencies: ["Commander", "BeaverDICodeGen"])
    ]
)

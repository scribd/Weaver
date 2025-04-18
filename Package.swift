// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Weaver",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Weaver", targets: ["WeaverMain"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.37.0"),
        .package(url: "https://github.com/kylef/Commander.git", from: "0.9.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "0.9.0"),
        .package(url: "https://github.com/scribd/Meta.git", .branch("master")),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.2.0")
    ],
    targets: [
        .target(name: "WeaverCodeGen", dependencies: [
            .product(name: "SourceKittenFramework", package: "SourceKitten"),
            "Meta",
            "PathKit"
        ]),
        .testTarget(name: "WeaverCodeGenTests", dependencies: ["WeaverCodeGen"]),
        .target(name: "WeaverCommand", dependencies: ["PathKit", "Commander", "Rainbow", "Yams", "WeaverCodeGen", "ShellOut"]),
        .testTarget(name: "WeaverCommandTests", dependencies: ["WeaverCommand"]),
        .executableTarget(name: "WeaverMain", dependencies: ["WeaverCommand"])
    ]
)

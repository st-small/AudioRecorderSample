// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Experiment",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "Experiment", targets: ["Experiment"]),
        .library(name: "NumbersClient", targets: ["NumbersClient"]),
        .library(name: "NumbersCore", targets: ["NumbersCore"]),
        .library(name: "NumbersView", targets: ["NumbersView"]),
        .library(name: "AudioRecorderClient", targets: ["AudioRecorderClient"]),
        .library(name: "AudioRecorderCore", targets: ["AudioRecorderCore"]),
        .library(name: "AudioRecorderView", targets: ["AudioRecorderView"]),
        .library(name: "TemporaryDirectory", targets: ["TemporaryDirectory"]),
        .library(name: "Helpers", targets: ["Helpers"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.6.0")),
    ],
    targets: [
        .target(name: "Experiment"),
        .target(name: "Helpers"),
        .testTarget(
            name: "ExperimentTests",
            dependencies: ["Experiment"]),
        .target(
            name: "NumbersClient",
            dependencies: [
                "Helpers",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]),
        .target(
            name: "NumbersCore",
            dependencies: [
                "NumbersClient",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]),
        .target(
            name: "NumbersView",
            dependencies: ["NumbersCore"]),
        .target(
            name: "AudioRecorderClient",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]),
        .target(
            name: "AudioRecorderCore",
            dependencies: [
                "AudioRecorderClient", "TemporaryDirectory",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]),
        .target(
            name: "AudioRecorderView",
            dependencies: ["Helpers", "AudioRecorderCore"]),
        .target(
            name: "TemporaryDirectory",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]),
    ]
)

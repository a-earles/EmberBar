// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EmberBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "EmberBar",
            path: "EmberBar",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)

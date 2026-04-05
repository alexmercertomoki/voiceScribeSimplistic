// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "VoiceScribe",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "VoiceScribe",
            path: "Sources/VoiceScribe",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

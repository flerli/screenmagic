// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenMagic",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ScreenMagic",
            path: "Sources"
        )
    ]
)

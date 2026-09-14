// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Franco",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Franco",
            path: "Sources/Franco",
            swiftSettings: [.unsafeFlags(["-Onone"], .when(configuration: .debug))]
        )
    ]
)

// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "term-beam",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "term-beam", targets: ["term-beam"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.15.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "term-beam",
            dependencies: [
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        )
    ]
)
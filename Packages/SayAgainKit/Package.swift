// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SayAgainKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SayAgainKit", targets: ["SayAgainKit"])
    ],
    targets: [
        .target(
            name: "SayAgainKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SayAgainKitTests",
            dependencies: ["SayAgainKit"]
        )
    ]
)

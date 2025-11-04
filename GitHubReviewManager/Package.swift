// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitHubReviewManager",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "GitHubReviewManager",
            targets: ["GitHubReviewManager"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GitHubReviewManager",
            dependencies: [],
            path: "GitHubReviewManager",
            exclude: ["Resources/Info.plist"], // Info.plist needs special handling
            resources: [
                .process("Resources")
            ]
        )
    ]
)


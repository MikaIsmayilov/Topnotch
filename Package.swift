// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Topnotch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Topnotch",
            path: "Sources/Topnotch"
        )
    ]
)

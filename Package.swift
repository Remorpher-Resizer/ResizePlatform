// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ResizePlatform",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "ResizePlatform", targets: ["ResizePlatform"]),
        .library(name: "ResizePlatform", targets: ["ResizePlatform"])
    ],
    dependencies: [
        // No external dependencies
    ],
    targets: [
        .target(
            name: "ResizePlatform",
            dependencies: []
        )
    ]
) 
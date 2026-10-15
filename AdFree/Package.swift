// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AdFree",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "AdFree", path: "Sources/AdFree")
    ]
)

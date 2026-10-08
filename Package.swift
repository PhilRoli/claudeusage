// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "https://github.com/PhilRoli/menubar-kit", from: "1.1.0")],
    targets: [
        .executableTarget(
            name: "ClaudeUsage",
            dependencies: [.product(name: "MenuBarKit", package: "menubar-kit")],
            path: "Sources/ClaudeUsage"
        ),
        .testTarget(
            name: "ClaudeUsageTests",
            dependencies: ["ClaudeUsage", .product(name: "MenuBarKit", package: "menubar-kit")],
            path: "Tests/ClaudeUsageTests"
        )
    ]
)

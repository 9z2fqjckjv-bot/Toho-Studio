// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TohoStudio",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TohoStudio", targets: ["TohoStudio"])
    ],
    targets: [
        .executableTarget(
            name: "TohoStudio",
            path: "Sources/TohoStudio"
        )
    ]
)

// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TohoMovieStudio",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TohoMovieStudio", targets: ["TohoMovieStudio"])
    ],
    targets: [
        .executableTarget(name: "TohoMovieStudio")
    ]
)

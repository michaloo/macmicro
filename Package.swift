// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacMicro",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "MacMicro",
            dependencies: ["SwiftTerm"],
            path: "Sources",
            exclude: ["CLI"],
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "macmicro-cli",
            path: "Sources/CLI"
        ),
    ]
)

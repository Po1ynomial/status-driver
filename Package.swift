// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "StatusDriver",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .target(name: "StatusDriverCore"),
        .executableTarget(
            name: "StatusDriver",
            dependencies: ["StatusDriverCore"]
        ),
        .executableTarget(
            name: "StatusDriverModelTests",
            dependencies: ["StatusDriverCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)

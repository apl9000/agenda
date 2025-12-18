// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Agenda",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "agenda",
            targets: ["Agenda"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Agenda",
            dependencies: [],
            path: "Sources/Agenda"
        ),
        .testTarget(
            name: "AgendaTests",
            dependencies: ["Agenda"],
            path: "Tests/AgendaTests"
        )
    ]
)

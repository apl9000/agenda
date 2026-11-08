// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// ld opens the -sectcreate file from its working directory, which is not
// necessarily the package root (for example `swift build` invoked via an
// absolute path from another cwd). An absolute path keeps the link stable.
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let infoPlistPath = packageRoot + "/Sources/Agenda/Info.plist"

// SwiftPM copies `linkerSettings` into OTHER_LDFLAGS and, through the Swift
// 6.4 release branch, passes those strings to `swiftc` unchanged. `swiftc`
// forwards an argument to ld only when it is preceded by `-Xlinker`.
// Command-line `-Xlinker` flags are a different path: SwiftPM runs those
// through `asSwiftcLinkerFlags()`, so they must not be prefixed again here.
//
// `unsafeFlags` is the only Package.swift API that can pass `-sectcreate`.
// A target that uses it cannot be a dependency of another package. Tests in
// this package can still depend on Agenda. Info.plist is excluded from the
// target because SwiftPM rejects a resource named Info.plist; the linker
// reads the file from source. No Developer ID is required: SwiftPM ad-hoc
// signs the product with `codesign --sign -` after the section exists, so
// the signature covers `__TEXT,__info_plist`.
let embedInfoPlistFlags = [
    "-Xlinker", "-sectcreate",
    "-Xlinker", "__TEXT",
    "-Xlinker", "__info_plist",
    "-Xlinker", infoPlistPath,
]

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
            path: "Sources/Agenda",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(embedInfoPlistFlags)
            ]
        ),
        .testTarget(
            name: "AgendaTests",
            dependencies: ["Agenda"],
            path: "Tests/AgendaTests"
        )
    ]
)

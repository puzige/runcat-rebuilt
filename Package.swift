// swift-tools-version:5.9
//
// RunCat — preservation rebuild of com.kyome.RunCat (delisted from the
// Mac App Store). See README.md for details.
//
// Tools version 5.9 pins the Swift 5 language mode for all targets
// (equivalent to swiftLanguageVersion(.v5)), which keeps this package
// buildable with the Command Line Tools toolchain without tripping
// Swift 6 strict concurrency diagnostics.
//
// Build the executable with `swift build -c release` and assemble the
// .app bundle with `scripts/build.sh`.

import PackageDescription

let package = Package(
    name: "RunCat",
    platforms: [
        .macOS(.v10_14)
    ],
    targets: [
        .executableTarget(
            name: "RunCat",
            path: "Sources/RunCat"
        )
    ]
)

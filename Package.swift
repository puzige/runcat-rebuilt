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
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Vendored copy of https://github.com/Kyome22/SystemInfoKit
        // (Apache-2.0, © Takuto Nakamura) — the official data layer of
        // RunCat, pinned as a local target so the repository stays
        // self-contained. Keep the Apache-2.0 headers in every file.
        .target(
            name: "SystemInfoKit",
            path: "Sources/SystemInfoKit",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "RunCat",
            dependencies: ["SystemInfoKit"],
            path: "Sources/RunCat"
        )
    ]
)

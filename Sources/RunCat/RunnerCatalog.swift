/*
 RunnerCatalog.swift
 RunCat (preservation rebuild)

 Based on "Menubar RunCat" by Takuto Nakamura.
 Copyright © 2019 Takuto Nakamura. All rights reserved.

 Licensed under the Apache License, Version 2.0.

 Runner metadata for the dashboard's runner picker. All runner frame
 directories live in the app bundle under "runners/<id>/page-N@1x.png"
 (extracted from the original delisted App Store binary). Categories,
 frame counts and display names are a reasonable reconstruction: the
 category labels come from the original Dashboard.strings and the
 display names from the original RunnerName.strings, but the grouping
 itself is an approximation (the original grouping table is not
 recoverable from the extracted assets).
*/

import AppKit
import CoreImage
import Foundation

enum RunnerCategory: String, CaseIterable {
    case defaultRunners = "categoryDefault"
    case animal = "categoryAnimal"
    case inanimate = "categoryInanimate"
    case seasonal = "categorySeasonal"
    case special = "categorySpecial"
}

struct Runner: Identifiable {
    let id: String
    let frameCount: Int
    let category: RunnerCategory

    /// Display name from the original RunnerName.strings (falls back to the id).
    var displayName: String {
        let key = RunnerCatalog.localizationKeyByAssetID[id] ?? id
        return Bundle.main.localizedString(forKey: key, value: key, table: "RunnerName")
    }

    func frame(at index: Int) -> NSImage? {
        // The extracted App Store resources retain the asset name in each
        // filename (for example runners/cat/cat-page-0@1x.png).  Looking up
        // only "page-0" silently returned nil.  Bundle.image(forResource:)
        // also does not recursively resolve these preserved subdirectories,
        // so construct the URL explicitly.
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let imageURL = resourceURL
            .appendingPathComponent("runners", isDirectory: true)
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("\(id)-page-\(index)@1x.png")
        guard let image = NSImage(contentsOf: imageURL) else { return nil }
        // Asset-catalog rendering intent is lost when the preserved PNGs are
        // copied out of Assets.car.  Restore template rendering for the
        // monochrome families so thumbnails follow light/dark appearance;
        // special-colored runners must retain their original pixels.
        image.isTemplate = category != .special
        return image
    }

    /// Classic's picker displays every runner on a trailing-aligned 50 x 18
    /// point canvas. The archived assets are 36 pixels high, so normalizing
    /// them to 18 points preserves their native Retina pixels without the
    /// 56 x 28 point resampling that made the rebuild look enlarged and soft.
    func thumbnail(at index: Int = 0) -> NSImage? {
        guard let image = frame(at: index) else { return nil }
        image.normalizeClassicRunnerHeight()
        image.resizeClassicThumbnailCanvas(width: 50)
        image.isTemplate = category != .special
        return image
    }

    func allFrames() -> [NSImage] {
        (0 ..< frameCount).compactMap { frame(at: $0) }
    }
}

private extension NSImage {
    var classicCIImage: CIImage? {
        guard let data = tiffRepresentation else { return nil }
        return CIImage(data: data)
    }

    func normalizeClassicRunnerHeight() {
        guard size.height > 0 else { return }
        let scale = size.height / 18
        size = NSSize(width: size.width / scale, height: size.height / scale)
    }

    func resizeClassicThumbnailCanvas(width: CGFloat) {
        guard let classicCIImage, size.height > 0, width > 0 else { return }
        let pixelHeight = classicCIImage.extent.height
        let pixelScale = pixelHeight / size.height
        let targetPixelWidth = width * pixelScale
        let trailingOffset = targetPixelWidth - classicCIImage.extent.width
        let translated = classicCIImage.transformed(
            by: CGAffineTransform(translationX: trailingOffset, y: 0)
        )
        let canvasRect = CGRect(x: 0, y: 0, width: targetPixelWidth, height: pixelHeight)
        let canvas = CIImage(color: .clear).cropped(to: canvasRect)
        let output = translated.composited(over: canvas).cropped(to: canvasRect)
        let representation = NSCIImageRep(ciImage: output)
        representations.forEach(removeRepresentation)
        addRepresentation(representation)
        size = NSSize(width: width, height: size.height)
    }
}

enum RunnerCatalog {
    /// The original app's default runner.
    static let defaultRunnerID = "cat"

    /// Asset directories use kebab-case while the original localization table
    /// retained its StoreKit-era identifiers.
    static let localizationKeyByAssetID: [String: String] = [
        "all-runners": "runners_all", "cat-b": "b_cat", "cat-c": "c_cat",
        "cat-tail": "tail_cat", "flash-cat": "cat_flash",
        "golden-cat": "cat_golden", "hamster-wheel": "wheel_hamster",
        "jack-o-lantern": "lantern_o_jack", "maneki-neko": "neko_maneki",
        "metal-cluster-cat": "cat_cluster_metal", "mock-nyan-cat": "cat_nyan_mock",
        "party-people": "people_party", "push-up": "up_push",
        "reindeer-sleigh": "sleigh_reindeer", "rotating-sushi": "sushi_rotating",
        "rubber-duck": "duck_rubber", "self-made": "made_self",
        "sine-curve": "curve_sine", "sit-up": "up_sit",
        "steam-locomotive": "locomotive_steam", "tapioca-drink": "drink_tapioca",
        "welsh-corgi": "corgi_welsh", "wind-chime": "chime_wind",
    ]

    static let all: [Runner] = [
        // Default Runners — the nine built-ins shown by Classic 12.8.
        Runner(id: "cat", frameCount: 5, category: .defaultRunners),
        Runner(id: "cat-b", frameCount: 5, category: .defaultRunners),
        Runner(id: "cat-c", frameCount: 5, category: .defaultRunners),
        Runner(id: "cat-tail", frameCount: 5, category: .defaultRunners),
        Runner(id: "mock-nyan-cat", frameCount: 5, category: .defaultRunners),
        Runner(id: "parrot", frameCount: 10, category: .defaultRunners),
        Runner(id: "human", frameCount: 5, category: .defaultRunners),
        Runner(id: "push-up", frameCount: 5, category: .defaultRunners),
        Runner(id: "sit-up", frameCount: 5, category: .defaultRunners),

        // Animal Type Runners.
        Runner(id: "bird", frameCount: 5, category: .animal),
        Runner(id: "butterfly", frameCount: 5, category: .animal),
        Runner(id: "chameleon", frameCount: 5, category: .animal),
        Runner(id: "cheetah", frameCount: 5, category: .animal),
        Runner(id: "chicken", frameCount: 5, category: .animal),
        Runner(id: "dinosaur", frameCount: 7, category: .animal),
        Runner(id: "dog", frameCount: 5, category: .animal),
        Runner(id: "dolphin", frameCount: 5, category: .animal),
        Runner(id: "fox", frameCount: 5, category: .animal),
        Runner(id: "frog", frameCount: 5, category: .animal),
        Runner(id: "golden-cat", frameCount: 10, category: .animal),
        Runner(id: "greyhound", frameCount: 14, category: .animal),
        Runner(id: "hamster-wheel", frameCount: 5, category: .animal),
        Runner(id: "hedgehog", frameCount: 5, category: .animal),
        Runner(id: "horse", frameCount: 5, category: .animal),
        Runner(id: "maneki-neko", frameCount: 15, category: .animal),
        Runner(id: "mouse", frameCount: 5, category: .animal),
        Runner(id: "octopus", frameCount: 5, category: .animal),
        Runner(id: "otter", frameCount: 8, category: .animal),
        Runner(id: "owl", frameCount: 5, category: .animal),
        Runner(id: "penguin", frameCount: 5, category: .animal),
        Runner(id: "penguin2", frameCount: 5, category: .animal),
        Runner(id: "pig", frameCount: 5, category: .animal),
        Runner(id: "puppy", frameCount: 5, category: .animal),
        Runner(id: "rabbit", frameCount: 5, category: .animal),
        Runner(id: "sheep", frameCount: 5, category: .animal),
        Runner(id: "squirrel", frameCount: 5, category: .animal),
        Runner(id: "terrier", frameCount: 5, category: .animal),
        Runner(id: "welsh-corgi", frameCount: 7, category: .animal),
        Runner(id: "whale", frameCount: 5, category: .animal),

        // Inanimate Type Runners.
        Runner(id: "bonfire", frameCount: 5, category: .inanimate),
        Runner(id: "coffee", frameCount: 10, category: .inanimate),
        Runner(id: "cogwheel", frameCount: 5, category: .inanimate),
        Runner(id: "cradle", frameCount: 5, category: .inanimate),
        Runner(id: "dragon", frameCount: 5, category: .inanimate),
        Runner(id: "drop", frameCount: 5, category: .inanimate),
        Runner(id: "earth", frameCount: 15, category: .inanimate),
        Runner(id: "engine", frameCount: 10, category: .inanimate),
        Runner(id: "factory", frameCount: 16, category: .inanimate),
        Runner(id: "fishman", frameCount: 5, category: .inanimate),
        Runner(id: "frypan", frameCount: 5, category: .inanimate),
        Runner(id: "mochi", frameCount: 5, category: .inanimate),
        Runner(id: "pulse", frameCount: 5, category: .inanimate),
        Runner(id: "reactor", frameCount: 5, category: .inanimate),
        Runner(id: "rocket", frameCount: 5, category: .inanimate),
        Runner(id: "rotating-sushi", frameCount: 6, category: .inanimate),
        Runner(id: "rubber-duck", frameCount: 5, category: .inanimate),
        Runner(id: "sausage", frameCount: 5, category: .inanimate),
        Runner(id: "slime", frameCount: 5, category: .inanimate),
        Runner(id: "sine-curve", frameCount: 5, category: .inanimate),
        Runner(id: "steam-locomotive", frameCount: 10, category: .inanimate),
        Runner(id: "sushi", frameCount: 16, category: .inanimate),
        Runner(id: "tapioca-drink", frameCount: 5, category: .inanimate),
        Runner(id: "triforce", frameCount: 9, category: .inanimate),
        Runner(id: "wind-chime", frameCount: 5, category: .inanimate),

        // Seasonal Runners.
        Runner(id: "ghost", frameCount: 5, category: .seasonal),
        Runner(id: "jack-o-lantern", frameCount: 5, category: .seasonal),
        Runner(id: "reindeer-sleigh", frameCount: 5, category: .seasonal),
        Runner(id: "snowman", frameCount: 5, category: .seasonal),
        Runner(id: "sparkler", frameCount: 5, category: .seasonal),

        // Special-Colored Runners.
        Runner(id: "city", frameCount: 10, category: .special),
        Runner(id: "dogeza", frameCount: 8, category: .special),
        Runner(id: "dots", frameCount: 10, category: .special),
        Runner(id: "entaku", frameCount: 9, category: .special),
        Runner(id: "flash-cat", frameCount: 5, category: .special),
        Runner(id: "metal-cluster-cat", frameCount: 10, category: .special),
        Runner(id: "party-people", frameCount: 14, category: .special),
        Runner(id: "pendulum", frameCount: 5, category: .special),
        Runner(id: "uhooi", frameCount: 10, category: .special),
    ]

    static func runner(withID id: String) -> Runner {
        all.first { $0.id == id } ?? all.first { $0.id == defaultRunnerID }!
    }

    static func groupedByCategory() -> [(RunnerCategory, [Runner])] {
        RunnerCategory.allCases.compactMap { category in
            let runners = all.filter { $0.category == category }
            return runners.isEmpty ? nil : (category, runners)
        }
    }
}

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
        Bundle.main.localizedString(forKey: id, value: id, table: "RunnerName")
    }

    func frame(at index: Int) -> NSImage? {
        Bundle.main.image(forResource: NSImage.Name("runners/\(id)/page-\(index)@1x"))
    }

    func allFrames() -> [NSImage] {
        (0 ..< frameCount).compactMap { frame(at: $0) }
    }
}

enum RunnerCatalog {
    /// The original app's default runner.
    static let defaultRunnerID = "cat"

    static let all: [Runner] = [
        // Default Runners — the eight free runners of the original app.
        Runner(id: "cat", frameCount: 5, category: .defaultRunners),
        Runner(id: "dog", frameCount: 5, category: .defaultRunners),
        Runner(id: "slime", frameCount: 5, category: .defaultRunners),
        Runner(id: "drop", frameCount: 5, category: .defaultRunners),
        Runner(id: "coffee", frameCount: 10, category: .defaultRunners),
        Runner(id: "cradle", frameCount: 5, category: .defaultRunners),
        Runner(id: "engine", frameCount: 10, category: .defaultRunners),
        Runner(id: "mochi", frameCount: 5, category: .defaultRunners),
        Runner(id: "rubber-duck", frameCount: 5, category: .defaultRunners),

        // Animal Type Runners.
        Runner(id: "bird", frameCount: 5, category: .animal),
        Runner(id: "butterfly", frameCount: 5, category: .animal),
        Runner(id: "cat-b", frameCount: 5, category: .animal),
        Runner(id: "cat-c", frameCount: 5, category: .animal),
        Runner(id: "cat-tail", frameCount: 5, category: .animal),
        Runner(id: "chameleon", frameCount: 5, category: .animal),
        Runner(id: "cheetah", frameCount: 5, category: .animal),
        Runner(id: "chicken", frameCount: 5, category: .animal),
        Runner(id: "dinosaur", frameCount: 7, category: .animal),
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
        Runner(id: "parrot", frameCount: 10, category: .animal),
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
        Runner(id: "cogwheel", frameCount: 5, category: .inanimate),
        Runner(id: "dragon", frameCount: 5, category: .inanimate),
        Runner(id: "earth", frameCount: 15, category: .inanimate),
        Runner(id: "factory", frameCount: 16, category: .inanimate),
        Runner(id: "fishman", frameCount: 5, category: .inanimate),
        Runner(id: "frypan", frameCount: 5, category: .inanimate),
        Runner(id: "human", frameCount: 5, category: .inanimate),
        Runner(id: "pulse", frameCount: 5, category: .inanimate),
        Runner(id: "push-up", frameCount: 5, category: .inanimate),
        Runner(id: "reactor", frameCount: 5, category: .inanimate),
        Runner(id: "rocket", frameCount: 5, category: .inanimate),
        Runner(id: "rotating-sushi", frameCount: 6, category: .inanimate),
        Runner(id: "sausage", frameCount: 5, category: .inanimate),
        Runner(id: "sine-curve", frameCount: 5, category: .inanimate),
        Runner(id: "sit-up", frameCount: 5, category: .inanimate),
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
        Runner(id: "mock-nyan-cat", frameCount: 5, category: .special),
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

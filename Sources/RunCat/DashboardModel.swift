/*
 DashboardModel.swift
 RunCat (preservation rebuild)

 Based on "Menubar RunCat" by Takuto Nakamura.
 Copyright © 2019 Takuto Nakamura. All rights reserved.

 Licensed under the Apache License, Version 2.0.
 Modified for the RunCat preservation rebuild, 2026.

 Simple ObservableObject model that drives the dashboard popover.
 System metrics come from the vendored SystemInfoKit (the official
 RunCat data layer): a 1-second monitor interval feeds an AsyncStream
 of SystemInfoBundle updates. Unlike RunCat Neo's point-free dependency
 injection, this is deliberately kept minimal. Published properties are
 only mutated on the main thread (the stream forwarding task is pinned
 to @MainActor), keeping the rest of the app free of actor plumbing.
*/

import Combine
import Foundation
import SystemInfoKit

final class DashboardModel: ObservableObject {
    enum Page: Equatable {
        case dashboard
        case runners
        case settings
    }

    @Published var page: Page = .dashboard
    @Published var systemInfo = SystemInfoBundle()
    @Published var selectedRunnerID: String {
        didSet {
            UserDefaults.standard.set(selectedRunnerID, forKey: "selectedRunner")
            onRunnerChanged?(selectedRunnerID)
        }
    }
    @Published var isShowUsage: Bool {
        didSet {
            UserDefaults.standard.set(isShowUsage, forKey: "showUsage")
            onShowUsageChanged?(isShowUsage)
        }
    }

    var onRunnerChanged: ((String) -> Void)?
    var onShowUsageChanged: ((Bool) -> Void)?

    private var streamTask: Task<Void, Never>? = nil
    private var isMonitoring = false

    init() {
        selectedRunnerID = UserDefaults.standard.string(forKey: "selectedRunner") ?? RunnerCatalog.defaultRunnerID
        isShowUsage = UserDefaults.standard.bool(forKey: "showUsage")
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        let observer = SystemInfoObserver.shared
        observer.startMonitoring(monitorInterval: 1.0)
        streamTask = Task { @MainActor [weak self] in
            for await bundle in observer.systemInfoStream() {
                guard let self else { return }
                self.systemInfo = bundle
            }
        }
    }

    func stopMonitoring() {
        streamTask?.cancel()
        streamTask = nil
        SystemInfoObserver.shared.stopMonitoring()
        isMonitoring = false
    }

    // MARK: - Localized labels (original App Store strings)

    func string(_ key: String, table: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: table)
    }
}

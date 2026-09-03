/*
 DashboardModel.swift
 RunCat (preservation rebuild)

 Based on "Menubar RunCat" by Takuto Nakamura.
 Copyright © 2019 Takuto Nakamura. All rights reserved.

 Licensed under the Apache License, Version 2.0.
 Modified for the RunCat preservation rebuild, 2026.

 Simple ObservableObject model that drives the dashboard popover.
 System metrics come from the vendored SystemInfoKit (the official
 RunCat data layer): Classic's 5-second monitor interval feeds an AsyncStream
 of SystemInfoBundle updates. Unlike RunCat Neo's point-free dependency
 injection, this is deliberately kept minimal. Published properties are
 only mutated on the main thread (the stream forwarding task is pinned
 to @MainActor), keeping the rest of the app free of actor plumbing.
*/

import Combine
import Foundation
import AppKit
import SystemInfoKit

private struct SystemInfoBarPreferences: Codable {
    var showMemory: Bool
    var batteryIndicatorType: Int
    var storageIndicatorType: Int
    var showCPU: Bool
    var cpuIndicatorType: Int
    var showNetwork: Bool
    var memoryIndicatorType: Int
    var showBattery: Bool
    var showStorage: Bool
}

struct DashboardMonitoringSelection: Equatable, Sendable {
    var memory: Bool
    var storage: Bool
    var battery: Bool
    var network: Bool
}

final class DashboardModel: ObservableObject {
    enum Page: Equatable {
        case dashboard
        case runners
        case settings
        case more

        var canvasSize: CGSize {
            switch self {
            case .more:
                return CGSize(width: 292, height: 216)
            case .dashboard, .runners, .settings:
                return CGSize(width: 292, height: 440)
            }
        }
    }

    @Published var page: Page = .dashboard {
        didSet {
            onPageChanged?(page)
        }
    }
    @Published var isRunnerListPresented = false
    @Published var systemInfo = SystemInfoBundle() {
        didSet {
            onDashboardSizeChanged?()
        }
    }
    @Published private(set) var monitorRevision = 0
    @Published private(set) var cpuHistory = Array(repeating: 0.0, count: 61)
    @Published private(set) var memoryHistory = Array(repeating: 0.0, count: 61)
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
    @Published var activateSystemInfoBar: Bool {
        didSet {
            UserDefaults.standard.set(activateSystemInfoBar, forKey: "activateSystemInfoBar")
        }
    }
    @Published var showMemory: Bool {
        didSet {
            persistSystemInfoBarPreferences()
            applyMonitoringSelection()
        }
    }
    @Published var showStorage: Bool {
        didSet {
            persistSystemInfoBarPreferences()
            applyMonitoringSelection()
        }
    }
    @Published var showBattery: Bool {
        didSet {
            persistSystemInfoBarPreferences()
            applyMonitoringSelection()
        }
    }
    @Published var showNetwork: Bool {
        didSet {
            persistSystemInfoBarPreferences()
            applyMonitoringSelection()
        }
    }
    @Published var invertSpeed: Bool { didSet { persist("invertSpeed", invertSpeed) } }
    @Published var flipHorizontally: Bool { didSet { persist("flipHorizontally", flipHorizontally) } }
    @Published var useAccentColor: Bool { didSet { persist("useAccentColor", useAccentColor) } }
    @Published var selectAutomatically: Bool { didSet { persist("selectAutomatically", selectAutomatically) } }
    @Published var onlyMonochromeRunners: Bool { didSet { persist("onlyMonochromeRunners", onlyMonochromeRunners) } }
    @Published var stopRunner: Bool { didSet { persist("stopRunner", stopRunner) } }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            onLaunchAtLoginChanged?(launchAtLogin)
        }
    }

    var onRunnerChanged: ((String) -> Void)?
    var onShowUsageChanged: ((Bool) -> Void)?
    var onRunnerPreferencesChanged: (() -> Void)?
    var onPageChanged: ((Page) -> Void)?
    var onDashboardSizeChanged: (() -> Void)?
    var onLaunchAtLoginChanged: ((Bool) -> Void)?

    private var streamTask: Task<Void, Never>? = nil
    private var isMonitoring = false

    var monitoringSelection: DashboardMonitoringSelection {
        DashboardMonitoringSelection(
            memory: showMemory,
            storage: showStorage,
            battery: showBattery,
            network: showNetwork
        )
    }

    /// Classic keeps a 196 pt information card for ordinary metrics, then
    /// grows it when a localized single-line value needs more room.  The
    /// 80/68 pt additions account for the card padding, icon column, HStack
    /// spacing, and the extra detail indentation measured from the 12.8
    /// MacBook reference capture.
    var systemInfoCardWidth: CGFloat {
        Self.systemInfoCardWidth(for: systemInfo, selection: monitoringSelection)
    }

    var canvasSize: CGSize {
        guard page == .dashboard else { return page.canvasSize }
        return CGSize(width: systemInfoCardWidth + 96, height: 440)
    }

    static func systemInfoCardWidth(
        for bundle: SystemInfoBundle,
        selection: DashboardMonitoringSelection
    ) -> CGFloat {
        var summaries = [String]()
        var details = [String]()

        func include(_ info: (any SystemInfo)?) {
            guard let info else { return }
            summaries.append(info.summary)
            details.append(contentsOf: info.details)
        }

        include(bundle.cpuInfo)
        if selection.memory { include(bundle.memoryInfo) }
        if selection.storage { include(bundle.storageInfo) }
        if selection.battery, let battery = bundle.batteryInfo {
            summaries.append(battery.summary)
            if battery.isInstalled {
                details.append(contentsOf: battery.details)
            }
        }
        if selection.network { include(bundle.networkInfo) }

        let summaryFont = NSFont.preferredFont(forTextStyle: .body)
        let detailFont = NSFont.preferredFont(forTextStyle: .caption1)
        let summaryWidth = summaries.map { textWidth($0, font: summaryFont) + 68 }.max() ?? 0
        let detailWidth = details.map { textWidth($0, font: detailFont) + 80 }.max() ?? 0
        return max(196, ceil(max(summaryWidth, detailWidth)))
    }

    private static func textWidth(_ string: String, font: NSFont) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: font]).width
    }

    init() {
        let systemInfoBarPreferences = Self.loadSystemInfoBarPreferences()
        selectedRunnerID = UserDefaults.standard.string(forKey: "selectedRunner") ?? RunnerCatalog.defaultRunnerID
        isShowUsage = UserDefaults.standard.bool(forKey: "showUsage")
        activateSystemInfoBar = Self.storedBool("activateSystemInfoBar", defaultValue: true)
        showMemory = systemInfoBarPreferences.showMemory
        showStorage = systemInfoBarPreferences.showStorage
        showBattery = systemInfoBarPreferences.showBattery
        showNetwork = systemInfoBarPreferences.showNetwork
        invertSpeed = UserDefaults.standard.bool(forKey: "invertSpeed")
        flipHorizontally = UserDefaults.standard.bool(forKey: "flipHorizontally")
        useAccentColor = UserDefaults.standard.bool(forKey: "useAccentColor")
        selectAutomatically = UserDefaults.standard.bool(forKey: "selectAutomatically")
        onlyMonochromeRunners = UserDefaults.standard.bool(forKey: "onlyMonochromeRunners")
        stopRunner = UserDefaults.standard.bool(forKey: "stopRunner")
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    private func persist(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        onRunnerPreferencesChanged?()
    }

    private static func storedBool(_ key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func loadSystemInfoBarPreferences() -> SystemInfoBarPreferences {
        if let data = UserDefaults.standard.data(forKey: "systemInfoBarBundle"),
           let preferences = try? JSONDecoder().decode(SystemInfoBarPreferences.self, from: data) {
            return preferences
        }

        // Keep every monitor enabled on first launch. CPU remains available
        // to the runner even though it is not exposed as a switch here.
        return SystemInfoBarPreferences(
            showMemory: true,
            batteryIndicatorType: 0,
            storageIndicatorType: 0,
            showCPU: true,
            cpuIndicatorType: 0,
            showNetwork: true,
            memoryIndicatorType: 0,
            showBattery: true,
            showStorage: true
        )
    }

    private func persistSystemInfoBarPreferences() {
        let preferences = SystemInfoBarPreferences(
            showMemory: showMemory,
            batteryIndicatorType: 0,
            storageIndicatorType: 0,
            showCPU: true,
            cpuIndicatorType: 0,
            showNetwork: showNetwork,
            memoryIndicatorType: 0,
            showBattery: showBattery,
            showStorage: showStorage
        )
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "systemInfoBarBundle")
        }
    }

    private var monitoringRequests: [SystemInfoType: Bool] {
        [
            .cpu: true,
            .memory: showMemory,
            .storage: showStorage,
            .battery: showBattery,
            .network: showNetwork,
        ]
    }

    private func applyMonitoringSelection() {
        guard isMonitoring else { return }
        SystemInfoObserver.shared.toggleActivation(requests: monitoringRequests)
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        let observer = SystemInfoObserver.shared
        observer.toggleActivation(requests: monitoringRequests)
        observer.startMonitoring(monitorInterval: 5.0)
        streamTask = Task { @MainActor [weak self] in
            for await bundle in observer.systemInfoStream() {
                guard let self else { return }
                self.systemInfo = bundle
                self.monitorRevision += 1
                if let value = bundle.cpuInfo?.percentage.value {
                    self.cpuHistory.append(value)
                    self.cpuHistory.removeFirst(max(0, self.cpuHistory.count - 61))
                }
                if let value = bundle.memoryInfo?.percentage.value {
                    self.memoryHistory.append(value)
                    self.memoryHistory.removeFirst(max(0, self.memoryHistory.count - 61))
                }
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

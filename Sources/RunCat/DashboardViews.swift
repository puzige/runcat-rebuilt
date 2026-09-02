/*
 DashboardViews.swift
 RunCat (preservation rebuild)

 Based on "Menubar RunCat" by Takuto Nakamura.
 Copyright © 2019 Takuto Nakamura. All rights reserved.

 Licensed under the Apache License, Version 2.0.
 Modified for the RunCat preservation rebuild, 2026.

 SwiftUI content of the menu bar popover: a dashboard that mirrors the
 delisted Mac App Store version of RunCat — system info sections on the
 left (CPU / Memory / Storage / Network with progress bars), a column of
 round buttons on the right (Runners / Store / Self-Made / Activity
 Monitor / Settings / More). Layout and copy follow the original; the
 graphs of the original are replaced by plain ProgressViews.
*/

import SwiftUI
import SystemInfoKit

// MARK: - Root

struct DashboardRootView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        Group {
            switch model.page {
            case .dashboard: DashboardView(model: model)
            case .runners: RunnerPickerView(model: model)
            case .settings: SettingsView(model: model)
            }
        }
        .frame(width: 380)
        .padding(8)
    }
}

// MARK: - Dashboard

private struct DashboardView: View {
    @ObservedObject var model: DashboardModel

    private var appName: String {
        (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "RunCat"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(verbatim: appName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                Spacer()
                HStack(spacing: 4) {
                    Menu {
                        Button(DashboardView.string("aboutApp")) { AppDelegate.openAboutWindow() }
                        Button(DashboardView.string("terminateApp")) { NSApp.terminate(nil) }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 26, height: 24)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(DashboardView.string("more"))
                }
            }
            SystemInfoStackView(bundle: model.systemInfo)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
                )
            ButtonBar(model: model)
        }
    }

    static func string(_ key: String, table: String? = "Dashboard") -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: table)
    }
}

// MARK: - System info stack (left column)

private struct SystemInfoStackView: View {
    var bundle: SystemInfoBundle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cpuInfo = bundle.cpuInfo {
                SystemInfoSectionView(icon: "cpu", summary: cpuInfo.summary, details: cpuInfo.details) {
                    ProgressView(value: cpuInfo.percentage.value, total: 100)
                        .progressViewStyle(.linear)
                }
            }
            if let memoryInfo = bundle.memoryInfo {
                divider
                SystemInfoSectionView(icon: "memorychip", summary: memoryInfo.summary, details: memoryInfo.details) {
                    ProgressView(value: memoryInfo.percentage.value, total: 100)
                        .progressViewStyle(.linear)
                }
            }
            if let storageInfo = bundle.storageInfo {
                divider
                SystemInfoSectionView(icon: "externaldrive", summary: storageInfo.summary, details: storageInfo.details) {
                    ProgressView(value: storageInfo.percentage.value, total: 100)
                        .progressViewStyle(.linear)
                }
            }
            if let networkInfo = bundle.networkInfo {
                divider
                SystemInfoSectionView(icon: "globe", summary: networkInfo.summary, details: networkInfo.details) {
                    EmptyView()
                }
            }
        }
        .padding(8)
    }

    private var divider: some View {
        Divider()
    }
}

private struct SystemInfoSectionView<Accessory: View>: View {
    var icon: String
    var summary: String
    var details: [String]
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: summary)
                Group {
                    ForEach(details.indices, id: \.self) { index in
                        Text(verbatim: details[index])
                            .font(.caption)
                    }
                    accessory()
                }
                .padding(.leading, 12)
            }
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Button bar (right column of the original dashboard)

private struct ButtonBar: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        HStack(spacing: 6) {
            RoundButton(icon: "pawprint", title: DashboardView.string("runners")) {
                model.page = .runners
            }
            RoundButton(icon: "cart", title: DashboardView.string("store"), disabledReason: DashboardView.string("store.unavailable", table: nil)) {}
            RoundButton(icon: "square.and.pencil", title: DashboardView.string("selfMade"), disabledReason: DashboardView.string("selfmade.unavailable", table: nil)) {}
            RoundButton(icon: "gauge", title: DashboardView.string("activityMonitor")) {
                openActivityMonitor()
            }
            RoundButton(icon: "gearshape", title: DashboardView.string("settings")) {
                model.page = .settings
            }
        }
    }

    private func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
}

private struct RoundButton: View {
    var icon: String
    var title: String
    var disabledReason: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(height: 16)
                Text(verbatim: title)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 60, height: 44)
        }
        .buttonStyle(.bordered)
        .disabled(disabledReason != nil)
        .help(disabledReason ?? title)
    }
}

// MARK: - Runner picker

struct RunnerPickerView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    model.page = .dashboard
                } label: {
                    Label(DashboardView.string("back"), systemImage: "chevron.backward")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(RunnerCatalog.groupedByCategory(), id: \.0.rawValue) { category, runners in
                        Text(verbatim: RunnerPickerView.string(category.rawValue))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                            ForEach(runners) { runner in
                                RunnerCellView(
                                    runner: runner,
                                    isSelected: runner.id == model.selectedRunnerID
                                ) {
                                    model.selectedRunnerID = runner.id
                                }
                            }
                        }
                    }
                }
                .padding(4)
            }
        }
        .padding(4)
    }

    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: "Dashboard")
    }
}

private struct RunnerCellView: View {
    var runner: Runner
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if let image = runner.frame(at: 0) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "pawprint")
                    }
                }
                .frame(width: 40, height: 28)
                Text(verbatim: runner.displayName)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 68, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.25)
                          : Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .help(runner.displayName)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    model.page = .dashboard
                } label: {
                    Label(DashboardView.string("back"), systemImage: "chevron.backward")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            Toggle(isOn: $model.isShowUsage) {
                Text(verbatim: SettingsView.string("menu.show_usage"))
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            Divider()
            Button {
                AppDelegate.openAboutWindow()
            } label: {
                Label(DashboardView.string("aboutApp"), systemImage: "info.circle")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            Button {
                NSApp.terminate(nil)
            } label: {
                Label(DashboardView.string("terminateApp"), systemImage: "power")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            Spacer()
        }
        .padding(4)
    }

    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}

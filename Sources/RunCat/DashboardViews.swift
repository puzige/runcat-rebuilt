/*
 DashboardViews.swift
 RunCat (preservation rebuild)

 Based on "Menubar RunCat" by Takuto Nakamura.
 Copyright © 2019 Takuto Nakamura. All rights reserved.

 Licensed under the Apache License, Version 2.0.
 Modified for the RunCat preservation rebuild, 2026.

 SwiftUI content of the menu bar popover.  The 292 x 440 point baseline,
 196 point minimum system card, action-cell styling, graphs and spacing are
 measured from the Classic 12.8 Retina reference capture.  Like Classic, the
 dashboard grows horizontally for a long localized metric such as a USB-C
 power-adapter name; the More page contracts to its measured 292 x 216 point
 content height. After consolidating Store
 into Runners and hiding the unavailable Self-Made editor, the remaining four
 action cells keep the original 72 x 64 point size, remain top-packed, and leave
 the unused space at the bottom. The system-info views intentionally share the
 open-source RunCat Neo implementation as its Apache-2.0 successor.
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
            case .more: MoreView(model: model)
            }
        }
        .frame(width: model.canvasSize.width, height: model.canvasSize.height)
    }
}

// MARK: - Dashboard

private struct DashboardView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        HStack(spacing: 8) {
            SystemInfoStackView(
                bundle: model.systemInfo,
                cpuHistory: model.cpuHistory,
                memoryHistory: model.memoryHistory,
                selection: model.monitoringSelection
            )
            .frame(width: model.systemInfoCardWidth, height: 424, alignment: .topLeading)
            .classicCellStyle(cornerRadius: 8)
            ButtonBar(model: model)
        }
        .padding(8)
    }

    static func string(_ key: String, table: String? = "Dashboard") -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: table)
    }
}

/// Deterministic MacBook-sized fixture for checking that long power-adapter
/// names stay inside the Classic information card.  It deliberately uses a
/// longer value than the 90W adapter reported in the regression screenshot.
struct BatteryDashboardPreviewView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        let cardWidth = DashboardModel.systemInfoCardWidth(
            for: Self.fixture,
            selection: Self.selection
        )
        HStack(spacing: 8) {
            SystemInfoStackView(
                bundle: Self.fixture,
                cpuHistory: Array(repeating: 20.8, count: 61),
                memoryHistory: [],
                selection: Self.selection
            )
            .frame(width: cardWidth, height: 424, alignment: .topLeading)
            .classicCellStyle(cornerRadius: 8)
            ButtonBar(model: model)
        }
        .padding(8)
        .frame(width: cardWidth + 96, height: 440)
    }

    static var canvasSize: CGSize {
        CGSize(
            width: DashboardModel.systemInfoCardWidth(for: fixture, selection: selection) + 96,
            height: 440
        )
    }

    static let selection = DashboardMonitoringSelection(
        memory: true,
        storage: true,
        battery: true,
        network: true
    )

    static var fixture: SystemInfoBundle {
        var bundle = SystemInfoBundle()
        bundle.cpuInfo = SystemInfoKit.CPUInfo(
            percentage: SystemInfoKit.Percentage(rawValue: 0.208),
            system: SystemInfoKit.Percentage(rawValue: 0.073),
            user: SystemInfoKit.Percentage(rawValue: 0.135),
            idle: SystemInfoKit.Percentage(rawValue: 0.792)
        )
        bundle.memoryInfo = SystemInfoKit.MemoryInfo(
            percentage: SystemInfoKit.Percentage(rawValue: 0.754),
            pressure: SystemInfoKit.Percentage(rawValue: 0.311),
            app: SystemInfoKit.ByteData(byteCount: 17_100_000_000),
            wired: SystemInfoKit.ByteData(byteCount: 3_800_000_000),
            compressed: SystemInfoKit.ByteData(byteCount: 8_200_000_000)
        )
        bundle.storageInfo = SystemInfoKit.StorageInfo(
            percentage: SystemInfoKit.Percentage(rawValue: 0.471),
            total: SystemInfoKit.ByteData(byteCount: 994_700_000_000),
            available: SystemInfoKit.ByteData(byteCount: 526_000_000_000),
            used: SystemInfoKit.ByteData(byteCount: 468_700_000_000)
        )
        bundle.batteryInfo = SystemInfoKit.BatteryInfo(
            percentage: SystemInfoKit.Percentage(rawValue: 0.8),
            isInstalled: true,
            isCharging: true,
            adapterName: "140W USB-C Power Adapter",
            maxCapacity: SystemInfoKit.Percentage(rawValue: 0.952),
            cycleCount: 37,
            temperature: SystemInfoKit.Temperature(value: 30.2)
        )
        bundle.networkInfo = SystemInfoKit.NetworkInfo(
            hasConnection: true,
            networkInterface: .wifi,
            ipAddress: "192.168.0.113",
            upload: SystemInfoKit.ByteData(byteCount: 146_600),
            download: SystemInfoKit.ByteData(byteCount: 189_400)
        )
        return bundle
    }
}

// MARK: - System info stack (left column)

private struct SystemInfoStackView: View {
    var bundle: SystemInfoBundle
    var cpuHistory: [Double]
    var memoryHistory: [Double]
    var selection: DashboardMonitoringSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cpuInfo = bundle.cpuInfo {
                SystemInfoSectionView(icon: cpuInfo.icon, summary: cpuInfo.summary, details: cpuInfo.details) {
                    LineGraphView(values: cpuHistory)
                }
            }
            if selection.memory, let memoryInfo = bundle.memoryInfo {
                divider
                SystemInfoSectionView(icon: memoryInfo.icon, summary: memoryInfo.summary, details: memoryInfo.details) {
                    EmptyView()
                }
            }
            if selection.storage, let storageInfo = bundle.storageInfo {
                divider
                SystemInfoSectionView(icon: storageInfo.icon, summary: storageInfo.summary, details: storageInfo.details) {
                    BarGraphView(value: storageInfo.percentage.value)
                }
            }
            if selection.battery {
                let batteryInfo = bundle.batteryInfo ?? .zero
                divider
                SystemInfoSectionView(
                    icon: batteryInfo.icon,
                    summary: batteryInfo.summary,
                    details: batteryInfo.isInstalled ? batteryInfo.details : []
                ) {
                    EmptyView()
                }
            }
            if selection.network, let networkInfo = bundle.networkInfo {
                divider
                SystemInfoSectionView(icon: networkInfo.icon, summary: networkInfo.summary, details: networkInfo.details) {
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
                            .help(details[index])
                    }
                    accessory()
                }
                .padding(.leading, 12)
            }
        }
        .fixedSize()
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LineGraphView: View {
    var values: [Double]

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 16))
            for (offset, value) in values.prefix(61).enumerated() {
                let clamped = min(100, max(2, value))
                path.addLine(to: CGPoint(
                    x: CGFloat(2) * CGFloat(offset),
                    y: CGFloat(16) - CGFloat(0.16 * clamped)
                ))
            }
            path.addLine(to: CGPoint(x: 120, y: 16))
            path.closeSubpath()
        }
        .fill(Color.accentColor)
        .frame(width: 120, height: 16)
    }
}

private struct BarGraphView: View {
    var value: Double

    var body: some View {
        Rectangle()
            .frame(width: 120, height: 8)
            .foregroundStyle(Color.clear)
            .border(Color.accentColor, width: 0.5)
            .overlay(alignment: .leading) {
                Rectangle()
                    .frame(width: 1.2 * min(100, max(0, value)), height: 8)
                    .foregroundStyle(Color.accentColor)
            }
    }
}

// MARK: - Button bar (right column of the original dashboard)

private struct ButtonBar: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        VStack(spacing: 8) {
            // The picker contains both built-in and former Store runners.
            ClassicActionButton(icon: "pawprint", title: DashboardView.string("runners")) {
                model.isRunnerListPresented.toggle()
            }
            .popover(isPresented: $model.isRunnerListPresented, arrowEdge: .trailing) {
                RunnerPickerView(model: model)
            }
            ClassicActionButton(
                icon: "waveform.path.ecg",
                title: DashboardView.string("activityMonitor"),
                iconSize: 23,
                compactTitle: true
            ) {
                openActivityMonitor()
            }
            ClassicActionButton(icon: "gear", title: DashboardView.string("settings")) {
                AppDelegate.showSettingsWindow()
            }
            ClassicActionButton(
                icon: "ellipsis",
                title: DashboardView.string("more"),
                iconSize: 26
            ) {
                model.page = .more
            }
        }
        .frame(height: 424, alignment: .top)
    }

    private func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
}

private struct ClassicActionButton: View {
    var icon: String
    var title: String
    var iconSize: CGFloat = 22
    var compactTitle = false
    var usesBundledIcon = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Group {
                    if usesBundledIcon,
                       let url = Bundle.main.url(forResource: "self-made@2x", withExtension: "png"),
                       let image = NSImage(contentsOf: url) {
                        Image(nsImage: image)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 27, height: 24)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: iconSize, weight: .regular))
                    }
                }
                .frame(height: 26)
                Text(verbatim: title)
                    .font(.system(size: compactTitle ? 8 : 10.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 72, height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .classicCellStyle(cornerRadius: 8)
        .help(title)
    }
}

private struct ClassicCellModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .compositingGroup()
            .shadow(radius: 2, y: 2)
    }
}

private extension View {
    func classicCellStyle(cornerRadius: CGFloat) -> some View {
        modifier(ClassicCellModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Runner picker

struct RunnerPickerView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(RunnerCatalog.groupedByCategory(), id: \.0.rawValue) { category, runners in
                    Text(verbatim: RunnerPickerView.string(category.rawValue))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    ForEach(runners) { runner in
                        RunnerRowView(
                            runner: runner,
                            isSelected: runner.id == model.selectedRunnerID
                        ) {
                            model.selectedRunnerID = runner.id
                            model.isRunnerListPresented = false
                        }
                        if runner.id != runners.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .frame(width: 196, height: 360)
        .classicCellStyle(cornerRadius: 8)
        .padding(8)
    }

    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: "Dashboard")
    }
}

private struct RunnerRowView: View {
    var runner: Runner
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 7, height: 7)
                Text(verbatim: runner.displayName)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let image = runner.thumbnail() {
                    Image(nsImage: image)
                        .frame(width: 50, height: 18)
                } else {
                    Image(systemName: "pawprint")
                        .frame(width: 50, height: 18)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(runner.displayName)
    }
}

// MARK: - More

private struct MoreView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                model.page = .dashboard
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 15, weight: .regular))
                    Text(verbatim: DashboardView.string("back"))
                        .font(.system(size: 14))
                }
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
                .frame(width: 292, height: 40, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                MoreActionRow(icon: "info", title: DashboardView.string("aboutApp")) {
                    AppDelegate.openAboutWindow()
                }
                MoreActionRow(icon: "lightbulb", title: DashboardView.string("help")) {
                    AppDelegate.openHelpPage()
                }
                MoreActionRow(icon: "envelope", title: DashboardView.string("reportAnIssue")) {
                    AppDelegate.reportIssue()
                }
                MoreActionRow(icon: "hand.wave", title: DashboardView.string("terminateApp")) {
                    NSApp.terminate(nil)
                }
            }
            .frame(width: 276, height: 168)
            .classicCellStyle(cornerRadius: 8)
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .frame(width: 292, height: 216, alignment: .topLeading)
    }
}

private struct MoreActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.22))
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 28, height: 28)

                Text(verbatim: title)
                    .font(.system(size: 14))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: 42)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var model: DashboardModel
    @State private var selectedTab: Int

    static let contentWidth: CGFloat = 490
    static let generalContentHeight: CGFloat = 444
    static let systemInfoContentHeight: CGFloat = 362

    init(model: DashboardModel) {
        self.model = model
        _selectedTab = State(initialValue: ProcessInfo.processInfo.arguments.contains("--preview-system-info-settings") ? 1 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                ClassicSettingsTabButton(
                    icon: "gear",
                    title: Self.string("generalTab", table: "Others"),
                    width: 55,
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }
                ClassicSettingsTabButton(
                    icon: "cpu",
                    title: Self.string("systemInfoTab", table: "Others"),
                    width: 70,
                    isSelected: selectedTab == 1
                ) {
                    selectedTab = 1
                }
            }
            .frame(width: 128, height: 46)
            .offset(x: -1)

            if selectedTab == 0 {
                ClassicGeneralSettingsView(model: model)
            } else {
                ClassicSystemInfoSettingsView(model: model)
            }
        }
        .frame(width: Self.contentWidth, height: contentHeight)
        .background {
            SettingsWindowTitleUpdater(
                title: Self.string(selectedTab == 0 ? "generalTab" : "systemInfoTab", table: "Others"),
                contentHeight: contentHeight
            )
        }
    }

    private var contentHeight: CGFloat {
        selectedTab == 0 ? Self.generalContentHeight : Self.systemInfoContentHeight
    }

    static func string(_ key: String, table: String = "GeneralSettings") -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: table)
    }
}

private struct SettingsWindowTitleUpdater: NSViewRepresentable {
    let title: String
    let contentHeight: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            guard let window = nsView?.window else { return }
            window.title = title

            let targetContentSize = NSSize(width: SettingsView.contentWidth, height: contentHeight)
            if let currentContentSize = window.contentView?.frame.size,
               abs(currentContentSize.width - targetContentSize.width) < 0.5,
               abs(currentContentSize.height - targetContentSize.height) < 0.5 {
                return
            }

            let targetFrameSize = window.frameRect(
                forContentRect: NSRect(origin: .zero, size: targetContentSize)
            ).size
            var targetFrame = window.frame
            let fixedTopEdge = targetFrame.maxY
            targetFrame.size = targetFrameSize
            targetFrame.origin.y = fixedTopEdge - targetFrameSize.height
            window.setFrame(targetFrame, display: true, animate: window.isVisible)
        }
    }
}

private struct ClassicSettingsTabButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var controlActiveState

    let icon: String
    let title: String
    let width: CGFloat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .frame(height: 27)
                Text(verbatim: title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(y: -3)
            }
            .foregroundStyle(foreground)
            .frame(width: width, height: 46)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(selectedBackground)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        if isSelected {
            return selectedForeground
        }
        return controlActiveState == .inactive ? Color.secondary.opacity(0.5) : Color.secondary
    }

    private var selectedForeground: Color {
        guard controlActiveState != .inactive else {
            return Color.secondary
        }
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .controlAccentColor
        let classicSelectionAdjustment = 20.0 / 255.0
        return Color(
            .sRGB,
            red: max(0, Double(accent.redComponent) - classicSelectionAdjustment),
            green: max(0, Double(accent.greenComponent) - classicSelectionAdjustment),
            blue: max(0, Double(accent.blueComponent) - classicSelectionAdjustment),
            opacity: Double(accent.alphaComponent)
        )
    }

    private var selectedBackground: Color {
        if colorScheme == .dark {
            // The Classic dark-mode value has not yet been measured from a reference screenshot.
            return Color(.sRGB, red: 58 / 255, green: 58 / 255, blue: 60 / 255, opacity: 1)
        }
        // Measured in both active and inactive Mac App Store Classic 12.8 windows: #E0DFDF.
        return Color(.sRGB, red: 224 / 255, green: 223 / 255, blue: 223 / 255, opacity: 1)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(SettingsView.string("runner"))
                .font(.system(size: 13, weight: .semibold))
                .padding(.leading, 23)
                .padding(.top, 10)

            VStack(spacing: 0) {
                CenteredSettingsToggle(SettingsView.string("invertSpeed"), isOn: $model.invertSpeed)
                    .frame(height: 43)
                settingsDivider
                CenteredSettingsToggle(SettingsView.string("flipHorizontally"), isOn: $model.flipHorizontally)
                    .frame(height: 38)
                settingsDivider
                CenteredSettingsToggle(SettingsView.string("useAccentColor"), isOn: $model.useAccentColor)
                    .frame(height: 38)
                settingsDivider
                VStack(spacing: 0) {
                    CenteredSettingsToggle(SettingsView.string("selectAutomatically"), isOn: $model.selectAutomatically)
                        .frame(height: 39)
                    Picker("", selection: $model.onlyMonochromeRunners) {
                        Text(SettingsView.string("allRunners")).tag(false)
                        Text(SettingsView.string("onlyMonochromeRunners")).tag(true)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .disabled(!model.selectAutomatically)
                    .controlSize(.regular)
                    .frame(width: 250, height: 43, alignment: .topLeading)
                }
                .frame(height: 82)
                settingsDivider
                CenteredSettingsToggle(SettingsView.string("stopRunner"), isOn: $model.stopRunner)
                    .frame(height: 43)
            }
            .frame(width: 444, height: 248)
            .classicSettingsPanel()
            .padding(.leading, 23)
            .padding(.top, 20)

            Text(SettingsView.string("launch"))
                .font(.system(size: 13, weight: .semibold))
                .padding(.leading, 23)
                .padding(.top, 20)

            CenteredSettingsToggle(SettingsView.string("launchAtLogin"), isOn: $model.launchAtLogin)
                .frame(width: 300, height: 48)
                .classicSettingsPanel()
                .padding(.leading, 23)
                .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var settingsDivider: some View {
        Divider().padding(.horizontal, 5)
    }
}

private struct CenteredSettingsToggle: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: title)
                .font(.system(size: 14))
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct ClassicSettingsPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .classicSettingsPanelBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
            }
    }
}

private extension NSColor {
    static let classicSettingsPanelBackground = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return .controlBackgroundColor
        }
        return NSColor(srgbRed: 223 / 255, green: 222 / 255, blue: 222 / 255, alpha: 1)
    }
}

private extension View {
    func classicSettingsPanel() -> some View {
        modifier(ClassicSettingsPanelModifier())
    }
}

private struct SystemInfoSettingsView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(SettingsView.string("systemInfoBar", table: "SystemInfoSettings"))
                .font(.system(size: 13, weight: .semibold))
                .padding(.top, 23)

            CenteredSettingsToggle(
                SettingsView.string("activate", table: "SystemInfoSettings"),
                isOn: $model.isShowUsage
            )
            .frame(width: 122, height: 48)
            .classicSettingsPanel()
            .padding(.top, 20)

            Text(SettingsView.string("monitoring", table: "SystemInfoSettings"))
                .font(.system(size: 13, weight: .semibold))
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 0) {
                Text(SettingsView.string("memoryPerformance", table: "SystemInfoSettings"))
                    .frame(height: 38)
                Divider()
                Text(SettingsView.string("storageCapacity", table: "SystemInfoSettings"))
                    .frame(height: 36)
                Divider()
                Text(SettingsView.string("networkConnection", table: "SystemInfoSettings"))
                    .frame(height: 38)
            }
            .font(.system(size: 14))
            .padding(.horizontal, 13)
            .frame(width: 450, height: 116, alignment: .leading)
            .classicSettingsPanel()
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Classic settings baseline

private struct ClassicGeneralSettingsView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(SettingsView.string("runner"))
                .font(.headline)
                .offset(x: 30, y: 26.5)
            GroupBox {
                VStack(spacing: 0) {
                    ClassicSettingsToggleRow(
                        SettingsView.string("invertSpeed"),
                        isOn: $model.invertSpeed,
                        height: 32
                    )
                    Divider()
                    ClassicSettingsToggleRow(SettingsView.string("flipHorizontally"), isOn: $model.flipHorizontally)
                    Divider()
                    ClassicSettingsToggleRow(SettingsView.string("useAccentColor"), isOn: $model.useAccentColor)
                    Divider()
                    ClassicSettingsToggleRow(SettingsView.string("selectAutomatically"), isOn: $model.selectAutomatically)
                    Picker("", selection: $model.onlyMonochromeRunners) {
                        Text(SettingsView.string("allRunners")).tag(false)
                        Text(SettingsView.string("onlyMonochromeRunners")).tag(true)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .disabled(!model.selectAutomatically)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 5)
                    .padding(.bottom, 8)
                    Divider()
                    ClassicSettingsToggleRow(
                        SettingsView.string("stopRunner"),
                        isOn: $model.stopRunner,
                        height: 32
                    )
                }
            }
            .frame(width: 450, height: 233)
            .offset(x: 20, y: 57.5)

            Text(SettingsView.string("launch"))
                .font(.headline)
                .offset(x: 30, y: 316.5)
            GroupBox {
                ClassicSettingsToggleRow(
                    SettingsView.string("launchAtLogin"),
                    isOn: $model.launchAtLogin,
                    height: 27
                )
            }
            .frame(width: 450, height: 37)
            .offset(x: 20, y: 346.5)
        }
        .frame(width: 490, height: 398, alignment: .topLeading)
    }
}

private struct ClassicSettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let height: CGFloat

    init(_ title: String, isOn: Binding<Bool>, height: CGFloat = 37) {
        self.title = title
        _isOn = isOn
        self.height = height
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: title)
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 5)
        .frame(height: height)
    }
}

private struct ClassicSystemInfoSettingsView: View {
    @ObservedObject var model: DashboardModel

    var body: some View {
        Form {
            Section {
                Toggle(
                    SettingsView.string("memoryPerformance", table: "SystemInfoSettings"),
                    isOn: $model.showMemory
                )
                Toggle(
                    SettingsView.string("storageCapacity", table: "SystemInfoSettings"),
                    isOn: $model.showStorage
                )
                Toggle(
                    SettingsView.string("batteryState", table: "SystemInfoSettings"),
                    isOn: $model.showBattery
                )
                Toggle(
                    SettingsView.string("networkConnection", table: "SystemInfoSettings"),
                    isOn: $model.showNetwork
                )
            } header: {
                Text(SettingsView.string("monitoring", table: "SystemInfoSettings"))
            }

            Section {
                Toggle(
                    SettingsView.string("systemInfoBar", table: "SystemInfoSettings"),
                    isOn: $model.activateSystemInfoBar
                )
            } header: {
                Text(SettingsView.string("experimentalFeature", table: "SystemInfoSettings"))
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .formStyle(.grouped)
        .frame(width: SettingsView.contentWidth, height: SettingsView.systemInfoContentHeight - 46)
    }
}

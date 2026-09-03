/*
 AppDelegate.swift
 RunCat (preservation rebuild)

 Based on "Menubar RunCat" by Takuto Nakamura.
 Created by Takuto Nakamura on 2019/08/06.
 Copyright © 2019 Takuto Nakamura. All rights reserved.

 Licensed under the Apache License, Version 2.0.
 Modified for the RunCat preservation rebuild, 2026:
 - Frame images are loaded from the app bundle's Resources directory
   ("runners/<name>/page-N@1x.png", extracted from the original
   delisted App Store binary) instead of a compiled asset catalog.
 - Left-clicking the status item now opens a dashboard popover
   (SwiftUI in an NSHostingView) mirroring the original app, while the
   right-click keeps a traditional NSMenu as a fallback.
 - The selected runner is persisted in UserDefaults("selectedRunner")
   and the frame loading is generalized to any runner.
*/

import Cocoa
import Darwin
import ServiceManagement
import SwiftUI
import SystemInfoKit

private final class ArrowlessPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Material host using AppKit's native visual-effect mask. When the visual
/// effect view is a window's content view, `maskImage` shapes both the material
/// and the window shadow; a CALayer mask only clips the view and can leave a
/// rectangular-looking backdrop at the corners.
private final class RoundedPopoverMaterialView: NSVisualEffectView {
    private let radius: CGFloat = 10
    private var renderedMaskSize = NSSize.zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureRoundedMask()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureRoundedMask()
    }

    override func layout() {
        super.layout()
        updateRoundedMask()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateRoundedMask()
        window?.invalidateShadow()
    }

    private func configureRoundedMask() {
        updateRoundedMask()
    }

    private func updateRoundedMask() {
        let size = bounds.size
        guard size.width > 0, size.height > 0, size != renderedMaskSize else {
            return
        }

        maskImage = NSImage(size: size, flipped: false) { [radius] rect in
            NSColor.white.setFill()
            NSBezierPath(
                roundedRect: rect,
                xRadius: radius,
                yRadius: radius
            ).fill()
            return true
        }
        renderedMaskSize = size
        window?.invalidateShadow()
    }
}

/// A transient menu-bar panel with the same call surface used by NSPopover,
/// but without AppKit's unavoidable callout arrow.
private final class ArrowlessPopover: NSObject {
    var contentSize = NSSize(width: 292, height: 440) {
        didSet {
            let topEdge = panel.frame.maxY
            let centerX = panel.frame.midX
            panel.setContentSize(contentSize)
            if panel.isVisible {
                var frame = panel.frame
                frame.origin.y = topEdge - frame.height
                frame.origin.x = centerX - frame.width / 2
                if let visibleFrame = panel.screen?.visibleFrame {
                    let inset: CGFloat = 4
                    frame.origin.x = min(
                        max(frame.origin.x, visibleFrame.minX + inset),
                        visibleFrame.maxX - frame.width - inset
                    )
                }
                panel.setFrame(frame, display: true)
            }
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.invalidateShadow()
        }
    }

    var behavior: NSPopover.Behavior = .applicationDefined
    var contentViewController: NSViewController? {
        didSet { installContent() }
    }

    var isShown: Bool { panel.isVisible }

    private let panel: ArrowlessPanel
    private var outsideClickMonitor: Any?

    override init() {
        panel = ArrowlessPanel(
            contentRect: NSRect(x: 0, y: 0, width: 292, height: 440),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
    }

    deinit {
        removeOutsideClickMonitor()
    }

    func show(
        relativeTo positioningRect: NSRect,
        of positioningView: NSView,
        preferredEdge _: NSRectEdge
    ) {
        guard let anchorWindow = positioningView.window,
              let screen = anchorWindow.screen ?? NSScreen.main ?? NSScreen.screens.first
        else {
            return
        }

        let windowRect = positioningView.convert(positioningRect, to: nil)
        let anchorRect = anchorWindow.convertToScreen(windowRect)
        let available = screen.visibleFrame
        let inset: CGFloat = 4
        let centeredX = anchorRect.midX - contentSize.width / 2
        let maximumX = max(available.minX + inset, available.maxX - contentSize.width - inset)
        let originX = min(max(centeredX, available.minX + inset), maximumX)

        // Classic's window begins immediately below the menu bar. Leaving one
        // point keeps its shadow separate without introducing a callout arrow.
        let anchoredY = min(anchorRect.minY - contentSize.height - 1,
                            available.maxY - contentSize.height - 1)
        let originY = max(available.minY + inset, anchoredY)

        panel.setFrame(
            NSRect(origin: NSPoint(x: originX, y: originY), size: contentSize),
            display: true
        )
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.invalidateShadow()
        panel.orderFrontRegardless()
        installOutsideClickMonitorIfNeeded()
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        removeOutsideClickMonitor()
        NotificationCenter.default.post(name: NSPopover.didCloseNotification, object: self)
    }

    private func installContent() {
        guard let controller = contentViewController else { return }

        panel.setContentSize(contentSize)
        let materialHost = RoundedPopoverMaterialView(
            frame: NSRect(origin: .zero, size: contentSize)
        )
        materialHost.autoresizingMask = [.width, .height]
        materialHost.material = .popover
        materialHost.blendingMode = .behindWindow
        materialHost.state = .active
        panel.contentView = materialHost

        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        materialHost.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: materialHost.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: materialHost.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: materialHost.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: materialHost.bottomAnchor),
        ])
        materialHost.layoutSubtreeIfNeeded()
        panel.invalidateShadow()
    }

    private func installOutsideClickMonitorIfNeeded() {
        guard behavior == .transient, outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.close()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = DashboardModel()
    private lazy var statusItem: NSStatusItem = {
        return NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()
    private let popover = ArrowlessPopover()
    private let menu = NSMenu()
    private var showUsageItem: NSMenuItem? = nil
    private var previewWindow: NSWindow?
    private var previewHostingController: NSViewController?
    private var previewContentSizeOverride: NSSize?
    private var settingsWindow: NSWindow?

    private var frames: [NSImage] = []
    private var index: Int = 0
    private var interval: Double = 1.0
    private let cpu = CPU()
    private var usage: CPUInfo = CPU.default
    private var cpuTimer: Timer? = nil
    private var runnerTimer: Timer? = nil
    private var automaticRunnerTimer: Timer? = nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--verify-runner-speed") {
            verifyRunnerSpeedAndExit()
        }
        if arguments.contains("--verify-runner-assets") {
            verifyRunnerAssetsAndExit()
        }
        if arguments.contains("--verify-live-monitor") {
            verifyLiveMonitorAndExit()
            return
        }
        if arguments.contains("--verify-monitor-toggles") {
            verifyMonitorTogglesAndExit()
            return
        }
        if arguments.contains("--verify-battery-layout") {
            verifyBatteryLayoutAndExit()
        }

        loadFrames(for: model.selectedRunnerID)
        model.onRunnerChanged = { [weak self] runnerID in
            self?.loadFrames(for: runnerID)
        }
        model.onShowUsageChanged = { [weak self] _ in
            self?.updateUsageDescription()
        }
        model.onPageChanged = { [weak self] page in
            self?.updateDashboardSize(for: page)
        }
        model.onDashboardSizeChanged = { [weak self] in
            guard let self else { return }
            self.updateDashboardSize(for: self.model.page)
        }
        model.onRunnerPreferencesChanged = { [weak self] in
            guard let self else { return }
            self.loadFrames(for: self.model.selectedRunnerID)
            self.configureAutomaticRunnerSelection()
            self.updateUsage()
        }
        model.onLaunchAtLoginChanged = { enabled in
            guard #available(macOS 13.0, *) else { return }
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("RunCat launch-at-login update failed: %@", error.localizedDescription)
            }
        }

        setupStatusItem()
        setupPopover()
        setNotifications()
        startRunning()
        // Keep a single SystemInfoKit stream alive for the application
        // lifetime. Cancelling and recreating the consumer with the transient
        // popover could leave a reopened dashboard on its buffered snapshot.
        model.startMonitoring()

        if arguments.contains("--preview-dashboard") ||
            arguments.contains("--preview-battery-dashboard") ||
            arguments.contains("--preview-runners") ||
            arguments.contains("--preview-more") {
            if arguments.contains("--preview-more") {
                model.page = .more
            }
            if arguments.contains("--preview-battery-dashboard") {
                showDashboardPreview(
                    content: AnyView(BatteryDashboardPreviewView(model: model)),
                    contentSize: BatteryDashboardPreviewView.canvasSize
                )
            } else {
                showDashboardPreview()
            }
            if arguments.contains("--preview-runners") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.model.isRunnerListPresented = true
                }
            }
        } else if arguments.contains("--preview-settings") ||
                    arguments.contains("--preview-system-info-settings") {
            openSettingsWindow()
        }
    }

    private func verifyRunnerAssetsAndExit() -> Never {
        let broken = RunnerCatalog.all.filter { runner in
            runner.allFrames().count != runner.frameCount
        }
        if !broken.isEmpty {
            let details = broken
                .map { "\($0.id): \($0.allFrames().count)/\($0.frameCount)" }
                .joined(separator: ", ")
            fputs("error: missing runner frames: \(details)\n", stderr)
            exit(EXIT_FAILURE)
        }

        let invalidThumbnails = RunnerCatalog.all.compactMap { runner -> String? in
            guard let thumbnail = runner.thumbnail() else { return runner.id }
            let validPointSize = abs(thumbnail.size.width - 50) < 0.001 &&
                abs(thumbnail.size.height - 18) < 0.001
            let representation = thumbnail.representations.first {
                $0.pixelsWide > 0 && $0.pixelsHigh > 0
            }
            let validPixelSize = representation?.pixelsWide == 100 &&
                representation?.pixelsHigh == 36
            return validPointSize && validPixelSize ? nil : runner.id
        }
        if !invalidThumbnails.isEmpty {
            fputs("error: invalid runner thumbnails: \(invalidThumbnails.joined(separator: ", "))\n", stderr)
            exit(EXIT_FAILURE)
        }
        print("Verified \(RunnerCatalog.all.count) runner asset sets.")
        exit(EXIT_SUCCESS)
    }

    private func verifyRunnerSpeedAndExit() -> Never {
        let samples: [(usage: Double, inverted: Bool, expected: Double)] = [
            (0, false, 0.5),
            (20, false, 0.125),
            (100, false, 0.025),
            (0, true, 0.05),
            (20, true, 0.5 / 8.5),
            (100, true, 1.0),
        ]
        let tolerance = 0.000_001
        for sample in samples {
            let actual = Self.runnerInterval(
                forCPUUsage: sample.usage,
                inverted: sample.inverted
            )
            guard abs(actual - sample.expected) < tolerance else {
                fputs(
                    "error: runner interval mismatch for CPU \(sample.usage): " +
                    "expected \(sample.expected), got \(actual)\n",
                    stderr
                )
                exit(EXIT_FAILURE)
            }
        }
        print("Verified Classic 12.8 runner timing formula.")
        exit(EXIT_SUCCESS)
    }

    private func verifyLiveMonitorAndExit() {
        model.startMonitoring()
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.2) { [model] in
            let revisions = model.monitorRevision
            model.stopMonitoring()
            guard revisions >= 2 else {
                fputs("error: live monitor produced only \(revisions) updates\n", stderr)
                exit(EXIT_FAILURE)
            }
            print("Verified live monitor stream (\(revisions) updates).")
            exit(EXIT_SUCCESS)
        }
    }

    private func verifyMonitorTogglesAndExit() {
        let original = model.monitoringSelection
        let expected = DashboardMonitoringSelection(
            memory: false,
            storage: false,
            battery: true,
            network: true
        )

        model.startMonitoring()
        model.showMemory = expected.memory
        model.showStorage = expected.storage
        model.showBattery = false
        model.showNetwork = expected.network
        model.showBattery = expected.battery

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [model] in
            let selectionMatches = model.monitoringSelection == expected
            let repositoriesMatch = model.systemInfo.memoryInfo == nil &&
                model.systemInfo.storageInfo == nil &&
                model.systemInfo.batteryInfo != nil

            model.showMemory = original.memory
            model.showStorage = original.storage
            model.showBattery = original.battery
            model.showNetwork = original.network
            model.stopMonitoring()

            guard selectionMatches, repositoriesMatch else {
                fputs("error: monitor toggles did not update dashboard repositories\n", stderr)
                exit(EXIT_FAILURE)
            }
            print("Verified monitor-toggle visibility and repository activation.")
            exit(EXIT_SUCCESS)
        }
    }

    private func verifyBatteryLayoutAndExit() -> Never {
        let fixture = BatteryDashboardPreviewView.fixture
        guard let chargingBattery = fixture.batteryInfo else {
            fputs("error: battery layout fixture is missing battery info\n", stderr)
            exit(EXIT_FAILURE)
        }
        let unpluggedBattery = BatteryInfo(
            percentage: chargingBattery.percentage,
            isInstalled: true,
            isCharging: false,
            adapterName: nil,
            maxCapacity: chargingBattery.maxCapacity,
            cycleCount: chargingBattery.cycleCount,
            temperature: chargingBattery.temperature
        )
        let cardWidth = DashboardModel.systemInfoCardWidth(
            for: fixture,
            selection: BatteryDashboardPreviewView.selection
        )
        let hasFullAdapterName = chargingBattery.details.contains {
            $0.contains("140W USB-C Power Adapter")
        }
        guard chargingBattery.icon.contains("bolt"),
              !unpluggedBattery.icon.contains("bolt"),
              chargingBattery.icon != unpluggedBattery.icon,
              cardWidth > 196,
              hasFullAdapterName
        else {
            fputs("error: charging icon or adaptive battery width regression\n", stderr)
            exit(EXIT_FAILURE)
        }
        print("Verified adaptive battery layout and charging-state icons (\(Int(cardWidth)) pt card).")
        exit(EXIT_SUCCESS)
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stopMonitoring()
        stopRunning()
    }

    // MARK: - Runner frames

    /// Load all frames of a runner from Bundle.main's "runners/<id>/"
    /// directory, normalized to the original menu bar size.
    private func loadFrames(for runnerID: String) {
        let sources: [NSImage]
        let isSpecialColored: Bool
        if model.stopRunner,
           let resourceURL = Bundle.main.resourceURL,
           let sleep = NSImage(contentsOf: resourceURL
               .appendingPathComponent("runners/cat-sleep/cat-sleep@1x.png")) {
            sources = [sleep]
            isSpecialColored = false
        } else {
            let runner = RunnerCatalog.runner(withID: runnerID)
            sources = runner.allFrames()
            isSpecialColored = runner.category == .special
        }
        frames = sources.map { source in
            // Classic 12.8 keeps every runner at 18 pt high while preserving
            // its own width.  The archived PNGs are 36 px high, so Cat alpha
            // becomes 28 x 18 pt and Cat beta becomes 31.5 x 18 pt.  A fixed
            // 28 pt width made beta's NSStatusItem four points too narrow.
            let representation = source.representations
                .filter { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }
                .max { $0.pixelsWide * $1.pixelsHigh < $1.pixelsWide * $0.pixelsHigh }
            let target: NSSize
            if let representation {
                let width = 18 * CGFloat(representation.pixelsWide) / CGFloat(representation.pixelsHigh)
                target = NSSize(width: width, height: 18)
            } else {
                target = NSSize(width: 28, height: 18)
            }
            let image: NSImage
            if model.flipHorizontally {
                let flipped = NSImage(size: target)
                flipped.lockFocus()
                NSGraphicsContext.current?.cgContext.translateBy(x: target.width, y: 0)
                NSGraphicsContext.current?.cgContext.scaleBy(x: -1, y: 1)
                source.draw(in: NSRect(origin: .zero, size: target),
                            from: NSRect(origin: .zero, size: source.size),
                            operation: .sourceOver,
                            fraction: 1)
                flipped.unlockFocus()
                image = flipped
            } else {
                // This is how the original Apache-licensed implementation
                // sizes menu-bar frames.  Changing NSImage.size preserves the
                // source representation; redrawing into a new bitmap first
                // can change the apparent glyph bounds on Retina displays.
                image = (source.copy() as? NSImage) ?? source
                image.size = target
            }
            image.isTemplate = !isSpecialColored || model.useAccentColor
            return image
        }
        index = 0
        statusItem.button?.contentTintColor = model.useAccentColor ? .controlAccentColor : nil
        statusItem.button?.image = frames.first
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem.button?.imagePosition = .imageTrailing
        statusItem.button?.image = frames.first
        if #available(macOS 10.15, *) {
            statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        } else {
            statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        }

        // Left click: dashboard popover. Right click: traditional menu.
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.action = #selector(statusItemClicked(_:))

        showUsageItem = menu.addItem(withTitle: localizedString("menu.show_usage", fallback: "Show CPU Usage"),
                                     action: #selector(toggleShowUsage(_:)),
                                     keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: localizedString("menu.about", fallback: "About RunCat"),
                     action: #selector(openAbout(_:)),
                     keyEquivalent: "")
        menu.addItem(withTitle: localizedString("menu.login_item_hint", fallback: "Launch at Login…"),
                     action: #selector(showLoginItemHint(_:)),
                     keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: localizedString("menu.quit", fallback: "Quit RunCat"),
                     action: #selector(terminateApp(_:)),
                     keyEquivalent: "q")
        menu.delegate = self
    }

    @objc func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            popover.close()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover(sender)
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        // Classic uses a 292 x 440 pt dashboard but shrinks secondary pages
        // such as More to their content height.
        popover.contentSize = model.canvasSize
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: DashboardRootView(model: model))
        NotificationCenter.default.addObserver(self, selector: #selector(popoverDidCloseNote(_:)),
                                               name: NSPopover.didCloseNotification,
                                               object: popover)
    }

    /// Deterministic, menu-bar-independent preview used for visual regression
    /// screenshots: `RunCat --preview-dashboard`.
    private func showDashboardPreview(
        content: AnyView? = nil,
        contentSize requestedContentSize: NSSize? = nil
    ) {
        let contentSize = requestedContentSize ?? model.canvasSize
        previewContentSizeOverride = requestedContentSize
        model.startMonitoring()
        let rootView = content ?? AnyView(DashboardRootView(model: model))
        let controller = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // MenuBarExtra/NSPopover windows are transparent material hosts.  An
        // ordinary titled NSWindow has an opaque windowBackgroundColor, which
        // makes every SwiftUI material appear almost white and invalidates a
        // color comparison with Classic.  Keep the preview host borderless and
        // transparent so the desktop underneath participates in the blur.
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        let materialHost = RoundedPopoverMaterialView(frame: window.contentView?.bounds ?? .zero)
        materialHost.material = .popover
        materialHost.blendingMode = .behindWindow
        materialHost.state = .active
        window.contentView = materialHost

        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        materialHost.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: materialHost.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: materialHost.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: materialHost.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: materialHost.bottomAnchor),
        ])
        materialHost.layoutSubtreeIfNeeded()
        window.invalidateShadow()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        previewHostingController = controller
        previewWindow = window
    }

    private func updateDashboardSize(for page: DashboardModel.Page) {
        let contentSize = model.canvasSize
        popover.contentSize = contentSize

        guard let previewWindow else { return }
        let resolvedContentSize = previewContentSizeOverride ?? contentSize
        let topEdge = previewWindow.frame.maxY
        let centerX = previewWindow.frame.midX
        previewWindow.setContentSize(resolvedContentSize)
        var frame = previewWindow.frame
        frame.origin.y = topEdge - frame.height
        frame.origin.x = centerX - frame.width / 2
        previewWindow.setFrame(frame, display: true)
        previewWindow.contentView?.layoutSubtreeIfNeeded()
        previewWindow.invalidateShadow()
    }

    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.close()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc func popoverDidCloseNote(_ notification: Notification) {
        // Monitoring intentionally remains active until app termination.
    }

    // MARK: - Legacy menu actions

    private func updateUsageDescription() {
        statusItem.button?.title = model.isShowUsage ? usage.description : ""
    }

    @objc func toggleShowUsage(_ sender: NSMenuItem) {
        model.isShowUsage.toggle()
        sender.state = model.isShowUsage ? .on : .off
    }

    @objc func openAbout(_ sender: Any?) {
        Self.openAboutWindow()
    }

    static func openAboutWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    static func showSettingsWindow() {
        (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
    }

    private func openSettingsWindow() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = NSHostingController(rootView: SettingsView(model: model))
        let window = NSWindow(contentViewController: controller)
        let opensSystemInfo = ProcessInfo.processInfo.arguments.contains("--preview-system-info-settings")
        window.setContentSize(NSSize(
            width: SettingsView.contentWidth,
            height: opensSystemInfo ? SettingsView.systemInfoContentHeight : SettingsView.generalContentHeight
        ))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.title = SettingsView.string("generalTab", table: "Others")
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    static func openHelpPage() {
        NSWorkspace.shared.open(URL(string: "https://kyome.io/runcat/index.html")!)
    }

    static func reportIssue() {
        let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "RunCat"
        let template = Bundle.main.localizedString(
            forKey: "mailIssueReport%@",
            value: "%@ Issue Report",
            table: "Others"
        )
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "kyomesuke@icloud.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: String(format: template, appName))
        ]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func showLoginItemHint(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = localizedString("menu.login_item_hint.title",
                                            fallback: "Add RunCat to Login Items")
        alert.informativeText = localizedString("menu.login_item_hint.message",
                                                fallback: "To launch RunCat automatically at login, open System Settings → General → Login Items and add RunCat there.")
        alert.addButton(withTitle: localizedString("menu.login_item_hint.open_settings",
                                                   fallback: "Open System Settings"))
        alert.addButton(withTitle: localizedString("menu.login_item_hint.ok", fallback: "OK"))
        if alert.runModal() == .alertFirstButtonReturn {
            if #available(macOS 13.0, *) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
            } else {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Accounts.prefPane"))
            }
        }
    }

    @objc func terminateApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func localizedString(_ key: String, fallback: String) -> String {
        return Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
    }

    // MARK: - Animation

    @objc func receiveSleep(_ notification: NSNotification) {
        stopRunning()
    }

    @objc func receiveWakeUp(_ notification: NSNotification) {
        startRunning()
    }

    private func setNotifications() {
        NSWorkspace.shared.notificationCenter
            .addObserver(self, selector: #selector(receiveSleep(_:)),
                         name: NSWorkspace.willSleepNotification,
                         object: nil)
        NSWorkspace.shared.notificationCenter
            .addObserver(self, selector: #selector(receiveWakeUp(_:)),
                         name: NSWorkspace.didWakeNotification,
                         object: nil)
    }

    private func updateUsage() {
        usage = cpu.currentUsage()
        interval = Self.runnerInterval(
            forCPUUsage: usage.value,
            inverted: model.invertSpeed
        )
        updateUsageDescription()
        restartRunnerTimer()
    }

    /// Classic 12.8 gives its key-frame animation a base duration of
    /// `frameCount / 2`, then applies this CPU-derived speed multiplier.
    /// Equivalently, each discrete frame lasts 0.5 seconds divided by speed.
    private static func runnerInterval(forCPUUsage usage: Double, inverted: Bool) -> Double {
        let baseSpeed = max(1.0, min(20.0, usage / 5.0))
        let speed = inverted ? (21.0 - baseSpeed) * 0.5 : baseSpeed
        return 0.5 / speed
    }

    private func restartRunnerTimer() {
        runnerTimer?.invalidate()
        guard !model.stopRunner, frames.count > 1 else { return }
        runnerTimer = Timer(timeInterval: interval, repeats: true, block: { [weak self] _ in
            self?.next()
        })
        RunLoop.main.add(runnerTimer!, forMode: .common)
    }

    private func next() {
        guard !frames.isEmpty else { return }
        index = (index + 1) % frames.count
        statusItem.button?.image = frames[index]
    }

    private func startRunning() {
        cpuTimer = Timer(timeInterval: 5.0, repeats: true, block: { [weak self] _ in
            self?.updateUsage()
        })
        RunLoop.main.add(cpuTimer!, forMode: .common)
        cpuTimer?.fire()
        configureAutomaticRunnerSelection()
    }

    private func configureAutomaticRunnerSelection() {
        automaticRunnerTimer?.invalidate()
        automaticRunnerTimer = nil
        guard model.selectAutomatically else { return }
        automaticRunnerTimer = Timer(timeInterval: 600, repeats: true) { [weak self] _ in
            guard let self else { return }
            let candidates = self.model.onlyMonochromeRunners
                ? RunnerCatalog.all.filter { $0.category != .special }
                : RunnerCatalog.all
            if let runner = candidates.randomElement() {
                self.model.selectedRunnerID = runner.id
            }
        }
        RunLoop.main.add(automaticRunnerTimer!, forMode: .common)
    }

    private func stopRunning() {
        runnerTimer?.invalidate()
        cpuTimer?.invalidate()
        automaticRunnerTimer?.invalidate()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        showUsageItem?.state = model.isShowUsage ? .on : .off
    }
}

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
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = DashboardModel()
    private lazy var statusItem: NSStatusItem = {
        return NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()
    private let popover = NSPopover()
    private let menu = NSMenu()
    private var showUsageItem: NSMenuItem? = nil

    private var frames: [NSImage] = []
    private var index: Int = 0
    private var interval: Double = 1.0
    private let cpu = CPU()
    private var usage: CPUInfo = CPU.default
    private var cpuTimer: Timer? = nil
    private var runnerTimer: Timer? = nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadFrames(for: model.selectedRunnerID)
        model.onRunnerChanged = { [weak self] runnerID in
            self?.loadFrames(for: runnerID)
        }
        model.onShowUsageChanged = { [weak self] _ in
            self?.updateUsageDescription()
        }

        setupStatusItem()
        setupPopover()
        setNotifications()
        startRunning()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopRunning()
    }

    // MARK: - Runner frames

    /// Load all frames of a runner from Bundle.main's "runners/<id>/"
    /// directory, normalized to the original menu bar size.
    private func loadFrames(for runnerID: String) {
        let target = NSSize(width: 28, height: 18)
        frames = RunnerCatalog.runner(withID: runnerID).allFrames().map { source in
            guard let tiff = source.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff) else {
                return source
            }
            let image = NSImage(size: target)
            image.addRepresentation(rep)
            return image
        }
        index = 0
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
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover(sender)
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover.contentSize = NSSize(width: 396, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: DashboardRootView(model: model))
        NotificationCenter.default.addObserver(self, selector: #selector(popoverDidCloseNote(_:)),
                                               name: NSPopover.didCloseNotification,
                                               object: popover)
    }

    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.close()
        } else {
            model.startMonitoring()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc func popoverDidCloseNote(_ notification: Notification) {
        model.stopMonitoring()
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
        interval = 0.2 / max(1.0, min(20.0, self.usage.value / 5.0))
        updateUsageDescription()
        restartRunnerTimer()
    }

    private func restartRunnerTimer() {
        runnerTimer?.invalidate()
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
    }

    private func stopRunning() {
        runnerTimer?.invalidate()
        cpuTimer?.invalidate()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        showUsageItem?.state = model.isShowUsage ? .on : .off
    }
}

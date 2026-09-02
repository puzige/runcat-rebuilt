/*
 AppDelegate.swift
 RunCat (preservation rebuild)

 Based on "Menubar RunCat" by Takuto Nakamura.
 Created by Takuto Nakamura on 2019/08/06.
 Copyright © 2019 Takuto Nakamura. All rights reserved.

 Licensed under the Apache License, Version 2.0.
 Modified for the RunCat preservation rebuild, 2026:
 - Frame images are loaded from the app bundle's Resources directory
   ("cat-page-0.png" ... "cat-page-4.png", extracted from the original
   delisted App Store binary) instead of a compiled asset catalog.
 - The menu now includes a localized "About" window, a hint on how to
   add the app as a login item from System Settings, and Quit.
*/

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItem: NSStatusItem = {
        return NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()
    private let menu = NSMenu()
    private lazy var frames: [NSImage] = {
        // Load the five animation frames straight from the main bundle's
        // Resources directory. This avoids the asset-catalog compiler,
        // which is not available with the Command Line Tools toolchain.
        let resourceURL = Bundle.main.resourceURL
        return (0 ..< 5).map { n in
            let path = resourceURL?.appendingPathComponent("cat-page-\(n).png").path
            guard let path = path, let image = NSImage(contentsOfFile: path) else {
                return NSImage() // empty fallback keeps the timer loop alive
            }
            image.size = NSSize(width: 28, height: 18)
            return image
        }
    }()
    private var index: Int = 0
    private var interval: Double = 1.0
    private let cpu = CPU()
    private var usage: CPUInfo = CPU.default
    private var cpuTimer: Timer? = nil
    private var runnerTimer: Timer? = nil
    private var isShowUsage: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setNotifications()
        startRunning()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopRunning()
    }

    private func updateUsageDescription() {
        statusItem.button?.title = isShowUsage ? usage.description : ""
    }

    @objc func toggleShowUsage(_ sender: NSMenuItem) {
        isShowUsage = (sender.state == .off)
        sender.state = isShowUsage ? .on : .off
        updateUsageDescription()
    }

    @objc func openAbout(_ sender: Any?) {
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

    private func setupStatusItem() {
        statusItem.button?.imagePosition = .imageTrailing
        statusItem.button?.image = frames.first
        if #available(macOS 10.15, *) {
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            statusItem.button?.font = font
        } else {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            statusItem.button?.font = font
        }
        menu.addItem(withTitle: localizedString("menu.show_usage", fallback: "Show CPU Usage"),
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
        statusItem.menu = menu
    }

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
        runnerTimer?.invalidate()
        runnerTimer = Timer(timeInterval: self.interval, repeats: true, block: { [weak self] _ in
            self?.next()
        })
        RunLoop.main.add(runnerTimer!, forMode: .common)
    }

    private func next() {
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

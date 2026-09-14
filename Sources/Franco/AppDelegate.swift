import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let tap = EventTap()
    private let settings = Settings.shared
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?
    private var languageItems: [NSMenuItem] = []
    private var enabledItem: NSMenuItem!

    private let languages: [(String, String, String)] = [
        ("ar", "ع", "Arabic (Franco / Arabizi)"), ("hi", "अ", "Hindi (Hinglish)"), ("ru", "Я", "Russian (translit)"), ("fa", "ف", "Persian (Pinglish)")
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()
        Engine.shared.warm(settings.language)
        tap.onToggle = { [weak self] in self?.toggleEnabled() }
        tap.onLanguage = { [weak self] idx in
            guard let self = self, idx < self.languages.count else { return }
            self.settings.language = self.languages[idx].0
            self.refreshMenu()
        }
        ensurePermissionThenStart()
    }

    // MARK: status item

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(enabledItem)
        menu.addItem(.separator())
        for (i, l) in languages.enumerated() {
            let it = NSMenuItem(title: "\(l.1)  \(l.2)", action: #selector(pickLanguage(_:)), keyEquivalent: "\(i + 1)")
            it.keyEquivalentModifierMask = [.command, .shift]
            it.target = self; it.representedObject = l.0
            menu.addItem(it); languageItems.append(it)
        }
        menu.addItem(.separator())
        let s = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","); s.target = self; menu.addItem(s)
        let a = NSMenuItem(title: "Accessibility permission…", action: #selector(openAX), keyEquivalent: ""); a.target = self; menu.addItem(a)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Franco", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        refreshMenu()
    }

    private func refreshMenu() {
        let glyph = languages.first { $0.0 == settings.language }?.1 ?? "ع"
        if let b = statusItem.button {
            b.title = settings.enabled ? glyph : "Aa"
            b.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
            b.alphaValue = settings.enabled ? 1 : 0.45
            b.toolTip = "Franco — \(settings.enabled ? "on" : "off") (\(settings.hotkey.display))"
        }
        enabledItem.state = settings.enabled ? .on : .off
        enabledItem.title = "Enabled   \(settings.hotkey.display)"
        for it in languageItems { it.state = (it.representedObject as? String) == settings.language ? .on : .off }
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
        if !settings.enabled { tap.composer.cancel() }
        refreshMenu()
    }

    @objc private func pickLanguage(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        settings.language = id
        tap.composer.cancel()
        refreshMenu()
    }

    @objc private func openAX() { AppDelegate.openAccessibilityPane() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
                             styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            w.title = "Franco Settings"
            w.contentView = NSHostingView(rootView: SettingsView())
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshMenu()
    }

    // MARK: permission

    static func openAccessibilityPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func ensurePermissionThenStart() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) {
            startTap()
            return
        }
        let alert = NSAlert()
        alert.messageText = "Franco needs Accessibility access"
        alert.informativeText = "Franco watches what you type so it can replace Latin words with Arabic (or Hindi/Russian/Persian). Enable it in System Settings → Privacy & Security → Accessibility, then Franco starts automatically."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { AppDelegate.openAccessibilityPane() }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] t in
            if AXIsProcessTrusted() { t.invalidate(); self?.startTap() }
        }
    }

    private func startTap() {
        if !tap.start() {
            let alert = NSAlert()
            alert.messageText = "Could not install the keyboard tap"
            alert.informativeText = "Check Accessibility (and Input Monitoring) permissions for Franco, then relaunch."
            alert.runModal()
        }
        refreshMenu()
    }
}

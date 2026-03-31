import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var closeObserver: NSObjectProtocol?
    private var spotlightPanel: NSPanel?
    private var spotlightMouseMonitor: Any?
    private var preferencesWindow: NSWindow?
    private var layoutsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupSpotlightPanel()
        setupHotkey()
        _ = WindowLayoutStore.shared   // start screen-change observer early
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "App Switcher")
            button.image?.isTemplate = true
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Layouts…", action: #selector(openLayouts), keyEquivalent: "l")
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AppSwitcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openLayouts() {
        if let w = layoutsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Window Layouts"
        window.contentViewController = NSHostingController(rootView: LayoutsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        layoutsWindow = window
    }

    @objc private func openPreferences() {
        if let w = preferencesWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.contentViewController = NSHostingController(rootView: PreferencesView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow = window
    }

    // MARK: - Popover

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: AppListView())
        popover.behavior = .transient
        popover.animates = true
        self.popover = popover

        closeObserver = NotificationCenter.default.addObserver(
            forName: .closePopover,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closePopover()
            self?.closeSpotlightPanel()
        }
    }

    // MARK: - Spotlight Panel

    private func setupSpotlightPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 100),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.contentViewController = NSHostingController(rootView: AppListView(isSpotlight: true))
        spotlightPanel = panel
    }

    private func toggleSpotlight() {
        guard let panel = spotlightPanel else { return }
        if panel.isVisible {
            closeSpotlightPanel()
        } else {
            closePopover()
            if let screen = NSScreen.main {
                let sf = screen.visibleFrame
                let x = sf.midX - panel.frame.width / 2
                let y = sf.maxY - sf.height * 0.38 - panel.frame.height / 2
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            spotlightMouseMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in self?.closeSpotlightPanel() }
        }
    }

    private func closeSpotlightPanel() {
        spotlightPanel?.orderOut(nil)
        if let m = spotlightMouseMonitor { NSEvent.removeMonitor(m); spotlightMouseMonitor = nil }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        HotkeyManager.shared.register { [weak self] in
            DispatchQueue.main.async {
                self?.toggleSpotlight()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
        if let observer = closeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let m = spotlightMouseMonitor { NSEvent.removeMonitor(m) }
    }
}

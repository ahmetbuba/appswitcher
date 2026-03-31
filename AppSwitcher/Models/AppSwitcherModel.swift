import AppKit

@MainActor
final class AppSwitcherModel: ObservableObject {
    @Published var apps: [RunningApp] = []

    private var observers: [NSObjectProtocol] = []

    init() {
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            let obs = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            observers.append(obs)
        }
    }

    deinit {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func refresh() {
        let hiddenStore = HiddenAppsStore.shared
        apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.localizedName != nil }
            .filter { nsApp in
                guard let bundleID = nsApp.bundleIdentifier else { return true }
                return !hiddenStore.isHidden(bundleID)
            }
            .map { nsApp in
                let pid = nsApp.processIdentifier
                let name = nsApp.localizedName ?? "Unknown"
                let icon = nsApp.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
                let isBrowser = RunningApp.isBrowserApp(nsApp)
                var windows: [WindowItem]
                if isBrowser {
                    windows = BrowserTabHelper.getTabs(for: nsApp)
                    if windows.isEmpty { windows = AccessibilityHelper.getWindows(for: pid) }
                } else {
                    windows = AccessibilityHelper.getWindows(for: pid)
                }
                return RunningApp(id: pid, name: name, icon: icon, nsApp: nsApp, windows: windows, isBrowser: isBrowser)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func activate(_ app: RunningApp) {
        let nsApp = app.nsApp
        if let bundleID = nsApp.bundleIdentifier {
            DispatchQueue.global().async {
                NSAppleScript(source: "tell application id \"\(bundleID)\" to reopen")?.executeAndReturnError(nil)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            nsApp.activate(options: .activateIgnoringOtherApps)
        }
    }

    func focusItem(_ item: WindowItem, in app: RunningApp) {
        if item.isBrowserTab {
            BrowserTabHelper.switchToTab(item, app: app.nsApp)
        } else {
            let nsApp = app.nsApp
            if let bundleID = nsApp.bundleIdentifier {
                DispatchQueue.global().async {
                    NSAppleScript(source: "tell application id \"\(bundleID)\" to reopen")?.executeAndReturnError(nil)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AccessibilityHelper.focusWindow(item, app: nsApp)
            }
        }
    }
}

import AppKit

@MainActor
final class AppSwitcherModel: ObservableObject {
    @Published var apps: [RunningApp] = []

    func refresh() {
        let hiddenStore = HiddenAppsStore.shared
        var seenBundleIDs = Set<String>()
        apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.localizedName != nil }
            .filter { nsApp in
                guard let bundleID = nsApp.bundleIdentifier else { return true }
                if hiddenStore.isHidden(bundleID) { return false }
                return seenBundleIDs.insert(bundleID).inserted
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
        app.nsApp.activate(options: .activateIgnoringOtherApps)
    }

    func focusItem(_ item: WindowItem, in app: RunningApp) {
        if item.isBrowserTab {
            BrowserTabHelper.switchToTab(item, app: app.nsApp)
        } else {
            AccessibilityHelper.focusWindow(item, app: app.nsApp)
        }
    }
}

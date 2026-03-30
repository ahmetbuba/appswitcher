import AppKit

struct WindowItem: Identifiable {
    let id: UUID = UUID()
    let title: String
    let axElement: AXUIElement?
    // For browser tabs
    var windowIndex: Int = 0
    var tabIndex: Int = 0
    var isBrowserTab: Bool = false
    var isNewTab: Bool = false
}

struct RunningApp: Identifiable, Equatable {
    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool { lhs.id == rhs.id }
    let id: pid_t
    let name: String
    let icon: NSImage
    let nsApp: NSRunningApplication
    var windows: [WindowItem]
    var isBrowser: Bool

    static func isBrowserApp(_ app: NSRunningApplication) -> Bool {
        guard let bundleID = app.bundleIdentifier else { return false }
        return BrowserTabHelper.supportedBundleIDs.contains(bundleID)
    }
}

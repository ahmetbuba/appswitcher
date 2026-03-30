import AppKit

@MainActor
final class HiddenAppsStore: ObservableObject {
    static let shared = HiddenAppsStore()

    // bundleID -> display name
    @Published private(set) var hidden: [String: String] = [:]

    private let key = "com.appswitcher.hiddenApps"

    private init() {
        hidden = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    }

    func hide(bundleID: String, name: String) {
        hidden[bundleID] = name
        persist()
    }

    func unhide(bundleID: String) {
        hidden.removeValue(forKey: bundleID)
        persist()
    }

    func isHidden(_ bundleID: String) -> Bool {
        hidden[bundleID] != nil
    }

    // Returns icon for a hidden app: prefers running instance, falls back to app bundle on disk
    func icon(for bundleID: String) -> NSImage {
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           let icon = running.icon {
            return icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }

    private func persist() {
        UserDefaults.standard.set(hidden, forKey: key)
    }
}

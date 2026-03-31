import AppKit

// MARK: - Data models

struct SavedScreenFrame: Codable, Equatable {
    var x, y, width, height: Double
}

struct SavedWindowEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var bundleID: String
    var windowTitle: String
    var frame: SavedScreenFrame
    var screenIndex: Int
    var isMinimized: Bool
}

struct MonitorFingerprint: Codable, Equatable {
    struct ScreenDesc: Codable, Equatable {
        var width, height, x, y: Double
    }
    var screens: [ScreenDesc]   // sorted by x then y — stable across calls
    var label: String           // e.g. "2560×1440 + 1920×1080"
}

struct WindowLayout: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var fingerprint: MonitorFingerprint
    var windows: [SavedWindowEntry]
    var createdAt: Date
    var updatedAt: Date
}

struct LayoutRestoreResult {
    var moved: Int = 0
    var skippedNotRunning: Int = 0
    var skippedAXRejected: Int = 0

    var summary: String {
        var parts: [String] = []
        parts.append("Restored \(moved) window\(moved == 1 ? "" : "s")")
        if skippedNotRunning > 0 {
            parts.append("\(skippedNotRunning) app\(skippedNotRunning == 1 ? "" : "s") not running")
        }
        if skippedAXRejected > 0 {
            parts.append("\(skippedAXRejected) skipped")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Store

@MainActor
final class WindowLayoutStore: ObservableObject {
    static let shared = WindowLayoutStore()

    @Published private(set) var layouts: [WindowLayout] = []
    @Published var suggestedLayout: WindowLayout? = nil

    private let key = "com.appswitcher.windowLayouts"
    private var screenChangeObserver: NSObjectProtocol?
    private var debounceWork: DispatchWorkItem?

    private init() {
        load()
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.debounceWork?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        let fp = WindowLayoutStore.currentFingerprint()
                        self.suggestedLayout = self.bestMatch(for: fp)
                    }
                }
                self.debounceWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
            }
        }
    }

    // MARK: - CRUD

    func saveNew(name: String) -> WindowLayout {
        var layout = WindowLayout(
            name: name,
            fingerprint: WindowLayoutStore.currentFingerprint(),
            windows: LayoutEngine.captureAllWindows(),
            createdAt: Date(),
            updatedAt: Date()
        )
        layouts.append(layout)
        persist()
        return layout
    }

    func update(_ layout: WindowLayout) {
        guard let idx = layouts.firstIndex(where: { $0.id == layout.id }) else { return }
        var updated = layout
        updated.windows = LayoutEngine.captureAllWindows()
        updated.fingerprint = WindowLayoutStore.currentFingerprint()
        updated.updatedAt = Date()
        layouts[idx] = updated
        persist()
    }

    func delete(id: UUID) {
        layouts.removeAll { $0.id == id }
        persist()
    }

    func rename(id: UUID, name: String) {
        guard let idx = layouts.firstIndex(where: { $0.id == id }) else { return }
        layouts[idx].name = name
        layouts[idx].updatedAt = Date()
        persist()
    }

    @discardableResult
    func restore(_ layout: WindowLayout) -> LayoutRestoreResult {
        LayoutEngine.applyLayout(layout)
    }

    // MARK: - Monitor

    static func currentFingerprint() -> MonitorFingerprint {
        let descs = NSScreen.screens
            .map { screen -> MonitorFingerprint.ScreenDesc in
                let f = screen.frame
                return .init(width: f.width, height: f.height, x: f.origin.x, y: f.origin.y)
            }
            .sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        let label = descs
            .map { "\(Int($0.width))×\(Int($0.height))" }
            .joined(separator: " + ")
        return MonitorFingerprint(screens: descs, label: label)
    }

    func bestMatch(for fingerprint: MonitorFingerprint) -> WindowLayout? {
        layouts.first { $0.fingerprint == fingerprint }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WindowLayout].self, from: data)
        else { return }
        layouts = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(layouts) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

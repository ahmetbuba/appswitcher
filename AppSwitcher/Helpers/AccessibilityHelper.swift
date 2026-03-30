import AppKit

enum AccessibilityHelper {

    static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func getWindows(for pid: pid_t) -> [WindowItem] {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        guard result == .success, let windowsArray = windowsRef as? [AXUIElement] else {
            return []
        }

        return windowsArray.compactMap { windowElement -> WindowItem? in
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String) ?? "Untitled"
            guard !title.isEmpty else { return nil }
            return WindowItem(title: title, axElement: windowElement)
        }
    }

    static func unminimizeAllWindows(for pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }
        for window in windows {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        }
    }

    static func focusWindow(_ item: WindowItem, app: NSRunningApplication) {
        app.activate(options: .activateIgnoringOtherApps)
        guard let element = item.axElement else { return }
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, true as CFTypeRef)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }
}

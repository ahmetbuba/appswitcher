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

    // MARK: - Layout geometry helpers

    static func readCGPoint(_ attribute: String, from element: AXUIElement) -> CGPoint? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              ref != nil else { return nil }
        let axVal = ref as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(axVal, .cgPoint, &point) else { return nil }
        return point
    }

    static func readCGSize(_ attribute: String, from element: AXUIElement) -> CGSize? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              ref != nil else { return nil }
        let axVal = ref as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(axVal, .cgSize, &size) else { return nil }
        return size
    }

    @discardableResult
    static func writeCGPoint(_ point: CGPoint, attribute: String, to element: AXUIElement) -> AXError {
        var mutable = point
        guard let axVal = AXValueCreate(.cgPoint, &mutable) else { return .failure }
        return AXUIElementSetAttributeValue(element, attribute as CFString, axVal)
    }

    @discardableResult
    static func writeCGSize(_ size: CGSize, attribute: String, to element: AXUIElement) -> AXError {
        var mutable = size
        guard let axVal = AXValueCreate(.cgSize, &mutable) else { return .failure }
        return AXUIElementSetAttributeValue(element, attribute as CFString, axVal)
    }
}

import AppKit

enum LayoutEngine {

    // MARK: - Capture

    static func captureAllWindows() -> [SavedWindowEntry] {
        let screens = NSScreen.screens.sorted { ($0.frame.origin.x, $0.frame.origin.y) < ($1.frame.origin.x, $1.frame.origin.y) }
        var entries: [SavedWindowEntry] = []

        for nsApp in NSWorkspace.shared.runningApplications {
            guard nsApp.activationPolicy == .regular,
                  let bundleID = nsApp.bundleIdentifier else { continue }

            let appElement = AXUIElementCreateApplication(nsApp.processIdentifier)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windowElements = windowsRef as? [AXUIElement] else { continue }

            for windowElement in windowElements {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef)
                let title = (titleRef as? String) ?? ""
                guard !title.isEmpty else { continue }

                guard let position = AccessibilityHelper.readCGPoint(kAXPositionAttribute as String, from: windowElement),
                      let size = AccessibilityHelper.readCGSize(kAXSizeAttribute as String, from: windowElement)
                else { continue }

                let frame = CGRect(origin: position, size: size)

                var minimizedRef: CFTypeRef?
                AXUIElementCopyAttributeValue(windowElement, kAXMinimizedAttribute as CFString, &minimizedRef)
                let isMinimized = (minimizedRef as? Bool) ?? false

                let screenIndex = screens.firstIndex(where: { $0.frame.contains(position) }) ?? 0

                entries.append(SavedWindowEntry(
                    bundleID: bundleID,
                    windowTitle: title,
                    frame: SavedScreenFrame(x: frame.origin.x, y: frame.origin.y,
                                           width: frame.size.width, height: frame.size.height),
                    screenIndex: screenIndex,
                    isMinimized: isMinimized
                ))
            }
        }
        return entries
    }

    // MARK: - Restore

    static func applyLayout(_ layout: WindowLayout) -> LayoutRestoreResult {
        var result = LayoutRestoreResult()

        // Build live window list
        let liveWindows = collectLiveWindows()
        var usedElements: Set<String> = []  // track by AXUIElement pointer string

        for entry in layout.windows {
            guard let element = findLiveElement(for: entry, in: liveWindows, usedElements: usedElements) else {
                result.skippedNotRunning += 1
                continue
            }

            // Mark element as used (by its pointer description)
            usedElements.insert("\(element)")

            var targetFrame = CGRect(
                x: entry.frame.x, y: entry.frame.y,
                width: entry.frame.width, height: entry.frame.height
            )
            targetFrame = clampToVisibleScreens(targetFrame)

            if entry.isMinimized {
                // Unminimize briefly to position, then re-minimize
                AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                let capturedElement = element
                let capturedFrame = targetFrame
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    AccessibilityHelper.writeCGPoint(capturedFrame.origin, attribute: kAXPositionAttribute as String, to: capturedElement)
                    AccessibilityHelper.writeCGSize(capturedFrame.size, attribute: kAXSizeAttribute as String, to: capturedElement)
                    AXUIElementSetAttributeValue(capturedElement, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                }
                result.moved += 1
                continue
            }

            let posErr = AccessibilityHelper.writeCGPoint(targetFrame.origin, attribute: kAXPositionAttribute as String, to: element)
            let sizeErr = AccessibilityHelper.writeCGSize(targetFrame.size, attribute: kAXSizeAttribute as String, to: element)

            if posErr != .success && sizeErr != .success {
                result.skippedAXRejected += 1
            } else {
                result.moved += 1
            }
        }

        return result
    }

    // MARK: - Helpers

    static func clampToVisibleScreens(_ frame: CGRect) -> CGRect {
        let best = NSScreen.screens.max(by: {
            $0.frame.intersection(frame).area < $1.frame.intersection(frame).area
        }) ?? NSScreen.main ?? NSScreen.screens[0]

        let sf = best.visibleFrame
        let minVisible: CGFloat = 100
        var out = frame
        out.origin.x = max(sf.minX, min(out.origin.x, sf.maxX - minVisible))
        out.origin.y = max(sf.minY, min(out.origin.y, sf.maxY - minVisible))
        return out
    }

    static func findLiveElement(
        for entry: SavedWindowEntry,
        in liveWindows: [(bundleID: String, title: String, element: AXUIElement, position: CGPoint)],
        usedElements: Set<String>
    ) -> AXUIElement? {
        let candidates = liveWindows.filter {
            $0.bundleID == entry.bundleID && !usedElements.contains("\($0.element)")
        }
        guard !candidates.isEmpty else { return nil }

        let savedPos = CGPoint(x: entry.frame.x, y: entry.frame.y)

        // 1. Exact title match
        let exact = candidates.filter { $0.title == entry.windowTitle }
        if exact.count == 1 { return exact[0].element }
        if exact.count > 1 {
            return exact.min(by: { distance($0.position, savedPos) < distance($1.position, savedPos) })?.element
        }

        // 2. Prefix match (first 30 chars)
        let prefix = String(entry.windowTitle.prefix(30))
        if prefix.count > 10 {
            let prefixMatches = candidates.filter { $0.title.hasPrefix(prefix) }
            if prefixMatches.count == 1 { return prefixMatches[0].element }
            if prefixMatches.count > 1 {
                return prefixMatches.min(by: { distance($0.position, savedPos) < distance($1.position, savedPos) })?.element
            }
        }

        // 3. Contains match
        let contains = candidates.filter { $0.title.localizedCaseInsensitiveContains(entry.windowTitle) ||
                                           entry.windowTitle.localizedCaseInsensitiveContains($0.title) }
        if !contains.isEmpty {
            return contains.min(by: { distance($0.position, savedPos) < distance($1.position, savedPos) })?.element
        }

        return nil
    }

    private static func collectLiveWindows() -> [(bundleID: String, title: String, element: AXUIElement, position: CGPoint)] {
        var result: [(bundleID: String, title: String, element: AXUIElement, position: CGPoint)] = []
        for nsApp in NSWorkspace.shared.runningApplications {
            guard nsApp.activationPolicy == .regular,
                  let bundleID = nsApp.bundleIdentifier else { continue }
            let appElement = AXUIElementCreateApplication(nsApp.processIdentifier)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windowElements = windowsRef as? [AXUIElement] else { continue }
            for win in windowElements {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
                let title = (titleRef as? String) ?? ""
                guard !title.isEmpty else { continue }
                let pos = AccessibilityHelper.readCGPoint(kAXPositionAttribute as String, from: win) ?? .zero
                result.append((bundleID: bundleID, title: title, element: win, position: pos))
            }
        }
        return result
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy  // squared distance — fine for comparison
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}

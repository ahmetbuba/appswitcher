import AppKit

enum BrowserTabHelper {

    static let supportedBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.googlecode.iterm2"
    ]

    static func getTabs(for app: NSRunningApplication) -> [WindowItem] {
        guard let bundleID = app.bundleIdentifier else { return [] }
        switch bundleID {
        case "com.apple.Safari":
            return getSafariTabs()
        case "com.google.Chrome":
            return getChromeTabs()
        case "com.googlecode.iterm2":
            return getITermTabs()
        case "org.mozilla.firefox":
            return AccessibilityHelper.getWindows(for: app.processIdentifier)
        default:
            return []
        }
    }

    static func switchToTab(_ item: WindowItem, app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return }
        // 'reopen' (kAEReopenApplication) unminimizes the app window — same event
        // the Dock sends on icon click. Use bundle ID to avoid localization issues.
        // Always delay before switching so the window has time to restore.
        runScript("tell application id \"\(bundleID)\" to reopen")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            performSwitch(item: item, bundleID: bundleID)
        }
    }

    private static func performSwitch(item: WindowItem, bundleID: String) {
        if item.isNewTab {
            openNewTab(bundleID: bundleID)
            return
        }
        switch bundleID {
        case "com.apple.Safari":
            switchSafariTab(windowIndex: item.windowIndex, tabIndex: item.tabIndex)
        case "com.google.Chrome":
            switchChromeTab(windowIndex: item.windowIndex, tabIndex: item.tabIndex)
        case "com.googlecode.iterm2":
            switchITermTab(windowIndex: item.windowIndex, tabIndex: item.tabIndex)
        default:
            break
        }
    }


    private static func openNewTab(bundleID: String) {
        switch bundleID {
        case "com.apple.Safari":
            runScript("""
            tell application "Safari"
                if (count windows) = 0 then
                    make new document
                else
                    tell window 1
                        set current tab to (make new tab)
                    end tell
                end if
            end tell
            """)
        case "com.google.Chrome":
            runScript("""
            tell application "Google Chrome"
                if (count windows) = 0 then
                    make new window
                else
                    tell window 1
                        make new tab
                    end tell
                end if
                activate
            end tell
            """)
        case "com.googlecode.iterm2":
            runScript("""
            tell application "iTerm2"
                tell current window
                    create tab with default profile
                end tell
            end tell
            """)
        default:
            break
        }
    }

    // MARK: - Safari

    private static func newTabSentinel() -> WindowItem {
        var item = WindowItem(title: "New Tab", axElement: nil)
        item.isBrowserTab = true
        item.isNewTab = true
        return item
    }

    private static func getSafariTabs() -> [WindowItem] {
        let script = """
        set output to ""
        tell application "Safari"
            repeat with wIndex from 1 to count windows
                try
                    repeat with tIndex from 1 to count tabs of window wIndex
                        set tabName to name of tab tIndex of window wIndex
                        if tabName is missing value then set tabName to "Untitled"
                        set output to output & wIndex & "|||" & tIndex & "|||" & tabName & "\n"
                    end repeat
                end try
            end repeat
        end tell
        return output
        """
        return [newTabSentinel()] + parseTextScript(script)
    }

    private static func switchSafariTab(windowIndex: Int, tabIndex: Int) {
        runScript("""
        tell application "Safari"
            set current tab of window \(windowIndex) to tab \(tabIndex) of window \(windowIndex)
            set index of window \(windowIndex) to 1
        end tell
        """)
    }

    // MARK: - Chrome

    private static func getChromeTabs() -> [WindowItem] {
        let script = """
        set output to ""
        tell application "Google Chrome"
            repeat with wIndex from 1 to count windows
                try
                    repeat with tIndex from 1 to count tabs of window wIndex
                        set tabName to title of tab tIndex of window wIndex
                        if tabName is missing value then set tabName to "Untitled"
                        set output to output & wIndex & "|||" & tIndex & "|||" & tabName & "\n"
                    end repeat
                end try
            end repeat
        end tell
        return output
        """
        return [newTabSentinel()] + parseTextScript(script)
    }

    private static func switchChromeTab(windowIndex: Int, tabIndex: Int) {
        runScript("""
        tell application "Google Chrome"
            set active tab index of window \(windowIndex) to \(tabIndex)
            set index of window \(windowIndex) to 1
            activate
        end tell
        """)
    }

    // MARK: - iTerm2

    private static func getITermTabs() -> [WindowItem] {
        let script = """
        set output to ""
        tell application "iTerm2"
            repeat with wIndex from 1 to count windows
                try
                    set w to window wIndex
                    repeat with tIndex from 1 to count tabs of w
                        set t to tab tIndex of w
                        set tabName to name of current session of t
                        if tabName is missing value then set tabName to "Shell"
                        set output to output & wIndex & "|||" & tIndex & "|||" & tabName & "\n"
                    end repeat
                end try
            end repeat
        end tell
        return output
        """
        return [newTabSentinel()] + parseTextScript(script)
    }

    private static func switchITermTab(windowIndex: Int, tabIndex: Int) {
        runScript("""
        tell application "iTerm2"
            tell window \(windowIndex)
                select tab \(tabIndex)
            end tell
        end tell
        """)
    }

    // MARK: - Helpers

    private static func parseTextScript(_ source: String) -> [WindowItem] {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        guard let output = script?.executeAndReturnError(&error),
              let raw = output.stringValue,
              !raw.isEmpty else { return [] }

        return raw
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> WindowItem? in
                let parts = line.components(separatedBy: "|||")
                guard parts.count == 3,
                      let wIdx = Int(parts[0]),
                      let tIdx = Int(parts[1]) else { return nil }
                var item = WindowItem(title: parts[2], axElement: nil)
                item.windowIndex = wIdx
                item.tabIndex = tIdx
                item.isBrowserTab = true
                return item
            }
    }

    private static func runScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
    }
}

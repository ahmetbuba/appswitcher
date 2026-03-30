# AppSwitcher

A lightweight macOS menu bar app for switching between running applications, windows, and browser tabs — entirely keyboard-driven.

> Vibe coded with [Claude](https://claude.ai) (Anthropic).

---

## Features

- **Menu bar icon** — click to open a compact app list popover
- **Cmd+Shift+Space** — open a large Spotlight-style panel centered on screen
- **Search** — type to filter apps instantly
- **Keyboard navigation** — arrow keys, Enter, Escape, no mouse required
- **Window sub-lists** — expand any app to see and focus individual windows
- **Browser tab sub-lists** — Safari, Chrome, and iTerm2 show open tabs; open a New Tab directly from the list
- **Firefox** — window titles listed via Accessibility API
- **Hide apps** — right-click any app to hide it from the list; manage hidden apps via the eye-slash toggle
- **Minimized window support** — switching to a tab automatically unminimizes the browser window
- **Configurable hotkey** — right-click the menu bar icon → Preferences to record a custom global shortcut
- No Dock icon, no background resource usage beyond what's needed

---

## Screenshots

| Menu bar popover | Spotlight panel |
|---|---|
| 340px compact popover below menu bar icon | 680px panel centered on screen |

---

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `↑` / `↓` | Navigate app list |
| `→` | Expand sub-items (windows / tabs) |
| `←` | Collapse sub-items |
| `Enter` | Activate selected app or sub-item |
| `Escape` | Collapse sub-items, or close panel |
| `Cmd+Shift+Space` | Toggle Spotlight panel (global, works in any app) |
| Right-click menu bar icon | Open context menu (Preferences, Quit) |

---

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (to build from source)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (to regenerate the `.xcodeproj`)

---

## Installation

### Option 1 — DMG Installer

1. Download [`AppSwitcher.dmg`](binaries/AppSwitcher.dmg) from the `binaries/` folder
2. Open the DMG
3. Drag **AppSwitcher** into the **Applications** folder
4. Eject the DMG and launch AppSwitcher from Applications

> macOS may show a security warning on first launch since the app is not notarized. To allow it:
> `System Settings → Privacy & Security → Open Anyway`

### Option 2 — Build from source

```bash
# Install xcodegen if you don't have it
brew install xcodegen

# Clone the repo
git clone https://github.com/ahmetbuba/appswitcher.git
cd appswitcher

# Generate the Xcode project
xcodegen generate

# Restore entitlements (xcodegen clears them)
cat > AppSwitcher/AppSwitcher.entitlements << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
EOF

# Build
xcodebuild -project AppSwitcher.xcodeproj -scheme AppSwitcher -configuration Debug build

# Install
cp -R build/Debug/AppSwitcher.app /Applications/AppSwitcher.app
open /Applications/AppSwitcher.app
```

---

## Permissions

AppSwitcher requests two permissions at runtime:

| Permission | Purpose |
|---|---|
| **Accessibility** | Read window titles and focus specific windows |
| **Automation** | List and switch browser tabs via AppleScript (Safari, Chrome, iTerm2) |

You will be prompted for Automation permission the first time you expand a browser's tab list. Accessibility permission can be granted from the banner shown at the bottom of the app list, or manually in:

```
System Settings → Privacy & Security → Accessibility
```

---

## Project Structure

```
AppSwitcher/
├── project.yml                        — xcodegen spec
└── AppSwitcher/
    ├── AppSwitcherApp.swift           — app entry point
    ├── AppDelegate.swift              — menu bar, popover, spotlight panel, hotkey
    ├── AppSwitcher.entitlements
    ├── Info.plist
    ├── Models/
    │   ├── RunningApp.swift           — data models
    │   ├── AppSwitcherModel.swift     — app list state
    │   ├── HiddenAppsStore.swift      — hidden apps persistence
    │   └── HotkeySettings.swift      — hotkey persistence & display helpers
    ├── Views/
    │   ├── AppListView.swift          — main list view + keyboard handling
    │   ├── AppRowView.swift           — individual app row
    │   ├── SubItemRowView.swift       — window / tab sub-item row
    │   └── PreferencesView.swift      — hotkey recorder UI
    └── Helpers/
        ├── AccessibilityHelper.swift  — AXUIElement window listing & focusing
        ├── BrowserTabHelper.swift     — AppleScript tab listing & switching
        └── HotkeyManager.swift        — Carbon global hotkey registration
```

---

## Tech Stack

- Swift + SwiftUI
- AppKit (NSPopover, NSPanel, NSStatusItem, NSRunningApplication)
- Accessibility API (AXUIElement)
- AppleScript via NSAppleScript
- Carbon RegisterEventHotKey (global hotkey)
- No third-party dependencies

---

## Known Limitations

- Firefox has no AppleScript tab support — window titles are shown instead of tab titles
- The app is not notarized — macOS Gatekeeper will block it on first launch (see Installation above)
- Accessibility permission is tied to the app's code signature — rebuilding from source requires re-granting the permission in System Settings
- Global hotkey (Cmd+Shift+Space) may conflict with other apps using the same shortcut

---

## License

MIT — see [LICENSE](LICENSE).

---

> Built entirely through conversation with [Claude](https://claude.ai) by Anthropic — no manual code written.

import Carbon
import AppKit

final class HotkeySettings: ObservableObject {
    static let shared = HotkeySettings()

    @Published private(set) var keyCode: UInt32
    @Published private(set) var modifiers: UInt32

    static let defaultKeyCode  = UInt32(kVK_Space)
    static let defaultModifiers = UInt32(cmdKey | shiftKey)

    private init() {
        if let kc = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? Int,
           let mo = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? Int {
            keyCode  = UInt32(kc)
            modifiers = UInt32(mo)
        } else {
            keyCode  = Self.defaultKeyCode
            modifiers = Self.defaultModifiers
        }
    }

    func update(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode  = keyCode
        self.modifiers = modifiers
        UserDefaults.standard.set(Int(keyCode),  forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(Int(modifiers), forKey: "hotkeyModifiers")
    }

    func resetToDefault() {
        update(keyCode: Self.defaultKeyCode, modifiers: Self.defaultModifiers)
    }

    var displayString: String {
        Self.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Display helpers

    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        modifiersString(modifiers) + keyName(keyCode)
    }

    static func modifiersString(_ mods: UInt32) -> String {
        var s = ""
        if mods & UInt32(controlKey) != 0 { s += "⌃" }
        if mods & UInt32(optionKey)  != 0 { s += "⌥" }
        if mods & UInt32(shiftKey)   != 0 { s += "⇧" }
        if mods & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s
    }

    static func keyName(_ keyCode: UInt32) -> String {
        let table: [Int: String] = [
            kVK_Space:         "Space",
            kVK_Return:        "↩",
            kVK_Tab:           "⇥",
            kVK_Delete:        "⌫",
            kVK_ForwardDelete: "⌦",
            kVK_Escape:        "⎋",
            kVK_UpArrow:       "↑",
            kVK_DownArrow:     "↓",
            kVK_LeftArrow:     "←",
            kVK_RightArrow:    "→",
            kVK_Home:          "↖",
            kVK_End:           "↘",
            kVK_PageUp:        "⇞",
            kVK_PageDown:      "⇟",
            kVK_F1:  "F1",  kVK_F2:  "F2",  kVK_F3:  "F3",  kVK_F4:  "F4",
            kVK_F5:  "F5",  kVK_F6:  "F6",  kVK_F7:  "F7",  kVK_F8:  "F8",
            kVK_F9:  "F9",  kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let name = table[Int(keyCode)] { return name }
        return characterForKeyCode(keyCode) ?? "(\(keyCode))"
    }

    private static func characterForKeyCode(_ keyCode: UInt32) -> String? {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutRef = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = unsafeBitCast(layoutRef, to: CFData.self)
        let layoutPtr  = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
        var deadKey: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var count = 0
        let status = UCKeyTranslate(
            layoutPtr, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKey, 4, &count, &chars
        )
        guard status == noErr, count > 0 else { return nil }
        return String(utf16CodeUnits: Array(chars.prefix(count)), count: count).uppercased()
    }

    // MARK: - NSEvent → Carbon conversion

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift)   { mods |= UInt32(shiftKey) }
        if flags.contains(.option)  { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }
}

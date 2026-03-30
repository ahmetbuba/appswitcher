import Carbon
import AppKit

final class HotkeyManager {
    static let shared = HotkeyManager()
    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    func register(handler: @escaping () -> Void) {
        self.handler = handler

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handler?()
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), &eventHandlerRef)

        registerHotKey()
    }

    /// Call after the user saves new hotkey settings.
    func reregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        registerHotKey()
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
    }

    private func registerHotKey() {
        let settings = HotkeySettings.shared
        let hotkeyID = EventHotKeyID(signature: OSType(0x41535748), id: 1)
        RegisterEventHotKey(settings.keyCode, settings.modifiers, hotkeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

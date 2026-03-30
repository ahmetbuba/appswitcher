import SwiftUI
import Carbon

struct PreferencesView: View {
    @StateObject private var settings = HotkeySettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AppSwitcher").font(.headline)
                    Text("Preferences").font(.subheadline).foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 20)

            Divider()
                .padding(.bottom, 20)

            // Hotkey section
            VStack(alignment: .leading, spacing: 8) {
                Label("Global Hotkey", systemImage: "keyboard")
                    .font(.system(size: 13, weight: .semibold))

                Text("Shows the Spotlight-style panel from any app.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                HotkeyRecorderField(
                    currentKeyCode: settings.keyCode,
                    currentModifiers: settings.modifiers
                ) { keyCode, modifiers in
                    settings.update(keyCode: keyCode, modifiers: modifiers)
                    HotkeyManager.shared.reregister()
                }
            }

            Divider()
                .padding(.vertical, 20)

            // Footer buttons
            HStack {
                Button("Reset to Default") {
                    settings.resetToDefault()
                    HotkeyManager.shared.reregister()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 12))

                Spacer()

                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

// MARK: - Hotkey Recorder Field

struct HotkeyRecorderField: View {
    let currentKeyCode: UInt32
    let currentModifiers: UInt32
    let onSave: (UInt32, UInt32) -> Void

    @State private var isRecording = false
    @State private var liveModifiers: UInt32 = 0
    @State private var keyMonitor: Any?
    @State private var flagsMonitor: Any?

    private var displayText: String {
        if isRecording {
            if liveModifiers == 0 { return "Press a key combination…" }
            return HotkeySettings.modifiersString(liveModifiers)
        }
        return HotkeySettings.displayString(keyCode: currentKeyCode, modifiers: currentModifiers)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(displayText)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(isRecording ? (liveModifiers == 0 ? .secondary : .primary) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(isRecording ? "Cancel" : "Record") {
                isRecording ? stopRecording() : startRecording()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isRecording ? .red : .accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1))
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isRecording ? Color.accentColor.opacity(0.06) : Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isRecording ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        liveModifiers = 0

        // Track modifier keys held live
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            liveModifiers = HotkeySettings.carbonModifiers(from: event.modifierFlags)
            return event
        }

        // Capture the key press
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape = cancel
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            let mods = HotkeySettings.carbonModifiers(from: event.modifierFlags)
            // Require at least one modifier
            if mods != 0 {
                onSave(UInt32(event.keyCode), mods)
                stopRecording()
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        liveModifiers = 0
        if let m = keyMonitor   { NSEvent.removeMonitor(m); keyMonitor   = nil }
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
    }
}

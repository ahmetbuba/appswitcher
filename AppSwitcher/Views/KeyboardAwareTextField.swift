import SwiftUI
import AppKit

/// NSTextField subclass that intercepts navigation keys before the text field handles them.
final class NavigableTextField: NSTextField {
    var onArrowDown: (() -> Void)?
    var onArrowUp:   (() -> Void)?
    var onReturn:    (() -> Void)?
    var onEscape:    (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: onArrowDown?()          // ↓
        case 126: onArrowUp?()            // ↑
        case 36, 76: onReturn?()          // Return / numpad Enter
        case 53: onEscape?()              // Escape
        default: super.keyDown(with: event)
        }
    }
}

/// SwiftUI wrapper. Callbacks are re-assigned on every render so they always
/// capture the latest filtered list and selectedIndex.
struct KeyboardAwareTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onArrowDown: () -> Void
    var onArrowUp:   () -> Void
    var onReturn:    () -> Void
    var onEscape:    () -> Void

    func makeNSView(context: Context) -> NavigableTextField {
        let field = NavigableTextField()
        field.placeholderString = placeholder
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        field.delegate = context.coordinator
        return field
    }

    /// Called on every SwiftUI render — keeps callbacks fresh.
    func updateNSView(_ field: NavigableTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.onArrowDown = onArrowDown
        field.onArrowUp   = onArrowUp
        field.onReturn    = onReturn
        field.onEscape    = onEscape
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: KeyboardAwareTextField
        init(_ parent: KeyboardAwareTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

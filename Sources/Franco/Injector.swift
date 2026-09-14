import AppKit
import Carbon.HIToolbox

/// Posts synthetic key events (backspaces, unicode text, named keys) tagged so our own tap ignores them.
enum Injector {
    static let magic: Int64 = 0x46524E43   // "FRNC"
    private static let source: CGEventSource? = {
        let s = CGEventSource(stateID: .combinedSessionState)
        s?.userData = magic
        return s
    }()

    static func isOurs(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == magic
    }

    static func key(_ code: CGKeyCode, flags: CGEventFlags = []) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else { return }
        down.flags = flags; up.flags = flags
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    static func backspace(_ count: Int) {
        for _ in 0..<max(0, count) { key(CGKeyCode(kVK_Delete)) }
    }

    static func type(_ text: String) {
        guard !text.isEmpty else { return }
        let units = Array(text.utf16)
        var i = 0
        while i < units.count {
            let chunk = Array(units[i..<min(i + 20, units.count)])
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
            var arr = chunk
            down.keyboardSetUnicodeString(stringLength: arr.count, unicodeString: &arr)
            up.keyboardSetUnicodeString(stringLength: arr.count, unicodeString: &arr)
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
            i += 20
        }
    }

    /// Replace the last `deleteCount` typed characters with `text`, then optionally a trailing string.
    static func replace(deleteCount: Int, with text: String, trailing: String = "") {
        backspace(deleteCount)
        type(text + trailing)
    }
}

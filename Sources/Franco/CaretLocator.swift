import AppKit
import ApplicationServices

/// Finds the screen rect of the text caret in the focused app via Accessibility; falls back sensibly.
enum CaretLocator {
    struct Anchor { let rect: CGRect; let exact: Bool }

    static func locate() -> Anchor {
        if let r = caretRect() { return Anchor(rect: r, exact: true) }
        // Fallback: just below the mouse pointer
        let m = NSEvent.mouseLocation
        return Anchor(rect: CGRect(x: m.x, y: m.y - 8, width: 1, height: 16), exact: false)
    }

    private static func caretRect() -> CGRect? {
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef else { return nil }
        let el = focused as! AXUIElement

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeVal = rangeRef else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeVal as! AXValue, .cfRange, &range) else { return nil }

        func bounds(_ r: CFRange) -> CGRect? {
            var rr = r
            guard let v = AXValueCreate(.cfRange, &rr) else { return nil }
            var out: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, v, &out) == .success,
                  let o = out else { return nil }
            var rect = CGRect.zero
            guard AXValueGetValue(o as! AXValue, .cgRect, &rect), rect.width < 4000, rect.height > 0 else { return nil }
            return rect
        }
        var rect = bounds(CFRange(location: range.location, length: 0))
        if rect == nil, range.location > 0 { rect = bounds(CFRange(location: range.location - 1, length: 1)) }
        if rect == nil { rect = bounds(CFRange(location: range.location, length: 1)) }
        guard var r = rect, r != .zero else { return nil }
        // AX coordinates are top-left origin on the primary screen; convert to AppKit bottom-left.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        r.origin.y = primaryHeight - r.origin.y - r.height
        return r
    }
}

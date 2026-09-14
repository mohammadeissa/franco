import AppKit
import Carbon.HIToolbox

/// Global keyboard tap. Routes keys to the Composer while composing; handles toggle hotkeys.
final class EventTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    let composer = Composer()
    private let settings = Settings.shared
    var onToggle: (() -> Void)?
    var onLanguage: ((Int) -> Void)?

    func start() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(proxy: proxy, type: type, event: event)
        }, userInfo: userInfo) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.composer.cancel()
        }
        return true
    }

    func stop() {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let s = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        tap = nil; source = nil
        composer.cancel()
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if Injector.isOurs(event) { return Unmanaged.passUnretained(event) }
        if type == .leftMouseDown || type == .rightMouseDown {
            composer.cancel()
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let hasCmdCtrlOpt = flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate)

        // Toggle hotkey
        if settings.hotkey.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { self.onToggle?() }
            return nil
        }
        // Language hotkeys: same modifiers + 1..4
        if settings.languageHotkeys, settings.hotkey.modifiersMatch(flags), hasCmdCtrlOpt {
            let digits: [Int64: Int] = [18: 0, 19: 1, 20: 2, 21: 3]
            if let idx = digits[keyCode] {
                DispatchQueue.main.async { self.onLanguage?(idx) }
                return nil
            }
        }

        guard settings.enabled, !IsSecureEventInputEnabled() else { return Unmanaged.passUnretained(event) }

        if hasCmdCtrlOpt {
            composer.cancel()
            return Unmanaged.passUnretained(event)
        }

        let composing = composer.isComposing
        switch Int(keyCode) {
        case kVK_Space:
            guard composing else { return Unmanaged.passUnretained(event) }
            if settings.commitOnSpace { composer.commit(trailing: " ") } else { composer.cancel(); return Unmanaged.passUnretained(event) }
            return nil
        case kVK_Return, kVK_ANSI_KeypadEnter:
            guard composing else { return Unmanaged.passUnretained(event) }
            composer.commit()
            Injector.key(CGKeyCode(keyCode), flags: flags)
            return nil
        case kVK_Tab:
            guard composing else { return Unmanaged.passUnretained(event) }
            composer.moveSelection(flags.contains(.maskShift) ? -1 : 1)
            return nil
        case kVK_DownArrow:
            guard composing else { return Unmanaged.passUnretained(event) }
            composer.moveSelection(1); return nil
        case kVK_UpArrow:
            guard composing else { return Unmanaged.passUnretained(event) }
            composer.moveSelection(-1); return nil
        case kVK_Escape:
            guard composing else { return Unmanaged.passUnretained(event) }
            composer.cancel(); return nil
        case kVK_Delete:
            if composing { composer.backspace() }
            return Unmanaged.passUnretained(event)
        case kVK_LeftArrow, kVK_RightArrow, kVK_ForwardDelete, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown:
            composer.cancel()
            return Unmanaged.passUnretained(event)
        default:
            break
        }

        // Printable character?
        var len = 0
        var buf = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &len, unicodeString: &buf)
        guard len == 1, let scalar = Unicode.Scalar(buf[0]) else {
            if composing { composer.cancel() }
            return Unmanaged.passUnretained(event)
        }
        let ch = Character(scalar)

        if ch.isLetter && ch.isASCII {
            composer.append(Character(ch.lowercased()))
            return Unmanaged.passUnretained(event)
        }
        if ch.isNumber && ch.isASCII {
            // digits start a word only for Arabic-script languages (3 7 2 5 ...), otherwise pass through
            let startsWord = Engine.shared.profile(settings.language)?.rtl ?? false
            if composing || startsWord { composer.append(ch) }
            return Unmanaged.passUnretained(event)
        }
        if ch == "'" || ch == "-" {
            if composing { composer.append(ch) }
            return Unmanaged.passUnretained(event)
        }
        // Punctuation / other symbol: commit then emit (possibly localized) punctuation
        if composing {
            composer.commit(trailing: composer.punctuation(for: ch))
            return nil
        }
        if settings.arabicPunctuation {
            let p = composer.punctuation(for: ch)
            if p != String(ch) { Injector.type(p); return nil }
        }
        return Unmanaged.passUnretained(event)
    }
}

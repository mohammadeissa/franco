import Foundation
import Combine
import AppKit

struct Hotkey: Codable, Equatable {
    var keyCode: UInt16
    var command: Bool
    var shift: Bool
    var control: Bool
    var option: Bool

    static let `default` = Hotkey(keyCode: 0 /* A */, command: true, shift: true, control: false, option: false)

    func matches(keyCode kc: Int64, flags: CGEventFlags) -> Bool {
        guard Int64(keyCode) == kc else { return false }
        return flags.contains(.maskCommand) == command
            && flags.contains(.maskShift) == shift
            && flags.contains(.maskControl) == control
            && flags.contains(.maskAlternate) == option
    }

    var modifiersMatch: (CGEventFlags) -> Bool {
        { f in f.contains(.maskCommand) == self.command && f.contains(.maskShift) == self.shift
            && f.contains(.maskControl) == self.control && f.contains(.maskAlternate) == self.option }
    }

    var display: String {
        var s = ""
        if control { s += "⌃" }
        if option { s += "⌥" }
        if shift { s += "⇧" }
        if command { s += "⌘" }
        return s + KeyNames.name(for: keyCode)
    }
}

enum KeyNames {
    static let map: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 49: "Space", 50: "`", 53: "Esc", 36: "↩", 48: "⇥", 51: "⌫",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
    static func name(for code: UInt16) -> String { map[code] ?? "key\(code)" }
}

/// UserDefaults-backed app settings, observable by SwiftUI.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var enabled: Bool { didSet { d.set(enabled, forKey: "enabled") } }
    @Published var language: String { didSet { d.set(language, forKey: "language"); Engine.shared.warm(language) } }
    @Published var hotkey: Hotkey { didSet { if let x = try? JSONEncoder().encode(hotkey) { d.set(x, forKey: "hotkey") } } }
    @Published var arabicPunctuation: Bool { didSet { d.set(arabicPunctuation, forKey: "arabicPunctuation") } }
    @Published var commitOnSpace: Bool { didSet { d.set(commitOnSpace, forKey: "commitOnSpace") } }
    @Published var panelAtCaret: Bool { didSet { d.set(panelAtCaret, forKey: "panelAtCaret") } }
    @Published var maxCandidates: Int { didSet { d.set(maxCandidates, forKey: "maxCandidates") } }
    @Published var learnWords: Bool { didSet { d.set(learnWords, forKey: "learnWords") } }
    @Published var showHints: Bool { didSet { d.set(showHints, forKey: "showHints") } }
    @Published var languageHotkeys: Bool { didSet { d.set(languageHotkeys, forKey: "languageHotkeys") } }
    @Published var panelScale: Double { didSet { d.set(panelScale, forKey: "panelScale") } }
    /// Modifier set for the language hotkeys (+ 1…4). Keys: "cs" ⌃⇧, "co" ⌃⌥, "os" ⌥⇧, "coc" ⌃⌥⌘
    @Published var languageModifiers: String { didSet { d.set(languageModifiers, forKey: "languageModifiers") } }

    static let modifierChoices: [(String, String)] = [("cs", "⌃⇧"), ("co", "⌃⌥"), ("os", "⌥⇧"), ("coc", "⌃⌥⌘")]
    func languageModifiersMatch(_ f: CGEventFlags) -> Bool {
        let c = f.contains(.maskControl), o = f.contains(.maskAlternate), s = f.contains(.maskShift), m = f.contains(.maskCommand)
        switch languageModifiers {
        case "co": return c && o && !s && !m
        case "os": return o && s && !c && !m
        case "coc": return c && o && m && !s
        default: return c && s && !o && !m
        }
    }
    var languageModifierMask: NSEvent.ModifierFlags {
        switch languageModifiers { case "co": return [.control, .option]; case "os": return [.option, .shift]; case "coc": return [.control, .option, .command]; default: return [.control, .shift] }
    }
    var languageModifierDisplay: String { Settings.modifierChoices.first { $0.0 == languageModifiers }?.1 ?? "⌃⇧" }

    private init() {
        d.register(defaults: [
            "enabled": true, "language": "ar", "arabicPunctuation": true, "commitOnSpace": true,
            "panelAtCaret": true, "maxCandidates": 7, "learnWords": true, "showHints": true, "languageHotkeys": true,
            "panelScale": 1.0, "languageModifiers": "cs"
        ])
        enabled = d.bool(forKey: "enabled")
        language = d.string(forKey: "language") ?? "ar"
        if let x = d.data(forKey: "hotkey"), let h = try? JSONDecoder().decode(Hotkey.self, from: x) { hotkey = h } else { hotkey = .default }
        arabicPunctuation = d.bool(forKey: "arabicPunctuation")
        commitOnSpace = d.bool(forKey: "commitOnSpace")
        panelAtCaret = d.bool(forKey: "panelAtCaret")
        maxCandidates = max(3, min(9, d.integer(forKey: "maxCandidates")))
        learnWords = d.bool(forKey: "learnWords")
        showHints = d.bool(forKey: "showHints")
        languageHotkeys = d.bool(forKey: "languageHotkeys")
        panelScale = d.double(forKey: "panelScale")
        languageModifiers = d.string(forKey: "languageModifiers") ?? "cs"
    }
}

import Foundation
import AppKit

let args = CommandLine.arguments
if args.count >= 3, args[1] == "--translit" {
    // franco --translit <lang> "word word ..."
    let lang = args[2]
    let text = args.dropFirst(3).joined(separator: " ")
    let t0 = Date()
    guard let t = Engine.shared.transliterator(lang) else { print("unknown language \(lang)"); exit(1) }
    let load = Date().timeIntervalSince(t0)
    var total = 0.0
    for word in text.split(separator: " ") {
        let s = Date()
        let c = t.candidates(for: String(word), limit: 7)
        let ms = Date().timeIntervalSince(s) * 1000
        total += ms
        let shown = c.map { cand -> String in
            let tag = cand.kind == .exact ? "" : (cand.kind == .literal ? "·lit" : "·+")
            return "\(cand.text)\(tag)"
        }.joined(separator: "  |  ")
        print(String(format: "%-14@ → %@   (%.1f ms)", String(word) as NSString, shown as NSString, ms))
    }
    print(String(format: "load %.0f ms · %d words · %.1f ms total", load * 1000, t.lexicon.trie.count, total))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

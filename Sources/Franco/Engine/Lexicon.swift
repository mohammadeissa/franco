import Foundation

/// Dictionary (frequency list) + Egyptian supplement + user-learned words, as a trie.
final class Lexicon {
    let profile: Profile
    let trie = Trie()
    private(set) var learned: [String: Int] = [:]
    private let learnedURL: URL

    init(profile: Profile) {
        self.profile = profile
        learnedURL = ResourceLocator.supportDir.appendingPathComponent("learned-\(profile.id).json")
        load()
    }

    private static let marks: Set<UInt32> = {
        var s = Set<UInt32>()
        for v in 0x064B...0x0652 { s.insert(UInt32(v)) }   // Arabic tashkeel
        s.insert(0x0670); s.insert(0x0640)                   // superscript alef, tatweel
        return s
    }()

    func normalize(_ w: String) -> String {
        guard profile.stripMarks else { return w }
        var out = String.UnicodeScalarView()
        for s in w.unicodeScalars where !Lexicon.marks.contains(s.value) { out.append(s) }
        return String(out)
    }

    private func isWordChar(_ s: Unicode.Scalar) -> Bool {
        switch s.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .otherLetter, .modifierLetter, .titlecaseLetter,
             .nonspacingMark, .spacingMark, .decimalNumber:
            return true
        default:
            return s.value == 0x200C || s == "-" || s == "'"   // ZWNJ (Persian), hyphen, apostrophe
        }
    }

    private func load() {
        for name in profile.dicts {
            guard let text = try? String(contentsOf: ResourceLocator.dict(name), encoding: .utf8) else { continue }
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                let parts = line.split(separator: " ", maxSplits: 1)
                guard parts.count == 2, let f = Int(parts[1]) else { continue }
                let w = normalize(String(parts[0]))
                guard !w.isEmpty, w.unicodeScalars.allSatisfy(isWordChar) else { continue }
                // Drop pure-ASCII entries (subtitles leak English words)
                guard w.unicodeScalars.contains(where: { $0.value > 0x7F }) else { continue }
                trie.insert(w, freq: f)
            }
        }
        if let d = try? Data(contentsOf: learnedURL),
           let m = try? JSONSerialization.jsonObject(with: d) as? [String: Int] {
            learned = m
            for (w, n) in m { trie.insert(w, freq: n * 200_000) }
        }
    }

    /// Record that the user picked `word` for input `latin`.
    func learn(_ word: String) {
        let w = normalize(word)
        guard !w.isEmpty else { return }
        learned[w, default: 0] += 1
        trie.insert(w, freq: 200_000)
        save()
    }

    func resetLearned() {
        learned = [:]
        try? FileManager.default.removeItem(at: learnedURL)
    }

    private func save() {
        if let d = try? JSONSerialization.data(withJSONObject: learned, options: [.prettyPrinted, .sortedKeys]) {
            try? d.write(to: learnedURL, options: .atomic)
        }
    }
}

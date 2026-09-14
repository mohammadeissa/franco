import Foundation

struct Candidate: Equatable {
    enum Kind { case exact, literal, completion }
    let text: String
    let score: Double
    let kind: Kind
}

/// Trie-constrained transliteration: walks the Latin input and the dictionary trie together,
/// so only real words surface; ranks them by frequency minus mapping cost. Adds a deterministic
/// literal transliteration (two vowel styles) and a few completions.
final class Transliterator {
    let profile: Profile
    let lexicon: Lexicon
    private let costCap = 7.0
    private let costWeight = 1.15

    init(profile: Profile, lexicon: Lexicon) {
        self.profile = profile
        self.lexicon = lexicon
    }

    // MARK: - Public

    func candidates(for rawInput: String, limit: Int = 7) -> [Candidate] {
        let input = Array(rawInput.lowercased())
        guard !input.isEmpty else { return [] }

        var results: [String: Double] = [:]
        var endNodes: [ObjectIdentifier: (TrieNode, Double)] = [:]
        var best: [Int: [ObjectIdentifier: Double]] = [:]
        var visited = 0

        func record(_ node: TrieNode, _ cost: Double) {
            if node.freq > 0, let w = node.word {
                let s = log(Double(node.freq) + 1) - costWeight * cost
                if s > (results[w] ?? -Double.infinity) { results[w] = s }
            }
            let id = ObjectIdentifier(node)
            if cost < (endNodes[id]?.1 ?? Double.infinity) { endNodes[id] = (node, cost) }
        }

        func step(_ pos: Int, _ node: TrieNode, _ cost: Double) -> Bool {
            visited += 1
            if visited > 40_000 || cost > costCap { return false }
            let id = ObjectIdentifier(node)
            if let b = best[pos]?[id], b <= cost { return false }
            best[pos, default: [:]][id] = cost
            return true
        }

        if profile.kind == "abugida" {
            func dfs(_ pos: Int, _ node: TrieNode, _ cost: Double) {
                guard step(pos, node, cost) else { return }
                if pos == input.count { record(node, cost); return }
                let rem = input.count - pos
                var matchedAny = false
                // 1. consonant (+ optional vowel sign)
                for clen in stride(from: min(3, rem), through: 1, by: -1) {
                    let chunk = String(input[pos..<pos + clen])
                    guard let cons = profile.consonants[chunk] else { continue }
                    matchedAny = true
                    let after = pos + clen
                    var matchedVowel = false
                    for vlen in stride(from: min(2, input.count - after), through: 1, by: -1) where vlen > 0 {
                        let vchunk = String(input[after..<after + vlen])
                        let vf = (after + vlen == input.count ? profile.vowelEnd[vchunk] : nil) ?? profile.vowelMap[vchunk]
                        guard let vfrags = vf else { continue }
                        matchedVowel = true
                        for c in cons { for v in vfrags {
                            if let nn = lexicon.trie.walk(node, c.text + v.matra) { dfs(after + vlen, nn, cost + c.cost + v.cost) }
                        } }
                    }
                    if !matchedVowel {
                        for c in cons {
                            if let nn = lexicon.trie.walk(node, c.text) { dfs(after, nn, cost + c.cost + (after == input.count ? 0 : 0.25)) }
                            if after < input.count, let nn = lexicon.trie.walk(node, c.text + profile.virama) { dfs(after, nn, cost + c.cost + 0.3) }
                        }
                    }
                    if pos > 0, clen == 1, chunk == "n" || chunk == "m" {
                        for nz in profile.nasal { if let nn = lexicon.trie.walk(node, nz.text) { dfs(after, nn, cost + nz.cost) } }
                    }
                }
                // 2. standalone vowel (independent form)
                for vlen in stride(from: min(2, rem), through: 1, by: -1) {
                    let vchunk = String(input[pos..<pos + vlen])
                    let vf = (pos + vlen == input.count ? profile.vowelEnd[vchunk] : nil) ?? profile.vowelMap[vchunk]
                    guard let vfrags = vf else { continue }
                    matchedAny = true
                    for v in vfrags where !v.independent.isEmpty {
                        if let nn = lexicon.trie.walk(node, v.independent) { dfs(pos + vlen, nn, cost + v.cost + (pos == 0 ? 0 : 0.6)) }
                    }
                }
                if !matchedAny { dfs(pos + 1, node, cost + 1.0) }
            }
            dfs(0, lexicon.trie.root, 0)
        } else {
            func rulesFor(_ chunk: String, _ atStart: Bool, _ atEnd: Bool) -> [Frag]? {
                if atEnd, let r = profile.end[chunk] { return r }
                if atStart, let r = profile.start[chunk] { return r }
                return profile.rules[chunk]
            }
            func dfs(_ pos: Int, _ node: TrieNode, _ cost: Double) {
                guard step(pos, node, cost) else { return }
                if pos == input.count { record(node, cost); return }
                let rem = input.count - pos
                var matchedAny = false
                // doubled consonant == shadda (single letter)
                if rem >= 2, input[pos] == input[pos + 1], !profile.vowels.contains(input[pos]), input[pos].isLetter {
                    let k = String(input[pos])
                    if let fr = rulesFor(k, pos == 0, pos + 2 == input.count) {
                        matchedAny = true
                        for f in fr where !f.text.isEmpty {
                            if let nn = lexicon.trie.walk(node, f.text) { dfs(pos + 2, nn, cost + f.cost + 0.1) }
                        }
                    }
                }
                var longerMatched = false
                for len in stride(from: min(profile.maxChunk, rem), through: 1, by: -1) {
                    let chunk = String(input[pos..<pos + len])
                    guard let fr = rulesFor(chunk, pos == 0, pos + len == input.count) else { continue }
                    matchedAny = true
                    let penalty = longerMatched ? 0.5 : 0   // prefer digraphs (sh, kh, gh…) over letter-by-letter
                    longerMatched = true
                    for f in fr {
                        if f.text.isEmpty { dfs(pos + len, node, cost + f.cost + penalty); continue }
                        if let nn = lexicon.trie.walk(node, f.text) { dfs(pos + len, nn, cost + f.cost + penalty) }
                    }
                }
                if !matchedAny { dfs(pos + 1, node, cost + 1.0) }
            }
            dfs(0, lexicon.trie.root, 0)
        }

        var out: [Candidate] = results.map { Candidate(text: $0.key, score: $0.value, kind: .exact) }
            .sorted { $0.score > $1.score }
        var seen = Set(out.map { $0.text })

        // literal fallbacks
        let lits = [literal(rawInput, expanded: false), literal(rawInput, expanded: true)]
        var litCands: [Candidate] = []
        for l in lits where !l.isEmpty && !seen.contains(l) {
            seen.insert(l); litCands.append(Candidate(text: l, score: -100, kind: .literal))
        }
        if out.isEmpty { out = litCands } else { out.append(contentsOf: litCands) }

        // completions from the deepest end nodes
        if input.count >= 2 {
            var comps: [(String, Int)] = []
            for (_, (node, _)) in endNodes.sorted(by: { $0.value.1 < $1.value.1 }).prefix(6) {
                comps.append(contentsOf: lexicon.trie.completions(from: node, limit: 4))
            }
            comps.sort { $0.1 > $1.1 }
            var added = 0
            for (w, _) in comps where !seen.contains(w) && added < 3 {
                seen.insert(w); out.append(Candidate(text: w, score: -200, kind: .completion)); added += 1
            }
        }
        return Array(out.prefix(limit))
    }

    /// Deterministic transliteration used when the dictionary has nothing.
    func literal(_ rawInput: String, expanded: Bool) -> String {
        let input = Array(rawInput.lowercased())
        var out = ""
        var pos = 0
        let n = input.count
        if profile.kind == "abugida" {
            var prevConsonantOpen = false
            while pos < n {
                var matched = false
                for clen in stride(from: min(3, n - pos), through: 1, by: -1) {
                    let chunk = String(input[pos..<pos + clen])
                    guard let base = profile.literalConsonants[chunk] else { continue }
                    matched = true
                    let after = pos + clen
                    var vlenMatched = 0
                    var matra = ""
                    for vlen in stride(from: min(2, n - after), through: 1, by: -1) where vlen > 0 {
                        let vchunk = String(input[after..<after + vlen])
                        if let lv = profile.literalVowels[vchunk] { matra = lv.1; vlenMatched = vlen; break }
                    }
                    if vlenMatched > 0 {
                        // final "a" is long
                        if after + vlenMatched == n, String(input[after..<after + vlenMatched]) == "a" { matra = "ा" }
                        out += base + matra; pos = after + vlenMatched; prevConsonantOpen = false
                    } else if after == n {
                        out += base; pos = after; prevConsonantOpen = false
                    } else {
                        out += base + profile.virama; pos = after; prevConsonantOpen = true
                    }
                    break
                }
                if matched { continue }
                var vmatched = false
                for vlen in stride(from: min(2, n - pos), through: 1, by: -1) {
                    let vchunk = String(input[pos..<pos + vlen])
                    if let lv = profile.literalVowels[vchunk] {
                        if prevConsonantOpen, out.hasSuffix(profile.virama) { out.removeLast(); out += lv.1 } else { out += lv.0 }
                        pos += vlen; vmatched = true; prevConsonantOpen = false; break
                    }
                }
                if !vmatched { out.append(input[pos]); pos += 1 }
            }
            return out
        }
        while pos < n {
            // collapse doubled consonants
            if pos + 1 < n, input[pos] == input[pos + 1], !profile.vowels.contains(input[pos]), input[pos].isLetter,
               profile.literal[String(input[pos])] != nil {
                let (s, m, e) = profile.literal[String(input[pos])]!
                out += pos == 0 ? s : (pos + 2 == n ? e : m)
                pos += 2; continue
            }
            var matched = false
            for len in stride(from: min(profile.maxChunk, n - pos), through: 1, by: -1) {
                let chunk = String(input[pos..<pos + len])
                guard let (s, m, e) = profile.literal[chunk] else { continue }
                if pos == 0 { out += s }
                else if pos + len == n { out += e }
                else if expanded, let x = profile.expanded[chunk] { out += x }
                else { out += m }
                pos += len; matched = true; break
            }
            if !matched { out.append(input[pos]); pos += 1 }
        }
        return out
    }
}

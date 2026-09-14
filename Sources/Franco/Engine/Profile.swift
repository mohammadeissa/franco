import Foundation

typealias Frag = (text: String, cost: Double)
typealias VowelFrag = (independent: String, matra: String, cost: Double)

/// Language profile loaded from Resources/profiles/<id>.json.
struct Profile {
    let id: String
    let name: String
    let flag: String
    let kind: String              // "alphabet" | "abugida"
    let rtl: Bool
    let dicts: [String]
    let stripMarks: Bool
    let punct: [String: String]
    let vowels: Set<Character>

    // alphabet
    let rules: [String: [Frag]]
    let start: [String: [Frag]]
    let end: [String: [Frag]]
    let literal: [String: (String, String, String)]   // start, mid, end
    let expanded: [String: String]

    // abugida
    let virama: String
    let consonants: [String: [Frag]]
    let vowelMap: [String: [VowelFrag]]
    let vowelEnd: [String: [VowelFrag]]
    let nasal: [Frag]
    let literalConsonants: [String: String]
    let literalVowels: [String: (String, String)]

    let maxChunk: Int

    static func load(_ id: String) throws -> Profile {
        let data = try Data(contentsOf: ResourceLocator.profile(id))
        guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Franco", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad profile \(id)"])
        }
        func frags(_ any: Any?) -> [String: [Frag]] {
            guard let d = any as? [String: [[Any]]] else { return [:] }
            var out: [String: [Frag]] = [:]
            for (k, arr) in d {
                out[k] = arr.compactMap { a in
                    guard a.count == 2, let t = a[0] as? String, let c = a[1] as? NSNumber else { return nil }
                    return (t, c.doubleValue)
                }
            }
            return out
        }
        func vfrags(_ any: Any?) -> [String: [VowelFrag]] {
            guard let d = any as? [String: [[Any]]] else { return [:] }
            var out: [String: [VowelFrag]] = [:]
            for (k, arr) in d {
                out[k] = arr.compactMap { a in
                    guard a.count == 3, let i = a[0] as? String, let m = a[1] as? String, let c = a[2] as? NSNumber else { return nil }
                    return (i, m, c.doubleValue)
                }
            }
            return out
        }
        func lit(_ any: Any?) -> [String: (String, String, String)] {
            guard let d = any as? [String: Any] else { return [:] }
            var out: [String: (String, String, String)] = [:]
            for (k, v) in d {
                if let s = v as? String { out[k] = (s, s, s) }
                else if let a = v as? [String], a.count == 3 { out[k] = (a[0], a[1], a[2]) }
            }
            return out
        }
        func litV(_ any: Any?) -> [String: (String, String)] {
            guard let d = any as? [String: [String]] else { return [:] }
            var out: [String: (String, String)] = [:]
            for (k, a) in d where a.count == 2 { out[k] = (a[0], a[1]) }
            return out
        }
        let rules = frags(j["rules"]), start = frags(j["start"]), end = frags(j["end"])
        let cons = frags(j["consonants"]), vm = vfrags(j["vowels_map"]), ve = vfrags(j["vowel_end"])
        let literal = lit(j["literal"])
        let nasalArr = (j["nasal"] as? [[Any]] ?? []).compactMap { a -> Frag? in
            guard a.count == 2, let t = a[0] as? String, let c = a[1] as? NSNumber else { return nil }
            return (t, c.doubleValue)
        }
        let keys = Array(rules.keys) + Array(start.keys) + Array(end.keys) + Array(cons.keys) + Array(vm.keys) + Array(literal.keys)
        return Profile(
            id: j["id"] as? String ?? id,
            name: j["name"] as? String ?? id,
            flag: j["flag"] as? String ?? "",
            kind: j["kind"] as? String ?? "alphabet",
            rtl: j["rtl"] as? Bool ?? false,
            dicts: j["dict"] as? [String] ?? [],
            stripMarks: j["stripMarks"] as? Bool ?? false,
            punct: j["punct"] as? [String: String] ?? [:],
            vowels: Set((j["vowels"] as? String ?? "aeiou")),
            rules: rules, start: start, end: end, literal: literal,
            expanded: j["expanded"] as? [String: String] ?? [:],
            virama: j["virama"] as? String ?? "्",
            consonants: cons, vowelMap: vm, vowelEnd: ve, nasal: nasalArr,
            literalConsonants: j["literal_consonants"] as? [String: String] ?? [:],
            literalVowels: litV(j["literal_vowels"]),
            maxChunk: keys.map { $0.count }.max() ?? 3
        )
    }

    static let all = ["ar", "hi", "ru", "fa"]
}

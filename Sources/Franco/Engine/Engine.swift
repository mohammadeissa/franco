import Foundation

/// Owns one Transliterator per language, lazily built and cached.
final class Engine {
    static let shared = Engine()
    private var cache: [String: Transliterator] = [:]
    private let lock = NSLock()

    func transliterator(_ id: String) -> Transliterator? {
        lock.lock(); defer { lock.unlock() }
        if let t = cache[id] { return t }
        guard let p = try? Profile.load(id) else { return nil }
        let t = Transliterator(profile: p, lexicon: Lexicon(profile: p))
        cache[id] = t
        return t
    }

    func profile(_ id: String) -> Profile? { transliterator(id)?.profile }

    func warm(_ id: String) { DispatchQueue.global(qos: .userInitiated).async { _ = self.transliterator(id) } }
}

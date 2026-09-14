import Foundation

/// Compact trie over Unicode scalars. Leaves carry a frequency (>0 == word).
final class TrieNode {
    var children: [UInt32: TrieNode] = [:]
    var freq: Int = 0
    var word: String? = nil

    @inline(__always) func child(_ s: UInt32) -> TrieNode? { children[s] }
}

final class Trie {
    let root = TrieNode()
    private(set) var count = 0

    func insert(_ word: String, freq: Int) {
        var node = root
        for s in word.unicodeScalars {
            if let c = node.children[s.value] { node = c } else {
                let c = TrieNode(); node.children[s.value] = c; node = c
            }
        }
        if node.freq == 0 { count += 1; node.word = word }
        node.freq += freq
    }

    /// Walk from `node` consuming `fragment`; nil if the path does not exist.
    @inline(__always) func walk(_ node: TrieNode, _ fragment: String) -> TrieNode? {
        var n = node
        for s in fragment.unicodeScalars {
            guard let c = n.children[s.value] else { return nil }
            n = c
        }
        return n
    }

    /// Collect up to `limit` words in the subtree below `node`, ranked by frequency.
    func completions(from node: TrieNode, limit: Int, maxDepth: Int = 4) -> [(String, Int)] {
        var out: [(String, Int)] = []
        var stack: [(TrieNode, Int)] = [(node, 0)]
        var visited = 0
        while let (n, d) = stack.popLast() {
            visited += 1
            if visited > 4000 { break }
            if n.freq > 0, let w = n.word, n !== node { out.append((w, n.freq)) }
            if d < maxDepth { for (_, c) in n.children { stack.append((c, d + 1)) } }
        }
        out.sort { $0.1 > $1.1 }
        return Array(out.prefix(limit))
    }
}

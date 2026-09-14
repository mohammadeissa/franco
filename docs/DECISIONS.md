# Decisions — Franco

## 2026-09-13
1. **Swift + CGEventTap, not Python/pynput.** `wispr` (sibling project) documents pynput crashing on macOS 26; a tap is also the only clean way to swallow Space/Tab/Esc while composing.
2. **Not an IMKit input method.** IMKit gives a native candidate window but requires switching input sources and is painful to develop without Xcode; the tap approach works with the user's current keyboard and toggles instantly.
3. **Pass-through composition + replace on commit** (Yamli feel: you see your Latin letters, they get swapped) instead of swallowing letters until commit. Replacement uses backspaces + `keyboardSetUnicodeString`, never the clipboard.
4. **Trie-constrained DFS over a frequency dictionary** for candidates (only real words surface, ranked by frequency − mapping cost), plus a deterministic literal fallback in two vowel styles, plus ≤3 completions. Chosen over forward rule expansion (combinatorial, no ranking) and over an ML model (offline, size, latency).
5. **Lexicons:** hermitdave/FrequencyWords OpenSubtitles lists (CC-BY-SA, fine for personal use) + a hand-curated Egyptian supplement with boosted frequencies so dialect wins over MSA homographs (`eh` → إيه, `2ahwa` → قهوة).
6. **Languages:** Arabic (Egyptian-first), Hindi, Russian, Persian — largest romanized-typing communities. Urdu/Greek/Turkish are one profile JSON away.
7. **Digits start a word only in Arabic-script languages** (2 3 5 6 7 8 9 are letters in Arabizi); a digits-only buffer is never replaced.
8. **Resources located by path, not `Bundle.module`,** so the same binary works from `swift run` and from the .app.
9. **Ad-hoc codesign with a fixed identifier** so the Accessibility grant survives rebuilds.

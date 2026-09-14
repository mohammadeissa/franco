# Franco — Implementation Plan (2026-09-13)

System-wide Arabizi → Arabic (and Hinglish → Devanagari, translit → Cyrillic, Pinglish → Persian) auto-typing for macOS. Works in any text field (WhatsApp, Messages, Safari, Notes…). Yamli-style: as you type a Latin word a floating panel shows ranked candidates; Space commits the highlighted one, arrows/Tab cycle, Esc keeps the Latin text.

## 1. Constraints & decisions

| Concern | Decision | Why |
|---|---|---|
| Language | Swift 6, SwiftPM executable packaged into `Franco.app` (LSUIElement menu-bar app) | Native CGEventTap + NSPanel + AX APIs; `wispr` project proved pynput crashes on macOS 26; no Xcode project needed (`swift build` + `scripts/bundle.sh`) |
| Keystroke capture | `CGEvent.tapCreate` at `.cgSessionEventTap`, `.headInsertEventTap`, `.defaultTap` (can swallow events) | Needs Accessibility permission once; lets us intercept Space/Tab/Esc/arrows while composing |
| Text replacement | Let Latin letters pass through (user sees what they type). On commit: post N `Delete` key events, then post the target word via `CGEvent` + `keyboardSetUnicodeString` (≤20 chars/event, chunked) | No clipboard clobbering; works in Electron, Catalyst (WhatsApp), WebKit, AppKit |
| Candidate panel | Non-activating `NSPanel` (`.nonactivatingPanel`, floating level) positioned at caret via AX `kAXBoundsForRangeParameterizedAttribute`; fallback: below mouse pointer / bottom-center of focused window | Never steals focus from the target app |
| Candidate engine | Trie-constrained DFS: dictionary (frequency list) stored as a trie of target-script words; Latin input segmented by per-language rule table (`latin chunk → [target fragments, cost]`); DFS walks input × trie simultaneously → only real words surface, ranked by `log(freq) − cost`; plus a deterministic rule-based transliteration appended as the "literal" candidate and prefix matches for long/unfinished words | This is how Yamli feels: vowels optional, digits (2 3 5 6 7 8 9) & digraphs (sh kh gh th dh ch) handled, dialect spelling tolerant |
| Lexicons | hermitdave/FrequencyWords (OpenSubtitles 2018) ar/ru/fa 50k, hi 21k + hand-curated Egyptian-dialect supplement (`Resources/dict/ar_egy.txt`) + user-learned words (`~/Library/Application Support/Franco/learned.json`, boosted on every pick) | Offline, fast (trie builds in <150 ms), improves with use |
| Languages | Arabic (Egyptian-first), Hindi, Russian, Persian | Largest romanized-typing communities: 400M+ / 600M / 250M / 110M speakers; rules in `Resources/profiles/*.json` so adding Urdu/Greek/Turkish later = one JSON file |
| Toggle | Global hotkey (default ⌘⇧A, configurable) + menu-bar click + per-language shortcut ⌃⌥1-4 | Instant on/off so English typing is never affected |
| Settings | SwiftUI window from menu bar: enabled, language, hotkey recorder, Arabic punctuation (? → ؟ , → ،), panel placement, "commit on Space", max candidates, learned words reset, launch at login | Easy config as requested |
| Abort rules | Composing stops (buffer flushed as Latin) on: app switch, mouse click, Cmd-key combos, Enter with empty buffer, non-word chars | Never traps the user |

## 2. Architecture

```
Franco.app (menu bar, no Dock icon)
├── main.swift            NSApplication bootstrap, CLI mode (`--translit ar mar7aba` for tests)
├── AppDelegate.swift     status item, menu, permission prompt, wiring
├── EventTap.swift        CGEventTap; key → Composer; hotkeys; swallow logic
├── Composer.swift        state machine: idle → composing(buffer) → commit/cancel; text injection
├── Injector.swift        post backspaces + unicode string via CGEvent
├── CaretLocator.swift    AX caret rect for panel placement (+fallbacks)
├── CandidatePanel.swift  NSPanel + SwiftUI candidate list (numbered, highlighted)
├── Engine/
│   ├── Profile.swift     language profile model (loaded from JSON)
│   ├── Trie.swift        compact trie over Unicode scalars, freq at leaves
│   ├── Lexicon.swift     loads dict + supplement + learned; builds trie per language (lazy, cached)
│   ├── Transliterator.swift  DFS matcher + literal fallback + ranking
│   └── Devanagari.swift  abugida-aware fragment generator for Hindi (consonant × vowel-sign, virama, nukta, anusvara)
├── Settings.swift        UserDefaults-backed ObservableObject
├── SettingsView.swift    SwiftUI settings window + hotkey recorder
└── Resources/ profiles/{ar,hi,ru,fa}.json  dict/{ar,hi,ru,fa}.txt  dict/ar_egy.txt
```

Flow: keyDown → EventTap → (if enabled && printable Latin/digit/apostrophe) append to buffer, pass event through, recompute candidates (async on engine queue, ≤5 ms), update panel → on Space/Enter/Tab/Esc/arrows while composing: swallow event, act.

## 3. Build order

1. Engine + CLI test harness (`swift run franco --translit ar "mar7aba ezayak 3amel eh"`) — verify quality on a 60-word Egyptian test sheet, plus hi/ru/fa spot checks.
2. Event tap + injector + minimal panel; manual test in TextEdit/Notes/WhatsApp.
3. Caret placement, settings window, hotkey recorder, learned words, launch-at-login.
4. `scripts/bundle.sh` → `build/Franco.app`; `scripts/install.sh` copies to /Applications and opens it; docs.

## 4. Verification

- Unit-style CLI checks: known words map to expected top-1 (`tests/cases_ar.txt` etc.), run by `scripts/test.sh`.
- Manual: Accessibility grant → type in WhatsApp; toggle hotkey; app switch mid-word; RTL punctuation.

## 5. Known limits (state up-front)

- Requires Accessibility permission (System Settings → Privacy & Security → Accessibility → Franco).
- Secure text fields (passwords) are untouchable by design (macOS blocks taps there).
- Caret-anchored panel depends on the app exposing AX text ranges; Electron apps often don't → panel falls back near the mouse pointer.
- Candidate quality is dictionary-bound; unknown words fall back to literal transliteration (still correct for most Arabizi).

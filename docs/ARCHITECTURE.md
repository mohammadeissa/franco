# Architecture — Franco

Swift 6 SwiftPM executable → packaged into `build/Franco.app` by `scripts/bundle.sh` (LSUIElement menu-bar app, ad-hoc signed).

## Modules (`Sources/Franco/`)
| File | Role |
|---|---|
| `main.swift` | CLI mode (`--translit`) or NSApplication bootstrap (`.accessory` policy) |
| `AppDelegate.swift` | status item + menu, Accessibility permission flow (prompt, poll every 1.5 s, then start tap), settings window |
| `EventTap.swift` | `CGEvent.tapCreate` session tap (head insert, can swallow). Key routing: hotkeys → composer keys (Space/Enter/Tab/↑↓/Esc/⌫) → printable chars → punctuation. Cancels on app switch, mouse click, modifier combos, navigation keys, secure input |
| `Composer.swift` | buffer + candidates + selection; commit = backspaces + unicode injection (+ trailing space/punct); learns picks |
| `Injector.swift` | synthetic key events tagged with `eventSourceUserData = "FRNC"`; unicode text in ≤20-UTF16 chunks |
| `CaretLocator.swift` | AX focused element → selected range → `AXBoundsForRange` → AppKit coords; fallback = mouse |
| `CandidatePanel.swift` | non-activating floating `NSPanel` + SwiftUI list (numbered rows, highlighted selection, kind badges, hints) |
| `Settings.swift` | `UserDefaults`-backed `ObservableObject` + `Hotkey` model |
| `SettingsView.swift` | SwiftUI form: enable, language, hotkey recorder, typing/panel options, launch at login (SMAppService), AX status, try-it field |
| `Engine/Profile.swift` | JSON profile model (alphabet rules or abugida tables) |
| `Engine/Trie.swift` | scalar trie with frequencies; completions |
| `Engine/Lexicon.swift` | loads dict files (strips tashkeel, drops ASCII junk) + learned words (`~/Library/Application Support/Franco/learned-<lang>.json`) |
| `Engine/Transliterator.swift` | trie-constrained DFS (alphabet + abugida variants), literal fallback (compact/expanded vowels), completions, ranking |
| `Engine/Engine.swift` | per-language transliterator cache, warm-up |
| `Engine/Resources.swift` | resource location (env → bundle → source tree) |

## Data
- `Resources/profiles/{ar,hi,ru,fa}.json` — mapping rules with costs; start/end context tables; literal tables; punctuation map.
- `Resources/dict/{ar,ru,fa}.txt` (50k, OpenSubtitles 2018 via hermitdave/FrequencyWords), `hi.txt` (21k), `ar_egy.txt` (hand-curated Egyptian dialect, ~465 words, boosted frequencies).
- Learned words: JSON per language in Application Support; inserted into the trie with a 200k boost per pick.

## Key flow
```
keyDown ──tap──▶ EventTap.handle ──▶ Composer.append ──▶ Transliterator.candidates (≤1 ms)
                                                        └──▶ CandidatePanel.show(at: CaretLocator.locate())
Space ──▶ Composer.commit ──▶ Injector.replace(deleteCount: n, with: word, trailing: " ")
```
Ranking: `ln(freq) − 1.15·cost`; exact dictionary matches → literal (2 styles) → completions (max 3).

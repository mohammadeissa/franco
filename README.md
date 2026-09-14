<div align="center">

# ⌨️ Franco

**Type Arabic the way you already type it. In every app on your Mac.**

`ezayak 3amel eh` → `إزيك عامل إيه`

A menu-bar app that watches the Latin word you're typing, shows ranked Arabic candidates in a floating panel next to your cursor, and swaps the word in when you hit Space. Works in WhatsApp, iMessage, Safari, Notes, Slack, Mail, anywhere. Also does Hindi, Russian and Persian. 100 % offline.

</div>

---

## The problem

Millions of people type Arabic in Latin letters: *Franco*, *Arabizi*, *3arabi*. It's fast because you never switch keyboards. It's also ugly, unreadable to parents, and useless for anything formal. [Yamli](https://www.yamli.com) solved this beautifully in 2009 but only inside a web page. Every messaging app still forces you to choose: switch layouts and hunt for letters, or send `mesh 3aref`.

Franco is Yamli for the whole operating system.

## How it feels

```
you type:    mar7aba
panel shows: 1 مرحبا   2 مرحب   3 مارحابا (literal)
Space →      مرحبا␣
```

- Type normally. Latin letters appear as usual.
- A small panel follows your caret with up to 9 candidates, best first.
- `Space` or `Enter` commits the highlighted one. `↑` `↓` or `Tab` cycle. `Esc` keeps the Latin word.
- Digits work the way you already use them: `2`=ء/ق, `3`=ع, `5`=خ, `6`=ط, `7`=ح, `8`=ق, `9`=ص. `sh`, `kh`, `gh`, `th`, `dh` too. Vowels optional.
- `?` and `,` become `؟` and `،` while you're in Arabic.
- Pick a second-ranked word once and Franco ranks it first next time.
- `⌘⇧A` turns it off instantly for English. `⌃⇧1-4` switch language.

## Why the candidates are good

Franco doesn't just map letters. It walks your Latin input and a **50,000-word frequency dictionary** at the same time, so only real words surface, ranked by how common they are minus how unusual the spelling mapping is. `kitab` gives كتاب, `so2al` gives سؤال, `2ahwa` gives قهوة, `delwa2ty` gives دلوقتي. A hand-curated Egyptian-dialect list on top makes sure `eh` is إيه and `keda` is كده, not the Modern Standard Arabic homographs. Unknown words fall back to a literal transliteration in two vowel styles. All of this runs in under a millisecond per keystroke.

Same engine, four languages:

| | Input | Output |
|---|---|---|
| 🇪🇬 Arabic | `el7amdulillah` | الحمدلله |
| 🇮🇳 Hindi | `dhanyavaad` | धन्यवाद |
| 🇷🇺 Russian | `pozhaluysta` | пожалуйста |
| 🇮🇷 Persian | `chetori` | چطوری |

Adding a language is one JSON file of mapping rules plus a word list.

## Install

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/mohammadeissa/franco.git
cd franco
./scripts/install.sh     # builds, copies to /Applications, launches
```

On first launch macOS asks for **Accessibility** access (System Settings → Privacy & Security → Accessibility → Franco). Franco needs it to see what you type and to replace it. It starts working the moment you flip the switch. No network access, ever.

Menu bar → **Settings…** for hotkey recording, language, punctuation, panel size, launch at login and a try-it box.

## How it works

Swift 6, no Xcode project, no dependencies.

- **CGEventTap** intercepts keystrokes system-wide and swallows Space/Tab/Esc/arrows only while a word is being composed.
- **Replacement** is backspaces + a Unicode key event. No clipboard, so your paste buffer is untouched.
- **Panel** is a non-activating `NSPanel` anchored to the caret via the Accessibility API, falling back to the mouse pointer for apps that don't expose it.
- **Engine** is a trie-constrained depth-first search over language profiles (`Resources/profiles/*.json`), testable from the command line:

```bash
swift run Franco --translit ar "sabah elkheir ya 7abibi"
./scripts/test.sh     # 84 regression cases across 4 languages
```

## Honest limits

- Password fields are untouchable by design (macOS blocks event taps in secure input).
- Candidate quality is bounded by the dictionary. Names and slang you use get learned after one pick.
- Some Electron apps don't expose the caret position; the panel then appears under the mouse pointer.

## License

MIT. Word lists from [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords) (CC-BY-SA 4.0, OpenSubtitles 2018).

# Project Context — Franco

**Owner:** Mohammad Eissa. **Created:** 2026-09-13.

## Why
Typing Egyptian Arabic on a Mac means either switching to an Arabic keyboard (slow, unfamiliar layout) or typing Arabizi/Franco (`ezayak 3amel eh`) which friends and family read but which looks sloppy and doesn't work with Arabic-only readers (parents). Yamli.com does the conversion beautifully but only inside its web page. Wispr Flow showed that a background utility can rewrite text in any app. Franco brings Yamli's behaviour to every text field, especially WhatsApp.

## Goals
- Type Latin, get native script, in any app, without switching keyboards.
- Multiple candidates per word, first one picked by Space; arrows/Tab to choose others; Esc keeps Latin.
- Instant global toggle so English typing is never disturbed.
- Same mechanism for other big romanized-typing communities: Hindi, Russian, Persian. Adding a language = one JSON profile + a word list.
- Fully offline, no accounts.

## Non-goals
- Not an Input Method (IMKit) — deliberately a tap-based utility so it works with the current keyboard layout and no input-source switching.
- Not a spell checker or translator.

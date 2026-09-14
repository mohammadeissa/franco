# Current Status — Franco

## State (2026-09-13)
- Engine complete for ar/hi/ru/fa; `scripts/test.sh` 84/84; <1 ms per word; lexicon load 30–80 ms.
- macOS app complete: menu bar, event tap, composer, injector, caret-anchored panel, settings window (hotkey recorder, options, launch-at-login, AX status, try-it box), language hotkeys (⌃⌥1-4).
- `build/Franco.app` builds via `scripts/bundle.sh`; `scripts/install.sh` installs to /Applications and launches.
- **Not yet verified end-to-end by a human:** the tap needs Accessibility permission, which only the user can grant (the agent session cannot click System Settings or take screenshots — Screen Recording is not granted to the terminal).

## Next steps
1. User: `./scripts/install.sh`, grant Accessibility, type in WhatsApp/Notes. Report: panel placement, replacement correctness, any app where injection misbehaves.
2. If WhatsApp doesn't expose the caret, panel falls back to mouse — consider remembering last caret rect per app.
3. Add an app icon (`Resources/AppIcon.icns`, bundle.sh already copies it if present).
4. Optional: Urdu profile (copy ar.json + fa.json ideas), Greek, Turkish.
5. Optional: per-app disable list (e.g., Terminal, code editors).

## Log
- 2026-09-14 — Bug: language hotkeys ⌘⇧1-4 swallowed macOS screenshot keys ⌘⇧3/⌘⇧4. Moved to ⌃⌥1-4.
- 2026-09-13 — Project created. Plan (`docs/PLAN.md`), engine, profiles, lexicons, full app, scripts, tests, docs.

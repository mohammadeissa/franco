# Franco — Agent Guide

Native macOS menu-bar app (Swift 6 / SwiftPM, no Xcode project) that converts romanized typing (Arabizi/Franco, Hinglish, Russian translit, Pinglish) into native script system-wide, Yamli-style, with a floating candidate panel. Built 2026-09-13.

## Orientation
- `docs/PLAN.md` — the implementation plan (decisions + architecture); `docs/PROJECT_CONTEXT.md` why; `docs/ARCHITECTURE.md` modules; `docs/CURRENT_STATUS.md` state + next steps; `docs/DECISIONS.md` decisions (do not relitigate)
- `README.md` — usage, keys, cheatsheet

## Commands
- Build: `swift build` (debug) / `swift build -c release`
- Engine CLI: `swift run Franco --translit <ar|hi|ru|fa> "words"` — fast way to check candidate quality
- Tests: `./scripts/test.sh` (cases in `tests/cases_<lang>.txt`, tab-separated `latin<TAB>expected`, expected must be in top-3)
- Package: `./scripts/bundle.sh` → `build/Franco.app`; Install+launch: `./scripts/install.sh`

## Conventions
- Engine (`Sources/Franco/Engine/`) is pure Swift, no AppKit — keep it testable from the CLI.
- Language behaviour lives in `Resources/profiles/<id>.json`, never hard-coded (except the abugida algorithm in `Transliterator.swift` which reads the Hindi tables).
- Costs in profiles: 0 = canonical mapping; ~0.3–0.8 = plausible; >1 = rare. Ranking = ln(freq) − 1.15·cost. Longest-match digraphs get priority (shorter splits +0.5).
- All synthetic events are tagged with `Injector.magic` so the tap ignores them — keep that invariant.
- Never use pynput/python for keyboard hooks on this machine (see ../wispr).
- Resources are located by `ResourceLocator` (env `FRANCO_RESOURCES` → app bundle → source tree); don't switch to `Bundle.module`.

## Doc maintenance (MANDATORY)
After ANY change: update `docs/CURRENT_STATUS.md` (dated log entry), `docs/ARCHITECTURE.md` if modules/data flow change, `docs/DECISIONS.md` for new decisions, README/AGENTS if commands change.

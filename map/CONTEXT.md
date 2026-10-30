# Map: Board Game Companion

Edit map for agents. The source tree is the truth; this cites it and never restates behaviour (that is [SPEC.md](../SPEC.md)). Verified against the working tree on 2026-10-28 (base commit `63a32a3`, with uncommitted changes).

Godot 4.7, typed GDScript, Mobile renderer, Jolt. iOS + Android. Offline, no accounts, no ads.

## Name collisions (product word vs code word)

| Say | Code | Where |
|---|---|---|
| **set** (of a particular board game) | `Game` | `scripts/core/game.gd` |
| **tool** on a set | `Preset` (+ a `*Tool` scene node built from it) | `scripts/core/preset.gd`, `scripts/game/game_screen.gd:_make_tool` |
| tool kind | `Preset.Type` (`DICE=0`, `BUZZER=3`, `HOURGLASS=4`) | numbers are saved, never reuse 1 and 2 |
| **Quick** | the built-in `Game` with `is_builtin`, id `"quick"` | `PresetStore.QUICK_ID` |
| toolbar icon | `ToolChip`, driven by `ToolDock` | `scripts/game/` |

A `Preset` has an icon and colour, never a name. `data` is the tool's own saved settings.

## Universes

- **live**: everything in `scripts/` except below, plus `scenes/`, `theme/`, `translations/`, `test/`.
- **leftover**: `scripts/timer/` (`TimeFormat`, `TimerAlert`) is live code in a folder named after the removed timers. Used by the hourglass and buzzer. Do not delete; renaming the folder is optional.
- **ghost** (docs that no longer match): `TapArea` doc says "used for the timers" (only the buzzer uses it); `SettingsScreen` doc lists three switches (there are four plus a sound theme); README layout omits `scripts/` subfolders. Trust the code, fix the comment when touching the file.
- Not app code: `addons/gut/` (test framework, leave alone), `build/` (git-ignored exports), `.godot/` (cache).

## Walk

1. Need the nouns? [_index.md](_index.md).
2. Changing something? [effects.md](effects.md): what it hits, which test to run.
3. Adding a new tool kind? [add-a-tool.md](add-a-tool.md).

## Rules that bite

- Core (`scripts/core/`) takes no scene dependencies so it unit-tests; keep it that way.
- A tool is built when its preset is opened and freed when the game closes or another preset takes over; nothing may keep running, sounding or reading motion after that (`_exit_tree`).
- Every user-visible string goes through `tr()` with a key in `translations/strings.csv`.
- Styling lives in `theme/app_theme.tres` and `UiStyle`; icons only through `IconLibrary`; sounds only through `SoundBank`.
- Persistence: `user://games.cfg` (PresetStore) and `user://settings.cfg` (AppSettings). Corrupt or missing falls back to defaults; unknown preset types are dropped on load.

## Run

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

Single file: add `-gselect=test_preset_store.gd`. Device deploy is in the root [CLAUDE.md](../CLAUDE.md).

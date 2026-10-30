# Nouns

One line per thing. Status: `verified` = checked against source on 2026-10-28. Open the source file, not a card; the doc comment at the top of each script is its contract.

## Data and persistence (`scripts/core/`)

- **Game** (set) `core/game.gd`: id, icon, colour, ordered `presets`; `to_dict`/`from_dict`. verified
- **Preset** (tool) `core/preset.gd`: type, icon, colour, `data`, optional screen `position` (fractions). verified
- **PresetStore** `core/preset_store.gd`: all games, every mutation autosaves; Quick always first. Tools call `preset_changed()` after editing `data`. verified
- **AppSettings** `core/app_settings.gd`: static global switches; `sound_theme` is the sound set in use now (set from the tool on show, not saved). verified
- **Themes** `core/themes.gd`: tool theme names → icon + sound set; `Preset.theme` holds one. verified
- **IconLibrary** `core/icon_library.gd`: icon name → SVG in `assets/icons/lucide/` (white, tinted at use). verified
- **SoundBank** `core/sound_bank.gd`: all sounds, synthesised in code or from `assets/sounds/rpg/`; `play_once`, `stream`, `sustained`. verified
- **ColorUtils**, **Ids** `core/`: contrast colour; unique ids. verified

## Screens (`scripts/main.gd`, `home/`, `game/`, `settings/`)

- **Main** `main.gd`: owns the store; swaps Home / GameScreen / Settings. verified
- **Home** `home/home.gd` + `GameTile`: tile grid, hold menu, drag-reorder, add game. verified
- **GameScreen** `game/game_screen.gd`: hosts the active tool, top bar, swipe between tools, builds tools by type; tools left behind are kept (out of the tree) so state survives. verified
- **ToolDock / ToolChip / ToolPicker** `game/`: toolbar, loose icons, the + drawer. verified
- **SettingsScreen**, **CreditsScreen** `settings/`. verified

## Tools

- **Dice** `dice/`: `DiceTool` (UI, saves `data.dice`, `data.auto_lock`) → `DiceTable` (3D world) → `Die` (RigidBody3D) + `DieShape` (pure geometry), `DiceDrawer`, `ChainFeedback` (lock sound/haptics). verified
- **Hourglass / timer** `hourglass/`: `HourglassTool` (saves `data.seconds`, `data.timed`, `data.kind` hourglass|digital, `data.alarm`; shows `DigitalTimer` `timer/digital_timer.gd` in digital kind) → `HourglassSand` (extends `SandGlass`; rigid-body grains) → `SandMass` + `sand.gdshader` (render), `HourglassShape` (pure outline), `HourglassArt`/`ArtLayer` (glass drawing), `SandHiss`. verified
- **Buzzer** `buzzer/buzzer_tool.gd`: saves `data.sound`; emits `appearance_changed` (icon follows sound). verified

## Shared UI (`scripts/ui/`, `theme/`)

- **UiStyle** shared look; **Spring** spring-chased values (all motion); **ChoiceDrawer** slide-onto-an-option row; **HoldMenu** Icon/Colour/Delete; **TapArea** big tap target; **TimeWheel** drag-to-set time. verified
- **TimeFormat**, **TimerAlert** `scripts/timer/`: clock text; end-of-timer vibrate + buzzer. verified
- **ActionBars** `ui/action_bars.gd`: one drawer open at a time; drawers of one family (menu + its list) stay together.
- **Haptics** `scripts/core/haptics.gd`: the one place the phone vibrates; drops a pulse that arrives while the last still runs.

## Tests (`test/`, GUT)

Core/store: `test_preset_store`, `test_color_utils`. Dice: `test_die_shape`, `test_dice_table_motion`, `test_dice_colors`, `test_dice_drawer`. Hourglass: `test_hourglass`. UI: `test_home`, `test_game_screen`, `test_tool_dock`, `test_choice_drawer`, `test_spring`. Sound/feedback: `test_sound_theme`, `test_feedback`.

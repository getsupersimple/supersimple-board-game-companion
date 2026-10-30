# If you change X

First-order only. Open the listed files, run the listed tests (`-gselect=<file>`), and do not touch the "not" column.

| Changing | Hits | Tests | Not (common wrong guess) |
|---|---|---|---|
| Saved shape of a game or preset (`to_dict`/`from_dict`) | `game.gd`, `preset.gd`, `preset_store.gd`, every tool that reads `data` | `test_preset_store` | AppSettings (separate file) |
| `Preset.Type` enum | `preset.gd`, `game_screen.gd` (`PICKER_TYPES`, `_make_tool`), `tool_chip.gd`, `tool_picker.gd`, SPEC | `test_preset_store`, `test_game_screen`, `test_tool_dock` | Never reuse numbers 1 and 2 |
| A tool's `data` keys | that `*_tool.gd` only; old saves must still load (use `.get` with default) | tool's test | PresetStore |
| Global switch | `app_settings.gd`, `settings_screen.gd`, `strings.csv` | `test_feedback` | Preset data |
| Tool theme (icon, sound set) | `themes.gd`, `preset.gd` (`theme`), `game_screen.gd` (`_apply_theme`), `hold_menu.gd`, `tool_picker.gd`, `sound_bank.gd` if sounds | `test_sound_theme`, `test_game_screen`, `test_preset_store` | `AppSettings.sound_theme` (runtime only, not saved) |
| Tools kept alive across swipes | `game_screen.gd` (`_kept`, `_retire`, `_forget`) | `test_game_screen` | A tool that must rebuild on change (colour) has to `_forget` |
| A sound | `sound_bank.gd` (+ `assets/sounds/rpg/`, `assets/sounds/futuristic/`; new wavs need `compress/mode=0` in their `.import`); callers pass names | `test_sound_theme` | Haptics (all go through `Haptics.pulse` in `core/haptics.gd`, which drops overlapping pulses; callers: `timer_alert.gd`, `chain_feedback.gd`, `die.gd`, `dice_table.gd`, `buzzer_tool.gd`; `settings_screen.gd` calls the engine directly) |
| Toolbar, drag, swipe | `tool_dock.gd`, `tool_chip.gd`, `game_screen.gd`, `Spring` | `test_tool_dock`, `test_game_screen`, `test_spring` | Home (it has its own tile drag in `home.gd`) |
| Hold menu or drawers | `hold_menu.gd`, `choice_drawer.gd`; callers: `home.gd`, `game_screen.gd`, `tool_picker.gd`, the three tools | `test_choice_drawer`, `test_home` | `DiceDrawer` is separate (the add-die drawer) |
| Home screen | `home.gd`, `game_tile.gd`, `home.tscn` | `test_home` | GameScreen |
| Die geometry or face reading | `die_shape.gd`, `die.gd` | `test_die_shape` | Dice table walls/camera |
| Dice physics, camera, walls, auto-lock | `dice_table.gd`, `die.gd`, `dice_tool.gd` | `test_dice_table_motion` | `DieShape` |
| Hourglass glass outline | `hourglass_shape.gd`, then `hourglass_art.gd`, `hourglass_sand.gd` (container), `sand_mass.gd` | `test_hourglass` | Time logic (system clock, in `HourglassSand`/`HourglassTool`) |
| Hourglass timing or modes | `hourglass_tool.gd`, `hourglass_sand.gd`, `time_wheel.gd` | `test_hourglass` | Frame counting is forbidden; use the system clock |
| Look (colours, fonts, shapes) | `theme/app_theme.tres`, `ui_style.gd` | none; check on device | Hardcoded colours in scripts |
| User-facing text | `translations/strings.csv` then re-import (`Godot --headless --import`) to rebuild `strings.en.translation` | none | |
| Icons | drop SVG in `assets/icons/lucide/` (white fill), register in `IconLibrary` lists if it should be pickable | none | |
| Export / bundle id | `export_presets.cfg`, `project.godot` | none | Deploy steps live in root CLAUDE.md |

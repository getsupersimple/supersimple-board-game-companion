# Process: add a new tool kind

The only recurring structural change. The tool contract is duck-typed (no base class).

Input: a tool idea (for example a score counter, from SPEC "Later"). Output: a kind in the + drawer that saves and restores.

1. `scripts/core/preset.gd`: add to `Type` with the next unused number (not 1 or 2), and a case in `default_icon` and `default_color`.
2. `scripts/<tool>/<tool>_tool.gd`: `class_name XTool extends Control`. Required: `var preset: Preset`, `var store: PresetStore`; fill the parent (`set_anchors_and_offsets_preset(PRESET_FULL_RECT)`) in `_ready`; read settings with `preset.data.get(key, default)`; after changing `data` call `store.preset_changed()`.
   Optional, found via `has_method` in `game_screen.gd`: `top_buttons() -> Array[Button]` (joins the back button), `accepts_swipe() -> bool`, `retap()` (active chip tapped again), signal `appearance_changed` (connect it in `_make_tool` as the buzzer does).
   Clean up in `_exit_tree` (stop sounds, release motion, screen-awake).
3. `scripts/game/game_screen.gd`: add to `PICKER_TYPES` and a case in `_make_tool`.
4. `scripts/game/tool_chip.gd` `_accessibility_label`: add a case with a `PRESET_<KIND>` string.
5. `translations/strings.csv`: that `PRESET_<KIND>` key and any text, through `tr()`. Re-import.
6. Test the pure logic in `test/test_x.gd` (GUT); keep logic out of the node.
7. Update SPEC.md and this map ([_index.md](_index.md), [effects.md](effects.md)).
8. Deploy to the phone (root CLAUDE.md).

Does not hit: `PresetStore`, `Home`, `Game` (they only see `Preset` and `data`).

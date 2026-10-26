# Board Game Companion: design spec

Agreed design from the planning interview. A free, offline, open source (MIT) SuperSimple app that replaces the things lost from board games: dice, timers, buzzers.

## Identity
- Name: **Board Game Companion** (home-screen label may be shortened)
- Bundle ID (iOS and Android): `com.getsupersimple.boardgamecompanion`
- License: MIT. Bundled assets must be CC0, MIT-compatible, or self-made.
- Free, no ads, no analytics, no accounts, no network permission, fully offline.

## Platforms and tech
- Godot, typed GDScript, **Mobile renderer**, Jolt physics. Export to iOS and Android.
- Portrait-locked on phones. Tablets use the same layout scaled up.
- Required support: devices from the last 3 years. Older devices best-effort.
- Pin the Godot version at project start (open item). Check current iOS/Android export minimums and Mobile-renderer fallback behavior in the docs.
- Compile materials/shaders during launch to avoid first-roll stutter.
- Tests: GUT unit tests for pure logic (timer state machine with injectable clock, preset store, tray model, face-from-orientation per die shape, corrupt save fallback). Keep logic separate from scene nodes. Manual device checklist before release.
- CI (GitHub Actions): run tests on every push; export Android on version tags. iOS builds and store uploads are manual in v1. Keep signing keys out of the repo.

## Performance
- Flag (not gate): cold start to a usable home screen over 2 s; under 60 fps with 12 dice moving. Make load as fast as possible.
- Timers use the system clock, never frame counting.
- Install size is tracked only.
- Measure on one older mid-range Android phone and one older iPhone.

## Structure
- **Game** (icon, color) is the top level. Home screen = tiles of games, plus a built-in **Quick** game (every tool type, no presets) shown first.
- Opening a game activates its first preset. A toolbar of presets sits along the bottom.
- **Preset** = a configured tool, identified by a colorable icon, **no name**. Types: dice tray (a coin flip is a d2), timer, two-player timer, buzzer. Any number of each, any order.
- Tapping a preset switches the main area. One active preset at a time. Dice presets drop their dice. Timers load idle.
- Changes to a preset autosave. No dirty state.
- Toolbar is hidden while a timer is running or paused. Visible in idle and finished.
- Drag a preset out of the toolbar to place it anywhere on screen (stored as screen fractions in the game config). Drag back to snap into the toolbar.
- Long-press starts iOS-style edit mode: presets jiggle, "x" deletes, drag moves, Duplicate. No tooltips.
- Accessibility labels are generated from content (for example "2 × d6", "1:00 timer").
- Settings is global, reached from the home screen: dice sound, timer buzzer, haptics (separate switches).
- Per-game remembered state (current tray, dice colors, timer setup). All in one `ConfigFile`. Corrupt or missing file falls back to defaults.
- One shared `Preset` record (type, icon, color, data, game id), one `PresetStore`, one shared list/edit UI. Tools supply capture and apply.

## Dice
- Dice: d2 (coin), d4, d6, d8, d10, d12, d20, d100, in a mixed tray. Cap about 12 dice (open item).
- Stylized, clean look. Near top-down fixed camera, soft contact shadows, bevelled edges.
- **Real physics decides every result.** No steering, no automatic nudging.
- Gravity follows device tilt. Friction keeps dice still until tilt overcomes it, so playful nudging works. Light smoothing on the accelerometer only. Tap a die to nudge it.
- Roll starts by shake or by the Roll button. Dropped dice (preset load, adding a die) are also real rolls.
- Adding a die drops only that die. It can hit existing dice with real physics. Removing a die lifts it out.
- A roll is decided when every die is settled flat (speed below a small threshold for a short hold). A cocked die leaves the roll undecided: its result slot shows a placeholder, the total is hidden, and the die gets an outline. The result bar always matches the table.
- Result bar at the top: each die's value in tray order and the total, large high-contrast numerals.
- Per-die color: free picker plus a swipe to curated swatches. Numeral color is chosen automatically from luminance.
- Verify whether small gravity changes keep Jolt's sleeping bodies awake. Update gravity only on meaningful change if so.

## Timers
- Single timer and two-player timer. Big tap area. Minute and second scroll wheels, an infinity toggle for count-up, and a "reset each turn" toggle that works for both counting modes. Screen stays awake while running.
- Tap to start, tap to pause or resume. In two-player, only the active half responds, with the far half rotated for the other player. Center strip holds pause and reset. Reset needs a long press or a confirm tick.
- At zero: stop at 0:00, signal by color, icon, pulse, optional buzzer, vibration. Tap resets. No overtime.

## Buzzer
- Minimal v1 tool: big tap area, a loud sound, a haptic. Multi-device buzzing is out of scope.

## UI
- Clean, plain, uncluttered, icon-first. Self-explanatory without text where possible.
- One Godot `Theme` resource, no hardcoded styling, so the coming style image and document can be applied in one file.
- Lucide icons (SVG, referenced by name in one place): a curated subset in icon category tabs plus a search box. Custom icons are added as they arrive. Keywords go through `tr()`.
- Strings go through `tr()`. English only for now. Follows the system language with an English fallback. No selector. Layouts must tolerate longer strings.

## Accessibility baseline
- Never rely on color alone.
- Large, high-contrast numerals. Tap targets at least 48 px.
- Respect the system reduce-motion setting. The physics roll itself stays.
- Screen-reader support is a stretch goal after the Godot version is pinned.

## Feedback
- Dice collision sounds throttled by impact velocity, plus haptics. Timer end buzzer is optional in settings.

## Later
- Finger picker, score counter, spinner, turn-timer variations, overtime, import and export of games, multi-device buzzers, screen-reader support, realistic dice theme.

## Open items
- Where the GitHub repo lives (personal or a SuperSimple org).
- Godot version to pin.
- Exact tray cap (about 12).
- Who draws the custom icons (placeholders use stock Lucide meanwhile).
- The style image and document, to come from you.

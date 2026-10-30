# Supersimple Board Game Companion: design spec

Agreed design from the planning interview. A free, offline, open source (MIT) SuperSimple app that replaces the things lost from board games: dice, an hourglass, buzzers.

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
- Tests: GUT unit tests for pure logic (the hourglass, preset store, tray model, face-from-orientation per die shape, corrupt save fallback). Keep logic separate from scene nodes. Manual device checklist before release.
- CI (GitHub Actions): run tests on every push; export Android on version tags. iOS builds and store uploads are manual in v1. Keep signing keys out of the repo.

## Performance
- Flag (not gate): cold start to a usable home screen over 2 s; under 60 fps with 16 dice moving. Make load as fast as possible.
- The hourglass uses the system clock, never frame counting.
- Install size is tracked only.
- Measure on one older mid-range Android phone and one older iPhone.

## Structure
- **Game** (icon, color) is the top level. Home screen = tiles of games, plus a built-in **Quick** game (every tool type, no presets) shown first.
- Leaving a game frees its tool at once: nothing goes on running, sounding or reading the phone's motion on the home or settings screens.
- The home screen ends its list of games with a large + tile that adds another (no maximum); the tiles scroll when they do not all fit. Holding a game opens a menu: Icon, Colour, Delete. Keeping the finger on Icon or Colour pops a list of icons or colours out underneath; slide onto one and let go. If the finger instead drags the tile away (not towards the menu), the menu goes and the tile is picked up: it follows the finger round the list with the others sliding aside on springs, and it springs into place where it is let go. Quick, the built-in game, stays first and cannot be deleted or moved.
- The toolbar's + opens a drawer to be touched on a tap; holding it opens the drawer under the finger and letting go closes it. Keeping a finger on a kind of tool pulls out the same drawer of icons as the home screen's, to its left; slide onto one and let go to add the tool wearing it.
- Every tool has a theme, chosen by icon: DnD (`dices`), Futuristic (`orbit`), Traditional (`landmark`), Old School (`joystick`) or Standard (`palette`, the default). The theme picks the tool's sounds, and the sounds follow the tool on show. Adding a tool: holding a kind in the + drawer pulls out the themes in place of the old icon list. Editing a tool: the hold menu has Icon, Colour, Theme and Delete. Icon offers twenty Lucide icons chosen for the tool's theme (`Themes.ICON_SETS`); games keep their own list. Each theme also has a palette of six colours (`Themes.PALETTES`), which is what a tool of that theme offers wherever a colour is chosen: the die colours, the edit menu's Colour, the hourglass sand and the digital timer's digits. A new tool starts in the first (dice), third (buzzer) or fourth (hourglass) colour of its theme's palette. Changing a tool's theme changes what it offers, not colours already chosen. The digital timer's digit colours are from the palette too (white until one is picked). Games keep their own colours. DnD, Futuristic and Traditional have their own sounds so far; the other two use the original synthesised ones until their sets exist. Futuristic and Traditional each have five recorded alarms (`assets/sounds/<theme>/`: chime, ding, buzz, horn, siren) used for the buzzer's four sounds and the hourglass and digital timer's time-up sounds (chime by default); their dice sounds are still the original ones. Traditional's chime is its ding. DnD uses recordings in `assets/sounds/rpg/`: four wooden knocks for dice (one picked at random each time), a heavy lock closing and opening, a lute-like chime for the hourglass, and for the buzzer a bronze bell (Bell), a low bronze gong held while pressed (Wrong answer), a war horn and an alarm bell.
- Opening a game activates its first preset. A toolbar of presets runs along the bottom, with the bottom margin kept clear of the swipe-up edge. Swiping sideways across the tool goes to the next or previous tool (not while a die is being dragged or a drawer is open).
- **Preset** = a configured tool, identified by a colorable icon, **no name**. Types: dice tray (a coin flip is a d2), hourglass, buzzer. Any number of each, any order.
- Tapping a preset switches the main area. One active preset at a time. Tapping the active preset again taps it again: dice roll, the hourglass pours its sand back to the start. There are no shake or reset buttons.
- The tools' own buttons (add a die) sit in the top bar beside the back button, all one size and on one line.
- Changes to a preset autosave. No dirty state.
- The toolbar scrolls sideways when it holds more presets than fit; the + button stays fixed beside it. + opens a vertical drawer that springs up with one button per tool kind.
- Drag a preset out of the toolbar to place it anywhere on screen (stored as screen fractions in the game config). Drag back to snap into the toolbar: the others slide aside and the icon springs into its place, like dropping an icon into an iPhone folder. All motion is spring-driven.
- Long-press on a preset in the toolbar opens the same menu as a game on the home screen (Icon, Colour, Delete; the lists are the same drawers). If the finger instead drags the icon away from the menu it is picked up: it can be carried anywhere on the screen, or back among the others in the toolbar. There is no jiggle edit mode. No tooltips.
- Accessibility labels are generated from content (for example "2 × d6", "hourglass").
- Settings is global, reached from the home screen: dice sound, timer buzzer, sand sound, haptics (separate switches). There is no theme choice in Settings.
- Per-game remembered state (current tray, dice colors, hourglass time). All in one `ConfigFile`. Corrupt or missing file falls back to defaults.
- One shared `Preset` record (type, icon, color, data, game id), one `PresetStore`, one shared list/edit UI. Tools supply capture and apply.

## Dice
- Dice: d2 (coin), d4, d6, d8, d10, d12, d20, d100, in a mixed tray. Cap of 16 dice.
- Stylized, clean look. Near top-down fixed camera, soft contact shadows, bevelled edges.
- **Real physics decides every result.** No steering, no automatic nudging.
- Gravity follows device tilt. Friction keeps dice still until tilt overcomes it, so playful nudging works. Light smoothing on the accelerometer only. Tap a die to nudge it.
- A quick tap on the table makes every die jump up. The walls stand in far enough that no die is drawn past the edge of the view.
- A locked die wears a round gold padlock badge, floating up and to the right of it, the same size on every kind of die, with no text beside it.
- After a long press on the bare table, swiping away from the drawer and letting go throws every unlocked die in the direction of the swipe, harder for a faster swipe. A swipe without a long press switches tools as on any screen, and a swipe never opens an action bar or sounds the buzzer: a press that has become a swipe is dropped. Tools slide without fading. Letting go of the long press on a toolbar icon puts its edit bar away unless the finger is on a choice. Each colour's tally along the top is the same width, shrinking so that a die of every colour still fits across the screen. Beside each die that has lain still for 300 ms sits a pill in its colour with the number it shows (a percentile pair has one, beside its tens die); it grows out with the same springy motion as the drawers and shrinks away when the die moves. Pressing a total at the top shows only the dice of that colour for as long as the finger stays down. A die is only picked up by a long press on it (then dragged, or, if the finger stays put a while longer, its menu opens); a finger that moves sooner is a swipe to the next tool. Dice are glossy faceted gems with a pale rim and white numerals. A die that is unlocked, by any means, is left alone by auto lock for a second.
- The buzzer waits a moment before sounding and does not sound at all for a swipe. Once it is sounding under a finger, that finger cannot swipe (and moving it changes nothing); it has to lift and swipe again. With the sound drawer out, sliding over each sound plays it as a preview.
- Holding a finger on the bare table pulls every die hard down onto the table for as long as it is held, and opens a drawer under it with "Auto lock all" and "Unlock all": slide onto one and let go. While Auto lock all is on (kept with the preset, shown as the dark choice) each die is locked in place as soon as it lies flat and still. Unlock all takes every padlock off, and with Auto lock all on the dice stay free for a second before it may lock them again.
- The camera looks straight down without perspective, so the dice go right to the edges of the table, down to the toolbar, and nothing is cut off at the edge.
- The roll area is tall (a ceiling well above a locked die), so dice can be passed over locked ones when the phone is turned over.
- Roll starts by shake or by tapping the dice preset in the toolbar again. Dropped dice (preset load, adding a die) are also real rolls.
- Adding dice: a + button at the top right. Tapping it opens a drawer hanging under it that names each kind plainly (D2, D4, D6 ... D100) and stays open until a tap lands outside it, so several dice can be added in a row. Holding it opens the drawer under the finger: drag onto a kind and let go to add it in a random colour, or keep the finger on it to pull out a drawer of colours to the side and slide onto one. At most 16 dice. The table has no backdrop panel: the page shows through, and there is no list of dice along the top, only a total per colour of die.
- Holding a finger on a die opens a drawer with Colour, Lock (Unlock when it is locked) and Remove. Pointing at Colour pops the row of colours out above at once; slide onto one and let go. Letting go without choosing anything locks the die (or unlocks it if it is locked).
- Adding a die drops only that die. It can hit existing dice with real physics. Removing a die lifts it out.
- A roll is decided when every die is settled flat (speed below a small threshold for a short hold). A cocked die leaves the roll undecided: its result slot shows a placeholder, each colour's total shows a ? until every die of that colour has landed and rested (a die being pressed down or held in a finger is not settled), and the die gets an outline.
- Result bar at the top: each die's value in tray order and the total, large high-contrast numerals.
- Per-die color: free picker plus a swipe to curated swatches. Numeral color is chosen automatically from luminance.
- Verify whether small gravity changes keep Jolt's sleeping bodies awake. Update gravity only on meaningful change if so.

## Hourglass and digital timer
- The only timer. A glass of real-physics sand (rigid-body grains in a glass-shaped container, metered through the neck by the system clock). One wheel shows the seconds left and sets the whole time when touched.
- The top right button switches between the hourglass and the digital timer, and shows the icon of the one it switches to (the clock in the hourglass view, the hourglass in the digital view). Holding a finger on the timer opens a menu under it: on the hourglass a gravity toggle, the colour of the sand and the sound played when time is up (the lists pop out above the menu, the way the finger came up; the glass's top and bottom are always the tool's colour, and the sand is the opposite colour until one is picked); on the digital timer the colour of its numbers and the sound. Sounds and colours pop out beside the menu; slide onto one and let go. Letting go on a menu choice, or anywhere in the list, puts the menu and its list away together; letting go away from the choices starts the timer over. All of it is remembered per preset. Only one drawer or menu is ever open at a time (a menu and its list count as one).
- Gravity on or off: with it on (the default) the glass **follows the tilt**; off it is **timed**. Details: **follows the tilt** (upright it runs down, upside down it runs back up, on its side or flat it stops) or **timed** (the glass is held upright whatever the phone does; the sand starts as a heap at the bottom of the top chamber and just runs, tapping the preset again pours it all back to start again, and it chimes when the last grain is through).
- At zero: a soft wind chime and two light taps, optional in settings. Screen stays awake while sand runs.
- The standard timer and the two-player timer were removed; their saved presets are dropped on load.
- **Digital timer**: an LED display (white and grey segments on black, in a border of the tool's colour) counting down minutes and seconds. Tap anywhere to start or pause, hold for the menu, drag up or down to set the time. It has no gravity choice; its menu has the colour of the numbers (white unless changed). It sounds the chosen alarm when it reaches zero.

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
- Whether 16 dice is the right cap.
- Who draws the custom icons (placeholders use stock Lucide meanwhile).
- The style image and document, to come from you.

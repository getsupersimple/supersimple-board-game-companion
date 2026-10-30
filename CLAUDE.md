# Working in this repo

Supersimple Board Game Companion: a Godot 4.7 (typed GDScript, Mobile renderer) iOS/Android app. Offline, no accounts, no ads, and only what it says: dice, hourglass, buzzer. The product word "set" is `Game` in code and a "tool" is a `Preset`.

| To do | Go to |
|---|---|
| Agreed product behaviour | [SPEC.md](SPEC.md) |
| Where something lives, name collisions, leftovers | [map/CONTEXT.md](map/CONTEXT.md), [map/_index.md](map/_index.md) |
| What a change hits and which test to run | [map/effects.md](map/effects.md) |
| Add a new kind of tool | [map/add-a-tool.md](map/add-a-tool.md) |
| Run the tests | command in [map/CONTEXT.md](map/CONTEXT.md) (GUT, headless) |

Run the relevant tests after logic changes. Keep `map/` current when you add or remove a script, tool or saved key.

## Always deploy to the phone after changes

After any code or asset change, export and install the app on William's iPhone so it can be tried on the device, without being asked. Skip only for docs-only or test-only changes.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-debug iOS build/ios/BoardGameCompanion.ipa
xcrun devicectl device install app --device 00008150-0000783402BB401C build/ios/BoardGameCompanion.ipa
xcrun devicectl device process launch --device 00008150-0000783402BB401C com.getsupersimple.boardgamecompanion
```

- The device is the paired physical "William" iPhone 17e. Check with `xcrun devicectl list devices` if the ID fails (the phone must be unlocked, connected and paired).
- Export takes a couple of minutes (it archives with xcodebuild).
- Say plainly whether the deploy succeeded or failed.

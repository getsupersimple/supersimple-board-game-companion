# Working in this repo

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

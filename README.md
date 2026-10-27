# Supersimple Board Game Companion

A free, offline, open source companion for board games: dice, timers, and a buzzer. Part of the SuperSimple app suite.

See [SPEC.md](SPEC.md) for the agreed design.

## Develop

1. Install Godot 4.7 or newer (the standard build, not the .NET build).
2. Open this folder as a project.
3. Tests use [GUT](https://github.com/bitwes/Gut). Install it into `addons/gut` to run `test/`.

## Layout

- `scripts/core/` game, preset and store logic, with no scene dependencies so it can be unit tested
- `scenes/` scenes
- `theme/app_theme.tres` the only place styling lives
- `translations/strings.csv` all user-facing strings, used through `tr()`
- `assets/icons/` SVG icons
- `test/` GUT tests

## License

MIT. Bundled assets must be CC0 or MIT-compatible.

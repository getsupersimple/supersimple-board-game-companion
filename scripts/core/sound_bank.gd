class_name SoundBank
extends RefCounted
## Every sound in the app, made in code, so there are no sound files to license
## or ship. Each is generated once and kept.

const SAMPLE_RATE := 22050
## The sounds a buzzer can make, in the order they are offered.
const BUZZER_SOUNDS: Array[String] = ["buzz", "ding", "horn", "siren"]
## The icon that stands for each buzzer sound.
const BUZZER_ICONS := {"buzz": "circle-x", "ding": "bell", "horn": "megaphone", "siren": "siren"}

## The recordings that stand in for sounds in the "rpg" theme, by what they are for.
const RPG_FILES := {"chain": "lock", "unchain": "unlock", "chime": "chime", "ding": "ding"}
## What the "rpg" theme holds down: a low bronze gong, a war horn and an alarm bell.
const RPG_HELD := {"buzz": "buzz_loop", "horn": "horn_loop", "siren": "siren_loop"}
## Themes made of five recorded alarms, in `assets/sounds/<theme>/` under the same file names.
## They serve every tool that ends or calls with a sound: the buzzer's four, and the hourglass and
## digital timer's end sounds (chime by default). Dice sounds are not recorded for these, so they
## stay as in the original set.
const ALARM_THEMES: Array[String] = ["futuristic", "traditional"]
const ALARM_FILES := {"chime": "chime", "ding": "ding", "buzz": "buzz_loop", "horn": "horn_loop", "siren": "siren_loop"}
const ALARM_HELD := {"buzz": "buzz_loop", "horn": "horn_loop", "siren": "siren_loop"}
## How many recordings of a die knocking there are.
const KNOCKS := 4

static var _cache := {}


## Plays a sound once from a throwaway player that tidies itself up.
static func play_once(host: Node, kind: String) -> void:
	if host == null or not host.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream(kind)
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## The sound for something that happens, in the sound theme that is chosen now. Sounds the
## theme does not change are the same in every theme.
static func stream(kind: String) -> AudioStreamWAV:
	if ALARM_THEMES.has(AppSettings.sound_theme):
		var recorded: String = ALARM_FILES.get(kind, "")
		if recorded != "":
			return _recording(recorded, AppSettings.sound_theme)
	if AppSettings.sound_theme == "rpg":
		# A die knocking is one of four recordings of wood on wood, a different one each time.
		if kind == "tick":
			return _recording("knock_%d" % (randi() % KNOCKS + 1))
		var file: String = RPG_FILES.get(kind, "")
		if file != "":
			return _recording(file)
	var key := "future:" + kind
	if not _cache.has(key):
		_cache[key] = _build(kind)
	return _cache[key]


## A recording of a theme ("rpg" unless said), loaded once.
static func _recording(file: String, theme: String = "rpg") -> AudioStreamWAV:
	var key := theme + ":" + file
	if not _cache.has(key):
		_cache[key] = load("res://assets/sounds/%s/%s.wav" % [theme, file]) as AudioStreamWAV
	return _cache[key]


## The same, set to go round and round, for a sound held down.
static func _recorded_loop(file: String, theme: String = "rpg") -> AudioStreamWAV:
	var key := theme + ":loop:" + file
	if not _cache.has(key):
		var wav := (load("res://assets/sounds/%s/%s.wav" % [theme, file]) as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2
		_cache[key] = wav
	return _cache[key]


## A version of a sound that keeps going for as long as it is held, or null for
## a sound that only makes sense once, like a bell. Each is a whole number of
## cycles, so the join where it loops cannot be heard.
static func sustained(kind: String) -> AudioStreamWAV:
	if ALARM_THEMES.has(AppSettings.sound_theme) and ALARM_HELD.has(kind):
		return _recorded_loop(ALARM_HELD[kind], AppSettings.sound_theme)
	if AppSettings.sound_theme == "rpg" and RPG_HELD.has(kind):
		return _recorded_loop(RPG_HELD[kind])
	var key := "sustained_" + kind
	if _cache.has(key):
		return _cache[key]
	var wav: AudioStreamWAV = null
	match kind:
		"buzz":
			wav = _render(1.0, func(t: float) -> float: return (_square(150.0, t) + _square(157.0, t)) * 0.22)
		"horn":
			wav = _render(1.0, func(t: float) -> float: return (fmod(t * 196.0, 1.0) * 2.0 - 1.0) * 0.38)
		"siren":
			# The pitch sweeps between 440 and 960 Hz twice a second, and the phase
			# is worked out exactly so that a second is a whole number of cycles.
			wav = _render(1.0, func(t: float) -> float:
				var phase := TAU * (700.0 * t - 260.0 / (TAU * 2.0) * cos(TAU * 2.0 * t))
				return sin(phase) * 0.4)
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(SAMPLE_RATE)
		_cache[key] = wav
	return wav


## The soft shh of sand pouring, a second and a half of filtered noise that loops.
## The noise has the lows and the highest highs taken out, so it hushes and does not
## hiss, and its end is faded into its start so the join cannot be heard.
static func sand_loop() -> AudioStreamWAV:
	if _cache.has("sand_loop"):
		return _cache["sand_loop"]
	var length := int(SAMPLE_RATE * 1.5)
	var overlap := int(SAMPLE_RATE * 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var raw := PackedFloat32Array()
	raw.resize(length + overlap)
	var bright := 0.0
	var dull := 0.0
	for i in raw.size():
		bright += 0.45 * (rng.randf_range(-1.0, 1.0) - bright)
		dull += 0.12 * (bright - dull)
		raw[i] = bright - dull
	var peak := 0.0
	var shaped := PackedFloat32Array()
	shaped.resize(length)
	for i in length:
		var value := raw[i]
		if i < overlap:
			var into := float(i) / overlap
			value = raw[i] * sqrt(into) + raw[length + i] * sqrt(1.0 - into)
		shaped[i] = value
		peak = maxf(peak, absf(value))
	var data := PackedByteArray()
	data.resize(length * 2)
	for i in length:
		data.encode_s16(i * 2, int(shaped[i] / peak * 0.8 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = length
	_cache["sand_loop"] = wav
	return wav


static func _build(kind: String) -> AudioStreamWAV:
	match kind:
		"alarm":
			return _render(0.8, func(t: float) -> float:
				return (_square(220.0, t) * 0.35) if fmod(t, 0.4) < 0.3 else 0.0)
		"buzz":
			# The wrong-answer buzzer: two slightly out-of-tune square waves.
			return _render(0.6, func(t: float) -> float:
				return (_square(150.0, t) + _square(157.0, t)) * 0.22 * _fade_out(t, 0.6, 0.08))
		"ding":
			return _render(1.4, func(t: float) -> float:
				var bell := sin(TAU * 880.0 * t) + 0.5 * sin(TAU * 1320.0 * t) + 0.25 * sin(TAU * 1760.0 * t)
				return bell * 0.35 * exp(-3.2 * t))
		"horn":
			return _render(0.9, func(t: float) -> float:
				var saw := fmod(t * 196.0, 1.0) * 2.0 - 1.0
				return saw * 0.38 * minf(t / 0.04, 1.0) * _fade_out(t, 0.9, 0.2))
		"siren":
			# The phase is added up, so the pitch can sweep without clicks.
			var phase := [0.0]
			return _render(1.1, func(t: float) -> float:
				var pitch := 700.0 + 260.0 * sin(TAU * 2.0 * t)
				phase[0] += TAU * pitch / SAMPLE_RATE
				return sin(phase[0]) * 0.4 * _fade_out(t, 1.1, 0.1))
		"chain":
			# A heavy metal door slamming and locking: the boom of the slam and the
			# clang of the panel ringing, then the latch clicking home and the bolt
			# thrown across.
			return _render(0.9, func(t: float) -> float:
				var slam := _slam(t, 0.0, 1.0)
				var latch := _latch(t, 0.075, 1.0) + _latch(t, 0.10, 0.6)
				var bolt := _bolt(t, 0.175)
				return tanh((slam + latch + bolt) * 0.8))
		"unchain":
			# The door unlatching: the bolt drawn back, then the latch letting go.
			return _render(0.45, func(t: float) -> float:
				var scrape := _noise(t) * _bump(t, 0.0, 0.07) * 0.20
				var draw := _mode(t, 0.07, 150.0, 30.0, 0.30) + _mode(t, 0.07, 740.0, 45.0, 0.20)
				var click := _latch(t, 0.13, 0.7)
				return tanh((scrape + draw + click) * 0.9))
		"chime":
			# A wind chime stirred by a breath of air: four metal tubes struck one after
			# another, soft and unhurried, each ringing on and fading away.
			return _render(2.9, func(t: float) -> float:
				var notes := [[0.00, 1568.0, 0.13], [0.14, 1976.0, 0.11], [0.30, 1318.0, 0.12], [0.50, 2093.0, 0.09]]
				var sound := 0.0
				for note in notes:
					sound += _tube(t, note[0], note[1], note[2])
				return sound)
		"tick":
			# A short click for a die knocking on something.
			return _render(0.06, func(t: float) -> float:
				var noise := sin(t * 91137.0) * sin(t * 40213.0)
				return noise * 0.7 * exp(-t * 90.0))
	return _render(0.1, func(_t: float) -> float: return 0.0)


static func _render(seconds: float, sample: Callable) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var value: float = clampf(sample.call(float(i) / SAMPLE_RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav


## The slam of a heavy metal door: a boom that drops in pitch, the panel ringing in
## several inharmonic modes that fade at different speeds, a sharp burst of noise
## at the instant of impact, and a few quieter echoes of the ringing from the room.
static func _slam(t: float, start: float, volume: float) -> float:
	if t < start:
		return 0.0
	var since := t - start
	var boom := sin(TAU * (78.0 + 40.0 * exp(-30.0 * since)) * since) * exp(-9.0 * since) * 0.85
	var impact := _noise(t) * exp(-300.0 * since) * 0.8 + _noise(t * 1.7) * exp(-38.0 * since) * 0.10
	var ring := _panel(since)
	for echo in [[0.025, 0.32], [0.058, 0.20], [0.105, 0.11]]:
		ring += _panel(since - echo[0]) * echo[1]
	return (boom + impact + ring) * volume


## What a steel panel does when it is hit: low modes that ring on, high ones that die fast.
static func _panel(since: float) -> float:
	if since < 0.0:
		return 0.0
	var ring := 0.0
	for mode in [[142.0, 14.0, 0.42], [231.0, 12.0, 0.38], [377.0, 16.0, 0.34], [612.0, 20.0, 0.28], [1010.0, 26.0, 0.22], [1633.0, 34.0, 0.17], [2410.0, 45.0, 0.12]]:
		ring += sin(TAU * mode[0] * since) * exp(-mode[1] * since) * mode[2]
	return ring


## A latch clicking home: two bright, short rings and a snap of noise.
static func _latch(t: float, start: float, volume: float) -> float:
	if t < start:
		return 0.0
	var since := t - start
	var snap := _noise(t * 2.3) * exp(-520.0 * since) * 0.45
	return (_mode(t, start, 3300.0, 190.0, 0.5) + _mode(t, start, 5200.0, 230.0, 0.34) + _mode(t, start, 1650.0, 120.0, 0.3) + snap) * volume


## A bolt thrown across: a low thunk with a short metallic ring on top.
static func _bolt(t: float, start: float) -> float:
	if t < start:
		return 0.0
	var since := t - start
	var thunk := sin(TAU * (160.0 - 60.0 * minf(since * 14.0, 1.0)) * since) * exp(-24.0 * since) * 0.6
	return thunk + _mode(t, start, 760.0, 36.0, 0.3) + _mode(t, start, 1900.0, 70.0, 0.22) + _noise(t * 3.1) * exp(-260.0 * since) * 0.3


## One chime tube struck at `start`: a pure tone, with two faint overtones that die
## sooner, as in a metal tube, and a slightly out-of-tune twin that makes it shimmer.
static func _tube(t: float, start: float, hz: float, volume: float) -> float:
	if t < start:
		return 0.0
	var since := t - start
	var soft_start := minf(since / 0.004, 1.0)
	var tone := sin(TAU * hz * since) + 0.5 * sin(TAU * hz * 1.006 * since)
	tone += 0.30 * sin(TAU * hz * 2.76 * since) * exp(-5.0 * since)
	tone += 0.10 * sin(TAU * hz * 5.40 * since) * exp(-9.0 * since)
	return tone * exp(-2.6 * since) * soft_start * volume


## One single ringing tone, starting at `start`.
static func _mode(t: float, start: float, hz: float, decay: float, volume: float) -> float:
	if t < start:
		return 0.0
	var since := t - start
	return sin(TAU * hz * since) * exp(-decay * since) * volume


## A smooth bump that rises and falls between two times, for shaping noise.
static func _bump(t: float, from: float, to: float) -> float:
	if t < from or t > to:
		return 0.0
	return sin(PI * (t - from) / (to - from))


## Noise without a random number generator, so the sound is the same every time.
static func _noise(t: float) -> float:
	return sin(t * 91137.0) * sin(t * 40213.0)


static func _square(hz: float, t: float) -> float:
	return 1.0 if sin(TAU * hz * t) >= 0.0 else -1.0


static func _fade_out(t: float, length: float, fade: float) -> float:
	return clampf((length - t) / fade, 0.0, 1.0)

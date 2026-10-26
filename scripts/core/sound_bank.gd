class_name SoundBank
extends RefCounted
## Every sound in the app, made in code, so there are no sound files to license
## or ship. Each is generated once and kept.

const SAMPLE_RATE := 22050
## The sounds a buzzer can make, in the order they are offered.
const BUZZER_SOUNDS: Array[String] = ["buzz", "ding", "horn", "siren"]
## The icon that stands for each buzzer sound.
const BUZZER_ICONS := {"buzz": "circle-x", "ding": "bell", "horn": "megaphone", "siren": "siren"}

static var _cache := {}


static func stream(kind: String) -> AudioStreamWAV:
	if not _cache.has(kind):
		_cache[kind] = _build(kind)
	return _cache[kind]


## A version of a sound that keeps going for as long as it is held, or null for
## a sound that only makes sense once, like a bell. Each is a whole number of
## cycles, so the join where it loops cannot be heard.
static func sustained(kind: String) -> AudioStreamWAV:
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


## One tiny grain tapping: on the glass, a bright little tink that dies at once; on
## other sand, a dull soft pat. Three of each, a little different, so a run of
## them does not sound like one sound over and over.
static func grain_tap(on_glass: bool, variant: int) -> AudioStreamWAV:
	return stream(("grain_glass_%d" if on_glass else "grain_sand_%d") % variant)


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
				var scrape := _noise(t) * _bump(t, 0.0, 0.07, 0.045) * 0.20
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
		"grain_glass_0", "grain_glass_1", "grain_glass_2":
			var pitch: float = [3600.0, 4350.0, 5100.0][kind.right(1).to_int()]
			return _render(0.06, func(t: float) -> float:
				return (_mode(t, 0.0, pitch, 230.0, 0.42) + _mode(t, 0.0, pitch * 1.52, 320.0, 0.24) \
						+ _noise(t * 1.3) * exp(-t * 800.0) * 0.14) * minf(t / 0.0006, 1.0))
		"grain_sand_0", "grain_sand_1", "grain_sand_2":
			var which: int = kind.right(1).to_int()
			var low := [0.0]
			return _render(0.05, func(t: float) -> float:
				# Noise run through a gentle low-pass, so it is a pat and not a click.
				low[0] += 0.22 * (_noise(t * (1.0 + 0.37 * which) + 0.011 * which) - low[0])
				return (low[0] * 1.5 * exp(-t * 150.0) + _mode(t, 0.0, 330.0 + 85.0 * which, 140.0, 0.20)) * minf(t / 0.0008, 1.0))
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
static func _bump(t: float, from: float, to: float, _soft: float) -> float:
	if t < from or t > to:
		return 0.0
	return sin(PI * (t - from) / (to - from))


## Noise without a random number generator, so the sound is the same every time.
static func _noise(t: float) -> float:
	return sin(t * 91137.0) * sin(t * 40213.0)


## One hit on metal, starting at `start`: a bright ring with overtones that dies away.
static func _clink(t: float, start: float, hz: float, decay: float, volume: float) -> float:
	if t < start:
		return 0.0
	var since := t - start
	var ring := sin(TAU * hz * since) + 0.5 * sin(TAU * hz * 2.76 * since) + 0.25 * sin(TAU * hz * 5.4 * since)
	return ring * exp(-decay * since) * volume


static func _square(hz: float, t: float) -> float:
	return 1.0 if sin(TAU * hz * t) >= 0.0 else -1.0


static func _fade_out(t: float, length: float, fade: float) -> float:
	return clampf((length - t) / fade, 0.0, 1.0)

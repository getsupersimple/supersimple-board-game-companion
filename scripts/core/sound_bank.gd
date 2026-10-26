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


static func _square(hz: float, t: float) -> float:
	return 1.0 if sin(TAU * hz * t) >= 0.0 else -1.0


static func _fade_out(t: float, length: float, fade: float) -> float:
	return clampf((length - t) / fade, 0.0, 1.0)

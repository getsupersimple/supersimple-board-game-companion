class_name TimerAlert
extends RefCounted
## What happens when a timer runs out: a vibration, and a buzzer if it is on.

const SAMPLE_RATE := 22050
const BUZZER_HZ := 220.0
const BUZZER_SECONDS := 0.8

static var _buzzer_stream: AudioStreamWAV


static func sound_the_alarm(host: Node) -> void:
	vibrate(600)
	if not AppSettings.timer_buzzer:
		return
	var player := AudioStreamPlayer.new()
	player.stream = buzzer_stream()
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func vibrate(milliseconds: int) -> void:
	if AppSettings.haptics:
		Input.vibrate_handheld(milliseconds)


## A harsh two-pulse square-wave buzz, made in code so the app needs no sound file.
static func buzzer_stream() -> AudioStreamWAV:
	if _buzzer_stream != null:
		return _buzzer_stream
	var count := int(SAMPLE_RATE * BUZZER_SECONDS)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var on := fmod(t, 0.4) < 0.3
		var wave := 1.0 if sin(TAU * BUZZER_HZ * t) >= 0.0 else -1.0
		data.encode_s16(i * 2, int(wave * 0.35 * 32767.0) if on else 0)
	_buzzer_stream = AudioStreamWAV.new()
	_buzzer_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_buzzer_stream.mix_rate = SAMPLE_RATE
	_buzzer_stream.stereo = false
	_buzzer_stream.data = data
	return _buzzer_stream

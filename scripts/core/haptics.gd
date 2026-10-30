class_name Haptics
extends RefCounted
## The one place the phone is made to vibrate. A pulse that arrives while the last is still
## running is dropped, because overlapping pulses can leave the motor stuck on. Follows the
## haptics setting.

static var _busy_until_msec := 0


## Vibrates for `milliseconds` unless the setting is off or the last pulse is still running.
static func pulse(milliseconds: int, strength: float = 1.0) -> void:
	if not AppSettings.haptics:
		return
	var now := Time.get_ticks_msec()
	if now < _busy_until_msec:
		return
	_busy_until_msec = now + milliseconds + 10
	Input.vibrate_handheld(milliseconds, strength)

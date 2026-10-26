class_name TimerClock
extends RefCounted
## One clock that counts down from a duration or counts up without limit. Time
## always comes from the caller's clock reading, in milliseconds, never from
## counting frames, so a dropped frame can never make a timer drift.

var limited := true
var duration_ms := 60000

var _banked_ms := 0
var _running_since := -1


func configure(is_limited: bool, seconds: int) -> void:
	limited = is_limited
	duration_ms = maxi(seconds, 1) * 1000


func start(now_ms: int) -> void:
	if _running_since < 0:
		_running_since = now_ms


func pause(now_ms: int) -> void:
	if _running_since >= 0:
		_banked_ms += now_ms - _running_since
		_running_since = -1


func reset() -> void:
	_banked_ms = 0
	_running_since = -1


func is_running() -> bool:
	return _running_since >= 0


func elapsed_ms(now_ms: int) -> int:
	return _banked_ms + (now_ms - _running_since if _running_since >= 0 else 0)


func remaining_ms(now_ms: int) -> int:
	return maxi(duration_ms - elapsed_ms(now_ms), 0)


## What the clock face shows: time left when counting down, time passed when up.
func display_ms(now_ms: int) -> int:
	return remaining_ms(now_ms) if limited else elapsed_ms(now_ms)


func is_out_of_time(now_ms: int) -> bool:
	return limited and elapsed_ms(now_ms) >= duration_ms

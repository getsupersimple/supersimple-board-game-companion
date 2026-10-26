class_name SingleTimer
extends RefCounted
## A single timer driven by taps: tap to start, tap to pause or resume, and a
## tap on a finished timer resets it. A limited timer stops at zero.

enum State { IDLE, RUNNING, PAUSED, FINISHED }

var clock := TimerClock.new()
var state := State.IDLE


func configure(is_limited: bool, seconds: int) -> void:
	clock.configure(is_limited, seconds)


func tap(now_ms: int) -> void:
	match state:
		State.IDLE, State.PAUSED:
			clock.start(now_ms)
			state = State.RUNNING
		State.RUNNING:
			clock.pause(now_ms)
			state = State.PAUSED
		State.FINISHED:
			reset()


func reset() -> void:
	clock.reset()
	state = State.IDLE


## Call every frame. Returns true on the moment a limited timer runs out.
func tick(now_ms: int) -> bool:
	if state == State.RUNNING and clock.is_out_of_time(now_ms):
		clock.pause(now_ms)
		state = State.FINISHED
		return true
	return false


func display_ms(now_ms: int) -> int:
	return clock.display_ms(now_ms)

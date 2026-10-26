class_name TwoPlayerTimer
extends RefCounted
## A turn timer for two players. Only the player whose turn it is can pass it.
## With "reset each turn" every turn starts from the full time (or from zero when
## counting up). Without it each player's clock carries on across turns, like a
## chess clock, or adds up the time they have taken.

enum State { IDLE, RUNNING, PAUSED, FINISHED }

var clocks: Array[TimerClock] = [TimerClock.new(), TimerClock.new()]
var reset_each_turn := false
var state := State.IDLE
var active := 0
## The player who ran out of time, or -1.
var loser := -1


func configure(is_limited: bool, seconds: int, reset_turns: bool) -> void:
	reset_each_turn = reset_turns
	for clock in clocks:
		clock.configure(is_limited, seconds)


## A tap by one of the players. Returns whether it did anything.
func tap(player: int, now_ms: int) -> bool:
	match state:
		State.IDLE:
			active = player
			_begin_turn(player, now_ms)
			state = State.RUNNING
			return true
		State.RUNNING:
			if player != active:
				return false
			clocks[active].pause(now_ms)
			if reset_each_turn:
				clocks[active].reset()
			active = 1 - active
			_begin_turn(active, now_ms)
			return true
		State.FINISHED:
			reset()
			return true
	return false


func toggle_pause(now_ms: int) -> void:
	if state == State.RUNNING:
		clocks[active].pause(now_ms)
		state = State.PAUSED
	elif state == State.PAUSED:
		clocks[active].start(now_ms)
		state = State.RUNNING


func reset() -> void:
	for clock in clocks:
		clock.reset()
	state = State.IDLE
	active = 0
	loser = -1


## Call every frame. Returns true on the moment a player runs out of time.
func tick(now_ms: int) -> bool:
	if state == State.RUNNING and clocks[active].is_out_of_time(now_ms):
		clocks[active].pause(now_ms)
		loser = active
		state = State.FINISHED
		return true
	return false


func display_ms(player: int, now_ms: int) -> int:
	return clocks[player].display_ms(now_ms)


func _begin_turn(player: int, now_ms: int) -> void:
	if reset_each_turn:
		clocks[player].reset()
	clocks[player].start(now_ms)

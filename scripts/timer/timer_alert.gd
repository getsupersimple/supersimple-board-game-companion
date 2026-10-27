class_name TimerAlert
extends RefCounted
## What happens when a timer runs out: a vibration, and a buzzer if it is on.

static func sound_the_alarm(host: Node) -> void:
	vibrate(600)
	if not AppSettings.timer_buzzer:
		return
	SoundBank.play_once(host, "alarm")


## The gentle way to say time is up, for the hourglass: a soft wind chime, and two
## light taps in the hand instead of a long buzz. It follows the same switches.
static func chime(host: Node) -> void:
	if AppSettings.haptics:
		Input.vibrate_handheld(35, 0.4)
		host.get_tree().create_timer(0.18).timeout.connect(func() -> void: Input.vibrate_handheld(25, 0.3))
	if not AppSettings.timer_buzzer:
		return
	SoundBank.play_once(host, "chime")


static func vibrate(milliseconds: int) -> void:
	if AppSettings.haptics:
		Input.vibrate_handheld(milliseconds)

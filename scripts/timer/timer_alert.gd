class_name TimerAlert
extends RefCounted
## What happens when a timer runs out: a vibration, and a buzzer if it is on.

static func sound_the_alarm(host: Node) -> void:
	vibrate(600)
	if not AppSettings.timer_buzzer:
		return
	var player := AudioStreamPlayer.new()
	player.stream = SoundBank.stream("alarm")
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func vibrate(milliseconds: int) -> void:
	if AppSettings.haptics:
		Input.vibrate_handheld(milliseconds)

class_name ChainFeedback
extends RefCounted
## What locking a die sounds and feels like: the slam of a heavy metal door, the
## latch clicking home and the bolt thrown across, with a hard thump in the hand and
## a sharp tick for each click. Letting go is the bolt drawn back and the latch
## letting go. Both follow the settings for sound and for vibration.


static func locked(host: Node) -> void:
	_play(host, "chain")
	# Each step is a delay in seconds, a length in milliseconds, and a strength.
	_pulse(host, [[0.0, 60, 1.0], [0.075, 12, 0.7], [0.10, 10, 0.5], [0.175, 45, 0.9]])


static func unlocked(host: Node) -> void:
	_play(host, "unchain")
	_pulse(host, [[0.07, 22, 0.45], [0.13, 12, 0.6]])


static func _play(host: Node, kind: String) -> void:
	if AppSettings.dice_sound:
		SoundBank.play_once(host, kind)


static func _pulse(host: Node, steps: Array) -> void:
	if not AppSettings.haptics or host == null or not host.is_inside_tree():
		return
	for step in steps:
		var delay: float = step[0]
		var length: int = step[1]
		var strength: float = step[2]
		if delay <= 0.0:
			Input.vibrate_handheld(length, strength)
		else:
			host.get_tree().create_timer(delay).timeout.connect(func() -> void: Input.vibrate_handheld(length, strength))

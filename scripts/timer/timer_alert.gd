class_name TimerAlert
extends RefCounted
## What happens when a timer runs out: a vibration, and a buzzer if it is on.

## The sounds a timer can end with, in the order they are offered, and the icon for each.
const ALARMS: Array[String] = ["chime", "ding", "buzz", "horn", "siren"]
const ALARM_ICONS := {"chime": "music", "ding": "bell", "buzz": "circle-x", "horn": "megaphone", "siren": "siren"}
const DEFAULT_ALARM := "chime"


static func sound_the_alarm(host: Node) -> void:
	vibrate(600)
	if not AppSettings.timer_buzzer:
		return
	SoundBank.play_once(host, "alarm")


## The way to say time is up for the hourglass and the digital timer: the sound the timer was
## given (a soft wind chime unless chosen otherwise), and two light taps in the hand instead of a
## long buzz. It follows the same switches.
static func chime(host: Node, alarm: String = DEFAULT_ALARM) -> void:
	Haptics.pulse(35, 0.4)
	if AppSettings.haptics:
		host.get_tree().create_timer(0.18).timeout.connect(func() -> void: Haptics.pulse(25, 0.3))
	if not AppSettings.timer_buzzer:
		return
	SoundBank.play_once(host, alarm if ALARMS.has(alarm) else DEFAULT_ALARM)


static func vibrate(milliseconds: int) -> void:
	Haptics.pulse(milliseconds)

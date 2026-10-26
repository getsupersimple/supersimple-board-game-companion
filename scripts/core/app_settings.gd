class_name AppSettings
extends RefCounted
## Global switches, saved in their own small file. Everything starts on.

const PATH := "user://settings.cfg"
const SECTION := "settings"

static var dice_sound := true
static var timer_buzzer := true
static var haptics := true


## Reads and writes a switch by name, so a settings row can be built from a list.
static func get_flag(flag: String) -> bool:
	match flag:
		"dice_sound":
			return dice_sound
		"timer_buzzer":
			return timer_buzzer
		"haptics":
			return haptics
	return false


static func set_flag(flag: String, value: bool) -> void:
	match flag:
		"dice_sound":
			dice_sound = value
		"timer_buzzer":
			timer_buzzer = value
		"haptics":
			haptics = value


static func load_settings(path: String = PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	dice_sound = bool(config.get_value(SECTION, "dice_sound", true))
	timer_buzzer = bool(config.get_value(SECTION, "timer_buzzer", true))
	haptics = bool(config.get_value(SECTION, "haptics", true))


static func save_settings(path: String = PATH) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "dice_sound", dice_sound)
	config.set_value(SECTION, "timer_buzzer", timer_buzzer)
	config.set_value(SECTION, "haptics", haptics)
	config.save(path)

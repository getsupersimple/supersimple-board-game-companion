class_name TimeFormat
extends RefCounted
## Clock-face text. A countdown rounds up, so it only reads 0:00 when time is
## really up. A count-up rounds down.


static func format(ms: int, count_down: bool) -> String:
	var total := int(ceil(ms / 1000.0)) if count_down else ms / 1000
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var seconds := total % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%d:%02d" % [minutes, seconds]

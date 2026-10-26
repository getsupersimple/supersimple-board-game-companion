class_name Ids
extends RefCounted
## Generates unique ids for games and presets.


static func new_id() -> String:
	return "%d_%d" % [Time.get_ticks_usec(), randi()]

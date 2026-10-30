class_name SandHiss
extends Node
## The soft shh of sand. The glass says how loud it should be, from 0 to 1, and the
## sound fades up and down towards it, so it never starts or stops with a click.

const POUR_DB := -36.0
const POUR_QUIET_DB := -60.0
const POUR_ATTACK := 1.4
const POUR_RELEASE := 4.0
## The shh starts to fade this long before the last of the sand is through.
const FADE_MS := 2000.0

var player: AudioStreamPlayer

var _level := 0.0


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.stream = SoundBank.sand_loop()
	add_child(player)


## How loud pouring sand is with this much time left: it fades over the last moments.
static func pouring_level(remaining_ms: int) -> float:
	return clampf(remaining_ms / FADE_MS, 0.0, 1.0)


## Fades the shh towards `wanted` and starts or stops the loop as needed.
func update(delta: float, wanted: float) -> void:
	_level = move_toward(_level, wanted, (POUR_ATTACK if wanted > _level else POUR_RELEASE) * delta)
	if _level <= 0.001:
		if player.playing:
			player.stop()
		return
	if not player.playing:
		player.play()
	player.volume_db = lerpf(POUR_QUIET_DB, POUR_DB, _level)

class_name BuzzerTool
extends Control
## A big buzzer: touch it for a loud sound and a buzz in the hand. Holding a finger
## on it a little longer opens a row of icons right under the finger, while it goes on
## sounding, to pick which sound it makes by sliding onto one and letting go (see
## ChoiceDrawer); the row goes away when the finger lifts, so one game can have a "right" and a "wrong"
## buzzer as two presets.

## The preset's own icon changes with its sound, so presets tell apart in the toolbar.
signal appearance_changed

const DEFAULT_SOUND := "buzz"
const LONG_PRESS_SECONDS := 0.45
const BUZZ_PULSE_MSEC := 90
## The buzzer waits this long after a touch, to see whether the finger is going to swipe.
const START_DELAY := 0.06
## A finger that moves this far has swiped, not pressed.
const SWIPE_CANCEL := 20.0
## A tap too quick to wait out still sounds for this long.
const TAP_SOUND_SECONDS := 0.15

var preset: Preset
var store: PresetStore

var _area: TapArea
var _drawer: ChoiceDrawer
var _player: AudioStreamPlayer
var _sound := DEFAULT_SOUND
var _press := 0
var _holding_for_drawer := false
## True while a finger is on the buzzer, which keeps the phone buzzing too.
var _buzzing := false
var _fingered := false
var _started := false
var _swiped := false
var _press_point := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sound = str(preset.data.get("sound", DEFAULT_SOUND))
	if not SoundBank.BUZZER_SOUNDS.has(_sound):
		_sound = DEFAULT_SOUND

	_area = TapArea.new()
	_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.tapped.connect(_on_pressed)
	_area.released.connect(_on_released)
	_area.gui_input.connect(_on_area_input)
	add_child(_area)

	_drawer = ChoiceDrawer.new()
	_drawer.setup(SoundBank.BUZZER_SOUNDS, SoundBank.BUZZER_ICONS)
	_drawer.picked.connect(_choose)
	add_child(_drawer)

	_player = AudioStreamPlayer.new()
	add_child(_player)
	_show_sound()


func _choose(kind: String) -> void:
	_sound = kind
	preset.data["sound"] = kind
	preset.icon = SoundBank.BUZZER_ICONS[kind]
	store.preset_changed()
	_show_sound()
	appearance_changed.emit()


func _show_sound() -> void:
	_area.look(preset.color, SoundBank.BUZZER_ICONS[_sound], "", 16)


## The buzzer sounds only while it is held down, and not for a swipe: it starts a moment after
## the touch, unless the finger has already moved off. A sound that can go on, like a buzz or a
## siren, goes on until the finger lifts, and every sound is cut off the moment it does.
func _on_pressed() -> void:
	if _drawer.is_open:
		return
	_fingered = true
	_swiped = false
	_press_point = get_global_mouse_position()
	_press += 1
	get_tree().create_timer(START_DELAY).timeout.connect(_begin.bind(_press))
	get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(_on_held.bind(_press))


func _begin(press_id: int) -> void:
	if _press == press_id and not _swiped:
		_start_sound()


func _start_sound() -> void:
	if _started:
		return
	_started = true
	var held := SoundBank.sustained(_sound)
	_player.stream = held if held != null else SoundBank.stream(_sound)
	_player.play()
	_buzzing = true
	_buzz()
	_area.self_modulate = Color(1, 1, 1, 0.55)


func _stop_sound() -> void:
	_buzzing = false
	_started = false
	_player.stop()
	_area.self_modulate = Color.WHITE


## A finger that moves off before the buzzer has begun, or while it sounds, has swiped: nothing
## sounds, and the swipe is left for the screen to take.
func _input(event: InputEvent) -> void:
	if not _fingered or _swiped or _holding_for_drawer or not event is InputEventMouseMotion:
		return
	if event.global_position.distance_to(_press_point) > SWIPE_CANCEL:
		_swiped = true
		_press = 0
		_stop_sound()


## The phone buzzes in short pulses end to end for as long as the finger is down.
func _buzz() -> void:
	if not _buzzing or not is_inside_tree():
		return
	Haptics.pulse(BUZZ_PULSE_MSEC)
	get_tree().create_timer((BUZZ_PULSE_MSEC + 15) / 1000.0).timeout.connect(_buzz)


func _on_released() -> void:
	var quick_tap := _fingered and not _started and not _swiped
	_fingered = false
	_press = 0
	if quick_tap:
		_start_sound()
		get_tree().create_timer(TAP_SOUND_SECONDS).timeout.connect(func() -> void:
			if not _fingered:
				_stop_sound())
	else:
		_stop_sound()


## Still holding after a moment: the drawer opens under the finger while the buzzer keeps
## sounding, and it goes away when the finger lifts.
func _on_held(press_id: int) -> void:
	if _press != press_id:
		return
	_press = 0
	_holding_for_drawer = true
	_drawer.open(get_local_mouse_position(), _sound, true)


## The finger that opened the drawer is still on the buzzer, so it is the buzzer that
## hears it move and lift; those go on to the drawer.
func _on_area_input(event: InputEvent) -> void:
	if not _holding_for_drawer:
		return
	if event is InputEventMouseMotion:
		_drawer.pointer_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_holding_for_drawer = false
		_drawer.pointer_up(event.position)
		_drawer.close()


## A swipe has taken the finger: nothing sounds and no row opens.
func cancel_press() -> void:
	_swiped = true
	_press = 0
	_stop_sound()


## A swipe across the buzzer goes to another tool, unless its drawer is out.
func accepts_swipe() -> bool:
	return not _holding_for_drawer and not _drawer.is_open


func _exit_tree() -> void:
	_player.stop()

class_name TwoPlayerTimerTool
extends Control
## A chess clock: two sides with seven-segment faces, the far one turned round for
## the player opposite. A lamp shows whose turn it is. Only the player whose turn
## it is can pass it. A strip between them holds the setup and,
## once play has started, pause and reset.

signal toolbar_visible_changed(is_visible: bool)

var preset: Preset
var store: PresetStore

var _game := TwoPlayerTimer.new()
var _halves: Array[ClockSide] = []
var _setup: TimerSetup
var _controls: HBoxContainer
var _pause_button: Button
var _shown_state := -1
var _shown_active := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 20)
	add_child(column)

	# Player 1 sits at the top of the screen, facing the other way.
	var top := ClockSide.new()
	top.upside_down = true
	top.lamp_color = preset.color
	top.tapped.connect(_on_half_tapped.bind(1))
	column.add_child(top)

	var strip := VBoxContainer.new()
	column.add_child(strip)
	_setup = TimerSetup.new()
	_setup.configure(preset.data, true)
	_setup.changed.connect(_on_setup_changed)
	strip.add_child(_setup)
	_controls = HBoxContainer.new()
	_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls.add_theme_constant_override("separation", 48)
	strip.add_child(_controls)
	_pause_button = _make_pause_button()
	_controls.add_child(_pause_button)
	_controls.add_child(SingleTimerTool.make_reset_button(_reset))

	var bottom := ClockSide.new()
	bottom.lamp_color = preset.color
	bottom.tapped.connect(_on_half_tapped.bind(0))
	column.add_child(bottom)
	_halves = [bottom, top]

	_apply_settings()
	_refresh_state()


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _game.tick(now):
		TimerAlert.sound_the_alarm(self)
	_refresh_state()
	_update_text(now)


func _update_text(now: int) -> void:
	for player in 2:
		_halves[player].set_text(TimeFormat.format(_game.display_ms(player, now), _game.clocks[player].limited))


func _make_pause_button() -> Button:
	var button := Button.new()
	button.icon = IconLibrary.get_icon("pause")
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(150, 150)
	button.focus_mode = Control.FOCUS_NONE
	button.accessibility_name = "Pause"
	button.add_theme_constant_override("icon_max_width", 72)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		button.add_theme_color_override(state, Color("#1C1C1E"))
	button.pressed.connect(func() -> void:
		_game.toggle_pause(Time.get_ticks_msec())
		_refresh_state())
	return button


func _on_setup_changed() -> void:
	preset.data.merge(_setup.to_data(), true)
	store.preset_changed()
	_apply_settings()
	_shown_state = -1


func _apply_settings() -> void:
	var data := _setup.to_data()
	_game.configure(data["limited"], data["seconds"], data["reset_each_turn"])


func _on_half_tapped(player: int) -> void:
	if _game.tap(player, Time.get_ticks_msec()):
		TimerAlert.vibrate(20)
	_refresh_state()


func _reset() -> void:
	_game.reset()
	_refresh_state()


func _refresh_state() -> void:
	if _game.state == _shown_state and _game.active == _shown_active:
		return
	var previous := _shown_state
	_shown_state = _game.state
	_shown_active = _game.active
	var idle := _game.state == TwoPlayerTimer.State.IDLE
	_setup.visible = idle
	_controls.visible = not idle
	_pause_button.icon = IconLibrary.get_icon("play" if _game.state == TwoPlayerTimer.State.PAUSED else "pause")
	DisplayServer.screen_set_keep_on(_game.state == TwoPlayerTimer.State.RUNNING)
	for player in 2:
		_style_half(player)
	_update_text(Time.get_ticks_msec())
	var show_toolbar := _game.state == TwoPlayerTimer.State.IDLE or _game.state == TwoPlayerTimer.State.FINISHED
	if previous == -1 or show_toolbar != (previous == TwoPlayerTimer.State.IDLE or previous == TwoPlayerTimer.State.FINISHED):
		toolbar_visible_changed.emit(show_toolbar)


## The player whose turn it is has the lamp lit and the brighter window; the
## other's window is dimmed. Colour is never the only cue: the lit side has no
## symbol while it runs, a paused clock shows a pause symbol, and time-up has one.
func _style_half(player: int) -> void:
	var area := _halves[player]
	area.pulse(false)
	match _game.state:
		TwoPlayerTimer.State.IDLE:
			area.look(false, true, false, "play")
		TwoPlayerTimer.State.RUNNING:
			area.look(player == _game.active, player == _game.active, false, "")
		TwoPlayerTimer.State.PAUSED:
			area.look(false, false, false, "pause" if player == _game.active else "")
		TwoPlayerTimer.State.FINISHED:
			if player == _game.loser:
				area.look(false, true, true, "hourglass")
				area.pulse(true)
			else:
				area.look(false, false, false, "")

class_name SingleTimerTool
extends Control
## One big tap area: tap to start, tap to pause or resume. Counts down from a set
## time, or up without limit. The toolbar is only shown while the timer is idle
## or finished, so a stray touch cannot swap the settings mid-game.

signal toolbar_visible_changed(is_visible: bool)

const PAUSED_GREY := Color("#8E8E93")
const TIME_UP_RED := Color("#E5484D")

var preset: Preset
var store: PresetStore

var _timer := SingleTimer.new()
var _area: TapArea
var _setup: TimerSetup
var _controls: HBoxContainer
var _shown_state := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 24)
	add_child(column)

	_area = TapArea.new()
	_area.tapped.connect(_on_tapped)
	column.add_child(_area)

	_setup = TimerSetup.new()
	_setup.configure(preset.data, false)
	_setup.changed.connect(_on_setup_changed)
	column.add_child(_setup)

	_controls = HBoxContainer.new()
	_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_controls)
	_controls.add_child(make_reset_button(_reset))

	_apply_settings()
	_refresh_state()


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _timer.tick(now):
		TimerAlert.sound_the_alarm(self)
	_refresh_state()
	_update_text(now)


func _update_text(now: int) -> void:
	_area.set_text(TimeFormat.format(_timer.display_ms(now), _timer.clock.limited))


## A reset button that has to be held, shared by both timers.
static func make_reset_button(on_held: Callable) -> HoldButton:
	var button := UiStyle.icon_button(HoldButton.new(), "rotate-ccw", 150, 72) as HoldButton
	button.accessibility_name = "Reset"
	button.held.connect(on_held)
	return button


func _on_setup_changed() -> void:
	preset.data.merge(_setup.to_data(), true)
	store.preset_changed()
	_apply_settings()
	_shown_state = -1


func _apply_settings() -> void:
	var data := _setup.to_data()
	_timer.configure(data["limited"], data["seconds"])


func _on_tapped() -> void:
	_timer.tap(Time.get_ticks_msec())
	TimerAlert.vibrate(20)
	_refresh_state()


func _reset() -> void:
	_timer.reset()
	_refresh_state()


func _refresh_state() -> void:
	if _timer.state == _shown_state:
		return
	var previous := _shown_state
	_shown_state = _timer.state
	var idle := _timer.state == SingleTimer.State.IDLE
	_setup.visible = idle
	_controls.visible = not idle
	DisplayServer.screen_set_keep_on(_timer.state == SingleTimer.State.RUNNING)
	_area.pulse(false)
	var base: Color = preset.color
	var size_big := 200
	match _timer.state:
		SingleTimer.State.IDLE:
			_area.look(base, "play", "", size_big)
		SingleTimer.State.RUNNING:
			_area.look(base, "", "", size_big)
		SingleTimer.State.PAUSED:
			_area.look(PAUSED_GREY, "pause", "", size_big)
		SingleTimer.State.FINISHED:
			_area.look(TIME_UP_RED, "hourglass", "", size_big)
			_area.pulse(true)
	_update_text(Time.get_ticks_msec())
	var show_toolbar := _timer.state == SingleTimer.State.IDLE or _timer.state == SingleTimer.State.FINISHED
	if previous == -1 or show_toolbar != (previous == SingleTimer.State.IDLE or previous == SingleTimer.State.FINISHED):
		toolbar_visible_changed.emit(show_toolbar)

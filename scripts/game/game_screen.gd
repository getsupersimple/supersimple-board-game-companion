class_name GameScreen
extends Control
## One game: the active tool fills the main area, the back button and the tool's own
## buttons run along the top, and the toolbar runs along the bottom. The toolbar and any
## icon dragged out onto the screen are looked after by ToolDock, which lies over it all.

signal back_pressed

const ADD_LONG_PRESS_SECONDS := 0.45
## A finger that goes this far sideways across the tool, and little up or down, starts a swipe
## to the next or previous tool.
const SWIPE_SLOP := 30.0
## Let go past this fraction of the tool's width, or faster than SWIPE_FLICK pixels a second.
const SWIPE_COMMIT := 0.25
const SWIPE_FLICK := 900.0
const SWIPE_SLIDE := 140.0
## The tool's top buttons fade over this many pixels either side of their resting place.
const ACTIONS_FADE := 10.0
const PICKER_TYPES: Array[Preset.Type] = [
	Preset.Type.DICE, Preset.Type.BUZZER, Preset.Type.HOURGLASS,
]

var store: PresetStore
var game: Game
var active_preset_id: String = ""

var _tool_host: Control
var _tool: Control
## Tools swiped or tapped away from, kept built (but out of the tree, so they neither sound nor
## move) by preset id, so coming back finds the dice locked and the sand where it was.
var _kept := {}
## The neighbouring tool, built and running as soon as a swipe heads towards it, so it comes in
## with the finger rather than being started after the finger lifts.
var _incoming: Control
var _incoming_direction := 0
var _dock: ToolDock
var _picker: ToolPicker
var _hold_menu: HoldMenu
var _held_preset_id := ""
var _add_press := 0
var _add_held := false
var _swipe_from := Vector2.ZERO
var _tracking := false
var _swiping := false
var _swipe_velocity := 0.0
var _swipe_msec := 0
var _actions_base_x := 0.0
## The top buttons fade in over this when a tool simply appears; a sliding tool fades them by position.
var _actions_fade := 1.0
var _actions_fade_tween: Tween
var _actions_latched := false

@onready var _back_button: Button = %BackButton
@onready var _actions: HBoxContainer = %ToolActions
@onready var _active_icon: TextureRect = %ActiveIcon
@onready var _bar_slot: Control = %BarSlot
@onready var _add_button: Button = %AddButton


func _ready() -> void:
	_back_button.icon = IconLibrary.get_icon("arrow-left")
	_back_button.accessibility_name = tr("GAME_BACK")
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	UiStyle.tint_icon(_back_button, UiStyle.INK)
	UiStyle.icon_button(_add_button, "plus", ToolChip.SIZE, 72)
	_add_button.accessibility_name = tr("TOOLBAR_ADD")
	_add_button.focus_mode = Control.FOCUS_NONE
	_add_button.gui_input.connect(_on_add_input)

	_actions.get_parent().sort_children.connect(func() -> void: _actions_base_x = _actions.position.x)
	_actions_base_x = _actions.position.x

	_tool_host = Control.new()
	_tool_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tool_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := _active_icon.get_parent().get_parent()
	column.add_child(_tool_host)
	column.move_child(_tool_host, _active_icon.get_parent().get_index() + 1)

	_dock = ToolDock.new()
	_dock.set_slot(_bar_slot)
	_dock.tapped.connect(_on_chip_tapped)
	_dock.held.connect(_on_dock_held)
	_dock.finger_moved.connect(func(point: Vector2) -> void: _hold_menu.finger_moved(point))
	_dock.finger_up.connect(func(point: Vector2) -> void: _hold_menu.finger_up(point))
	_dock.placed_in_bar.connect(_on_placed_in_bar)
	_dock.placed_on_screen.connect(_on_placed_on_screen)
	add_child(_dock)

	_hold_menu = HoldMenu.new()
	_hold_menu.close_on_release = true
	_hold_menu.icon_chosen.connect(_on_icon_chosen)
	_hold_menu.color_chosen.connect(_on_color_chosen)
	_hold_menu.theme_chosen.connect(_on_theme_chosen)
	_hold_menu.delete_chosen.connect(func() -> void: _on_delete_requested(_held_preset_id))
	_hold_menu.drag_started.connect(func(point: Vector2) -> void: _dock.carry(point))
	_hold_menu.let_through = _dock.has_chip_at
	add_child(_hold_menu)

	_picker = ToolPicker.new()
	_picker.setup(PICKER_TYPES)
	_picker.picked.connect(_on_type_picked)
	add_child(_picker)


func open_game(game_store: PresetStore, game_id: String) -> void:
	store = game_store
	game = store.get_game(game_id)
	_picker.close()
	_dock.clear()
	_forget_all()
	active_preset_id = game.presets[0].id if not game.presets.is_empty() else ""
	_dock.sync(game.presets, active_preset_id, false)
	_show_active_preset()


## Leaves the game: the tool is taken out of the tree and freed, so nothing in it goes on
## running, sounding or reading the phone's motion while another screen is showing.
func close_game() -> void:
	_picker.close()
	_dock.clear()
	_drop_tool()
	_forget_all()
	game = null
	active_preset_id = ""


func _drop_tool() -> void:
	_drop_incoming()
	# The tool's own buttons go back to it, so a tool that is kept has them when it returns.
	for button in _actions.get_children():
		_actions.remove_child(button)
		var owner_tool: Variant = button.get_meta("tool_owner", null)
		if owner_tool is Control and is_instance_valid(owner_tool):
			button.visible = false
			owner_tool.add_child(button)
		else:
			button.queue_free()
	if _tool != null:
		var leaving := _tool
		_tool = null
		_retire(leaving)


## A tool that is no longer on show is kept for later if its preset still exists and nothing
## else already stands for it; otherwise it is freed.
func _retire(tool: Control) -> void:
	if not is_instance_valid(tool):
		return
	_stop_slide(tool)
	if tool.get_parent() != null:
		tool.get_parent().remove_child(tool)
	var id := str(tool.get_meta("preset_id", ""))
	var shown: bool = (_tool != null and str(_tool.get_meta("preset_id", "")) == id) \
			or (_incoming != null and str(_incoming.get_meta("preset_id", "")) == id)
	if id == "" or game == null or game.find_preset(id) == null or _kept.has(id) or shown:
		tool.queue_free()
		return
	_kept[id] = tool


## Frees the kept tool of a preset, such as one that has changed colour or been deleted.
func _forget(preset_id: String) -> void:
	var kept: Variant = _kept.get(preset_id, null)
	_kept.erase(preset_id)
	if kept is Control and is_instance_valid(kept):
		kept.queue_free()


func _forget_all() -> void:
	for id in _kept.keys():
		_forget(id)


func _fade_in_actions() -> void:
	_actions_latched = true
	_actions_fade = 0.0
	_start_fade()


func _start_fade() -> void:
	if _actions_fade_tween != null:
		_actions_fade_tween.kill()
	_actions_fade_tween = create_tween()
	_actions_fade_tween.tween_property(self, "_actions_fade", 1.0, 0.3)


## A sliding tool brings its buttons in by position, so it skips the timed fade.
func _skip_actions_fade() -> void:
	if _actions_fade_tween != null:
		_actions_fade_tween.kill()
	_actions_latched = false
	_actions_fade = 1.0


func _show_active_preset(running: Control = null) -> void:
	_drop_tool()
	var active := game.find_preset(active_preset_id)
	_tool = running if running != null else _make_tool(active)
	if active != null:
		_apply_theme(active)
	if _tool != null:
		if _tool.get_parent() == null:
			_tool_host.add_child(_tool)
		_take_top_buttons()
		_fade_in_actions()
		_active_icon.get_parent().visible = false
		_tool_host.visible = true
		return
	_tool_host.visible = false
	_active_icon.get_parent().visible = true
	_active_icon.visible = active != null
	if active != null:
		_active_icon.texture = IconLibrary.get_icon(active.icon)
		_active_icon.modulate = active.color


## The tool's own buttons (add a die, switch the hourglass) join the back button in the
## top bar, so they all sit on one line.
func _take_top_buttons() -> void:
	if not _tool.has_method("top_buttons"):
		return
	for button in _tool.top_buttons():
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
		button.visible = true
		button.set_meta("tool_owner", _tool)
		button.reparent(_actions, false)


## The tool for a preset: the one kept from before if there is one, else a new one. Null for a
## preset that has no screen yet.
func _make_tool(active: Preset) -> Control:
	if active == null:
		return null
	var kept: Variant = _kept.get(active.id, null)
	if kept is Control and is_instance_valid(kept):
		_kept.erase(active.id)
		_stop_slide(kept)
		# Out of the tree a control with anchors keeps its size as offsets from a zero-sized parent, so
		# put it back to filling its parent, or it comes back twice the size.
		kept.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		kept.position = Vector2.ZERO
		kept.mouse_filter = Control.MOUSE_FILTER_STOP
		return kept
	var built := _build_tool(active)
	if built != null:
		built.set_meta("preset_id", active.id)
	return built


func _build_tool(active: Preset) -> Control:
	match active.type:
		Preset.Type.DICE:
			var dice_tool := DiceTool.new()
			dice_tool.preset = active
			dice_tool.store = store
			return dice_tool
		Preset.Type.HOURGLASS:
			var glass_tool := HourglassTool.new()
			glass_tool.preset = active
			glass_tool.store = store
			return glass_tool
		Preset.Type.BUZZER:
			var buzzer_tool := BuzzerTool.new()
			buzzer_tool.preset = active
			buzzer_tool.store = store
			buzzer_tool.appearance_changed.connect(_refresh_dock)
			return buzzer_tool
	return null


## The tool's top buttons (the +) slide with the tool and are only visible within a few pixels of
## their resting place, so they fade out as it leaves and in as the next one arrives.
func _process(_delta: float) -> void:
	if _tool == null or _actions == null:
		return
	var x := _tool.position.x
	_actions.position.x = _actions_base_x + x
	if _swiping:
		_actions_latched = false
	if _actions_latched:
		_actions.modulate.a = _actions_fade
		return
	var alpha := clampf(1.0 - absf(x) / ACTIONS_FADE, 0.0, 1.0)
	if not _swiping and absf(x) < ACTIONS_FADE:
		# The tool has arrived: from here the buttons fade in by time, and a spring past its place
		# does not blink them out again.
		_actions_latched = true
		_actions_fade = alpha
		_start_fade()
	_actions.modulate.a = alpha


## How far apart neighbouring tools sit: a whole screen width, so each one comes in as a page
## with its own border around it rather than its content starting at the edge of the screen.
func _travel() -> float:
	return get_viewport_rect().size.x


## A finger dragged sideways over the tool takes the tool with it. Let go past a quarter of the
## way, or flicking, and the next (or previous) tool slides in; let go short of that, or after
## sliding back, and the tool springs home. The tool can refuse with `accepts_swipe`, say while a
## finger is dragging a die.
func _input(event: InputEvent) -> void:
	if _tool == null or not (event is InputEventMouse):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_tracking = _tool_host.get_global_rect().has_point(event.global_position) \
					and not _hold_menu.is_open and not _picker.is_open
			_swipe_from = event.global_position
			_swipe_velocity = 0.0
			_swipe_msec = Time.get_ticks_msec()
		elif _tracking:
			_tracking = false
			if _swiping:
				_swiping = false
				_finish_swipe(event.global_position.x - _swipe_from.x)
	elif event is InputEventMouseMotion and _tracking and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var moved: Vector2 = event.global_position - _swipe_from
		if not _swiping:
			if absf(moved.x) < SWIPE_SLOP or absf(moved.x) < absf(moved.y) * 1.5:
				return
			if _tool.has_method("accepts_swipe") and not _tool.accepts_swipe():
				_tracking = false
				return
			_swiping = true
			if _tool.has_method("cancel_press"):
				_tool.cancel_press()
		var now := Time.get_ticks_msec()
		var seconds := maxf((now - _swipe_msec) / 1000.0, 0.001)
		_swipe_velocity = lerpf(_swipe_velocity, event.relative.x / seconds, 0.5)
		_swipe_msec = now
		_drag_tool(moved.x)
		get_viewport().set_input_as_handled()


## Whether a tool lies `direction` places along the game's list, and its index.
func _neighbour(direction: int) -> int:
	if game == null:
		return -1
	for i in game.presets.size():
		if game.presets[i].id == active_preset_id:
			var next := i + direction
			return next if next >= 0 and next < game.presets.size() else -1
	return -1


## The tool follows the finger, and the neighbouring tool, already running,
## comes in behind it; with nothing beyond, the tool drags stiffly.
func _drag_tool(offset: float) -> void:
	var direction := 1 if offset < 0.0 else -1
	if _neighbour(direction) < 0:
		_drop_incoming()
		offset *= 0.3
	else:
		_bring_incoming(direction)
	_tool.position.x = offset
	if _incoming != null:
		_incoming.position.x = offset + direction * _travel()


## Has the tool `direction` places along coming in, starting it if it is not already.
func _bring_incoming(direction: int) -> void:
	if _incoming != null and _incoming_direction == direction:
		return
	_drop_incoming()
	var next := _neighbour(direction)
	var running := _make_tool(game.presets[next])
	if running == null:
		return
	_incoming = running
	_incoming_direction = direction
	_tool_host.add_child(running)
	running.position.x = direction * _travel()
	for button in running.call("top_buttons") if running.has_method("top_buttons") else []:
		button.visible = false


func _drop_incoming() -> void:
	if _incoming != null:
		var leaving := _incoming
		_incoming = null
		_retire(leaving)


func _finish_swipe(offset: float) -> void:
	var direction := 1 if offset < 0.0 else -1
	var far := absf(offset) > _tool_host.size.x * SWIPE_COMMIT
	var flicked := absf(_swipe_velocity) > SWIPE_FLICK and signf(_swipe_velocity) == signf(offset)
	if (far or flicked) and step_tool(direction, true):
		return
	_drop_incoming()
	_slide_in(_tool, _tool.position.x)


## Shows the tool `direction` places along the game's list, if there is one; true when it did. Given
## `from_swipe`, the tool already coming in carries on from where the finger left it and the old
## one slides out; otherwise the new tool slides in a little way.
func step_tool(direction: int, from_swipe: bool = false) -> bool:
	var next := _neighbour(direction)
	if next < 0:
		return false
	var running := _incoming if _incoming_direction == direction else null
	_incoming = null
	var outgoing := _tool if from_swipe and running != null else null
	if outgoing != null:
		_tool = null
	active_preset_id = game.presets[next].id
	_dock.sync(game.presets, active_preset_id, false)
	_dock.reveal(active_preset_id)
	_show_active_preset(running)
	_skip_actions_fade()
	if outgoing != null:
		_slide_out(outgoing, -direction * _travel())
	if _tool != null:
		if running != null and from_swipe:
			_slide_in(_tool, _tool.position.x)
		else:
			_slide_in(_tool, direction * SWIPE_SLIDE)
	return true


## The tool springs in to its place from where it is.
func _slide_in(tool: Control, from_x: float) -> void:
	tool.position.x = from_x
	_stop_slide(tool)
	var tween := tool.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tool, "position:x", 0.0, 0.3)
	tool.set_meta("slide", tween)


## The tool left behind carries on off the edge, and goes.
func _slide_out(tool: Control, to_x: float) -> void:
	tool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stop_slide(tool)
	var tween := tool.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(tool, "position:x", to_x, 0.3)
	tween.chain().tween_callback(_retire.bind(tool))
	tool.set_meta("slide", tween)


## A tool being moved again drops the slide it was still making.
func _stop_slide(tool: Control) -> void:
	if not tool.has_meta("slide"):
		return
	var running: Variant = tool.get_meta("slide")
	if running is Tween and running.is_valid():
		running.kill()


func _refresh_dock() -> void:
	_dock.sync(game.presets, active_preset_id, false)


## A tap on the + opens the drawer to be touched; holding it opens the drawer under the
## finger, which can go straight on to a kind (and an icon) and let go to add it.
func _on_add_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_add_press += 1
			get_tree().create_timer(ADD_LONG_PRESS_SECONDS).timeout.connect(_on_add_held.bind(_add_press))
		elif _add_held:
			_add_held = false
			_picker.pointer_up(_to_picker(event.position))
		elif _add_press != 0:
			_add_press = 0
			_picker.open(_add_button, false)
	elif event is InputEventMouseMotion and _add_held:
		_picker.pointer_move(_to_picker(event.position))


func _on_add_held(press_id: int) -> void:
	if _add_press != press_id:
		return
	_add_press = 0
	_add_held = true
	_picker.open(_add_button, true)


func _to_picker(button_point: Vector2) -> Vector2:
	return _add_button.global_position + button_point - _picker.global_position


func _on_type_picked(preset_type: Preset.Type, chosen_theme: String) -> void:
	var theme_name := chosen_theme if chosen_theme != "" else game.theme
	var preset := Preset.create_default(preset_type)
	preset.theme = theme_name
	preset.color = Themes.new_tool_color(theme_name, preset_type)
	store.add_preset(game.id, preset)
	active_preset_id = preset.id
	_dock.sync(game.presets, active_preset_id)
	_dock.reveal(preset.id)
	_show_active_preset()
	if theme_name != Themes.DEFAULT:
		SoundBank.play_once(self, "chain")


## The sounds of the tool on show are those of its theme.
func _apply_theme(preset: Preset) -> void:
	AppSettings.sound_theme = Themes.sound_set(preset.theme)


## Tapping the tool that is already showing taps it again: dice roll, the sand starts over.
## Slides to the tool `preset_id` names. Tools in between are laid out in a row with the two
## ends and the whole row pans past in one movement, so going from the first tool to the third
## runs straight through the second without stopping at it.
func _slide_to(preset_id: String) -> void:
	var from := game.presets.find(game.find_preset(active_preset_id))
	var to := game.presets.find(game.find_preset(preset_id))
	if from < 0 or to < 0:
		return
	var direction := 1 if to > from else -1
	var steps := absi(to - from)
	var travel := _travel()
	var row: Array[Control] = []
	var outgoing := _tool
	_drop_incoming()
	_tool = null
	if outgoing != null:
		_stop_slide(outgoing)
		outgoing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.append(outgoing)
	for i in range(1, steps):
		var passing := _make_tool(game.presets[from + direction * i])
		if passing == null:
			continue
		passing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tool_host.add_child(passing)
		for button in passing.call("top_buttons") if passing.has_method("top_buttons") else []:
			button.visible = false
		row.append(passing)
		passing.set_meta("row_index", i)
	active_preset_id = preset_id
	_dock.sync(game.presets, active_preset_id, false)
	_dock.reveal(active_preset_id)
	_show_active_preset()
	_skip_actions_fade()
	if outgoing != null:
		outgoing.set_meta("row_index", 0)
	if _tool == null or outgoing == null:
		for tool in row:
			_retire(tool)
		return
	_tool.set_meta("row_index", steps)
	row.append(_tool)
	var pan := func(offset: float) -> void:
		for tool in row:
			if is_instance_valid(tool):
				tool.position.x = direction * travel * int(tool.get_meta("row_index")) + offset
	pan.call(0.0)
	var tween := _tool.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tool.set_meta("slide", tween)
	tween.tween_method(pan, 0.0, -direction * travel * steps, 0.3 + 0.1 * (steps - 1))
	tween.tween_callback(func() -> void:
		for tool in row:
			if tool != _tool and is_instance_valid(tool):
				_retire(tool))


func _on_chip_tapped(preset_id: String) -> void:
	if preset_id == active_preset_id:
		if _tool != null and _tool.has_method("retap"):
			_tool.retap()
		return
	_slide_to(preset_id)


## A tool in the toolbar was held: a menu to change its icon or colour or delete it opens, and
## dragging the icon away picks it up to be moved.
func _on_dock_held(preset_id: String, finger: Vector2) -> void:
	var preset := game.find_preset(preset_id)
	if preset == null:
		return
	_held_preset_id = preset_id
	_hold_menu.open(_dock.global_position + _dock.chip_center(preset_id), finger, preset.icon, preset.color, true, true, preset.theme)


func _on_icon_chosen(icon_name: String) -> void:
	var preset := game.find_preset(_held_preset_id)
	if preset == null:
		return
	preset.icon = icon_name
	store.preset_changed()
	_dock.sync(game.presets, active_preset_id, false)


func _on_theme_chosen(theme_name: String) -> void:
	var preset := game.find_preset(_held_preset_id)
	if preset == null:
		return
	_recolor_dice(preset, preset.theme, theme_name)
	preset.theme = theme_name
	store.preset_changed()
	# The tool offers its theme's colours, so a tool of another theme is built again.
	_forget(preset.id)
	if preset.id == active_preset_id:
		_drop_tool()
		_forget(preset.id)
		_show_active_preset()
	SoundBank.play_once(self, "chain")


## A dice tool changing theme takes its dice's colours along: each becomes the same place in the new
## palette.
func _recolor_dice(preset: Preset, from_theme: String, to_theme: String) -> void:
	var old_palette := Themes.palette(from_theme)
	var new_palette := Themes.palette(to_theme)
	for entry in preset.data.get("dice", []):
		if entry is Dictionary and entry.get("color") is Color:
			entry["color"] = new_palette[Themes.nearest_index(old_palette, entry["color"])]


func _on_color_chosen(color: Color) -> void:
	var preset := game.find_preset(_held_preset_id)
	if preset == null:
		return
	preset.color = color
	store.preset_changed()
	_dock.sync(game.presets, active_preset_id, false)
	if preset.id == active_preset_id:
		# The tool is built from its colour, so this one is built again.
		_drop_tool()
		_forget(preset.id)
		_show_active_preset()
	else:
		_forget(preset.id)


## Deleting the tool on show slides to the one on its left (or, for the first, the one that
## takes its place), and the deleted tool goes out the other side.
func _on_delete_requested(preset_id: String) -> void:
	var index := game.presets.find(game.find_preset(preset_id))
	store.remove_preset(game.id, preset_id)
	_forget(preset_id)
	if active_preset_id != preset_id:
		_dock.sync(game.presets, active_preset_id, false)
		return
	var direction := -1 if index > 0 else 1
	var outgoing := _tool
	_tool = null
	_drop_incoming()
	active_preset_id = game.presets[maxi(index - 1, 0)].id if not game.presets.is_empty() else ""
	_dock.sync(game.presets, active_preset_id, false)
	_dock.reveal(active_preset_id)
	_show_active_preset()
	_skip_actions_fade()
	if outgoing != null:
		_slide_out(outgoing, -direction * _travel())
	if _tool != null and outgoing != null:
		_slide_in(_tool, direction * _travel())


func _on_placed_in_bar(preset_id: String, bar_index: int) -> void:
	store.place_in_bar(game.id, preset_id, bar_index)
	_dock.sync(game.presets, active_preset_id, false)


func _on_placed_on_screen(preset_id: String, fraction: Vector2) -> void:
	store.place_on_screen(game.id, preset_id, fraction)
	_dock.sync(game.presets, active_preset_id, false)

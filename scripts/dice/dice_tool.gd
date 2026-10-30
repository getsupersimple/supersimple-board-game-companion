class_name DiceTool
extends Control
## The dice tool: the total on top and the physics table. A + button at the top
## right adds dice: tap it, or hold it and drag down, to open a drawer of dice (see
## DiceDrawer). Rolling is done by tapping the tool's own icon in the toolbar again, or
## by shaking the phone. The dice on the table are saved into the preset after every
## change.

const MAX_DICE := 16
const DIE_KINDS: Array[int] = [2, 4, 6, 8, 10, 12, 20, 100]
const PERCENTILE := 100
const PALETTE: Array[Color] = [
	Color("#4F7CFF"), Color("#E5484D"), Color("#30A46C"),
	Color("#F5A524"), Color("#8E4EC6"), Color("#1C1C1E"),
]
## Holding a die in the top row, or the + button, this long is a long press.
const LONG_PRESS_SECONDS := 0.45
const TOP_ICON_SIZE := 72
const LOCK_CHOICES: Array[String] = ["auto", "unlock"]
const DIE_CHOICES: Array[String] = ["color", "lock", "remove"]
const DIE_ICONS := {"lock": "lock", "unlock": "lock-open", "color": "palette", "remove": "trash-2"}
## A touch on the table shorter and shorter-moving than this is a tap.
const TAP_MSEC := 300
const TAP_SLOP := 24.0
## After a long press on the bare table, a finger that goes this far across it throws the dice that way.
## Every colour's tally is at most this wide, so they line up whatever the number.
const TOTAL_WIDTH := 170.0
const SCORE_GAP := 8.0
const SCORE_FONT := 56
const THROW_DISTANCE := 90.0
const THROW_MIN_SPEED := 6.0
const THROW_MAX_SPEED := 16.0

var preset: Preset
var store: PresetStore

var _table: DiceTable
var _container: SubViewportContainer
var _totals: HBoxContainer
var _values: Array = []
var _shown_totals := {}
## Over the table: beside each die that has settled, a pill with what it shows.
var _score_layer: Control
var _scores := {}
## Counts presses on the top row. Non-zero while a press may still become a tap or a
## long press; the first of release and timeout takes it.
var _color_drawer: ChoiceDrawer
var _lock_drawer: ChoiceDrawer
var _surface_press := 0
## The drawer that has the finger now down, which gets its moves and its lift.
var _held_menu: ChoiceDrawer
var _die_drawer: ChoiceDrawer
var _menu_die: Die
var _menu_point := Vector2.ZERO
var _colors_for: Die
var _drawer: DiceDrawer
var _plus: Button
var _plus_press := 0
var _tap_start := Vector2.ZERO
var _tap_msec := 0
var _hold_point := Vector2.ZERO
var _hold_msec := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 16)
	add_child(column)

	_totals = HBoxContainer.new()
	_totals.alignment = BoxContainer.ALIGNMENT_CENTER
	_totals.add_theme_constant_override("separation", 12)
	_totals.custom_minimum_size = Vector2(0, UiStyle.TOP_BUTTON)
	column.add_child(_totals)
	_totals.resized.connect(func() -> void: _show_totals(_shown_totals))

	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	_container.add_child(viewport)
	_table = DiceTable.new()
	viewport.add_child(_table)
	_table.results_changed.connect(_update_results)
	_container.resized.connect(_fit_table)
	_container.gui_input.connect(_on_table_input)
	_score_layer = Control.new()
	_score_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.add_child(_score_layer)

	_build_plus_button()
	_fit_table.call_deferred()
	_load_saved_dice.call_deferred()


## A finger on the table picks up the die under it, drags it around, and lets
## go on release. A quick tap that goes nowhere makes every die jump. Holding a finger
## on the bare table opens a drawer of what to do with the locks, and a swipe away from it
## after that throws the dice. Touches are delivered
## as left clicks and drags, and the view has the same size as the container.
func _on_table_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var on_a_die := _table.begin_touch(event.position)
			_tap_start = event.position
			_tap_msec = Time.get_ticks_msec()
			if not on_a_die:
				_surface_press += 1
				get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(_on_surface_held.bind(_surface_press, event.position))
		else:
			_surface_press = 0
			_table.press_down(false)
			_table.end_touch()
			if _held_menu != null:
				var menu := _held_menu
				_held_menu = null
				_release_menu(menu, event.position)
				return
			var quick := Time.get_ticks_msec() - _tap_msec < TAP_MSEC
			if quick and event.position.distance_to(_tap_start) < TAP_SLOP:
				_table.jump_all()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if _held_menu != null:
			_move_menu(event.position)
		else:
			if event.position.distance_to(_tap_start) > TAP_SLOP:
				_surface_press = 0
			_table.move_touch(event.position)


## The finger that opened a drawer moves. With the colours out beside the die's drawer, a finger
## over them moves among them.
func _move_menu(table_point: Vector2) -> void:
	if _held_menu == _die_drawer and _color_drawer.is_open:
		var local := _to_menu(_color_drawer, table_point)
		if _color_drawer.covers(local):
			_color_drawer.pointer_move(local)
			return
		_color_drawer.pointer_move(Vector2(-9999.0, -9999.0))
	_held_menu.pointer_move(_to_menu(_held_menu, table_point))


## The finger that opened a drawer lifts: over the colours that picks one, and the die's drawer
## goes with them.
func _release_menu(menu: ChoiceDrawer, table_point: Vector2) -> void:
	if menu == _die_drawer and _color_drawer.is_open:
		var local := _to_menu(_color_drawer, table_point)
		if _color_drawer.covers(local):
			_color_drawer.pointer_up(local)
			_die_drawer.close()
			return
	if menu == _lock_drawer and not _lock_drawer.covers(_to_menu(menu, table_point)):
		# After a long press, a swipe that leaves the drawer behind throws the dice that way.
		var swept := table_point - _hold_point
		if swept.length() > THROW_DISTANCE:
			var seconds := maxf((Time.get_ticks_msec() - _hold_msec) / 1000.0, 0.08)
			_table.throw_all(swept, clampf(swept.length() / seconds / 100.0, THROW_MIN_SPEED, THROW_MAX_SPEED))
	if menu == _die_drawer and _die_drawer.item_at(_to_menu(menu, table_point)) < 0:
		_lock_by_default()
	menu.pointer_up(_to_menu(menu, table_point))
	if menu == _die_drawer:
		# The colours go when the finger lifts, like the drawer they came out of.
		_color_drawer.close()


## Letting go of a held die without choosing anything locks it (or unlocks it if it is locked).
func _lock_by_default() -> void:
	if _menu_die == null or not _table.dice.has(_menu_die):
		return
	if _menu_die.locked:
		_on_die_choice("unlock")
	elif not _cannot_lock(_menu_die).has("lock"):
		_on_die_choice("lock")


func _on_surface_held(press_id: int, point: Vector2) -> void:
	if _surface_press != press_id:
		return
	_surface_press = 0
	_hold_point = point
	_hold_msec = Time.get_ticks_msec()
	_table.press_down(true)
	_held_menu = _lock_drawer
	_lock_drawer.open(_to_menu(_lock_drawer, point), "auto" if _table.auto_lock else "", true)


## A finger held still on a die opens what can be done with it: lock it, or unlock it if it
## is locked, change its colour, or take it off the table.
func _on_die_held(die: Die, view_position: Vector2) -> void:
	if not _table.dice.has(die):
		return
	_menu_die = die
	_hold(die, true)
	var kinds: Array[String] = ["color", "unlock" if die.locked else "lock", "remove"]
	_die_drawer.setup(kinds, DIE_ICONS, {
		"lock": tr("DICE_LOCK"), "unlock": tr("DICE_UNLOCK"),
		"color": tr("DICE_CHANGE_COLOR"), "remove": tr("DICE_REMOVE"),
	})
	_die_drawer.set_disabled(_cannot_lock(die))
	_held_menu = _die_drawer
	_menu_point = _to_menu(_die_drawer, view_position)
	_die_drawer.open(_menu_point, "", true)


## While the drawer is open the die falls to the table, so whether it can be locked is
## looked at again each frame, and Lock dims or lights as it lands.
func _process(_delta: float) -> void:
	_place_scores()
	if _die_drawer == null or not _die_drawer.is_open or _menu_die == null or not is_instance_valid(_menu_die):
		return
	_die_drawer.set_disabled(_cannot_lock(_menu_die))


## The choices that cannot be picked for a die: Lock, when it cannot lie flat because it is
## on another die or wedged against something.
func _cannot_lock(die: Die) -> Array[String]:
	var cannot: Array[String] = []
	if die.locked:
		return cannot
	for half in [die, die.partner]:
		if half != null and not half.can_lie_flat():
			cannot.append("lock")
			break
	return cannot


func _on_die_choice(kind: String) -> void:
	if _menu_die == null or not _table.dice.has(_menu_die):
		return
	match kind:
		"lock":
			for half in [_menu_die, _menu_die.partner]:
				if half != null:
					half.try_lock()
		"unlock":
			for half in [_menu_die, _menu_die.partner]:
				if half != null:
					half.set_locked(false)
		"remove":
			_table.remove_die(_menu_die)
			_save()
		"color":
			_pop_out_colors(false)


## Pointing at Colour pops the colours out right away, above the drawer, like the other menus.
func _on_die_hovered(kind: String) -> void:
	if kind == "color":
		_pop_out_colors(true)
	elif kind != "" and _color_drawer.is_open:
		_color_drawer.close()


func _pop_out_colors(held: bool) -> void:
	if _color_drawer.is_open or _menu_die == null:
		return
	_colors_for = _menu_die
	_color_drawer.open_below(_die_drawer.rect(), str(_palette_index(_menu_die.die_color)), held, true)


## The die is let go when its drawer goes, unless the colours are still out for it.
func _on_die_menu_closed() -> void:
	if not _color_drawer.is_open and _menu_die != null and is_instance_valid(_menu_die):
		_hold(_menu_die, false)
	_menu_die = null


## Where a point of the table's view is, in a drawer's own coordinates.
func _to_menu(drawer: ChoiceDrawer, table_point: Vector2) -> Vector2:
	return _container.global_position + table_point - drawer.global_position


func _on_lock_choice(kind: String) -> void:
	if kind == "unlock":
		_table.unlock_all()
		return
	_table.auto_lock = not _table.auto_lock
	preset.data["auto_lock"] = _table.auto_lock
	store.preset_changed()


func _fit_table() -> void:
	if _container.size.y > 0.0:
		_table.set_view_aspect(_container.size.x / _container.size.y)


func _load_saved_dice() -> void:
	for entry in preset.data.get("dice", []):
		if not entry is Dictionary:
			continue
		var sides := int(entry.get("sides", 0))
		var color: Variant = entry.get("color", PALETTE[0])
		if not color is Color:
			color = PALETTE[0]
		if sides == PERCENTILE:
			_table.add_percentile(color)
			_update_results(_values)
		elif Die.is_supported(sides):
			_table.add_die(sides, color)


func _build_plus_button() -> void:
	_plus = UiStyle.icon_button(Button.new(), "plus", UiStyle.TOP_BUTTON, TOP_ICON_SIZE)
	_plus.focus_mode = Control.FOCUS_NONE
	_plus.accessibility_name = tr("DICE_ADD")
	_plus.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_plus.offset_left = -UiStyle.TOP_BUTTON
	_plus.offset_right = 0.0
	_plus.offset_top = 0.0
	_plus.offset_bottom = UiStyle.TOP_BUTTON
	_plus.gui_input.connect(_on_plus_input)
	add_child(_plus)
	_drawer = DiceDrawer.new()
	_drawer.setup(DIE_KINDS, PALETTE)
	_drawer.picked.connect(_add_die)
	add_child(_drawer)
	_color_drawer = ChoiceDrawer.new()
	_color_drawer.setup_colors(PALETTE)
	_color_drawer.picked.connect(_on_color_picked)
	_color_drawer.closed.connect(_on_colors_closed)
	add_child(_color_drawer)
	_lock_drawer = ChoiceDrawer.new()
	_lock_drawer.setup(LOCK_CHOICES, {"auto": "lock", "unlock": "lock-open"}, {"auto": tr("DICE_AUTO_LOCK"), "unlock": tr("DICE_UNLOCK_ALL")})
	_lock_drawer.close_on_release = true
	_lock_drawer.picked.connect(_on_lock_choice)
	add_child(_lock_drawer)
	_die_drawer = ChoiceDrawer.new()
	_die_drawer.setup(DIE_CHOICES, DIE_ICONS, {"lock": tr("DICE_LOCK"), "remove": tr("DICE_REMOVE")})
	_die_drawer.close_on_release = true
	_die_drawer.picked.connect(_on_die_choice)
	_die_drawer.hovered.connect(_on_die_hovered)
	_die_drawer.closed.connect(_on_die_menu_closed)
	add_child(_die_drawer)
	ActionBars.family(_die_drawer, [_die_drawer, _color_drawer])
	_table.die_held.connect(_on_die_held)
	_table.auto_lock = bool(preset.data.get("auto_lock", false))


## The buttons that belong in the screen's top bar, beside the back button.
func top_buttons() -> Array[Button]:
	return [_plus]


## A swipe across the table goes to another tool, unless a finger is busy with a die or a drawer.
func accepts_swipe() -> bool:
	return not _table.is_dragging() and _held_menu == null and not _drawer.is_open \
			and not _color_drawer.is_open and not _die_drawer.is_open and not _lock_drawer.is_open


## A swipe has taken the finger: a press that is still waiting to become a long press is dropped.
func cancel_press() -> void:
	_surface_press = 0


## Tapping the tool's icon in the toolbar while it is showing rolls the dice again.
func retap() -> void:
	_table.roll_all()


## A quick tap opens the drawer to be touched; holding opens it under the finger, which
## can go straight on to a die and a colour without lifting.
func _on_plus_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_plus_press += 1
			get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(_on_plus_held.bind(_plus_press))
		elif _plus_press != 0:
			_plus_press = 0
			if not _drawer.is_open:
				_drawer.open(_plus, false)
		else:
			_drawer.pointer_up(_to_drawer(event.position))
	elif event is InputEventMouseMotion and _plus_press == 0 and _drawer.is_open:
		_drawer.pointer_move(_to_drawer(event.position))


func _on_plus_held(press_id: int) -> void:
	if _plus_press != press_id:
		return
	_plus_press = 0
	_drawer.open(_plus, true)


func _to_drawer(plus_position: Vector2) -> Vector2:
	return _plus.global_position + plus_position - _drawer.global_position


## A die of a kind has been picked in the drawer; no colour means any colour.
func _add_die(sides: int, color: Variant) -> void:
	var needed := 2 if sides == PERCENTILE else 1
	if _table.dice.size() + needed > MAX_DICE:
		return
	var paint: Color = color if color is Color else PALETTE.pick_random()
	if sides == PERCENTILE:
		_table.add_percentile(paint)
		_update_results(_values)
	else:
		_table.add_die(sides, paint)
	_save()


func _palette_index(color: Color) -> int:
	for i in PALETTE.size():
		if PALETTE[i].is_equal_approx(color):
			return i
	return -1


## A colour was picked in the drawer: the die is painted, both halves of a percentile pair.
func _on_color_picked(kind: String) -> void:
	if _colors_for != null and _table.dice.has(_colors_for):
		_on_color_chosen(_colors_for, PALETTE[int(kind)])


## Keeps a die, and its other half, perfectly still while it is being dealt with.
func _hold(die: Die, on: bool) -> void:
	for half in [die, die.partner]:
		if half != null and is_instance_valid(half):
			half.hold(on)


func _on_colors_closed() -> void:
	if not _die_drawer.is_open and _colors_for != null and is_instance_valid(_colors_for):
		_hold(_colors_for, false)
	_colors_for = null


func _on_color_chosen(die: Die, color: Color) -> void:
	for half in [die, die.partner]:
		if half != null:
			half.set_color(color)
	_update_results(_values)
	_save()


func _update_results(values: Array) -> void:
	_values = values
	var totals := {}
	var undecided := {}
	var i := 0
	while i < _table.dice.size():
		var die := _table.dice[i]
		# A die the table has not reported on yet is undecided, not left out of its colour's total.
		var value: int = values[i] if i < values.size() else -1
		if die.numeral_style == Die.NumeralStyle.TENS and die.partner != null:
			# A percentile pair reads as one number from 1 to 100.
			var units_value: int = values[i + 1] if i + 1 < values.size() else -1
			value = -1 if value < 0 or units_value < 0 else maxi((value % 10) * 10 + units_value % 10, 0)
			if value == 0:
				value = 100
			i += 1
		i += 1
		totals[die.die_color] = int(totals.get(die.die_color, 0)) + maxi(value, 0)
		if value < 0:
			undecided[die.die_color] = true
	# A colour whose dice have all settled shows its total whatever the others are doing; one
	# with a die still rolling shows a question mark.
	for color in undecided:
		totals[color] = -1
	_show_totals(totals)


## Beside each die that lies flat and still, a pill in its colour with the number it shows. A
## percentile pair reads as one number, beside its tens die.
func _place_scores() -> void:
	if _score_layer == null or _table.camera == null:
		return
	var seen := {}
	for die in _table.dice:
		if die.numeral_style == Die.NumeralStyle.UNITS:
			continue
		var value := _score_of(die)
		if value < 0 or not die.is_at_rest():
			continue
		seen[die] = true
		var pill: PanelContainer = _scores.get(die)
		if pill == null:
			pill = _make_score_pill(die)
			_scores[die] = pill
			_score_layer.add_child(pill)
		if pill.get_meta("color") != die.die_color:
			pill.set_meta("color", die.die_color)
			pill.add_theme_stylebox_override("panel", _pill_box(die.die_color))
		var label := pill.get_child(0) as Label
		label.text = str(value)
		pill.reset_size()
		var centre := _table.camera.unproject_position(die.global_position)
		var reach_px := _table.camera.unproject_position(die.global_position + Vector3(die.reach(), 0.0, 0.0)).x - centre.x
		var at := Vector2(centre.x + reach_px + SCORE_GAP, centre.y + reach_px * 0.2 - pill.size.y / 2.0)
		if at.x + pill.size.x > _score_layer.size.x:
			at.x = centre.x - reach_px - SCORE_GAP - pill.size.x
		pill.position = at
	for die in _scores.keys():
		if not seen.has(die):
			var gone: Control = _scores[die]
			_scores.erase(die)
			if is_instance_valid(gone):
				gone.queue_free()


## What a die shows: -1 while it is not lying flat; a percentile's tens die reads the whole pair.
func _score_of(die: Die) -> int:
	var value := die.read_value()
	if die.numeral_style != Die.NumeralStyle.TENS or die.partner == null:
		return value
	var units := die.partner.read_value()
	if value < 0 or units < 0 or not die.partner.is_at_rest():
		return -1
	var whole := (value % 10) * 10 + units % 10
	return 100 if whole == 0 else whole


func _make_score_pill(die: Die) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _pill_box(die.die_color))
	pill.set_meta("color", die.die_color)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", SCORE_FONT)
	label.add_theme_color_override("font_color", Color.WHITE)
	pill.add_child(label)
	return pill


## A dark pill in a colour's own hue, with a light edge of it.
func _pill_box(color: Color) -> StyleBoxFlat:
	var box := UiStyle.box(color.darkened(0.3), 48)
	box.border_color = color.lightened(0.45)
	box.set_border_width_all(4)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	return box


## One total per colour of die, in a pill of that colour, once every die has settled. The pills
## share the width there is, so a die of every colour still fits across the screen.
func _show_totals(totals: Dictionary) -> void:
	_shown_totals = totals
	for child in _totals.get_children():
		_totals.remove_child(child)
		child.queue_free()
	var many := totals.size() > 1
	var font_size := 72 if not many else (48 if totals.size() <= 4 else 40)
	var gaps := (totals.size() - 1) * float(_totals.get_theme_constant("separation"))
	var available := _totals.size.x if _totals.size.x > 0.0 else get_viewport_rect().size.x
	var width := minf(TOTAL_WIDTH, (available - gaps) / maxf(totals.size(), 1.0))
	for color: Color in totals:
		var pill := PanelContainer.new()
		var box := _pill_box(color)
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		pill.add_theme_stylebox_override("panel", box if many else StyleBoxEmpty.new())
		pill.custom_minimum_size.x = width if many else 0.0
		var label := Label.new()
		label.text = str(totals[color]) if totals[color] >= 0 else "?"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", font_size)
		if many:
			label.add_theme_color_override("font_color", Color.WHITE)
		pill.add_child(label)
		_totals.add_child(pill)


func _save() -> void:
	var saved: Array[Dictionary] = []
	for die in _table.dice:
		if die.numeral_style == Die.NumeralStyle.UNITS:
			continue
		var is_percentile := die.numeral_style == Die.NumeralStyle.TENS
		saved.append({"sides": PERCENTILE if is_percentile else die.sides, "color": die.die_color})
	preset.data["dice"] = saved
	store.preset_changed()

class_name Home
extends Control
## Home screen: one tile per game, with the built-in Quick game first and a large + tile at
## the end of the list that adds another. The tiles scroll when they do not all fit.
##
## Holding a tile opens a menu (see HoldMenu): its icon, its colour, its theme, delete. If instead the
## finger drags the tile away, the menu goes and the tile is picked up: it follows the finger
## round the list, the others slide aside to make room, and it springs into place where it is
## let go.

signal game_selected(game_id: String)
signal settings_pressed

const COLUMNS := 2
const GAP := 32.0
const MARGIN := 48
const LONG_PRESS_SECONDS := 0.45
const DRAG_SLOP := 18.0
const EDGE_ZONE := 140.0
const EDGE_SCROLL_SPEED := 1100.0
const FOLLOW_STIFFNESS := 1100.0
const FOLLOW_DAMPING := 54.0
const SETTLE_STIFFNESS := 380.0
const SETTLE_DAMPING := 24.0

var store: PresetStore

var _hold_menu: HoldMenu
## Offered by a long press on the + tile: the look of the set to add.
var _theme_drawer: ChoiceDrawer
var _add_press := 0
var _add_held := false
var _add_tile: GameTile
var _tiles := {}
var _springs := {}
var _side := 300.0
var _press := 0
var _press_y := 0.0
var _scroll_start := 0
var _dragging := false
var _held_game: Game
var _held_tile: GameTile
var _held := false
var _swallow_until := 0
## When a touch last put the hold menu away, and whether the press now down did.
var _dismissed_msec := -1000
var _press_dismissed := false
var _reordering := false
var _grab := Vector2.ZERO
var _pointer := Vector2.ZERO
var _drop_index := 0

@onready var _grid: Control = %Grid
@onready var _scroll: ScrollContainer = %Scroll
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	_settings_button.icon = IconLibrary.get_icon("settings")
	_settings_button.accessibility_name = tr("HOME_SETTINGS")
	_settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	UiStyle.tint_icon(_settings_button, UiStyle.INK)
	resized.connect(_update_tile_sizes)

	_hold_menu = HoldMenu.new()
	_hold_menu.icon_chosen.connect(_on_icon_chosen)
	_hold_menu.color_chosen.connect(_on_color_chosen)
	_hold_menu.theme_chosen.connect(_on_theme_chosen)
	_hold_menu.delete_chosen.connect(_on_delete_chosen)
	_hold_menu.drag_started.connect(_on_drag_started)
	_hold_menu.dismissed.connect(func() -> void: _dismissed_msec = Time.get_ticks_msec())
	_hold_menu.let_through = func(_point: Vector2) -> bool: return true
	add_child(_hold_menu)

	_theme_drawer = ChoiceDrawer.new()
	_theme_drawer.setup(Themes.NAMES, Themes.ICONS)
	_theme_drawer.columns = Themes.NAMES.size()
	_theme_drawer.picked.connect(_add_game_in)
	add_child(_theme_drawer)


func show_games(game_store: PresetStore) -> void:
	store = game_store
	var keep := _scroll.scroll_vertical
	for tile in _tiles.values():
		tile.queue_free()
		_grid.remove_child(tile)
	_tiles.clear()
	_springs.clear()
	if _add_tile != null:
		_grid.remove_child(_add_tile)
		_add_tile.queue_free()
	for game in store.games:
		_add_game_tile(game)
	_add_tile = GameTile.new()
	_add_tile.setup("plus", UiStyle.PANEL, "HOME_ADD_GAME")
	_add_tile.gui_input.connect(_on_add_tile_input)
	_grid.add_child(_add_tile)
	_update_tile_sizes()
	_layout(true)
	_restore_scroll.call_deferred(keep)


func _restore_scroll(position: int) -> void:
	_scroll.scroll_vertical = position


func _add_game_tile(game: Game) -> void:
	var tile := GameTile.new()
	tile.setup(game.icon, game.color, "HOME_QUICK_GAME" if game.id == PresetStore.QUICK_ID else "HOME_GAME")
	tile.pressed.connect(_on_tile_pressed.bind(game))
	tile.gui_input.connect(_on_tile_input.bind(tile, game))
	_grid.add_child(tile)
	_tiles[game.id] = tile
	_springs[game.id] = Spring.new(Vector2.ZERO)


func _on_tile_pressed(game: Game) -> void:
	if _held or _dragging or _press_dismissed or Time.get_ticks_msec() < _swallow_until:
		return
	game_selected.emit(game.id)


# ------------------------------------------------------------------ touches on a tile

## A press on a tile can be a tap that opens the game, a swipe that scrolls the list (the
## tiles are buttons, so they would otherwise swallow it), or a hold that opens the menu.
func _on_tile_input(event: InputEvent, tile: GameTile, game: Game) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press += 1
			_dragging = false
			_press_dismissed = Time.get_ticks_msec() - _dismissed_msec < 100
			_press_y = tile.get_global_mouse_position().y
			_scroll_start = _scroll.scroll_vertical
			get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(_on_tile_held.bind(_press, tile, game))
		else:
			_press += 1
			_finger_up(tile.get_global_mouse_position())
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var at := tile.get_global_mouse_position()
		if _held:
			_finger_moved(at)
		elif absf(at.y - _press_y) > DRAG_SLOP or _dragging:
			_dragging = true
			_scroll.scroll_vertical = _scroll_start - int(at.y - _press_y)


func _on_tile_held(press_id: int, tile: GameTile, game: Game) -> void:
	if _press != press_id or _dragging or not is_instance_valid(tile):
		return
	_held = true
	_held_game = game
	_held_tile = tile
	var changeable := not game.is_builtin
	_hold_menu.open(tile.get_global_rect().get_center(), tile.get_global_mouse_position(), game.icon, game.color, changeable, changeable, game.theme)


## The finger that is down moves: into the menu or its lists, or, once it has been taken away
## from them, dragging the tile about.
func _finger_moved(at: Vector2) -> void:
	_pointer = at
	if _reordering:
		_update_reorder()
	else:
		_hold_menu.finger_moved(at)


func _finger_up(at: Vector2) -> void:
	if not _held:
		return
	_held = false
	_swallow_until = Time.get_ticks_msec() + 150
	if _reordering:
		_end_reorder()
	else:
		_hold_menu.finger_up(at)


# ------------------------------------------------------------------ the menu's choices

func _on_icon_chosen(icon_name: String) -> void:
	if _held_game == null:
		return
	store.set_game_icon(_held_game.id, icon_name)
	show_games(store)


func _on_color_chosen(color: Color) -> void:
	if _held_game == null:
		return
	store.set_game_color(_held_game.id, color)
	show_games(store)


func _on_theme_chosen(theme_name: String) -> void:
	if _held_game == null:
		return
	store.set_game_theme(_held_game.id, theme_name)
	show_games(store)


func _on_delete_chosen() -> void:
	if _held_game == null:
		return
	store.delete_game(_held_game.id)
	show_games(store)


func _on_drag_started(_at: Vector2) -> void:
	_begin_reorder()


# ------------------------------------------------------------------ reordering

## Picks the tile up: the menu goes away and the tile follows the finger.
func _begin_reorder() -> void:
	_reordering = true
	var tile := _held_tile
	_grab = _pointer - _grid.global_position - tile.position
	_grid.move_child(tile, -1)
	var spring: Spring = _springs[_held_game.id]
	spring.stiffness = FOLLOW_STIFFNESS
	spring.damping = FOLLOW_DAMPING
	spring.value = tile.position
	_update_reorder()


func _update_reorder() -> void:
	var spring: Spring = _springs[_held_game.id]
	var board := _pointer - _grid.global_position
	spring.target = board - _grab
	var centre := board - _grab + Vector2(_side, _side) / 2.0
	var column := clampi(floori(centre.x / (_side + GAP)), 0, COLUMNS - 1)
	var row := maxi(floori(centre.y / (_side + GAP)), 0)
	_drop_index = clampi(row * COLUMNS + column, 1, store.games.size() - 1)
	_layout(false)


## Lets go of the tile: it springs into its place and the new order is kept.
func _end_reorder() -> void:
	_reordering = false
	var spring: Spring = _springs[_held_game.id]
	spring.stiffness = SETTLE_STIFFNESS
	spring.damping = SETTLE_DAMPING
	store.move_game(_held_game.id, _drop_index)
	_layout(false)


func _process(delta: float) -> void:
	for id in _springs:
		var spring: Spring = _springs[id]
		spring.step(delta)
		if _tiles.has(id):
			_tiles[id].position = spring.value
	if _reordering:
		var view := _scroll.get_global_rect()
		if _pointer.y < view.position.y + EDGE_ZONE:
			_scroll.scroll_vertical -= int(EDGE_SCROLL_SPEED * delta)
		elif _pointer.y > view.end.y - EDGE_ZONE:
			_scroll.scroll_vertical += int(EDGE_SCROLL_SPEED * delta)
		_update_reorder()


# ------------------------------------------------------------------ layout

## Where a place in the list is, on the board.
func slot_position(index: int) -> Vector2:
	return Vector2((index % COLUMNS) * (_side + GAP), (index / COLUMNS) * (_side + GAP))


## Sends every tile to its place: in order, with a gap where a tile being carried would land.
func _layout(snap: bool) -> void:
	var order: Array[Game] = []
	for game in store.games:
		if not (_reordering and _held_game != null and game.id == _held_game.id):
			order.append(game)
	for i in order.size():
		var slot := i
		if _reordering and i >= _drop_index:
			slot = i + 1
		_place(order[i].id, slot_position(slot), snap)
	if not _reordering:
		for game in store.games:
			if _springs.has(game.id):
				_springs[game.id].stiffness = SETTLE_STIFFNESS
				_springs[game.id].damping = SETTLE_DAMPING
	# The + tile follows the last game.
	_add_tile.position = slot_position(store.games.size())
	var rows := ceili(float(store.games.size() + 1) / COLUMNS)
	_grid.custom_minimum_size = Vector2(0, rows * (_side + GAP) - GAP)


func _place(game_id: String, point: Vector2, snap: bool) -> void:
	var spring: Spring = _springs[game_id]
	if snap:
		spring.snap(point)
		_tiles[game_id].position = point
	else:
		spring.target = point


## A tap on the + tile adds a set in a random theme; holding it offers the themes to pick from.
func _on_add_tile_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_add_press += 1
			_add_held = false
			get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(_on_add_held.bind(_add_press))
		else:
			_add_press += 1
			if _add_held:
				_add_held = false
				_theme_drawer.pointer_up(_add_tile.get_global_mouse_position() - _theme_drawer.global_position)
			elif Time.get_ticks_msec() - _dismissed_msec >= 400:
				_add_game_in(Themes.NAMES.pick_random())
	elif event is InputEventMouseMotion and _add_held:
		_theme_drawer.pointer_move(_add_tile.get_global_mouse_position() - _theme_drawer.global_position)


func _on_add_held(press_id: int) -> void:
	if _add_press != press_id:
		return
	_add_held = true
	Haptics.pulse(20)
	_theme_drawer.open_below(_add_tile.get_global_rect(), "", true, true)


## Adds a set in a theme: its icon and colour are the next ones of that theme's.
func _add_game_in(theme_name: String) -> void:
	var index := store.games.size() - 1
	var icons := Themes.icon_set(theme_name)
	var colors := Themes.palette(theme_name)
	var game := Game.create(icons[index % icons.size()], colors[index % colors.size()])
	game.theme = theme_name
	store.add_game(game)
	show_games(store)
	# Scrolled to the end, where the new game is.
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


## Keeps tiles square, from the width there is.
func _update_tile_sizes() -> void:
	_side = (size.x - 2.0 * MARGIN - GAP * (COLUMNS - 1)) / COLUMNS
	var every: Array = _tiles.values()
	if _add_tile != null:
		every.append(_add_tile)
	for tile in every:
		(tile as Control).custom_minimum_size = Vector2(_side, _side)
		(tile as Control).size = Vector2(_side, _side)
	if store != null:
		_layout(true)

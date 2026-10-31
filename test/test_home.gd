extends GutTest

const SCENE := preload("res://scenes/home/home.tscn")

var _home: Home
var _store: PresetStore


func _make_home(extra_games: int) -> void:
	_store = PresetStore.new("user://test_home.cfg")
	_store.load_store()
	for i in extra_games:
		_store.add_game(Game.create("dices", Color.RED))
	_home = SCENE.instantiate()
	add_child_autofree(_home)
	_home.show_games(_store)


func after_each() -> void:
	DirAccess.remove_absolute("user://test_home.cfg")


func _press(tile: Control, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	tile.gui_input.emit(event)


func test_a_large_plus_tile_ends_the_list_and_adds_a_game_with_no_limit() -> void:
	_make_home(12)
	await wait_seconds(0.3)
	var plus: GameTile = _home._add_tile
	assert_eq(plus.size, _home._grid.get_child(1).size, "as large as a game")
	assert_eq(plus.position, _home.slot_position(_store.games.size()), "right after the last game")
	var before := _store.games.size()
	_home._add_game_in("standard")
	assert_eq(_store.games.size(), before + 1, "there is no maximum")
	await wait_seconds(0.3)
	assert_eq(_home._add_tile.position, _home.slot_position(_store.games.size()), "and it moves along")
	assert_null(_home.find_child("AddButton", true, false), "no small + in the corner")


func test_the_list_scrolls_when_there_are_more_games_than_fit() -> void:
	_make_home(12)
	await wait_seconds(0.4)
	var bar := _home._scroll.get_v_scroll_bar()
	assert_gt(bar.max_value, bar.page, "more than fits, so it scrolls")


func _hold(tile: Control) -> void:
	_press(tile, true)
	await wait_seconds(Home.LONG_PRESS_SECONDS + 0.2)


func _at(drawer: ChoiceDrawer, index: int) -> Vector2:
	return drawer.item_rect(index).get_center() + drawer.global_position


func test_holding_a_game_opens_a_menu_of_icon_colour_and_delete() -> void:
	_make_home(1)
	await wait_seconds(0.3)
	await _hold(_home._grid.get_child(1))
	assert_true(_home._hold_menu.menu.is_open)
	assert_eq(_home._hold_menu.menu._kinds, ["icon", "color", "theme", "delete"])
	assert_false(_home._hold_menu.menu.is_disabled("delete"))


func test_the_built_in_game_cannot_be_deleted_or_dragged() -> void:
	_make_home(1)
	await wait_seconds(0.3)
	await _hold(_home._grid.get_child(0))
	assert_true(_home._hold_menu.menu.is_disabled("delete"))
	assert_false(_home._hold_menu.menu.is_disabled("icon"))
	_home._finger_moved(_home._hold_menu.hold_origin + Vector2(0, 300))
	assert_false(_home._reordering, "and it cannot be picked up")


func test_keeping_the_finger_on_icon_pops_the_icons_out_underneath_and_one_can_be_chosen() -> void:
	_make_home(1)
	await wait_seconds(0.3)
	var tile: Control = _home._grid.get_child(1)
	await _hold(tile)
	_home._finger_moved(_at(_home._hold_menu.menu, 0))
	assert_true(_home._hold_menu.icon_drawer.is_open)
	assert_gt(_home._hold_menu.icon_drawer.rect().position.y, _home._hold_menu.menu.rect().end.y - 1.0, "underneath")
	var target := 5
	_home._finger_moved(_at(_home._hold_menu.icon_drawer, target))
	_home._finger_up(_at(_home._hold_menu.icon_drawer, target))
	assert_eq(_store.games[1].icon, Themes.icon_set(Themes.DEFAULT)[target])
	assert_false(_home._hold_menu.icon_drawer.is_open)
	var reloaded := PresetStore.new("user://test_home.cfg")
	reloaded.load_store()
	assert_eq(reloaded.games[1].icon, Themes.icon_set(Themes.DEFAULT)[target], "saved")


func test_colour_pops_a_list_of_colours_out_underneath_and_one_can_be_chosen() -> void:
	_make_home(1)
	await wait_seconds(0.3)
	await _hold(_home._grid.get_child(1))
	_home._finger_moved(_at(_home._hold_menu.menu, 1))
	assert_true(_home._hold_menu.color_drawer.is_open)
	assert_false(_home._hold_menu.icon_drawer.is_open)
	_home._finger_moved(_at(_home._hold_menu.color_drawer, 3))
	_home._finger_up(_at(_home._hold_menu.color_drawer, 3))
	assert_eq(_store.games[1].color, Themes.palette(Themes.DEFAULT)[3])


func test_delete_removes_the_game() -> void:
	_make_home(2)
	await wait_seconds(0.3)
	var gone := _store.games[1].id
	await _hold(_home._grid.get_child(1))
	_home._finger_moved(_at(_home._hold_menu.menu, 3))
	_home._finger_up(_at(_home._hold_menu.menu, 3))
	assert_null(_store.get_game(gone))
	assert_eq(_store.games.size(), 2)


func test_dragging_the_tile_after_a_hold_picks_it_up_and_dropping_moves_it() -> void:
	_make_home(3)
	await wait_seconds(0.3)
	var moved := _store.games[1].id
	var tile: GameTile = _home._grid.get_child(1)
	await _hold(tile)
	assert_true(_home._hold_menu.menu.is_open)
	var start_position := tile.position
	var picked_up_at: Vector2 = _home._hold_menu.hold_origin + Vector2(0, 160)
	var target := _home._grid.global_position + _home.slot_position(3) + Vector2(_home._side, _home._side) / 2.0
	_home._finger_moved(picked_up_at)
	assert_true(_home._reordering, "dragged away from the menu, the tile is picked up")
	assert_false(_home._hold_menu.menu.is_open, "and the menu goes")
	_home._finger_moved(target)
	await wait_seconds(0.8)
	assert_lt(tile.position.distance_to(start_position + target - picked_up_at), 6.0, "following the finger, grip and all")
	_home._finger_up(target)
	assert_eq(_store.games[3].id, moved, "the game is now fourth")
	assert_eq(_store.games[0].id, PresetStore.QUICK_ID, "Quick stays first")
	await wait_seconds(1.0)
	assert_lt(tile.position.distance_to(_home.slot_position(3)), 4.0, "settled in its place")


func test_moving_towards_or_onto_the_menu_does_not_pick_the_tile_up_and_nor_does_leaving_it_after_being_on_it() -> void:
	_make_home(2)
	await wait_seconds(0.3)
	await _hold(_home._grid.get_child(1))
	var towards: Vector2 = _home._hold_menu.menu.rect().get_center() + _home._hold_menu.menu.global_position - _home._hold_menu.hold_origin
	_home._finger_moved(_home._hold_menu.hold_origin + towards.normalized() * 80.0)
	assert_false(_home._reordering, "heading for the menu")
	_home._finger_moved(_at(_home._hold_menu.menu, 0))
	assert_true(_home._hold_menu.icon_drawer.is_open, "onto Icon")
	_home._finger_moved(_at(_home._hold_menu.icon_drawer, 2))
	assert_false(_home._reordering, "onto the list that popped out")
	_home._finger_moved(_home._hold_menu.hold_origin + Vector2(0, 400))
	assert_false(_home._reordering, "out of the menu and its list, the tile is not picked up")
	assert_false(_home._hold_menu.is_open, "and the menu and its lists are all put away")
	assert_false(_home._hold_menu.icon_drawer.is_open)


func test_a_tap_still_opens_the_game_and_a_hold_does_not() -> void:
	_make_home(1)
	await wait_seconds(0.3)
	var opened := []
	_home.game_selected.connect(func(id: String) -> void: opened.append(id))
	var tile: GameTile = _home._grid.get_child(1)
	tile.pressed.emit()
	assert_eq(opened.size(), 1)
	_press(tile, true)
	await wait_seconds(Home.LONG_PRESS_SECONDS + 0.2)
	_press(tile, false)
	tile.pressed.emit()
	assert_eq(opened.size(), 1, "the release of a hold is not a tap")


func _touch_outside(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	event.global_position = at
	_home._hold_menu._input(event)


func test_a_hold_on_another_game_while_a_menu_is_left_open_opens_that_games_menu() -> void:
	_make_home(2)
	await wait_seconds(0.3)
	var first: Control = _home._grid.get_child(1)
	var second: Control = _home._grid.get_child(2)
	await _hold(first)
	_press(first, false)
	assert_false(_home._hold_menu.menu.is_open, "put away when the finger lifts")
	_touch_outside(Vector2(5, 5))
	_press(second, true)
	assert_false(_home._hold_menu.menu.is_open, "the touch put it away")
	await wait_seconds(Home.LONG_PRESS_SECONDS + 0.2)
	assert_true(_home._hold_menu.menu.is_open, "and the hold opened the next one")
	assert_eq(_home._held_game, _store.games[2])


func test_a_tap_on_a_game_while_a_menu_is_open_only_puts_the_menu_away() -> void:
	_make_home(2)
	await wait_seconds(0.3)
	var first: Control = _home._grid.get_child(1)
	var second: Control = _home._grid.get_child(2)
	var opened := []
	_home.game_selected.connect(func(id: String) -> void: opened.append(id))
	await _hold(first)
	_press(first, false)
	_touch_outside(Vector2(5, 5))
	_press(second, true)
	_press(second, false)
	second.pressed.emit()
	await wait_seconds(0.3)
	assert_eq(opened, [], "no game opened")


func test_letting_go_on_icon_puts_the_icons_away_with_the_menu() -> void:
	_make_home(1)
	await wait_seconds(0.3)
	await _hold(_home._grid.get_child(1))
	_home._finger_moved(_at(_home._hold_menu.menu, 0))
	assert_true(_home._hold_menu.icon_drawer.is_open)
	_home._finger_up(_at(_home._hold_menu.menu, 0))
	assert_false(_home._hold_menu.menu.is_open)
	assert_false(_home._hold_menu.icon_drawer.is_open, "both go at once")


func test_a_set_remembers_its_theme_and_changing_it_moves_its_icon_and_colour_into_the_theme() -> void:
	_make_home(1)
	await wait_seconds(0.3)
	var game: Game = _store.games[1]
	game.icon = "heart"
	game.color = Color("#4F7CFF")
	_store.set_game_theme(game.id, "dnd")
	assert_eq(game.theme, "dnd")
	assert_true(Themes.icon_set("dnd").has(game.icon), "an icon the theme has")
	assert_true(Themes.palette("dnd").has(game.color), "a colour of its palette")
	var reloaded := PresetStore.new("user://test_home.cfg")
	reloaded.load_store()
	assert_eq(reloaded.games[1].theme, "dnd", "saved")


func test_adding_a_set_in_a_chosen_theme_uses_that_themes_icon_and_colour() -> void:
	_make_home(1)
	await wait_seconds(0.3)
	_home._add_game_in("futuristic")
	var added: Game = _store.games[_store.games.size() - 1]
	assert_eq(added.theme, "futuristic")
	assert_true(Themes.icon_set("futuristic").has(added.icon))
	assert_true(Themes.palette("futuristic").has(added.color))


func test_holding_the_plus_tile_offers_the_themes_and_a_tap_adds_a_set() -> void:
	_make_home(1)
	await wait_seconds(0.3)
	var before := _store.games.size()
	_home._on_add_held(_home._add_press)
	assert_true(_home._theme_drawer.is_open)
	_home._theme_drawer.close()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	_home._on_add_tile_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	_home._on_add_tile_input(up)
	assert_eq(_store.games.size(), before + 1, "a quick tap adds one")

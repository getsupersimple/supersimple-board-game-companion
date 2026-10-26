class_name Home
extends Control
## Home screen: one tile per game, with the built-in Quick game first.

signal game_selected(game_id: String)

const COLUMNS := 2
const NEW_GAME_COLORS: Array[Color] = [
	Color("#4F7CFF"), Color("#E5484D"), Color("#30A46C"), Color("#F5A524"), Color("#8E4EC6"),
]

var store: PresetStore

@onready var _grid: GridContainer = %Grid
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	_settings_button.icon = IconLibrary.get_icon("settings")
	_settings_button.accessibility_name = tr("HOME_SETTINGS")
	_grid.columns = COLUMNS
	for color_name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		_settings_button.add_theme_color_override(color_name, Color("#1C1C1E"))
	resized.connect(_update_tile_sizes)


func show_games(game_store: PresetStore) -> void:
	store = game_store
	for child in _grid.get_children():
		child.queue_free()
	for game in store.games:
		_add_game_tile(game)
	_add_new_game_tile()
	_update_tile_sizes()


func _add_game_tile(game: Game) -> void:
	var tile := _make_tile()
	tile.setup(game.icon, game.color, "HOME_QUICK_GAME" if game.id == PresetStore.QUICK_ID else "HOME_GAME")
	tile.pressed.connect(func() -> void: game_selected.emit(game.id))
	_grid.add_child(tile)


func _add_new_game_tile() -> void:
	var tile := _make_tile()
	tile.setup("plus", Color("#EDEDF2"), "HOME_ADD_GAME")
	tile.pressed.connect(_on_add_game_pressed)
	_grid.add_child(tile)


func _on_add_game_pressed() -> void:
	# Placeholder until the icon and color pickers exist.
	var index := store.games.size() - 1
	var icon_name := IconLibrary.GAME_ICONS[index % IconLibrary.GAME_ICONS.size()]
	var tile_color := NEW_GAME_COLORS[index % NEW_GAME_COLORS.size()]
	store.add_game(Game.create(icon_name, tile_color))
	show_games(store)


func _make_tile() -> GameTile:
	return GameTile.new()


## Keeps tiles square: a scroll container gives its children no height to
## derive a ratio from, so the size is set from the available width.
func _update_tile_sizes() -> void:
	var gap: int = _grid.get_theme_constant("h_separation")
	var margin: int = 48
	var side := (size.x - 2.0 * margin - gap * (COLUMNS - 1)) / COLUMNS
	for tile in _grid.get_children():
		(tile as Control).custom_minimum_size = Vector2(side, side)

extends Control
## Entry point. Owns the store and switches between the home and game screens.

var store: PresetStore

@onready var _home: Home = %Home
@onready var _game_screen: GameScreen = %GameScreen


func _ready() -> void:
	store = PresetStore.new()
	store.load_store()
	_home.show_games(store)
	_home.game_selected.connect(_on_game_selected)
	_game_screen.back_pressed.connect(_show_home)


func _on_game_selected(game_id: String) -> void:
	_game_screen.open_game(store, game_id)
	_home.visible = false
	_game_screen.visible = true


func _show_home() -> void:
	_game_screen.visible = false
	_home.visible = true

extends Control
## Entry point. Owns the store and switches between the home, game and settings
## screens.

var store: PresetStore

var _settings: SettingsScreen

@onready var _home: Home = %Home
@onready var _game_screen: GameScreen = %GameScreen


func _ready() -> void:
	AppSettings.load_settings()
	store = PresetStore.new()
	store.load_store()
	_home.show_games(store)
	_home.game_selected.connect(_on_game_selected)
	_home.settings_pressed.connect(_show_settings)
	_game_screen.back_pressed.connect(_show_home)
	_settings = SettingsScreen.new()
	_settings.visible = false
	_settings.back_pressed.connect(_show_home)
	add_child(_settings)


func _on_game_selected(game_id: String) -> void:
	_game_screen.open_game(store, game_id)
	_home.visible = false
	_game_screen.visible = true


func _show_settings() -> void:
	_game_screen.close_game()
	_home.visible = false
	_settings.visible = true


func _show_home() -> void:
	_game_screen.close_game()
	_game_screen.visible = false
	_settings.visible = false
	_home.visible = true

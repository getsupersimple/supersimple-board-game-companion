extends Control
## Entry point. Owns the store and shows the home screen.

var store: PresetStore

@onready var _home: Home = %Home


func _ready() -> void:
	store = PresetStore.new()
	store.load_store()
	_home.show_games(store)
	_home.game_selected.connect(_on_game_selected)


func _on_game_selected(game_id: String) -> void:
	# The game screen with its toolbar comes next.
	print("Selected game: ", game_id)

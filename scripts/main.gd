extends Control
## Entry point. Loads the store; the home screen of game tiles comes next.

var store: PresetStore


func _ready() -> void:
	store = PresetStore.new()
	store.load_store()

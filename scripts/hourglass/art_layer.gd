class_name ArtLayer
extends Node2D
## A layer of drawing that is made once and kept. The drawing is a function that
## is handed this node to draw on.

var draw_function: Callable


func _draw() -> void:
	if draw_function.is_valid():
		draw_function.call(self)

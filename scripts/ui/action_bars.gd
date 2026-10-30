class_name ActionBars
extends RefCounted
## Keeps one drawer open at a time. Every drawer, menu and picker that pops out of a button
## calls `opening` as it opens, and every other one in the tree is put away. Drawers that
## belong to one another, like a menu and the list it pops out, share a family and stay
## together.

const GROUP := &"action_bars"


## `bar` is about to open: close every open bar that is not of its family.
static func opening(bar: Control) -> void:
	if not bar.is_in_group(GROUP):
		bar.add_to_group(GROUP)
	if not bar.is_inside_tree():
		return
	var mine: Object = bar.get_meta("family", bar)
	for other in bar.get_tree().get_nodes_in_group(GROUP):
		if other == bar or other.get_meta("family", other) == mine:
			continue
		if other.get("is_open") == true:
			other.call("close")


## Makes these bars one family: opening one leaves the others as they are.
static func family(owner: Object, bars: Array) -> void:
	for bar in bars:
		bar.set_meta("family", owner)

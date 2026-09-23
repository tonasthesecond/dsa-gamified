extends Node
## Dev check for Content: looks up the placeholder rows and one missing id.
## godot --headless --path client res://dev/smoke_content.tscn

func _ready() -> void:
	for id: String in ["Goblin", "Wraith"]:
		var unit := Content.get_unit(id)
		print("unit %s: %s" % [id, unit.display_name if unit else "<no row>"])
	for id: String in ["attack", "drain"]:
		var move := Content.get_move(id)
		print("move %s: %s" % [id, move.display_name if move else "<no row>"])
	get_tree().quit()

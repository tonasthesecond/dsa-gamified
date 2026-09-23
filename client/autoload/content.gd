extends Node
## Autoload `Content`. Lookup tables for the things events refer to by id:
## unit kinds (a spawn's `name`) and moves (an action's `action`).
##
## Rows are added with register_unit / register_move in _ready below.
## A missing row is not an error: get_* returns null and the caller falls back.

var _units: Dictionary[String, UnitData] = {}
var _moves: Dictionary[String, MoveData] = {}


func _ready() -> void:
	# --- PLACEHOLDER: delete both rows once real content is registered. ---
	var placeholder_unit := UnitData.new()
	placeholder_unit.display_name = "PLACEHOLDER Goblin"
	register_unit("Goblin", placeholder_unit)

	var placeholder_move := MoveData.new()
	placeholder_move.display_name = "PLACEHOLDER Attack"
	placeholder_move.description = "Every combatant has it."
	placeholder_move.animation_key = &"placeholder_attack"
	register_move("attack", placeholder_move)
	# --- end PLACEHOLDER ---


func register_unit(id: String, data: UnitData) -> void:
	if _units.has(id):
		push_warning("Content: unit %s registered twice; keeping the second" % id)
	_units[id] = data


func get_unit(id: String) -> UnitData:
	return _units.get(id)


func register_move(id: String, data: MoveData) -> void:
	if _moves.has(id):
		push_warning("Content: move %s registered twice; keeping the second" % id)
	_moves[id] = data


func get_move(id: String) -> MoveData:
	return _moves.get(id)

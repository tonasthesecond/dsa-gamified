class_name Combatant
extends RefCounted
## One unit in one battle; everything that changes during a fight lives here.

var id: String
var unit: UnitDef
var side: int
## A copy, so changing it never touches the shared UnitDef.
var stats: Stats
var max_hp: int
var hp: int
var moves: Array[Move] = []
## Damage absorbed before hp, until this unit's next action.
var guard: int = 0
## {"move": Move, "targets": Array[Combatant]}, or empty.
var intent: Dictionary = {}
## What the UnitDef's body generated for this fight; empty without a body. Re-rolled after each crit.
var body_value: Dictionary = {}


func _init(p_id: String, p_unit: UnitDef, p_side: int, p_max_hp: int, shared_moves: Array[Move]) -> void:
	id = p_id
	unit = p_unit
	side = p_side
	stats = p_unit.stats.duplicate()
	max_hp = p_max_hp
	hp = p_max_hp
	moves.append_array(p_unit.moves)
	moves.append_array(shared_moves)


## Returns the UnitDef's name.
func display_name() -> String:
	return unit.name


## Returns true while hp is above 0.
func is_alive() -> bool:
	return hp > 0


## Returns the move with this id, or null.
func find_move(move_id: Variant) -> Move:
	for move in moves:
		if move.id == move_id:
			return move
	return null


## Generates a new body; does nothing, and draws nothing from `rng`, for a unit without one.
func reroll_body(rng: RandomNumberGenerator) -> void:
	if unit.body != null:
		body_value = unit.body.generate(rng)


## Returns the values in this unit's body, in the body's own order; empty without one.
func body_values() -> Array:
	return unit.body.values(body_value) if unit.body != null else []


## Returns the intent as a command, such as "attack knight", or null.
func intent_command() -> Variant:
	if intent.is_empty():
		return null
	return Combatant.command(intent.move, intent.targets)


## Returns a move and its targets as a command; a SELF move names no target.
static func command(move: Move, targets: Array) -> String:
	var words: Array[String] = [move.id]
	if move.target != Move.Target.SELF:
		for target: Combatant in targets:
			words.append(target.id)
	return " ".join(words)

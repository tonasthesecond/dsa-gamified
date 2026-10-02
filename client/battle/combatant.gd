class_name Combatant
extends RefCounted
## One unit in one battle: the part that changes. What it is lives in `unit`,
## a shared UnitDef that is never modified. Which side it fights for is `side`,
## an index into Battle.sides, set by whoever builds the battle.

var id: String
var unit: UnitDef
var side: int
## This battle's own copy of the unit's stats, so changing them mid-fight
## (a buff, a curse) never touches the shared UnitDef.
var stats: Stats
## The stats' hp plus whatever bonus the encounter rolled.
var max_hp: int
var hp: int
## The unit's own moves, then the battle's shared ones (pass).
var moves: Array[Move] = []
## Damage still to be absorbed before hp, from a guard. It lasts until this
## unit's next action.
var guard: int = 0
## What it telegraphed this turn, {"move": Move, "targets": Array[Combatant]};
## empty if nothing.
var intent: Dictionary = {}


func _init(p_id: String, p_unit: UnitDef, p_side: int, p_max_hp: int, shared_moves: Array[Move]) -> void:
	id = p_id
	unit = p_unit
	side = p_side
	stats = p_unit.stats.duplicate()
	max_hp = p_max_hp
	hp = p_max_hp
	moves.append_array(p_unit.moves)
	moves.append_array(shared_moves)


func display_name() -> String:
	return unit.name


func is_alive() -> bool:
	return hp > 0


## Null if this unit does not know that move.
func find_move(move_id: Variant) -> Move:
	for move in moves:
		if move.id == move_id:
			return move
	return null


## The intent as a command, in the form the student sends ("attack knight");
## null if none.
func intent_command() -> Variant:
	if intent.is_empty():
		return null
	return Combatant.command(intent.move, intent.targets)


## A move and its targets as a command: the move id, then each target's id. A
## SELF move names no target: "block".
static func command(move: Move, targets: Array) -> String:
	var words: Array[String] = [move.id]
	if move.target != Move.Target.SELF:
		for target: Combatant in targets:
			words.append(target.id)
	return " ".join(words)

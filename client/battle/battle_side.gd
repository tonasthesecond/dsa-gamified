class_name BattleSide
extends RefCounted
## One side of a battle: who is on it and who picks their actions.

## The `team` spawn events carry, such as "hero" or "enemy". Only a label for
## the log: nothing in the battle reads it.
var team: String
var controller: Controller
var combatants: Array[Combatant] = []


func _init(p_team: String, p_controller: Controller, p_combatants: Array[Combatant]) -> void:
	team = p_team
	controller = p_controller
	combatants = p_combatants

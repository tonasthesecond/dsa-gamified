class_name BattleSide
extends RefCounted
## One side of a battle: a team label, its controller and its combatants.

var team: String
var controller: Controller
var combatants: Array[Combatant] = []


func _init(p_team: String, p_controller: Controller, p_combatants: Array[Combatant]) -> void:
	team = p_team
	controller = p_controller
	combatants = p_combatants

class_name Controller
extends Resource
## Decides for one side's units. Holds no battle state, so it can be shared.


## Called once before turn 1: {}, {"error": message} or {"abort": ...}.
func begin(_battle: Battle) -> Dictionary:
	return {}


## Returns what the unit telegraphs, {"move": Move, "targets": [Combatant]}, or {}.
func plan(_battle: Battle, _unit: Combatant) -> Dictionary:
	return {}


## Returns {"action": {"move": id, "targets": [ids]}}, {"error": message} or {"abort": ...}.
func act(_battle: Battle, _unit: Combatant) -> Dictionary:
	return {"action": {"move": "pass", "targets": []}}


## Returns the error an illegal action ends the battle with, or "" to let it fizzle.
func refuse(_battle: Battle, _unit: Combatant, problem: String) -> String:
	return problem

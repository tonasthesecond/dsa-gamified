class_name TelegraphAI
extends Controller
## AI that telegraphs its first move at the first living opponent, then does it.


func plan(battle: Battle, unit: Combatant) -> Dictionary:
	var move: Move = unit.moves[0]
	var target := battle.first_living_opponent(unit) if move.target == Move.Target.ENEMY else unit
	return {"move": move, "targets": [target] as Array[Combatant]}


func act(_battle: Battle, unit: Combatant) -> Dictionary:
	var move: Move = unit.intent.move
	var ids: Array = []
	if move.target != Move.Target.SELF:
		ids = unit.intent.targets.map(func(t: Combatant) -> String: return t.id)
	return {"action": {"move": move.id, "targets": ids}}


## Its target died first; the move fizzles.
func refuse(_battle: Battle, _unit: Combatant, _problem: String) -> String:
	return ""

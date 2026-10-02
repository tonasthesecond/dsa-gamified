class_name TelegraphController
extends Controller
## A plain AI that shows its hand: each turn, every unit telegraphs its first
## move, at the first living opponent (or at itself, for a move that is not
## aimed at enemies), then does exactly that. Subclass and override plan for
## smarter telegraphing; act and refuse stay the same.


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


## Its target can die before its turn comes up. It still tried; nothing happens.
func refuse(_battle: Battle, _unit: Combatant, _problem: String) -> String:
	return ""

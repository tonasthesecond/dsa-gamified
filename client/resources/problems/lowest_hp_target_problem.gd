class_name LowestHpTargetProblem
extends Problem
## Right when the target has the least hp of the user's living opponents; ties all count.


func takes_answer() -> bool:
	return false


func is_correct(battle: Battle, user: Combatant, target: Combatant, _answer: Variant) -> bool:
	for unit in battle.turn_order():
		if unit.side != user.side and unit.hp < target.hp:
			return false
	return true

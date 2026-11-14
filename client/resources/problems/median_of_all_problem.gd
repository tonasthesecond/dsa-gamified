class_name MedianOfAllProblem
extends Problem
## The median of every value in the bodies of the user's living opponents; with an even count, the mean of the two middles.


func expected(battle: Battle, user: Combatant, _target: Combatant) -> Variant:
	var found: Array = []
	for unit in battle.turn_order():
		if unit.side != user.side:
			found.append_array(unit.body_values())
	if found.is_empty():
		return null
	found.sort()
	var half := found.size() / 2
	if found.size() % 2 == 1:
		return found[half]
	return (found[half - 1] + found[half]) / 2.0

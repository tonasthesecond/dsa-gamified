class_name MinIndexProblem
extends Problem
## The position of the smallest value in the target's body, counting from 0.


func expected(_battle: Battle, _user: Combatant, target: Combatant) -> Variant:
	var found := target.body_values()
	return found.find(found.min()) if not found.is_empty() else null

class_name MiddleValueProblem
extends Problem
## The value halfway along the target's body; with an even length, the second of the two middles, where a slow pointer stops when a fast one runs out.


func expected(_battle: Battle, _user: Combatant, target: Combatant) -> Variant:
	var found := target.body_values()
	return found[found.size() / 2] if not found.is_empty() else null

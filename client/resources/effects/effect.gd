class_name Effect
extends Resource
## One step of a move. Changes the battle only through Battle's primitives.


## Applies this step to a target already known to be legal.
func apply(_battle: Battle, _user: Combatant, _target: Combatant, _scratch: MoveScratch) -> void:
	pass

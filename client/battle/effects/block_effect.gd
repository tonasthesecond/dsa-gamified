class_name BlockEffect
extends Effect
## A guard: if the move bounces off this target, logs why and stops the rest of
## the move. Put it first in a move's effects and subclass it for the rule.


## Why this move bounces off this target, shown to the player; empty if it lands.
func reason(_battle: Battle, _user: Combatant, _target: Combatant) -> String:
	return ""


func apply(battle: Battle, user: Combatant, target: Combatant, scratch: MoveScratch) -> void:
	var why := reason(battle, user, target)
	if not why.is_empty():
		battle.block(target, why)
		scratch.halt()

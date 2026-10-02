class_name BlockEffect
extends Effect
## Stops the move on a target it bounces off; subclass reason() and put it first.


## Returns why the move bounces off this target, or "" if it lands.
func reason(_battle: Battle, _user: Combatant, _target: Combatant) -> String:
	return ""


func apply(battle: Battle, user: Combatant, target: Combatant, scratch: MoveScratch) -> void:
	var why := reason(battle, user, target)
	if not why.is_empty():
		battle.block(target, why)
		scratch.halt()

class_name BounceEffect
extends ImmunityEffect
## Always bounces, with a reason the level writes; a gate rule puts one in `when_wrong`.

@export var why: String = "The answer was wrong."


func reason(_battle: Battle, _user: Combatant, _target: Combatant) -> String:
	return why

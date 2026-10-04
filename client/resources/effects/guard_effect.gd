class_name GuardEffect
extends Effect
## Guards the target for `percent` of a user stat until its next action.

@export var stat: Stats.Stat = Stats.Stat.STRENGTH
@export var percent: int = 100


func apply(battle: Battle, user: Combatant, target: Combatant, _move_context: MoveContext) -> void:
	battle.guard(target, user.stats.scaled(stat, percent))

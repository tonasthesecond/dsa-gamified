class_name GuardEffect
extends Effect
## Guards the target: the next `percent` of the user's `stat` in damage it
## takes before its next action is absorbed. On a SELF move the target is the
## user, which is what block does.

@export var stat: Stats.Stat = Stats.Stat.STRENGTH
@export var percent: int = 100


func apply(battle: Battle, user: Combatant, target: Combatant, _scratch: MoveScratch) -> void:
	battle.guard(target, user.stats.scaled(stat, percent))

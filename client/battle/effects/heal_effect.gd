class_name HealEffect
extends Effect
## Heals the target, or the user, by `percent` of one of the user's stats; or
## by `percent` of a number an earlier effect of the same move left in the
## scratch (drain heals by 100% of MoveScratch.DAMAGE).

@export var stat: Stats.Stat = Stats.Stat.MAGIC
@export var percent: int = 100
## Heal the user instead of the target.
@export var on_user: bool = false
## A scratch key to take `percent` of instead of a stat; empty to use `stat`.
@export var from_scratch: String = ""


func apply(battle: Battle, user: Combatant, target: Combatant, scratch: MoveScratch) -> void:
	var base := user.stats.value(stat) if from_scratch.is_empty() else scratch.get_value(from_scratch)
	battle.heal(user if on_user else target, base * percent / 100)

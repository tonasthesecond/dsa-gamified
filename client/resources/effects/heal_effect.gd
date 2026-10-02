class_name HealEffect
extends Effect
## Heals by `percent` of a user stat, or of a scratch value when `from_scratch` is set.

@export var stat: Stats.Stat = Stats.Stat.MAGIC
@export var percent: int = 100
@export var on_user: bool = false
## A MoveScratch key, such as "damage" for drain.
@export var from_scratch: String = ""


func apply(battle: Battle, user: Combatant, target: Combatant, scratch: MoveScratch) -> void:
	var base := user.stats.value(stat) if from_scratch.is_empty() else scratch.get_value(from_scratch)
	battle.heal(user if on_user else target, base * percent / 100)

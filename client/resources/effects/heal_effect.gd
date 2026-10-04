class_name HealEffect
extends Effect
## Heals by `percent` of a user stat, or of a MoveContext value when `from_context` is set.

@export var stat: Stats.Stat = Stats.Stat.MAGIC
@export var percent: int = 100
@export var on_user: bool = false
## A MoveContext key, such as "damage" for drain.
@export var from_context: String = ""


func apply(battle: Battle, user: Combatant, target: Combatant, move_context: MoveContext) -> void:
	var base := user.stats.value(stat) if from_context.is_empty() else move_context.get_value(from_context)
	battle.heal(user if on_user else target, base * percent / 100)

class_name DamageEffect
extends Effect
## Hurts the target for `percent` of a user stat and records what landed.

@export var stat: Stats.Stat = Stats.Stat.STRENGTH
@export var percent: int = 100


func apply(battle: Battle, user: Combatant, target: Combatant, move_context: MoveContext) -> void:
	move_context.add(MoveContext.DAMAGE, battle.deal_damage(target, user.stats.scaled(stat, percent)))

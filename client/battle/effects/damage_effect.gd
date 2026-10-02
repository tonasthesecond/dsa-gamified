class_name DamageEffect
extends Effect
## Hurts the target for `percent` of one of the user's stats, and adds what
## actually landed to the scratch under MoveScratch.DAMAGE. The basic attack is
## 100% of strength.

@export var stat: Stats.Stat = Stats.Stat.STRENGTH
@export var percent: int = 100


func apply(battle: Battle, user: Combatant, target: Combatant, scratch: MoveScratch) -> void:
	scratch.add(MoveScratch.DAMAGE, battle.deal_damage(target, user.stats.scaled(stat, percent)))

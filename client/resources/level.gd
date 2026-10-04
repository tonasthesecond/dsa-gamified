class_name Level
extends Resource
## A battle as data: sides, seed and turn limit.

@export var rng_seed: int = 0
@export var max_turns: int = 20
@export var player_side: int = 0
## Moves every unit gets after its own, such as pass and block.
@export var shared_moves: Array[Move] = []
## Side order breaks speed ties.
@export var sides: Array[LevelSide] = []


## Builds a Battle ready to run; `context` is handed to the controllers.
func create_battle(context: Dictionary = {}) -> Battle:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var battle_sides: Array[BattleSide] = []
	for index in sides.size():
		var spec: LevelSide = sides[index]
		var units: Array[Combatant] = []
		for slot in spec.units:
			var max_hp := slot.unit.stats.hp
			if slot.bonus_max_hp > 0:
				max_hp += rng.randi_range(0, slot.bonus_max_hp)
			units.append(Combatant.new(slot.id, slot.unit, index, max_hp, shared_moves))
		battle_sides.append(BattleSide.new(spec.team, spec.controller, units))
	return Battle.new(battle_sides, player_side, max_turns, rng, context)

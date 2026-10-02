class_name Encounter
extends Resource
## A battle written down as data: the sides, who controls each, a seed and a
## turn limit. `create_battle` turns it into a Battle ready to run. Everything
## random comes from `rng_seed`, so the same code against the same encounter
## always plays out the same way.
##
## This is only one way to build a Battle; see battle.gd.

@export var rng_seed: int = 0
@export var max_turns: int = 20
## The side whose win or loss the result reports.
@export var player_side: int = 0
## Moves every unit gets after its own, such as pass.
@export var shared_moves: Array[Move] = []
## Who acts first is speed; between equally fast units, the earlier side.
@export var sides: Array[SideSpec] = []


## `context` is handed to the controllers, such as {"strategy": client}.
func create_battle(context: Dictionary = {}) -> Battle:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var battle_sides: Array[BattleSide] = []
	for index in sides.size():
		var spec: SideSpec = sides[index]
		var units: Array[Combatant] = []
		for slot in spec.units:
			var max_hp := slot.unit.stats.hp
			if slot.bonus_max_hp > 0:
				max_hp += rng.randi_range(0, slot.bonus_max_hp)
			units.append(Combatant.new(slot.id, slot.unit, index, max_hp, shared_moves))
		battle_sides.append(BattleSide.new(spec.team, spec.controller, units))
	return Battle.new(battle_sides, player_side, max_turns, rng, context)

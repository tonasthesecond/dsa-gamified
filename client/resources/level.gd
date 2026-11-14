class_name Level
extends Resource
## A battle as data: sides, seed and turn limit.

## Shown on the overworld and the battle screen.
@export var title: String = ""
## What the player reads before the first submit: the goal and what is new here.
@export_multiline var briefing: String = ""
## The code the editor opens with before the player has a draft, a .java in data/starters/; empty for CodePanel's.
@export_file("*.java") var starter_code: String = ""
@export var rng_seed: int = 0
@export var max_turns: int = 20
@export var player_side: int = 0
## Moves every unit gets after its own, such as pass and block.
@export var shared_moves: Array[Move] = []
## Side order breaks speed ties.
@export var sides: Array[LevelSide] = []
## Questions on top of the units' crits, judged on every move the player's side aims at an enemy.
@export var rules: Array[LevelRule] = []


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
			var unit := Combatant.new(slot.id, slot.unit, index, max_hp, shared_moves)
			unit.reroll_body(rng)
			units.append(unit)
		battle_sides.append(BattleSide.new(spec.team, spec.controller, units))
	var battle := Battle.new(battle_sides, player_side, max_turns, rng, context)
	battle.rules = rules
	return battle

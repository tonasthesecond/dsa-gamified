class_name Stats
extends Resource
## A unit's numbers. Moves never carry a number of their own to hurt or heal
## with: each effect names one of these and a percentage of it, so the same
## move hits harder in stronger hands.

enum Stat { HP, STRENGTH, MAGIC, SPEED }

## How each Stat is spelled in the state the student sees.
const NAMES: Array[String] = ["hp", "strength", "magic", "speed"]

## Maximum health.
@export var hp: int = 1
## What physical moves scale off.
@export var strength: int = 0
## What spells, heals and drains scale off.
@export var magic: int = 0
## Who acts first: the fastest living unit, every turn.
@export var speed: int = 0


func value(stat: Stat) -> int:
	match stat:
		Stat.HP:
			return hp
		Stat.STRENGTH:
			return strength
		Stat.MAGIC:
			return magic
		_:
			return speed


## `percent` of a stat, rounded down: 100 is the stat itself, 150 half again.
func scaled(stat: Stat, percent: int) -> int:
	return value(stat) * percent / 100

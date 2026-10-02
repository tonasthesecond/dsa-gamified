class_name Stats
extends Resource
## A unit's numbers; every effect scales off one of them.

enum Stat { HP, STRENGTH, MAGIC, SPEED }

const NAMES: Array[String] = ["hp", "strength", "magic", "speed"]

@export var hp: int = 1
@export var strength: int = 0
@export var magic: int = 0
## Higher acts first.
@export var speed: int = 0


## Returns the value of a stat.
func value(stat: Stat) -> int:
	return get(NAMES[stat])


## Returns `percent` of a stat, rounded down.
func scaled(stat: Stat, percent: int) -> int:
	return value(stat) * percent / 100

class_name UnitDef
extends Resource
## A kind of unit: name, stats and moves, with no side or controller.

## Shown to the student and in the log.
@export var name: String = ""
@export var stats: Stats
## TelegraphController uses the first.
@export var moves: Array[Move] = []

class_name UnitDef
extends Resource
## What a kind of unit is: stats and moves. Nothing here says which side it is
## on or who picks its actions; the battle assigns both.

## Shown to the student and in the log; the client looks up art by it.
@export var name: String = ""
## Its numbers: hp, strength, magic, speed. Every move scales off these.
@export var stats: Stats
## In the unit's own order. A default AI may care: TelegraphController uses the first.
@export var moves: Array[Move] = []

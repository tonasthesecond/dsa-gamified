class_name UnitDef
extends Resource
## A kind of unit: name, stats and moves, with no side or controller.

## Shown to the student and in the log.
@export var name: String = ""
@export var stats: Stats
## TelegraphController uses the first.
@export var moves: Array[Move] = []
## The data structure this kind of unit shows the student, or null for a plain unit.
@export var body: Body
## The question about the body whose right answer makes a hit on this unit a crit.
@export var crit: Problem

class_name LevelSide
extends Resource
## One side of a Level: a team label, a controller and its units.

@export var team: String = ""
@export var controller: Controller
@export var units: Array[LevelUnit] = []

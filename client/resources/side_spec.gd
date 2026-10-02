class_name SideSpec
extends Resource
## One side of an Encounter: a team label, a controller and its units.

@export var team: String = ""
@export var controller: Controller
@export var units: Array[UnitSlot] = []

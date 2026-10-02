class_name SideSpec
extends Resource
## One side of an Encounter: a label, who picks its actions, and its units.

## Only a label for the log's spawn events, such as "hero" or "enemy".
@export var team: String = ""
@export var controller: Controller
@export var units: Array[UnitSlot] = []

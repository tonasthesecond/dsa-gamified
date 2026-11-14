class_name Move
extends Resource
## Something a unit can do on its turn: an id and a list of effects.

enum Target { ENEMY, ALLY, SELF }

const TARGET_NAMES: Array[String] = ["enemy", "ally", "self"]

## The first word of a student's command and the `move` on its events; never rename.
@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var target: Target = Target.ENEMY
@export var max_targets: int = 1
## Run in order, once per target.
@export var effects: Array[Effect] = []
## Run after `effects` on a target whose crit the student answered right; empty means this move never crits.
@export var crit_effects: Array[Effect] = []


## Returns how many ids may follow the move in a command: 0 for a SELF move.
func target_count() -> int:
	return 0 if target == Target.SELF else max_targets

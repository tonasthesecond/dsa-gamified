class_name Move
extends Resource
## Something a unit can do on its turn: an id, a name and an ordered list of
## effects. Every unit's moves are these, the basic attack and pass included,
## so the battle has no per-move branches. A new move is a new list of existing
## effects; only a new mechanic needs a new Effect.

## Who the move may be used on, relative to the side of whoever uses it.
enum Target { ENEMY, ALLY, SELF }

## How Target is spelled in the state the student sees.
const TARGET_NAMES: Array[String] = ["enemy", "ally", "self"]

## Stable: the first word of the command a student sends ("attack e1"), and
## the `move` of every event this move causes. Pick it once.
@export var id: String = ""
@export var name: String = ""
## Shown to the student: what the move does, in words.
@export_multiline var description: String = ""
@export var target: Target = Target.ENEMY
## How many targets one use may name, at least one. Effects run once per
## target, in the order named. A SELF move takes none and ignores this.
@export var max_targets: int = 1
## Run in order by Battle.use, once per target. Empty for a move that does nothing.
@export var effects: Array[Effect] = []


## How many ids may follow the move in a command: 0 for a SELF move.
func target_count() -> int:
	return 0 if target == Target.SELF else max_targets

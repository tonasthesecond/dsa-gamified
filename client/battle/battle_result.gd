class_name BattleResult
extends RefCounted
## How one battle went, and every event of it.

## Whether the player's side won.
var won: bool = false
## Why it ended, for the player. Repeats `error` when there is one.
var reason: String = ""
## Non-empty only when a controller's decider misbehaved, such as the
## student's code throwing or making an illegal move.
var error: String = ""
var events: Array[Dictionary] = []
## Non-empty when the battle could not be finished at all, such as the compile
## service going away: whatever the controller reported. Nothing else is
## meaningful then.
var abort: Dictionary = {}


## The battle as the envelope's `result`: {won, reason, error, events}.
func to_dict() -> Dictionary:
	return {"won": won, "reason": reason, "error": error, "events": events}

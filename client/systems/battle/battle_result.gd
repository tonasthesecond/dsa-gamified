class_name BattleResult
extends RefCounted
## How a battle ended, and its events.

var won: bool = false
var reason: String = ""
## Set when a decider misbehaved; repeated in `reason`.
var error: String = ""
var events: Array[Dictionary] = []
## Set when the battle could not finish at all, such as the server going away.
var abort: Dictionary = {}


## Returns the envelope's `result`: {won, reason, error, events}.
func to_dict() -> Dictionary:
	return {"won": won, "reason": reason, "error": error, "events": events}

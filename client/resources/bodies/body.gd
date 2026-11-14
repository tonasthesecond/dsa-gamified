class_name Body
extends Resource
## A data structure a kind of unit carries; the student reads it in the state and answers questions about it.


## Returns a fresh structure as JSON-like data, drawn only from `rng` so a battle replays the same.
func generate(_rng: RandomNumberGenerator) -> Dictionary:
	return {}


## Returns every value the structure holds, for questions that look across bodies, such as a median of all.
func values(_body: Dictionary) -> Array:
	return []

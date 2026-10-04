class_name MoveContext
extends RefCounted
## Values shared by the effects of one use of a move on one target.

const DAMAGE := "damage"

var halted: bool = false
var _values: Dictionary[String, int] = {}


## Returns a value, 0 if nothing wrote it.
func get_value(key: String) -> int:
	return _values.get(key, 0)


## Adds to a value.
func add(key: String, amount: int) -> void:
	_values[key] = get_value(key) + amount


## Stops the rest of the move's effects.
func halt() -> void:
	halted = true

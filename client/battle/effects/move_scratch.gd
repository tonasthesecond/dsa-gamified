class_name MoveScratch
extends RefCounted
## Scratch for one use of one move: made when the move starts, dropped when it
## ends. Lets a later effect read what an earlier one did, such as a heal sized
## off the damage that just landed. Never logged, never shown to the student.

## Written by DamageEffect: the health it actually took off, summed.
const DAMAGE := "damage"

var halted: bool = false
var _values: Dictionary[String, int] = {}


## 0 if no effect has written this key yet.
func get_value(key: String) -> int:
	return _values.get(key, 0)


func add(key: String, amount: int) -> void:
	_values[key] = get_value(key) + amount


## Stops the move: none of its later effects run.
func halt() -> void:
	halted = true

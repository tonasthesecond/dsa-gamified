class_name Problem
extends Resource
## A question Godot can answer itself; a unit's kind uses one for crits, a level for its rules.

## What the student's code reads to tell problems apart, such as "middle".
@export var id: String = ""
@export_multiline var description: String = ""


## Returns the right answer for a move by `user` on `target`, or null when there is none to give.
func expected(_battle: Battle, _user: Combatant, _target: Combatant) -> Variant:
	return null


## Returns false for a problem judged from the move alone, so the student sends no answer for it.
func takes_answer() -> bool:
	return true


## Returns true when `answer` is right. Whole numbers match whether they arrive as 2 or 2.0.
func is_correct(battle: Battle, user: Combatant, target: Combatant, answer: Variant) -> bool:
	var right: Variant = expected(battle, user, target)
	if answer == null or right == null:
		return false
	return typeof(normalized(answer)) == typeof(normalized(right)) and normalized(answer) == normalized(right)


## Returns a JSON value with every whole float as an int, since JSON parsing makes every number a float.
static func normalized(value: Variant) -> Variant:
	if value is float and value == floorf(value):
		return int(value)
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = normalized(value[key])
		return out
	if value is Array:
		var out := []
		for item: Variant in value:
			out.append(normalized(item))
		return out
	return value

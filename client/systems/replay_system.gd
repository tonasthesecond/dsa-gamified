class_name ReplaySystem
extends Node
## Replays a battle's envelope one event at a time, out through signals.

signal battle_loaded
## The envelope was not a battle; `line` is the compiler's Submission.java line, or -1.
signal submission_failed(message: String, line: int)
signal battle_reset
signal spawned(event: Dictionary)
signal intent(event: Dictionary)
signal action(event: Dictionary)
signal died(event: Dictionary)
signal ended(won: bool, reason: String)
## Any event a move caused (it carries `move`): damage, heal, blocked, guard, or a new one.
signal effect_applied(event: Dictionary)
## A new event type without `move`; replay carries on.
signal unknown_event(event: Dictionary)

const _COMPILER_LINE := "Submission\\.java:(\\d+):"

var envelope: Dictionary = {}
var cursor: int = 0
var turn: int = 0

var _events: Array = []
var _units: Dictionary = {}  # unit id -> {name, team, hp, max_hp, alive}
var _unit_order: Array[String] = []


## Loads an envelope from BattleRunner and resets to the start.
func load_battle(new_envelope: Dictionary) -> void:
	envelope = _whole_numbers_to_int(new_envelope)
	_events = []
	_clear_state()
	if envelope.get("status") != "ok":
		var message := str(envelope.get("message", ""))
		submission_failed.emit(message, _compiler_line(message))
		return
	var result: Variant = envelope.get("result")
	if not result is Dictionary or not result.get("events") is Array:
		submission_failed.emit("status ok without a battle", -1)
		return
	_events = result.events
	battle_loaded.emit()
	reset()


## Applies the next event; returns false once the battle is over.
func step() -> bool:
	if is_finished():
		return false
	var event: Dictionary = _events[cursor]
	cursor += 1
	turn = event.turn
	match event.type:
		"spawn":
			_units[event.unit] = {
				"name": event.name, "team": event.team,
				"hp": event.hp, "max_hp": event.maxHp, "alive": true,
			}
			_unit_order.append(event.unit)
			spawned.emit(event)
		"intent":
			intent.emit(event)
		"action":
			action.emit(event)
		"death":
			_units[event.unit].alive = false
			died.emit(event)
		"end":
			ended.emit(event.won, event.reason)
		_ when event.has("move"):
			if event.has("hp"):
				_units[event.unit].hp = event.hp
			effect_applied.emit(event)
		_:
			unknown_event.emit(event)
	return true


## Applies every remaining event.
func skip_to_end() -> void:
	while step():
		pass


## Goes back to before the first event.
func reset() -> void:
	_clear_state()
	battle_reset.emit()


## Returns true when every event is applied.
func is_finished() -> bool:
	return cursor >= _events.size()


## Returns the ids spawned so far.
func unit_ids() -> Array[String]:
	return _unit_order.duplicate()


## Returns {name, team, hp, max_hp, alive} for a unit.
func unit_state(id: String) -> Dictionary:
	return _units.get(id, {}).duplicate()


func _clear_state() -> void:
	cursor = 0
	turn = 0
	_units.clear()
	_unit_order.clear()


static func _compiler_line(message: String) -> int:
	var regex := RegEx.create_from_string(_COMPILER_LINE)
	var found := regex.search(message)
	return int(found.get_string(1)) if found else -1


# JSON parses every number as a float; every number in the log is an int.
static func _whole_numbers_to_int(value: Variant) -> Variant:
	if value is float and value == floorf(value):
		return int(value)
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = _whole_numbers_to_int(value[key])
		return out
	if value is Array:
		var out := []
		for item: Variant in value:
			out.append(_whole_numbers_to_int(item))
		return out
	return value

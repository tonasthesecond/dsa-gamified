class_name Simulation
extends Node
## Replays one battle's envelope, one event at a time.
##
## State is derived only from the events up to the cursor: no timers, no tweens,
## no references to other nodes. Everything leaves through signals, so whatever
## listens (Presentation today) can be replaced without touching this file.
## The event format is server/docs/protocol.md.

## The envelope had status "ok"; the battle is loaded and reset.
signal battle_loaded

## The envelope never became a battle: compile error, timeout, bad request.
## `line` is the Submission.java line the compiler pointed at, or -1.
signal submission_failed(message: String, line: int)
## The cursor went back to 0; listeners clear their state.
signal battle_reset

# Battle structure: one signal per event `type`, each carrying the raw event.
# `intent` and `action` events carry `move`, the id of the move coming or used.
signal spawned(event: Dictionary)  # spawn
signal intent(event: Dictionary)  # intent
signal action(event: Dictionary)  # action
signal died(event: Dictionary)  # death
signal ended(won: bool, reason: String)  # end
## What a move did: every event that carries `move` and is not an intent or an
## action, such as `damage`, `heal` or `blocked`. Listeners dispatch on
## `event.type` or `event.move`. A new effect on the server arrives here with
## no change to this file; if one ever needs a change here, that is a bug.
signal effect_applied(event: Dictionary)
## An event with no `move` whose `type` this file does not know. That is a new
## structural primitive on the server, never a new effect: anything a move
## causes carries `move` and goes to effect_applied. Replay carries on past it.
signal unknown_event(event: Dictionary)

const _COMPILER_LINE := "Submission\\.java:(\\d+):"

var envelope: Dictionary = {}
## Number of events applied so far.
var cursor: int = 0
## `turn` of the last applied event; 0 during spawns.
var turn: int = 0

var _events: Array = []
var _units: Dictionary = {}  # unit id -> {name, team, hp, max_hp, alive}
var _unit_order: Array[String] = []


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


## Applies the next event and emits its signal. False once the battle is over.
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
			# Effect output. The only state an effect can change is hp.
			if event.has("hp"):
				_units[event.unit].hp = event.hp
			effect_applied.emit(event)
		_:
			unknown_event.emit(event)
	return true


func skip_to_end() -> void:
	while step():
		pass


func reset() -> void:
	_clear_state()
	battle_reset.emit()


func is_finished() -> bool:
	return cursor >= _events.size()


## The battle as sent: {won, reason, error, events}; empty if none is loaded.
func battle() -> Dictionary:
	var result: Variant = envelope.get("result")
	return result if result is Dictionary else {}


## Unit ids in spawn order, as far as the cursor has got.
func unit_ids() -> Array[String]:
	return _unit_order.duplicate()


## {name, team, hp, max_hp, alive} for a spawned unit; a copy.
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


## JSON.parse_string makes every number a float; every number in the protocol
## is an integer, so turn them back into ints once, here.
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

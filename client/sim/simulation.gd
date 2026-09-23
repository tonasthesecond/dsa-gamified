class_name Simulation
extends Node
## Replays one envelope from the compile service, one event at a time.
##
## State is derived only from the events up to the cursor: no timers, no tweens,
## no references to other nodes. Everything leaves through signals, so whatever
## listens (Presentation today) can be replaced without touching this file.
## The event format is server/docs/protocol.md.

## The envelope had status "ok"; scenario 0 is selected and reset.
signal battle_loaded(scenario_count: int)
## The envelope never became a battle: compile error, timeout, bad request.
## `line` is the Submission.java line the compiler pointed at, or -1.
signal submission_failed(message: String, line: int)
## The cursor went back to 0 on scenario `index`; listeners clear their state.
signal scenario_reset(index: int)

# One signal per event `type` in protocol.md, each carrying the raw event.
signal spawned(event: Dictionary)  # spawn
signal intent(event: Dictionary)  # intent
signal action(event: Dictionary)  # action
signal blocked(event: Dictionary)  # blocked
signal damaged(event: Dictionary)  # damage
signal healed(event: Dictionary)  # heal
signal died(event: Dictionary)  # death
signal ended(won: bool, reason: String)  # end
## An event type this client does not know yet. The server may add types;
## replay carries on past it.
signal unknown_event(event: Dictionary)

const _COMPILER_LINE := "Submission\\.java:(\\d+):"

var envelope: Dictionary = {}
var scenario_index: int = -1
## Number of events applied so far in the current scenario.
var cursor: int = 0
## `turn` of the last applied event; 0 during spawns.
var turn: int = 0

var _events: Array = []
var _units: Dictionary = {}  # unit id -> {name, team, hp, max_hp, alive}
var _unit_order: Array[String] = []


func load_battle(new_envelope: Dictionary) -> void:
	envelope = _whole_numbers_to_int(new_envelope)
	scenario_index = -1
	_events = []
	_clear_state()
	if envelope.get("status") != "ok":
		var message := str(envelope.get("message", ""))
		submission_failed.emit(message, _compiler_line(message))
		return
	var result: Variant = envelope.get("result")
	if not result is Dictionary or not result.get("scenarios") is Array or result.scenarios.is_empty():
		submission_failed.emit("server sent status ok without any scenarios", -1)
		return
	battle_loaded.emit(scenario_count())
	select_scenario(0)


func select_scenario(index: int) -> void:
	assert(index >= 0 and index < scenario_count(), "no scenario %d" % index)
	scenario_index = index
	_events = current_scenario().events
	reset()


## Applies the next event and emits its signal. False once the scenario is over.
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
		"blocked":
			blocked.emit(event)
		"damage":
			_units[event.unit].hp = event.hp
			damaged.emit(event)
		"heal":
			_units[event.unit].hp = event.hp
			healed.emit(event)
		"death":
			_units[event.unit].alive = false
			died.emit(event)
		"end":
			ended.emit(event.won, event.reason)
		_:
			unknown_event.emit(event)
	return true


func skip_to_end() -> void:
	while step():
		pass


func reset() -> void:
	_clear_state()
	scenario_reset.emit(scenario_index)


func is_finished() -> bool:
	return cursor >= _events.size()


func scenario_count() -> int:
	var result: Variant = envelope.get("result")
	return result.scenarios.size() if result is Dictionary else 0


## The current scenario as sent: {seed, won, reason, error, events}.
func current_scenario() -> Dictionary:
	return envelope.result.scenarios[scenario_index] if scenario_index >= 0 else {}


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

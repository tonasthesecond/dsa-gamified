class_name ScriptedStrategyClient
extends StrategyClient
## A student written in GDScript, for testing battles without the compile
## service. `decide_fn` takes the state and returns the whole reply, such as
## {"action": "pass"} or {"error": {"kind": "threw", ...}}.

var _decide_fn: Callable
var _start_reply: Dictionary


func _init(decide_fn: Callable, start_reply: Dictionary = {"error": null}) -> void:
	_decide_fn = decide_fn
	_start_reply = start_reply


func start() -> Dictionary:
	return _start_reply


func decide(state: Dictionary) -> Dictionary:
	# A copy, as the wire would give: the student cannot reach into the battle.
	var reply: Dictionary = _decide_fn.call(state.duplicate(true))
	if not reply.has("error"):
		reply.error = null
	return reply

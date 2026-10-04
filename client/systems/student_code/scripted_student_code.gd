class_name ScriptedStudentCode
extends StudentCode
## A student written in GDScript, for tests: `decide_fn(state)` returns the whole reply.

var _decide_fn: Callable
var _start_reply: Dictionary


func _init(decide_fn: Callable, start_reply: Dictionary = {"error": null}) -> void:
	_decide_fn = decide_fn
	_start_reply = start_reply


func start() -> Dictionary:
	return _start_reply


func decide(state: Dictionary) -> Dictionary:
	var reply: Dictionary = _decide_fn.call(state.duplicate(true))
	if not reply.has("error"):
		reply.error = null
	return reply

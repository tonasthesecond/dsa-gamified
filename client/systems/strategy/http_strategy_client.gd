class_name HttpStrategyClient
extends StrategyClient
## The student's code on the compile service: /start per battle, /decide per call.

## Added to the per-call timeout for the round trip.
const SLACK_MS := 5000

var _connection: RunnerConnection
var _build: String
var _timeout_ms: int
var _instance: String = ""


func _init(connection: RunnerConnection, build: String, timeout_ms: int) -> void:
	_connection = connection
	_build = build
	_timeout_ms = timeout_ms


func start() -> Dictionary:
	var reply := _call("/start?build=%s&timeout_ms=%d" % [_build.uri_encode(), _timeout_ms], "")
	if reply.has("abort"):
		return reply
	_instance = reply.instance
	return {"error": reply.error}


func decide(state: Dictionary) -> Dictionary:
	var reply := _call("/decide?instance=%s" % _instance.uri_encode(), JSON.stringify(state, "", false))
	if reply.has("abort"):
		return reply
	return {"action": reply.action, "error": reply.error}


func _call(path: String, body: String) -> Dictionary:
	var reply := _connection.post(path, body, _timeout_ms + SLACK_MS)
	if reply.has("transport"):
		return {"abort": reply.transport, "transport": true}
	if reply.get("status") != "ok":
		return {"abort": "%s: %s" % [reply.get("status"), reply.get("message")]}
	console += str(reply.get("console", ""))
	return reply

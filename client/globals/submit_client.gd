extends Node
## Compiles a submission, plays a level against it on a worker thread, and emits the log.

## {status, message, console, result}; `result` is null unless status is "ok".
signal result_ready(envelope: Dictionary)
## The server could not be reached or answered nonsense.
signal submit_failed(reason: String)

const LEVELS_DIR := "res://data/levels/"
const MAX_CONSOLE_CHARS := 4000

var _thread: Thread


## Plays data/levels/<level>.tres against `source`; ignored while one is running.
func submit(source: String, level: String) -> void:
	if _thread != null:
		return
	var encounter := load(LEVELS_DIR + level + ".tres") as Encounter
	if encounter == null:
		_fail.call_deferred("no level %s in %s" % [level, LEVELS_DIR])
		return
	var settings := Config.settings
	_thread = Thread.new()
	_thread.start(_play.bind(source, encounter, settings.server_url,
		int(settings.timeout_sec * 1000), settings.decide_timeout_ms))


# Worker thread.
func _play(source: String, encounter: Encounter, server_url: String,
		build_timeout_ms: int, decide_timeout_ms: int) -> void:
	var connection := RunnerConnection.new(server_url)
	var outcome := _build_and_run(connection, source, encounter, build_timeout_ms, decide_timeout_ms)
	connection.close()
	_finish.call_deferred(outcome)


func _build_and_run(connection: RunnerConnection, source: String, encounter: Encounter,
		build_timeout_ms: int, decide_timeout_ms: int) -> Dictionary:
	var built := connection.post("/build", source, build_timeout_ms)
	if built.has("transport"):
		return built
	if built.get("status") != "ok":
		return {"envelope": _envelope(built.get("status"), built.get("message", ""), "", null)}

	var client := HttpStrategyClient.new(connection, built.build, decide_timeout_ms)
	var result := encounter.create_battle({StudentController.CONTEXT_KEY: client}).run()
	connection.post("/close?build=%s" % str(built.build).uri_encode(), "", 5000)

	if not result.abort.is_empty():
		if result.abort.get("transport", false):
			return {"transport": result.abort.abort}
		return {"envelope": _envelope("runtime_error", str(result.abort.abort), client.console, null)}
	return {"envelope": _envelope("ok", "", client.console, result.to_dict())}


func _envelope(status: String, message: String, console: String, result: Variant) -> Dictionary:
	var trimmed := console.strip_edges()
	if trimmed.length() > MAX_CONSOLE_CHARS:
		trimmed = trimmed.substr(0, MAX_CONSOLE_CHARS) + "\n... [output truncated]"
	return {"status": status, "message": message, "console": trimmed, "result": result}


func _finish(outcome: Dictionary) -> void:
	_thread.wait_to_finish()
	_thread = null
	if outcome.has("transport"):
		_fail(outcome.transport)
	else:
		result_ready.emit(outcome.envelope)


func _fail(reason: String) -> void:
	submit_failed.emit(reason)

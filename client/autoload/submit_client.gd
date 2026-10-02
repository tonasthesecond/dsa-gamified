extends Node
## Autoload `SubmitClient`. Compiles a Submission.java on the compile service,
## plays the whole battle against it, and hands the finished log over.
##
## The battle runs on a worker thread before anything is shown: every time a
## student unit acts, the thread asks the compiled code over HTTP and waits.
## The finished envelope, {status, message, console, result}, is emitted on the
## main thread. Simulation reads `status`; a compile error is a result too.

## {status, message, console, result}; `result` is BattleResult.to_dict(), or
## null when status is not "ok".
signal result_ready(envelope: Dictionary)
## No envelope could be made: server unreachable, timeout, bad response.
signal submit_failed(reason: String)

const LEVELS_DIR := "res://levels/"
const MAX_CONSOLE_CHARS := 4000

var _thread: Thread


## Plays the encounter res://levels/<level>.tres against `source`. Ignored
## while a submission is still running.
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


## Runs on the worker thread, and hands _finish {"envelope": ...} or
## {"transport": reason} on the main thread.
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

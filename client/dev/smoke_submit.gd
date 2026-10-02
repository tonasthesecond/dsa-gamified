extends Node
## Dev check for SubmitClient against the configured server: plays smoke with
## dev/fixtures/Submission.java and demo with dev/fixtures/demo_win.java,
## prints how each went, quits. Needs the server running.
## godot --headless --path client res://dev/smoke_submit.tscn
##
## With --record after --, also writes the envelopes to dev/fixtures/smoke.json
## and dev/fixtures/demo.json, the fixtures the other dev checks replay:
## godot --headless --path client res://dev/smoke_submit.tscn -- --record

const CASES := [
	["smoke", "res://dev/fixtures/Submission.java", "res://dev/fixtures/smoke.json"],
	["demo", "res://dev/fixtures/demo_win.java", "res://dev/fixtures/demo.json"],
]


func _ready() -> void:
	var record := "--record" in OS.get_cmdline_user_args()
	for case: Array in CASES:
		var started := Time.get_ticks_msec()
		SubmitClient.submit(FileAccess.get_file_as_string(case[1]), case[0])
		var outcome: Array = await _next_outcome()
		var took := Time.get_ticks_msec() - started
		if outcome[0] == "failed":
			print("%s: submit_failed: %s" % [case[0], outcome[1]])
			continue
		var envelope: Dictionary = outcome[1]
		var result: Variant = envelope.result
		print("%s: status=%s message=%s won=%s events=%d, %d ms including the compile" % [
			case[0], envelope.status, envelope.message,
			result.won if result else "-", result.events.size() if result else 0, took])
		if record and envelope.status == "ok":
			var file := FileAccess.open(case[2], FileAccess.WRITE)
			file.store_string(JSON.stringify(envelope, "", false) + "\n")
			print("  recorded ", case[2])
	get_tree().quit()


func _next_outcome() -> Array:
	var outcome: Array = []
	var on_result := func(envelope: Dictionary) -> void: outcome.assign(["ok", envelope])
	var on_fail := func(reason: String) -> void: outcome.assign(["failed", reason])
	SubmitClient.result_ready.connect(on_result, CONNECT_ONE_SHOT)
	SubmitClient.submit_failed.connect(on_fail, CONNECT_ONE_SHOT)
	while outcome.is_empty():
		await get_tree().process_frame
	if SubmitClient.result_ready.is_connected(on_result):
		SubmitClient.result_ready.disconnect(on_result)
	if SubmitClient.submit_failed.is_connected(on_fail):
		SubmitClient.submit_failed.disconnect(on_fail)
	return outcome

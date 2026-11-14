extends Node
## Plays the fixture submissions and every level's starter code through the server; `-- --record` rewrites the fixtures. Exits 1 if a starter does not build and play.

const CASES := [
	["smoke", "res://tests/fixtures/Submission.java", "res://tests/fixtures/smoke.json"],
	["demo", "res://tests/fixtures/demo_win.java", "res://tests/fixtures/demo.json"],
	["worm_test", "res://tests/fixtures/worm_crit.java", "res://tests/fixtures/worm_test.json"],
	["camp", "res://tests/fixtures/campaign.java", "res://tests/fixtures/camp.json"],
	["burrow", "res://tests/fixtures/campaign.java", "res://tests/fixtures/burrow.json"],
	["nest", "res://tests/fixtures/campaign.java", "res://tests/fixtures/nest.json"],
	["pecking_order", "res://tests/fixtures/campaign.java", "res://tests/fixtures/pecking_order.json"],
	["gatehouse", "res://tests/fixtures/campaign.java", "res://tests/fixtures/gatehouse.json"],
]


func _ready() -> void:
	var record := "--record" in OS.get_cmdline_user_args()
	for case: Array in CASES:
		var started := Time.get_ticks_msec()
		BattleRunner.submit(FileAccess.get_file_as_string(case[1]), case[0])
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
	var failures := await _starters()
	get_tree().quit(1 if failures > 0 else 0)


## Every campaign starter compiles and plays with no error, and Goblin Camp's wins as its briefing says.
func _starters() -> int:
	var failures := 0
	var campaign: Campaign = load("res://data/campaign.tres")
	for stage in campaign.stages:
		var spec: Level = load("res://data/levels/%s.tres" % stage.level)
		BattleRunner.submit(FileAccess.get_file_as_string(spec.starter_code), stage.level)
		var outcome: Array = await _next_outcome()
		var envelope: Dictionary = outcome[1] if outcome[0] == "ok" else {}
		var result: Variant = envelope.get("result")
		var fine: bool = envelope.get("status") == "ok" and result != null and result.error == "" \
			and (stage.level != "camp" or result.won)
		print("%s starter: %s" % [stage.level, "ok, won=%s in %s" % [result.won, result.reason] if fine
			else "FAIL: %s" % (outcome[1] if outcome[0] == "failed" else envelope)])
		if not fine:
			failures += 1
	return failures


func _next_outcome() -> Array:
	var outcome: Array = []
	var on_result := func(envelope: Dictionary) -> void: outcome.assign(["ok", envelope])
	var on_fail := func(reason: String) -> void: outcome.assign(["failed", reason])
	BattleRunner.result_ready.connect(on_result, CONNECT_ONE_SHOT)
	BattleRunner.submit_failed.connect(on_fail, CONNECT_ONE_SHOT)
	while outcome.is_empty():
		await get_tree().process_frame
	if BattleRunner.result_ready.is_connected(on_result):
		BattleRunner.result_ready.disconnect(on_result)
	if BattleRunner.submit_failed.is_connected(on_fail):
		BattleRunner.submit_failed.disconnect(on_fail)
	return outcome

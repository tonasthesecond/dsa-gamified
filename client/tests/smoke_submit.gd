extends Node
## Plays the fixture submissions through the server; `-- --record` rewrites the fixtures.

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
	get_tree().quit()


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

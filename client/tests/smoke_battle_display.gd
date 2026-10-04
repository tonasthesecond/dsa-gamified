extends Node
## Replays the smoke fixture into BattleDisplay.

func _ready() -> void:
	var replay: ReplaySystem = $ReplaySystem
	($BattleDisplay as BattleDisplay).listen_to(replay)
	replay.load_battle(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/smoke.json")))
	replay.skip_to_end()
	get_tree().quit()

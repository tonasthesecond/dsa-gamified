extends Node
## Replays the smoke fixture into Presentation.

func _ready() -> void:
	var sim: Simulation = $Simulation
	($Presentation as Presentation).listen_to(sim)
	sim.load_battle(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/smoke.json")))
	sim.skip_to_end()
	get_tree().quit()

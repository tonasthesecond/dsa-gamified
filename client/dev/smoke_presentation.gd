extends Node
## Dev check for Presentation: replays the smoke fixture into it. No server needed.
## godot --headless --path client res://dev/smoke_presentation.tscn

func _ready() -> void:
	var sim: Simulation = $Simulation
	($Presentation as Presentation).listen_to(sim)
	sim.load_battle(JSON.parse_string(FileAccess.get_file_as_string("res://dev/fixtures/smoke_win.json")))
	sim.skip_to_end()
	get_tree().quit()

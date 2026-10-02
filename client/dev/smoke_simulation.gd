extends Node
## Dev check for Simulation: replays the fixture envelopes and prints every
## signal plus the final unit state. No server needed.
## godot --headless --path client res://dev/smoke_simulation.tscn

const FIXTURES := ["res://dev/fixtures/demo.json", "res://dev/fixtures/compile_error.json"]

@onready var sim: Simulation = $Simulation


func _ready() -> void:
	for info: Dictionary in sim.get_script().get_script_signal_list():
		var signal_name: String = info.name
		sim.connect(signal_name, func(a: Variant = null, b: Variant = null) -> void:
			print("%s: %s" % [signal_name, a if b == null else [a, b]]))
	for path: String in FIXTURES:
		print("--- ", path)
		sim.load_battle(JSON.parse_string(FileAccess.get_file_as_string(path)))
		sim.skip_to_end()
		for id in sim.unit_ids():
			print("  %s %s" % [id, sim.unit_state(id)])
	get_tree().quit()

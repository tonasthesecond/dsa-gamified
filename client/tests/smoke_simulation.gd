extends Node
## Replays the fixtures through Simulation and prints every signal.

const FIXTURES := ["res://tests/fixtures/demo.json", "res://tests/fixtures/compile_error.json"]

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

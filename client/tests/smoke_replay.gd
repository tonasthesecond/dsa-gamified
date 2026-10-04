extends Node
## Replays the fixtures through ReplaySystem and prints every signal.

const FIXTURES := ["res://tests/fixtures/demo.json", "res://tests/fixtures/compile_error.json"]

@onready var replay: ReplaySystem = $ReplaySystem


func _ready() -> void:
	for info: Dictionary in replay.get_script().get_script_signal_list():
		var signal_name: String = info.name
		replay.connect(signal_name, func(a: Variant = null, b: Variant = null) -> void:
			print("%s: %s" % [signal_name, a if b == null else [a, b]]))
	for path: String in FIXTURES:
		print("--- ", path)
		replay.load_battle(JSON.parse_string(FileAccess.get_file_as_string(path)))
		replay.skip_to_end()
		for id in replay.unit_ids():
			print("  %s %s" % [id, replay.unit_state(id)])
	get_tree().quit()

class_name BattleController
extends Control
## Wires SubmitClient, Simulation, Presentation and Flow together, and autoplays the replay.

signal closed

@export var step_seconds: float = 0.5

## A file name in data/levels/.
var level: String = Config.settings.default_level

var _autoplay := Timer.new()

@onready var simulation: Simulation = $Simulation
@onready var presentation: Presentation = $Presentation
@onready var flow: Flow = $Flow


func _ready() -> void:
	presentation.listen_to(simulation)

	flow.submit_pressed.connect(func(source: String) -> void:
		SubmitClient.submit(source, level))
	SubmitClient.result_ready.connect(simulation.load_battle)

	SubmitClient.submit_failed.connect(flow.show_transport_error)
	simulation.submission_failed.connect(flow.show_submission_error)

	simulation.battle_loaded.connect(flow.show_battle)
	flow.step_pressed.connect(simulation.step)
	flow.skip_pressed.connect(func() -> void:
		_autoplay.stop()
		simulation.skip_to_end())
	flow.reset_pressed.connect(func() -> void:
		simulation.reset()
		_autoplay.start())
	flow.leave_pressed.connect(func() -> void:
		_autoplay.stop()
		closed.emit())

	_autoplay.wait_time = step_seconds
	_autoplay.timeout.connect(func() -> void:
		if not simulation.step():
			_autoplay.stop())
	add_child(_autoplay)
	simulation.battle_loaded.connect(_autoplay.start)


## Shows an empty battle screen for a level.
func open(level_id: String) -> void:
	level = level_id
	_autoplay.stop()
	simulation.reset()
	flow.show_idle()

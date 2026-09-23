class_name BattleController
extends Node
## The only node that talks to more than one system: it feeds SubmitClient's
## result into Simulation, starts Presentation listening, and connects Flow to
## both. Every cross-system connection in the client is in _ready below.

@onready var simulation: Simulation = $Simulation
@onready var presentation: Presentation = $Presentation
@onready var flow: Flow = $Flow


func _ready() -> void:
	presentation.listen_to(simulation)

	flow.submit_pressed.connect(func(source: String) -> void:
		SubmitClient.submit(source, Config.settings.default_level))
	SubmitClient.result_ready.connect(simulation.load_battle)

	# Same error state in Flow, two different causes, kept as two connections.
	SubmitClient.submit_failed.connect(flow.show_transport_error)
	simulation.submission_failed.connect(flow.show_submission_error)

	simulation.battle_loaded.connect(flow.show_battle)
	flow.step_pressed.connect(simulation.step)
	flow.skip_pressed.connect(simulation.skip_to_end)
	flow.reset_pressed.connect(simulation.reset)
	flow.scenario_selected.connect(simulation.select_scenario)

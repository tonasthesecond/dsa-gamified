class_name BattleScreen
extends Control
## Wires BattleRunner, ReplaySystem, BattleDisplay and CodePanel together, and autoplays the replay.

signal closed

@export var step_seconds: float = 0.5

## A file name in data/levels/.
var level: String = Config.settings.default_level

var _autoplay := Timer.new()

@onready var replay: ReplaySystem = $ReplaySystem
@onready var battle_display: BattleDisplay = $BattleDisplay
@onready var code_panel: CodePanel = $CodePanel


func _ready() -> void:
	battle_display.listen_to(replay)

	code_panel.submit_pressed.connect(func(source: String) -> void:
		BattleRunner.submit(source, level))
	BattleRunner.result_ready.connect(replay.load_battle)

	BattleRunner.submit_failed.connect(code_panel.show_transport_error)
	replay.submission_failed.connect(code_panel.show_submission_error)

	replay.battle_loaded.connect(code_panel.show_battle)
	code_panel.step_pressed.connect(replay.step)
	code_panel.skip_pressed.connect(func() -> void:
		_autoplay.stop()
		replay.skip_to_end())
	code_panel.reset_pressed.connect(func() -> void:
		replay.reset()
		_autoplay.start())
	code_panel.leave_pressed.connect(func() -> void:
		_autoplay.stop()
		closed.emit())

	_autoplay.wait_time = step_seconds
	_autoplay.timeout.connect(func() -> void:
		if not replay.step():
			_autoplay.stop())
	add_child(_autoplay)
	replay.battle_loaded.connect(_autoplay.start)


## Shows an empty battle screen for a level.
func open(level_id: String) -> void:
	level = level_id
	_autoplay.stop()
	replay.reset()
	code_panel.show_idle()

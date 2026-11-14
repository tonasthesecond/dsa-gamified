class_name BattleScreen
extends Control
## Wires BattleRunner, ReplaySystem, BattleDisplay and CodePanel together, and autoplays the replay.

signal closed
## The replay of a won battle reached its end.
signal cleared(level_id: String)

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
		Progress.save_draft(level, source)
		BattleRunner.submit(source, level))
	BattleRunner.result_ready.connect(replay.load_battle)

	BattleRunner.progress.connect(code_panel.show_progress)
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
		Progress.save_draft(level, code_panel.source())
		closed.emit())

	_autoplay.wait_time = step_seconds
	_autoplay.timeout.connect(func() -> void:
		if not replay.step():
			_autoplay.stop())
	add_child(_autoplay)
	replay.battle_loaded.connect(_autoplay.start)
	replay.battle_loaded.connect(%Briefing.hide)
	replay.ended.connect(func(won: bool, _reason: String) -> void:
		if won:
			Progress.mark_cleared(level, replay.turn)
			cleared.emit(level))


## Shows an empty battle screen for a level, with its briefing and the player's last code for it.
func open(level_id: String) -> void:
	level = level_id
	_autoplay.stop()
	replay.reset()
	var spec: Level = load("res://data/levels/%s.tres" % level_id)
	code_panel.set_source(Progress.draft(level_id, starter_for(spec)))
	code_panel.show_idle()
	%Briefing.text = briefing(spec)
	%Briefing.show()


## The level's starter code, or CodePanel's when it has none.
func starter_for(spec: Level) -> String:
	if spec.starter_code.is_empty():
		return code_panel.starter
	return FileAccess.get_file_as_string(spec.starter_code)


## Returns what the player needs before writing code: the goal, each kind of enemy's crit, and the rules.
static func briefing(spec: Level) -> String:
	var lines: Array[String] = [spec.title, spec.briefing, ""]
	var seen: Dictionary = {}
	for side_index in spec.sides.size():
		if side_index == spec.player_side:
			continue
		for slot in spec.sides[side_index].units:
			var kind := slot.unit
			if seen.has(kind):
				seen[kind].append(slot.id)
				continue
			seen[kind] = [slot.id]
	for kind: UnitDef in seen:
		var line := "%s (%s)" % [kind.name, ", ".join(seen[kind])]
		if kind.crit != null:
			line += ". Crit \"%s\": %s" % [kind.crit.id, kind.crit.description]
		lines.append(line)
	for rule in spec.rules:
		lines.append("Rule \"%s\": %s" % [rule.id, rule.description])
	return "\n".join(lines).strip_edges()

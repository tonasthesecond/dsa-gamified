extends Node
## The whole client: submits the starter code, then a broken one. Needs the server.

const PROGRESS_FILE := "user://smoke_game_progress.json"


func _ready() -> void:
	# Its own save file, so the broken code it submits never becomes the player's draft.
	DirAccess.remove_absolute(PROGRESS_FILE)
	Progress.use_file(PROGRESS_FILE)
	var main: Node = preload("res://main.tscn").instantiate()
	add_child(main)
	var battle_screen: BattleScreen = main.get_node("%BattleScreen")
	var code_panel := battle_screen.code_panel
	var submit: Button = code_panel.get_node("%Submit")

	battle_screen.open("gatehouse")
	print("briefing:\n", battle_screen.get_node("%Briefing").text)
	battle_screen.open(Config.settings.default_level)

	var turns: Array[int] = []
	BattleRunner.progress.connect(func(turn: int, _max_turns: int) -> void: turns.append(turn))
	var status: Label = code_panel.get_node("%Status")
	submit.pressed.emit()
	print("code panel state: ", CodePanel.State.keys()[code_panel.state], ", status: ", status.text)
	await _left_submitting(code_panel)
	print("progress turns seen: ", turns, ", last status: ", status.text)
	print("code panel state: ", CodePanel.State.keys()[code_panel.state])
	if code_panel.state == CodePanel.State.REPLAYING:
		code_panel.get_node("%Skip").pressed.emit()
		var editor: TextEdit = code_panel.get_node("%Editor")
		editor.text = editor.text.replace("return", "return return")
		submit.pressed.emit()
		await _left_submitting(code_panel)
		print("code panel state: %s, error: %s" % [CodePanel.State.keys()[code_panel.state], code_panel.get_node("%Error").text])
	DirAccess.remove_absolute(PROGRESS_FILE)
	get_tree().quit()


func _left_submitting(code_panel: CodePanel) -> void:
	while code_panel.state == CodePanel.State.SUBMITTING:
		await get_tree().process_frame

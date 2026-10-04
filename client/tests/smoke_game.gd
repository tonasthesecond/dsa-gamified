extends Node
## The whole client: submits the starter code, then a broken one. Needs the server.

func _ready() -> void:
	var main: Node = preload("res://main.tscn").instantiate()
	add_child(main)
	var code_panel := (main.get_node("%BattleScreen") as BattleScreen).code_panel
	var submit: Button = code_panel.get_node("%Submit")

	submit.pressed.emit()
	print("code panel state: ", CodePanel.State.keys()[code_panel.state])
	await _left_submitting(code_panel)
	print("code panel state: ", CodePanel.State.keys()[code_panel.state])
	if code_panel.state == CodePanel.State.REPLAYING:
		code_panel.get_node("%Skip").pressed.emit()
		var editor: TextEdit = code_panel.get_node("%Editor")
		editor.text = editor.text.replace("return", "return return")
		submit.pressed.emit()
		await _left_submitting(code_panel)
		print("code panel state: %s, error: %s" % [CodePanel.State.keys()[code_panel.state], code_panel.get_node("%Error").text])
	get_tree().quit()


func _left_submitting(code_panel: CodePanel) -> void:
	while code_panel.state == CodePanel.State.SUBMITTING:
		await get_tree().process_frame

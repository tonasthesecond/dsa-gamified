extends Node
## Dev check for the whole client: runs main.tscn, submits the starter source,
## skips to the end, then submits a broken source. Needs the server running;
## without one it shows the transport error instead.
## godot --headless --path client res://dev/smoke_flow.tscn

func _ready() -> void:
	var main: BattleController = preload("res://main.tscn").instantiate()
	add_child(main)
	var flow := main.flow
	var submit: Button = flow.get_node("%Submit")

	submit.pressed.emit()
	print("flow state: ", Flow.State.keys()[flow.state])
	await _left_submitting(flow)
	print("flow state: ", Flow.State.keys()[flow.state])
	if flow.state == Flow.State.REPLAYING:
		flow.get_node("%Skip").pressed.emit()
		var editor: TextEdit = flow.get_node("%Editor")
		editor.text = editor.text.replace("));", "))")
		submit.pressed.emit()
		await _left_submitting(flow)
		print("flow state: %s, error: %s" % [Flow.State.keys()[flow.state], flow.get_node("%Error").text])
	get_tree().quit()


func _left_submitting(flow: Flow) -> void:
	while flow.state == Flow.State.SUBMITTING:
		await get_tree().process_frame

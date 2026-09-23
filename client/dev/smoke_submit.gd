extends Node
## Dev check for SubmitClient: sends dev/fixtures/Submission.java to the
## configured server, prints what comes back, quits.
## godot --headless --path client res://dev/smoke_submit.tscn

func _ready() -> void:
	SubmitClient.result_ready.connect(func(envelope: Dictionary) -> void:
		print("result_ready: status=%s message=%s" % [envelope.status, envelope.message])
		get_tree().quit())
	SubmitClient.submit_failed.connect(func(reason: String) -> void:
		print("submit_failed: %s" % reason)
		get_tree().quit())
	var source := FileAccess.get_file_as_string("res://dev/fixtures/Submission.java")
	SubmitClient.submit(source, "smoke")

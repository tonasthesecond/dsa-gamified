class_name CodePanel
extends Control
## The code editor and replay buttons; emits what the player did and nothing else.

enum State { IDLE, SUBMITTING, REPLAYING, ERROR }

signal submit_pressed(source: String)
signal step_pressed
signal skip_pressed
signal reset_pressed
signal leave_pressed

var state: State = State.IDLE
## The code the editor starts with, for a level with no draft yet.
var starter: String = ""

@onready var _editor: TextEdit = %Editor
@onready var _submit: Button = %Submit
@onready var _spinner: ProgressBar = %Spinner
@onready var _replay: Control = %Replay
@onready var _error: Label = %Error


func _ready() -> void:
	starter = _editor.text
	_submit.pressed.connect(func() -> void:
		_set_state(State.SUBMITTING)
		submit_pressed.emit(_editor.text))
	%Step.pressed.connect(step_pressed.emit)
	%Skip.pressed.connect(skip_pressed.emit)
	%Reset.pressed.connect(reset_pressed.emit)
	%Leave.pressed.connect(leave_pressed.emit)
	_set_state(State.IDLE)


## The code in the editor.
func source() -> String:
	return _editor.text


## Replaces the code in the editor.
func set_source(text: String) -> void:
	_editor.text = text
	_editor.clear_undo_history()


## Shows that the server could not be reached.
func show_transport_error(reason: String) -> void:
	_error.text = "Could not reach the server: %s" % reason
	_set_state(State.ERROR)


## Shows a compile or runtime error, selecting its line.
func show_submission_error(message: String, line: int) -> void:
	_error.text = message if line < 1 else "Line %d: %s" % [line, message]
	if line >= 1:
		_editor.set_caret_line(line - 1)
		_editor.select(line - 1, 0, line - 1, _editor.get_line(line - 1).length())
	_set_state(State.ERROR)


## Shows the replay controls.
func show_battle() -> void:
	_set_state(State.REPLAYING)


## Shows the editor with nothing replaying.
func show_idle() -> void:
	_set_state(State.IDLE)


func _set_state(new_state: State) -> void:
	state = new_state
	_submit.disabled = state == State.SUBMITTING
	%Leave.disabled = state == State.SUBMITTING
	_editor.editable = state != State.SUBMITTING
	_spinner.visible = state == State.SUBMITTING
	_replay.visible = state == State.REPLAYING
	_error.visible = state == State.ERROR

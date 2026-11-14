extends Node2D
## Overworld rig: walking into an open Area2D with `level` metadata opens that battle.

const SPEED := 220.0
const CLEARED_COLOR := Color(0.3, 0.85, 0.4, 0.5)
const LOCKED_COLOR := Color(0.45, 0.45, 0.45, 0.35)

var in_battle := false
var campaign: Campaign = preload("res://data/campaign.tres")

@onready var player: CharacterBody2D = $Overworld/Player
@onready var battle_layer: CanvasLayer = $BattleLayer
@onready var battle: BattleScreen = %BattleScreen


func _ready() -> void:
	for zone in zones():
		zone.set_meta("open_color", zone.get_node("Fill").color)
		zone.set_meta("title", zone.get_node("Name").text)
		zone.body_entered.connect(func(body: Node2D) -> void:
			if body == player and not in_battle and is_open(zone.get_meta("level")):
				_open_battle(zone.get_meta("level")))
	battle.closed.connect(func() -> void:
		battle_layer.hide()
		in_battle = false)
	battle.cleared.connect(func(_level: String) -> void: paint_zones())
	paint_zones()


func _physics_process(_delta: float) -> void:
	if in_battle:
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction += Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	player.velocity = direction.limit_length(1.0) * SPEED
	player.move_and_slide()


## The level zones on the overworld.
func zones() -> Array[Area2D]:
	var found: Array[Area2D] = []
	for child in $Overworld.get_children():
		if child is Area2D and child.has_meta("level"):
			found.append(child)
	return found


## True when the campaign lets the player into this level.
func is_open(level: String) -> bool:
	return campaign.is_unlocked(level, Progress.is_cleared)


## Colors each zone cleared, open or locked, from Progress.
func paint_zones() -> void:
	for zone in zones():
		var level: String = zone.get_meta("level")
		var fill: ColorRect = zone.get_node("Fill")
		var title: String = zone.get_meta("title")
		if Progress.is_cleared(level):
			fill.color = CLEARED_COLOR
			zone.get_node("Name").text = "%s (%d turns)" % [title, Progress.best_turns(level)]
		elif is_open(level):
			fill.color = zone.get_meta("open_color")
			zone.get_node("Name").text = title
		else:
			fill.color = LOCKED_COLOR
			zone.get_node("Name").text = title + " (locked)"


func _open_battle(level: String) -> void:
	in_battle = true
	player.velocity = Vector2.ZERO
	battle_layer.show()
	battle.open(level)

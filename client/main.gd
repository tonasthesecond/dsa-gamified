extends Node2D
## The rig: a top-down overworld with a player and level zones, and the battle
## screen on a layer above it. A zone is any Area2D under Overworld with a
## `level` metadata entry; walking into it opens that level's battle.

const SPEED := 220.0

var in_battle := false

@onready var player: CharacterBody2D = $Overworld/Player
@onready var battle_layer: CanvasLayer = $BattleLayer
@onready var battle: BattleController = %BattleController


func _ready() -> void:
	for zone in $Overworld.get_children():
		if zone is Area2D:
			zone.body_entered.connect(func(body: Node2D) -> void:
				if body == player and not in_battle:
					_open_battle(zone.get_meta("level")))
	battle.closed.connect(func() -> void:
		battle_layer.hide()
		in_battle = false)


func _physics_process(_delta: float) -> void:
	if in_battle:
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction += Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	player.velocity = direction.limit_length(1.0) * SPEED
	player.move_and_slide()


func _open_battle(level: String) -> void:
	in_battle = true
	player.velocity = Vector2.ZERO
	battle_layer.show()
	battle.open(level)

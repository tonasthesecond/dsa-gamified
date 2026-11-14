extends Node2D
## Overworld rig: walking into an Area2D with `level` metadata opens that battle.

const SPEED := 220.0
const CLEARED_COLOR := Color(0.3, 0.85, 0.4, 0.5)

var in_battle := false

@onready var player: CharacterBody2D = $Overworld/Player
@onready var battle_layer: CanvasLayer = $BattleLayer
@onready var battle: BattleScreen = %BattleScreen


func _ready() -> void:
	for zone in $Overworld.get_children():
		if zone is Area2D:
			zone.body_entered.connect(func(body: Node2D) -> void:
				if body == player and not in_battle:
					_open_battle(zone.get_meta("level")))
	battle.closed.connect(func() -> void:
		battle_layer.hide()
		in_battle = false)
	battle.cleared.connect(func(level: String) -> void:
		for zone in $Overworld.get_children():
			if zone is Area2D and zone.get_meta("level") == level:
				zone.get_node("Fill").color = CLEARED_COLOR)


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

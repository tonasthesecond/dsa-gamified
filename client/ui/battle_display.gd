class_name BattleDisplay
extends Node
## Draws a replay as coloured boxes on `stage`; prints every event without one.

const LEFT_COLOR := Color(0.25, 0.45, 0.9)
const RIGHT_COLOR := Color(0.85, 0.3, 0.3)
const ACTING_COLOR := Color(1.0, 0.85, 0.2)
const DEAD_COLOR := Color(0.35, 0.35, 0.35)
const BOX_SIZE := Vector2(64, 64)

## Needs %HeroColumn, %EnemyColumn and %Banner.
@export var stage: Control

var _boxes: Dictionary = {}  # unit id -> {rect, label, base, name, hp, max_hp, guard, alive}
var _left_team: String = ""
var _last_actor: String = ""


## Connects to every ReplaySystem signal.
func listen_to(replay: ReplaySystem) -> void:
	replay.battle_reset.connect(_on_reset)
	replay.spawned.connect(_on_spawned)
	replay.intent.connect(func(event: Dictionary) -> void: print("intent: %s" % event))
	replay.action.connect(_on_action)
	replay.effect_applied.connect(_on_effect_applied)
	replay.died.connect(_on_died)
	replay.ended.connect(_on_ended)
	replay.unknown_event.connect(func(event: Dictionary) -> void: print("unknown: %s" % event))


func _on_reset() -> void:
	for box: Dictionary in _boxes.values():
		box.rect.get_parent().queue_free()
	_boxes.clear()
	_left_team = ""
	_last_actor = ""
	if stage:
		stage.get_node("%Banner").text = ""


func _on_spawned(event: Dictionary) -> void:
	print("spawn: %s" % event)
	if not stage:
		return
	if _left_team.is_empty():
		_left_team = event.team
	var left: bool = event.team == _left_team
	var holder := VBoxContainer.new()
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rect := ColorRect.new()
	rect.custom_minimum_size = BOX_SIZE
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.color = LEFT_COLOR if left else RIGHT_COLOR
	holder.add_child(label)
	holder.add_child(rect)
	stage.get_node("%HeroColumn" if left else "%EnemyColumn").add_child(holder)
	_boxes[event.unit] = {
		"rect": rect, "label": label, "base": rect.color,
		"name": event.name, "hp": event.hp, "max_hp": event.maxHp, "guard": 0, "alive": true,
	}
	_refresh(event.unit)


func _on_action(event: Dictionary) -> void:
	print("action: %s" % event)
	if not stage:
		return
	if _boxes.has(_last_actor) and _boxes[_last_actor].alive:
		_boxes[_last_actor].rect.color = _boxes[_last_actor].base
	_last_actor = event.unit
	_boxes[event.unit].rect.color = ACTING_COLOR
	_boxes[event.unit].guard = 0
	_refresh(event.unit)


func _on_effect_applied(event: Dictionary) -> void:
	print("%s: %s" % [event.type, event])
	if not stage:
		return
	var box: Dictionary = _boxes[event.unit]
	if event.has("hp"):
		box.hp = event.hp
	if event.type == "guard":
		box.guard = event.amount
	box.guard -= event.get("absorbed", 0)
	_refresh(event.unit)


func _on_died(event: Dictionary) -> void:
	print("death: %s" % event)
	if not stage:
		return
	var box: Dictionary = _boxes[event.unit]
	box.alive = false
	box.rect.color = DEAD_COLOR
	box.label.text = "%s  KO" % box.name


func _on_ended(won: bool, reason: String) -> void:
	print("end: won=%s %s" % [won, reason])
	if stage:
		stage.get_node("%Banner").text = "%s: %s" % ["Victory" if won else "Defeat", reason]


func _refresh(id: String) -> void:
	var box: Dictionary = _boxes[id]
	if not box.alive:
		return
	box.label.text = "%s  %d/%d" % [box.name, box.hp, box.max_hp]
	if box.guard > 0:
		box.label.text += "  [guard %d]" % box.guard

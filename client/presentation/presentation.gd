class_name Presentation
extends Node
## Shows a Simulation. It prints every signal, and when given a `stage` it also
## draws each unit as a coloured box: the first team to spawn on the left, every
## other team on the right, and whoever acts lit up. It reads Simulation
## through signals and Content for names, and changes neither.

const LEFT_COLOR := Color(0.25, 0.45, 0.9)
const RIGHT_COLOR := Color(0.85, 0.3, 0.3)
const ACTING_COLOR := Color(1.0, 0.85, 0.2)
const DEAD_COLOR := Color(0.35, 0.35, 0.35)
const BOX_SIZE := Vector2(64, 64)

## Where units are drawn. Needs %HeroColumn, %EnemyColumn and %Banner below it.
## Without one, Presentation only prints.
@export var stage: Control

## How to show each kind of move output, keyed by the event `type` that
## Simulation.effect_applied carries. A visual for a new effect is one entry.
var type_hooks: Dictionary[String, Callable] = {
	"damage": func(event: Dictionary) -> void: print("damage: %s" % event),
	"heal": func(event: Dictionary) -> void: print("heal: %s" % event),
	"blocked": func(event: Dictionary) -> void: print("blocked: %s" % event),
	"guard": func(event: Dictionary) -> void: print("guard: %s" % event),
}
## Extra flourishes for one move, keyed by move id. Run after the type hook.
var move_hooks: Dictionary[String, Callable] = {}

var _boxes: Dictionary = {}  # unit id -> {rect, label, base, name, hp, max_hp, guard, alive}
var _left_team: String = ""
var _last_actor: String = ""


func listen_to(sim: Simulation) -> void:
	sim.battle_loaded.connect(func() -> void: print("battle_loaded"))
	sim.submission_failed.connect(
		func(message: String, line: int) -> void:
			print("submission_failed: line %d: %s" % [line, message])
	)
	sim.battle_reset.connect(_on_reset)
	sim.spawned.connect(_on_spawned)
	sim.intent.connect(
		func(event: Dictionary) -> void: print("intent: %s %s" % [event, _move_label(event.move)])
	)
	sim.action.connect(_on_action)
	sim.effect_applied.connect(_on_effect_applied)
	sim.died.connect(_on_died)
	sim.ended.connect(_on_ended)
	sim.unknown_event.connect(func(event: Dictionary) -> void: print("unknown_event: %s" % event))


func _on_reset() -> void:
	print("battle_reset")
	for box: Dictionary in _boxes.values():
		box.rect.get_parent().queue_free()
	_boxes.clear()
	_left_team = ""
	_last_actor = ""
	if stage:
		_banner().text = ""


func _on_spawned(event: Dictionary) -> void:
	print("spawned: %s %s" % [event, _unit_label(event.name)])
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
	print("action: %s %s" % [event, _move_label(event.move)])
	if not stage:
		return
	if _boxes.has(_last_actor) and _boxes[_last_actor].alive:
		_boxes[_last_actor].rect.color = _boxes[_last_actor].base
	_last_actor = event.unit
	_boxes[event.unit].rect.color = ACTING_COLOR
	# A guard lasts until its unit acts again, as in Battle.run.
	_boxes[event.unit].guard = 0
	_refresh(event.unit)


func _on_effect_applied(event: Dictionary) -> void:
	var type_hook: Callable = type_hooks.get(event.type, Callable())
	if type_hook.is_valid():
		type_hook.call(event)
	else:
		print("effect_applied (no type hook for %s): %s" % [event.type, event])
	var move_hook: Callable = move_hooks.get(event.move, Callable())
	if move_hook.is_valid():
		move_hook.call(event)
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
	print("died: %s" % event)
	if not stage:
		return
	var box: Dictionary = _boxes[event.unit]
	box.alive = false
	box.rect.color = DEAD_COLOR
	box.label.text = "%s  KO" % box.name


func _on_ended(won: bool, reason: String) -> void:
	print("ended: won=%s reason=%s" % [won, reason])
	if stage:
		_banner().text = "%s: %s" % ["Victory" if won else "Defeat", reason]


func _refresh(id: String) -> void:
	var box: Dictionary = _boxes[id]
	if not box.alive:
		return
	box.label.text = "%s  %d/%d" % [box.name, box.hp, box.max_hp]
	if box.guard > 0:
		box.label.text += "  [guard %d]" % box.guard


func _banner() -> Label:
	return stage.get_node("%Banner")


func _unit_label(kind: String) -> String:
	var unit := Content.get_unit(kind)
	return "(%s)" % unit.display_name if unit else "(no Content row for unit %s)" % kind


func _move_label(id: String) -> String:
	var move := Content.get_move(id)
	return "(%s)" % move.display_name if move else "(no Content row for move %s)" % id

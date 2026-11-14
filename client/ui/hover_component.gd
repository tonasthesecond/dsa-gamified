class_name HoverComponent
extends Node
## Child of a Control or CollisionObject2D; pops `scene` up in HoverUI while the mouse is on its parent.

## The popup; its root is a Control, and an optional `setup(data)` fills it in.
@export var scene: PackedScene
## Seconds the mouse must stay before the popup shows.
@export var delay: float = 0.0
## Passed to the popup's `setup`; the parent when left null.
var data: Variant = null

var _hovered := false
var _elapsed := 0.0


func _ready() -> void:
	set_process(false)
	var target := get_parent()
	assert(target is Control or target is CollisionObject2D, "HoverComponent needs a Control or CollisionObject2D parent")
	target.mouse_entered.connect(_on_mouse_entered)
	target.mouse_exited.connect(_on_mouse_exited)
	tree_exiting.connect(func() -> void: HoverUI.clear(self))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= delay:
		set_process(false)
		HoverUI.show_for(self)


## What the popup is set up with.
func get_data() -> Variant:
	return get_parent() if data == null else data


func _on_mouse_entered() -> void:
	if _hovered or scene == null:
		return
	_hovered = true
	_elapsed = 0.0
	set_process(true)


func _on_mouse_exited() -> void:
	_hovered = false
	set_process(false)
	HoverUI.clear(self)

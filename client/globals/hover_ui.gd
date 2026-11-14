extends CanvasLayer
## Shows one HoverComponent's scene as its child, next to the mouse and kept on screen.

## Gap between the mouse and the popup.
const OFFSET := Vector2(12, 12)

var _popup: Control
var _source: HoverComponent


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if _popup:
		_place()


## Replaces the current popup with `source`'s scene, calling its `setup(data)` if it has one.
func show_for(source: HoverComponent) -> void:
	clear()
	_source = source
	_popup = source.scene.instantiate()
	_ignore_mouse(_popup)
	_popup.visible = false
	add_child(_popup)
	if _popup.has_method("setup"):
		_popup.setup(source.get_data())
	# Wait a frame so containers have their final size before the first placement.
	await get_tree().process_frame
	if is_instance_valid(_popup) and _source == source:
		_place()
		_popup.visible = true


## Removes the popup; with `source`, only if that component owns it.
func clear(source: HoverComponent = null) -> void:
	if source and source != _source:
		return
	if _popup:
		_popup.queue_free()
	_popup = null
	_source = null


# --- Helpers ---

func _place() -> void:
	var mouse := get_viewport().get_mouse_position()
	var screen := get_viewport().get_visible_rect().size
	var size := _popup.size
	var x := mouse.x + OFFSET.x
	if x + size.x > screen.x:
		x = mouse.x - OFFSET.x - size.x
	var y := mouse.y + OFFSET.y
	if y + size.y > screen.y:
		y = mouse.y - OFFSET.y - size.y
	_popup.position = Vector2(x, y)


## The popup must never take the mouse, or the target would see mouse_exited.
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

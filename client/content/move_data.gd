class_name MoveData
extends Resource
## What the client knows about one move. Registered in Content under the move
## id that `action` and `intent` events carry in their `action` field.

@export var display_name: String = ""
@export_multiline var description: String = ""
## Which animation Presentation plays for this move; free-form until there is art.
@export var animation_key: StringName = &""

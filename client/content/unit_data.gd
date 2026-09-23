class_name UnitData
extends Resource
## What the client knows about one kind of unit. Registered in Content under
## the `name` a spawn event carries ("Goblin"), not the per-battle unit id ("e1").

@export var display_name: String = ""
## Scene Presentation instances for this unit; may stay null until there is art.
@export var scene: PackedScene

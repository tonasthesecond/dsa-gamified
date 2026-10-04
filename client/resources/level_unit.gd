class_name LevelUnit
extends Resource
## One unit on a side of a Level, under a battle id like "e1".

@export var id: String = ""
@export var unit: UnitDef
## Up to this much extra max hp, rolled from the seed.
@export var bonus_max_hp: int = 0

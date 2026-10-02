class_name UnitSlot
extends Resource
## One place on a side in an Encounter: which unit, under which id.

## The per-battle id events and states use, such as "e1". Unique in the battle.
@export var id: String = ""
@export var unit: UnitDef
## Up to this much extra max hp, rolled from the encounter's seed; 0 for none.
@export var bonus_max_hp: int = 0

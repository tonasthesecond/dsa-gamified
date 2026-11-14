class_name LevelRule
extends Resource
## A level's own question on top of the units' crits, and what a right or a wrong answer does.

## The label the student writes the answer under: "attack e1 | median 5.5".
@export var id: String = ""
@export_multiline var description: String = ""
@export var problem: Problem
## Run on the target before the move when the answer is wrong; a BounceEffect here makes the rule a gate.
@export var when_wrong: Array[Effect] = []
## Run on the target after the move when the answer is right; a DamageEffect here makes the rule a bonus.
@export var when_right: Array[Effect] = []

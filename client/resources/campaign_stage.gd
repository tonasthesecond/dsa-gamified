class_name CampaignStage
extends Resource
## One campaign level and the levels to clear before it opens.

## A file name in data/levels/.
@export var level: String = ""
## Level ids that must all be cleared first; empty for the first level.
@export var requires: Array[String] = []

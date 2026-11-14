class_name Campaign
extends Resource
## The campaign's levels in order, and which of them are open.

@export var stages: Array[CampaignStage] = []


## True when every level `level_id` requires is cleared; a level outside the campaign is always open.
func is_unlocked(level_id: String, is_cleared: Callable) -> bool:
	for stage in stages:
		if stage.level == level_id:
			return stage.requires.all(func(required: String) -> bool: return is_cleared.call(required))
	return true

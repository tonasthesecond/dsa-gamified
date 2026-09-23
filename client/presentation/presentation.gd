class_name Presentation
extends Node
## Shows a Simulation. For now it only prints each signal; this is the node to
## gut and rebuild with visuals. It reads Simulation through signals and
## Content for names, and changes neither.


func listen_to(sim: Simulation) -> void:
	sim.battle_loaded.connect(func(count: int) -> void: print("battle_loaded: %d scenarios" % count))
	sim.submission_failed.connect(func(message: String, line: int) -> void:
		print("submission_failed: line %d: %s" % [line, message]))
	sim.scenario_reset.connect(func(index: int) -> void: print("scenario_reset: %d" % index))
	sim.spawned.connect(func(event: Dictionary) -> void:
		print("spawned: %s %s" % [event, _unit_label(event.name)]))
	sim.intent.connect(func(event: Dictionary) -> void:
		print("intent: %s %s" % [event, _move_label(event.action)]))
	sim.action.connect(func(event: Dictionary) -> void:
		print("action: %s %s" % [event, _move_label(event.action)]))
	sim.blocked.connect(func(event: Dictionary) -> void: print("blocked: %s" % event))
	sim.damaged.connect(func(event: Dictionary) -> void: print("damaged: %s" % event))
	sim.healed.connect(func(event: Dictionary) -> void: print("healed: %s" % event))
	sim.died.connect(func(event: Dictionary) -> void: print("died: %s" % event))
	sim.ended.connect(func(won: bool, reason: String) -> void:
		print("ended: won=%s reason=%s" % [won, reason]))
	sim.unknown_event.connect(func(event: Dictionary) -> void: print("unknown_event: %s" % event))


func _unit_label(kind: String) -> String:
	var unit := Content.get_unit(kind)
	return "(%s)" % unit.display_name if unit else "(no Content row for unit %s)" % kind


func _move_label(id: String) -> String:
	var move := Content.get_move(id)
	return "(%s)" % move.display_name if move else "(no Content row for move %s)" % id

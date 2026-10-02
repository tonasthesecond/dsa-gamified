class_name BattleLog
extends RefCounted
## The events of one battle, in order, as Dictionaries in the vocabulary of
## server/docs/protocol.md, so Simulation and Presentation replay them as they
## are. Only Battle writes to it.

var events: Array[Dictionary] = []


func spawn(unit: Combatant, team: String) -> void:
	events.append({"turn": 0, "type": "spawn", "unit": unit.id, "name": unit.display_name(),
		"team": team, "hp": unit.hp, "maxHp": unit.max_hp})


func intent(turn: int, unit: Combatant, move: Move, targets: Array) -> void:
	events.append(_with_move({"turn": turn, "type": "intent", "unit": unit.id}, move, targets))


func action(turn: int, unit: Combatant, move: Move, targets: Array) -> void:
	events.append(_with_move({"turn": turn, "type": "action", "unit": unit.id}, move, targets))


## `target` is who the move bounced off.
func blocked(turn: int, target: Combatant, reason: String, source: Move) -> void:
	events.append(_with_source({"turn": turn, "type": "blocked", "unit": target.id, "reason": reason}, source))


## `hp` is after the damage; `amount` is what got past the guard, and
## `absorbed`, only there when it is not 0, what the guard took.
func damage(turn: int, unit: Combatant, amount: int, absorbed: int, source: Move) -> void:
	var event := {"turn": turn, "type": "damage", "unit": unit.id, "amount": amount, "hp": unit.hp}
	if absorbed > 0:
		event.absorbed = absorbed
	events.append(_with_source(event, source))


## `amount` is the guard the unit now has.
func guard(turn: int, unit: Combatant, amount: int, source: Move) -> void:
	events.append(_with_source({"turn": turn, "type": "guard", "unit": unit.id, "amount": amount}, source))


## `hp` is after the healing; `amount` is what the unit actually got.
func heal(turn: int, unit: Combatant, amount: int, source: Move) -> void:
	events.append(_with_source({"turn": turn, "type": "heal", "unit": unit.id,
		"amount": amount, "hp": unit.hp}, source))


func death(turn: int, unit: Combatant) -> void:
	events.append({"turn": turn, "type": "death", "unit": unit.id})


func end(turn: int, won: bool, reason: String) -> void:
	events.append({"turn": turn, "type": "end", "won": won, "reason": reason})


## `action` is the move's id; a move aimed at its own user has no target.
## `target` is the first target, and `targets`, only there when there is more
## than one, all of them in order. `move` repeats the id under the name every
## move-related event uses.
func _with_move(event: Dictionary, move: Move, targets: Array) -> Dictionary:
	event.action = move.id
	if move.target != Move.Target.SELF:
		event.target = (targets[0] as Combatant).id
		if targets.size() > 1:
			event.targets = targets.map(func(t: Combatant) -> String: return t.id)
	return _with_source(event, move)


## Which move an event came from; left out when it came from none.
func _with_source(event: Dictionary, source: Move) -> Dictionary:
	if source != null:
		event.move = source.id
	return event

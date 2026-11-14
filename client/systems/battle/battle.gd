class_name Battle
extends RefCounted
## One battle, played start to finish with nothing shown. Every rule lives here.

const WON := "All enemies defeated"
const LOST := "Party defeated"
const OUT_OF_TURNS := "Turn limit reached"

var sides: Array[BattleSide] = []
## Side by side in side order; the dead stay.
var combatants: Array[Combatant] = []
var player_side: int
var max_turns: int
## The only source of randomness.
var rng: RandomNumberGenerator
## For the controllers, such as the StudentCode under "student_code".
var context: Dictionary
var turn: int = 0
var battle_log := BattleLog.new()
## The level's rules, judged on each move the player's side aims at an enemy; set by Level.create_battle.
var rules: Array[LevelRule] = []

var _resolving: Move = null


func _init(p_sides: Array[BattleSide], p_player_side: int, p_max_turns: int,
		p_rng: RandomNumberGenerator, p_context: Dictionary = {}) -> void:
	sides = p_sides
	player_side = p_player_side
	max_turns = p_max_turns
	rng = p_rng
	context = p_context
	for side in sides:
		combatants.append_array(side.combatants)


## Plays the battle out and returns its result and events.
func run() -> BattleResult:
	for unit in combatants:
		battle_log.spawn(unit, sides[unit.side].team)

	var begun: Array[Controller] = []
	for side in sides:
		if side.controller in begun:
			continue
		begun.append(side.controller)
		var started := side.controller.begin(self)
		if started.has("abort"):
			return _aborted(started)
		if started.has("error"):
			return _end(1, false, started.error, started.error)

	for t in range(1, max_turns + 1):
		turn = t

		for unit in turn_order():
			unit.intent = controller_of(unit).plan(self, unit)
			if not unit.intent.is_empty():
				battle_log.intent(turn, unit, unit.intent.move, unit.intent.targets)

		for actor in turn_order():
			if not actor.is_alive():
				continue
			actor.guard = 0
			var controller := controller_of(actor)
			var decision := controller.act(self, actor)
			if decision.has("abort"):
				return _aborted(decision)
			if decision.has("error"):
				return _end(turn, false, decision.error, decision.error)
			var move_id: String = decision.action.move
			var target_ids: Array = decision.action.targets

			var problem := use_error(actor, move_id, target_ids)
			var move := actor.find_move(move_id)
			var targets := resolve_targets(actor, move, target_ids)
			if not problem.is_empty():
				var refusal := controller.refuse(self, actor, problem)
				if not refusal.is_empty():
					return _end(turn, false, refusal, refusal)
				if move != null and not targets.is_empty() and not targets.has(null):
					battle_log.action(turn, actor, move, targets)
				continue

			battle_log.action(turn, actor, move, targets)
			use(move, actor, targets, decision.action.get("answers", {}))

			if _others_wiped_out():
				return _end(turn, true, WON)
			if living(player_side).is_empty():
				return _end(turn, false, LOST)
	return _end(max_turns, false, OUT_OF_TURNS)


# --- Queries ---


## Returns the living, fastest first; ties keep side order.
func turn_order() -> Array[Combatant]:
	var order: Array[Combatant] = []
	for unit in combatants:
		if unit.is_alive():
			order.append(unit)
	order.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if a.stats.speed != b.stats.speed:
			return a.stats.speed > b.stats.speed
		return combatants.find(a) < combatants.find(b))
	return order


## Returns the controller of a unit's side.
func controller_of(unit: Combatant) -> Controller:
	return sides[unit.side].controller


## Returns the living combatants of one side.
func living(side: int) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for unit in sides[side].combatants:
		if unit.is_alive():
			result.append(unit)
	return result


## Returns the first living opponent in turn order, or null.
func first_living_opponent(unit: Combatant) -> Combatant:
	for other in turn_order():
		if other.side != unit.side:
			return other
	return null


## Returns the combatant with this id, or null.
func find(id: Variant) -> Combatant:
	for unit in combatants:
		if unit.id == id:
			return unit
	return null


## Returns who a move lands on: the user for a SELF move, else each id's combatant.
func resolve_targets(user: Combatant, move: Move, target_ids: Array) -> Array[Combatant]:
	var targets: Array[Combatant] = []
	if move == null:
		return targets
	if move.target == Move.Target.SELF:
		targets.append(user)
		return targets
	for id: Variant in target_ids:
		targets.append(find(id))
	return targets


## Returns why this use of a move is illegal, or "" if it is legal.
func use_error(user: Combatant, move_id: String, target_ids: Array) -> String:
	var move := user.find_move(move_id)
	if move == null:
		return "%s tried to use \"%s\", which it does not know." % [user.display_name(), move_id]
	var count := move.target_count()
	if count == 0 and not target_ids.is_empty():
		return "%s tried to use %s on someone, but it takes no target." % [user.display_name(), move.name]
	if count > 0 and target_ids.is_empty():
		return "%s tried to use %s without a target." % [user.display_name(), move.name]
	if target_ids.size() > count:
		return "%s tried to use %s on %d targets, but it takes at most %d." % [
			user.display_name(), move.name, target_ids.size(), count]
	for i in target_ids.size():
		var target := find(target_ids[i])
		if target == null:
			return "%s tried to use %s on \"%s\", which is not in this battle." % [
				user.display_name(), move.name, target_ids[i]]
		var what := "%s tried to use %s on %s, " % [user.display_name(), move.name, target.display_name()]
		if target_ids.find(target_ids[i]) < i:
			return what + "which it already named."
		if not target.is_alive():
			return what + "which is already dead."
		if move.target == Move.Target.ENEMY and target.side == user.side:
			return what + "which is not an enemy."
		if move.target == Move.Target.ALLY and target.side != user.side:
			return what + "which is not an ally."
	return ""


## Returns what the student sees for this unit: {turn, self, allies, enemies}.
func state_for(unit: Combatant) -> Dictionary:
	var allies: Array = []
	var enemies: Array = []
	for other in turn_order():
		(allies if other.side == unit.side else enemies).append(_view(other))
	var rule_views: Array = []
	for rule in rules:
		rule_views.append({"id": rule.id, "description": rule.description,
			"answer": rule.problem.takes_answer()})
	return {"turn": turn, "self": _view(unit), "allies": allies, "enemies": enemies, "rules": rule_views}


# --- Moves and primitives ---


## Runs a legal move's effects on each target in order.
func use(move: Move, user: Combatant, targets: Array[Combatant], answers: Dictionary = {}) -> void:
	_resolving = move
	for target in targets:
		var move_context := MoveContext.new()
		# Judged before anything lands, so a crit is about the body the student saw.
		var right: Array[LevelRule] = []
		var wrong: Array[LevelRule] = []
		for rule in _rules_for(move, user):
			if rule.problem.is_correct(self, user, target, answers.get(rule.id)):
				right.append(rule)
			else:
				wrong.append(rule)
		var crit := _is_crit(move, user, target, answers)

		for rule in wrong:
			_apply(rule.when_wrong, user, target, move_context)
		_apply(move.effects, user, target, move_context)
		if crit and not move_context.halted:
			_apply(move.crit_effects, user, target, move_context)
			if target.is_alive():
				target.reroll_body(rng)
		for rule in right:
			_apply(rule.when_right, user, target, move_context)
	_resolving = null


## Hurts a combatant through its guard; returns the hp it lost.
func deal_damage(target: Combatant, amount: int) -> int:
	amount = maxi(amount, 0)
	var absorbed := mini(amount, target.guard)
	target.guard -= absorbed
	amount -= absorbed
	var before := target.hp
	target.hp = maxi(target.hp - amount, 0)
	battle_log.damage(turn, target, amount, absorbed, _resolving)
	if not target.is_alive():
		battle_log.death(turn, target)
	return before - target.hp


## Heals a combatant up to its max; returns how much it got.
func heal(target: Combatant, amount: int) -> int:
	var healed := mini(maxi(amount, 0), target.max_hp - target.hp)
	target.hp += healed
	battle_log.heal(turn, target, healed, _resolving)
	return healed


## Logs that a move bounced off a combatant.
func block(target: Combatant, reason: String) -> void:
	battle_log.blocked(turn, target, reason, _resolving)


## Sets a combatant's guard until its next action.
func guard(target: Combatant, amount: int) -> void:
	target.guard = maxi(amount, 0)
	battle_log.guard(turn, target, target.guard, _resolving)


# --- Internals ---


## Rules only judge the player's side: the AIs never answer, so a gate would stop every enemy hit.
func _rules_for(move: Move, user: Combatant) -> Array[LevelRule]:
	if move.target != Move.Target.ENEMY or user.side != player_side:
		return []
	return rules


func _is_crit(move: Move, user: Combatant, target: Combatant, answers: Dictionary) -> bool:
	var problem: Problem = target.unit.crit
	if move.target != Move.Target.ENEMY or move.crit_effects.is_empty() or problem == null:
		return false
	return answers.has("crit") and problem.is_correct(self, user, target, answers.crit)


func _apply(effects: Array[Effect], user: Combatant, target: Combatant, move_context: MoveContext) -> void:
	for effect in effects:
		if move_context.halted:
			break
		effect.apply(self, user, target, move_context)


func _others_wiped_out() -> bool:
	for unit in combatants:
		if unit.side != player_side and unit.is_alive():
			return false
	return true


func _view(unit: Combatant) -> Dictionary:
	var moves: Array = []
	for move in unit.moves:
		moves.append({"id": move.id, "name": move.name, "description": move.description,
			"target": Move.TARGET_NAMES[move.target], "targets": move.target_count()})
	return {"id": unit.id, "name": unit.display_name(), "hp": unit.hp, "maxHp": unit.max_hp,
		"strength": unit.stats.strength, "magic": unit.stats.magic, "speed": unit.stats.speed,
		"guard": unit.guard, "intent": unit.intent_command(), "moves": moves,
		"body": unit.body_value.duplicate(true) if not unit.body_value.is_empty() else null,
		"crit": {"id": unit.unit.crit.id, "description": unit.unit.crit.description} if unit.unit.crit != null else null}


func _end(at_turn: int, won: bool, reason: String, error: String = "") -> BattleResult:
	battle_log.end(at_turn, won, reason)
	var result := BattleResult.new()
	result.won = won
	result.reason = reason
	result.error = error
	result.events = battle_log.events
	return result


func _aborted(why: Dictionary) -> BattleResult:
	var result := BattleResult.new()
	result.abort = why
	result.events = battle_log.events
	return result

class_name Battle
extends RefCounted
## One battle, start to finish, simulated in one go with nothing shown. Hand
## it sides of combatants, each side with a Controller that picks its units'
## actions; `run` plays it out and returns the whole event battle_log.
##
## It knows no level, no scene and no network. An Encounter is one way to build
## one; a roguelike carrying hp from fight to fight, or an overworld starting a
## fight on contact, can build the sides itself and call `run` the same way.
##
## Every rule of a turn is in here: turn order (turn_order), legality
## (use_error), resolving a move (use), and the primitives effects are built
## from (deal_damage, heal, block, guard), which are the only things that log.
##
## An action is {"move": id, "targets": [ids]}: what a student's command
## "attack e1" means once StudentController has split it.

const WON := "All enemies defeated"
const LOST := "Party defeated"
const OUT_OF_TURNS := "Turn limit reached"

var sides: Array[BattleSide] = []
## Every combatant, side by side in side order. Dead ones stay.
var combatants: Array[Combatant] = []
## The side whose win or loss the result reports.
var player_side: int
var max_turns: int
## For anything random during the battle, so the same seed replays the same battle.
var rng: RandomNumberGenerator
## Whatever the controllers need from the host, such as the student's
## StrategyClient under "strategy". The battle itself never reads it.
var context: Dictionary
var turn: int = 0
var battle_log := BattleLog.new()

## The move `use` is resolving, so the primitives can say where an event came from.
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

		# 1. Whoever telegraphs does it now, before anyone acts.
		for unit in turn_order():
			unit.intent = controller_of(unit).plan(self, unit)
			if not unit.intent.is_empty():
				battle_log.intent(turn, unit, unit.intent.move, unit.intent.targets)

		# 2. Everyone acts in turn order; anyone who died earlier in the turn is skipped.
		for actor in turn_order():
			if not actor.is_alive():
				continue
			# A guard lasts until its unit acts again.
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
				# It still tried, usually at a target that died first; nothing happens.
				if move != null and not targets.is_empty() and not targets.has(null):
					battle_log.action(turn, actor, move, targets)
				continue

			# 3. Resolve it.
			battle_log.action(turn, actor, move, targets)
			use(move, actor, targets)

			# 4. After every action. Nothing stops a side hurting itself, so
			#    both ends are checked.
			if _others_wiped_out():
				return _end(turn, true, WON)
			if living(player_side).is_empty():
				return _end(turn, false, LOST)
	return _end(max_turns, false, OUT_OF_TURNS)


## Who acts this turn, in order: the living, fastest first. Ties go to whoever
## comes first in `combatants`, side by side in side order. The one place turn
## order lives.
func turn_order() -> Array[Combatant]:
	var order: Array[Combatant] = []
	for unit in combatants:
		if unit.is_alive():
			order.append(unit)
	# sort_custom is not stable, so the tie-break has to be spelled out.
	order.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if a.stats.speed != b.stats.speed:
			return a.stats.speed > b.stats.speed
		return combatants.find(a) < combatants.find(b))
	return order


func controller_of(unit: Combatant) -> Controller:
	return sides[unit.side].controller


## The living combatants of one side, in side order.
func living(side: int) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for unit in sides[side].combatants:
		if unit.is_alive():
			result.append(unit)
	return result


## The first living combatant on any other side, in turn order; null if none.
func first_living_opponent(unit: Combatant) -> Combatant:
	for other in turn_order():
		if other.side != unit.side:
			return other
	return null


## Null if no combatant has that id.
func find(id: Variant) -> Combatant:
	for unit in combatants:
		if unit.id == id:
			return unit
	return null


## Who a move lands on: the user itself for a SELF move, else the combatant
## with each id, null for an id nobody has. Empty if the move is unknown.
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


## Whether this unit may use this move on these targets. The one place a move
## and its targets are checked against each other. Empty if it is legal, else
## a message naming the unit and the move.
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


## The battle from one unit's point of view, in the shape of
## server/docs/runner.md: {turn, self, allies, enemies}. Allies include the
## unit itself; both lists hold only the living, in turn order.
func state_for(unit: Combatant) -> Dictionary:
	var allies: Array = []
	var enemies: Array = []
	for other in turn_order():
		(allies if other.side == unit.side else enemies).append(_view(other))
	return {"turn": turn, "self": _view(unit), "allies": allies, "enemies": enemies}


## Carries out a move use_error has already allowed. For each target in
## order: the move's effects in order, sharing one fresh MoveScratch, until one
## of them halts it. The one place a move is resolved.
func use(move: Move, user: Combatant, targets: Array[Combatant]) -> void:
	_resolving = move
	for target in targets:
		var scratch := MoveScratch.new()
		for effect in move.effects:
			if scratch.halted:
				break
			effect.apply(self, user, target, scratch)
	_resolving = null


## Hurts a combatant and logs it, and its death at 0. Its guard takes the
## damage first. A primitive. Returns the health it actually took off, less
## than amount if a guard took some or the target had less left.
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


## Heals a combatant, never past its maximum, and logs how much it got. A
## primitive. Returns how much it got.
func heal(target: Combatant, amount: int) -> int:
	var healed := mini(maxi(amount, 0), target.max_hp - target.hp)
	target.hp += healed
	battle_log.heal(turn, target, healed, _resolving)
	return healed


## Logs that a move had no effect on this target, and why. A primitive.
func block(target: Combatant, reason: String) -> void:
	battle_log.blocked(turn, target, reason, _resolving)


## Gives a combatant a guard: the next `amount` damage it takes before its
## next action is absorbed. Replaces any guard it had. A primitive.
func guard(target: Combatant, amount: int) -> void:
	target.guard = maxi(amount, 0)
	battle_log.guard(turn, target, target.guard, _resolving)


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
		"guard": unit.guard, "intent": unit.intent_command(), "moves": moves}


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

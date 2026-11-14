extends Node
## Battle rules against GDScript students, no server; exits 1 on failure.

var _failures := 0


func _ready() -> void:
	_pipeline_recordings()
	_rules()
	_commands()
	_stats()
	_student_errors()
	_seeded()
	_swapped()
	_crits()
	_level_rules()
	_campaign()
	print("ALL BATTLE CHECKS PASSED" if _failures == 0 else "%d BATTLE CHECK(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## The recorded fixtures must match the same strategies written in GDScript.
func _pipeline_recordings() -> void:
	var students := {"smoke": _first_enemy, "demo": _demo_win, "worm_test": _worm_crit}
	for level_id: String in ["camp", "burrow", "nest", "pecking_order", "gatehouse"]:
		students[level_id] = _campaign_student.bind("lowest")
	for level_id: String in students:
		var path := "res://tests/fixtures/%s.json" % level_id
		if not FileAccess.file_exists(path):
			print("skipped: %s is not recorded; see tests/smoke_submit.gd" % path)
			continue
		var recorded: Dictionary = ReplaySystem._whole_numbers_to_int(
			JSON.parse_string(FileAccess.get_file_as_string(path)))
		var result := _battle(level_id, students[level_id]).run()
		_check_events("%s, recorded through the server" % level_id, result.events, recorded.result.events)


func _rules() -> void:
	var passed := _battle("smoke", _pass).run()
	_check("always passing: lost", passed.won, false)
	_check("always passing: reason", passed.reason, Battle.OUT_OF_TURNS)
	_check("always passing: no error", passed.error, "")

	var lost := _battle("demo", _demo_lose).run()
	_check("knight sits out: lost", lost.won, false)
	_check("knight sits out: reason", lost.reason, Battle.LOST)

	var invalid := _battle("demo", _borrows_heal).run()
	_check("a move the unit does not know: error", invalid.error,
		"Knight tried to use \"heal\", which it does not know.")
	_check("a move the unit does not know: reason repeats it", invalid.reason, invalid.error)
	_check("a move the unit does not know: last event is end", invalid.events[-1].type, "end")

	var wrong := _battle("demo", _heals_enemy).run()
	_check("heal on an enemy: error", wrong.error, "Cleric tried to use Heal on Wraith, which is not an ally.")

	var nowhere := _battle("smoke", func(_s: Dictionary) -> Dictionary:
		return {"action": "attack e9"}).run()
	_check("a target not in the battle: error", nowhere.error,
		"Hero tried to use Attack on \"e9\", which is not in this battle.")


## Every move is a command, its id then up to its number of target ids.
func _commands() -> void:
	var errors := {
		"pass e1": "Hero tried to use Pass on someone, but it takes no target.",
		"attack": "Hero tried to use Attack without a target.",
		"attack e1 e1": "Hero tried to use Attack on 2 targets, but it takes at most 1.",
	}
	for command: String in errors:
		var result := _battle("smoke", func(_s: Dictionary) -> Dictionary: return {"action": command}).run()
		_check("\"%s\": error" % command, result.error, errors[command])

	var not_string := _battle("smoke", func(_s: Dictionary) -> Dictionary:
		return {"action": {"move": "pass"}}).run()
	_check("a command that is not a String: error", not_string.error,
		"Your decide() for Hero returned something that is not a String.")

	var spaced := _battle("smoke", func(s: Dictionary) -> Dictionary:
		return {"action": "  attack \t " + s.enemies[0].id + " "}).run()
	_check("extra spaces in a command are fine", spaced.won, true)

	# The knight cleaves both goblins; the cleric blocks.
	var cleaved := _battle("demo", func(s: Dictionary) -> Dictionary:
		return {"action": "cleave e1 e2" if s.self.id == "knight" else "block"}).run()
	var cleave_hits := cleaved.events.filter(func(e: Dictionary) -> bool:
		return e.type == "damage" and e.move == "cleave" and e.turn == 1)
	_check("cleave e1 e2: hits e1 then e2, for 70% of the knight's 6 strength",
		cleave_hits.map(func(e: Dictionary) -> Array: return [e.unit, e.amount]), [["e1", 4], ["e2", 4]])
	var cleave_action: Dictionary = cleaved.events.filter(func(e: Dictionary) -> bool:
		return e.type == "action" and e.move == "cleave")[0]
	_check("cleave e1 e2: the action names both", cleave_action.get("targets"), ["e1", "e2"])
	_check("cleave e1 e2: target is still the first", cleave_action.target, "e1")
	var dupe := _battle("demo", func(s: Dictionary) -> Dictionary:
		return {"action": "cleave e1 e1" if s.self.id == "knight" else "pass"}).run()
	_check("cleave e1 e1: error", dupe.error, "Knight tried to use Cleave on Goblin, which it already named.")
	var one := _battle("demo", func(s: Dictionary) -> Dictionary:
		return {"action": "cleave e1" if s.self.id == "knight" else "block e1"}).run()
	_check("cleave with one id is fine; block with one is not", one.error,
		"Cleric tried to use Block on someone, but it takes no target.")

	# Blocking every turn against a slime that hits for 1: nothing gets through.
	var blocked := _battle("smoke", func(_s: Dictionary) -> Dictionary: return {"action": "block"}).run()
	var guards := blocked.events.filter(func(e: Dictionary) -> bool: return e.type == "guard")
	_check("block: guards the hero for 100% of its 6 strength", [guards[0].unit, guards[0].amount, guards[0].move], ["hero", 6, "block"])
	var hits := blocked.events.filter(func(e: Dictionary) -> bool: return e.type == "damage")
	_check("block: every hit is absorbed", hits.all(func(e: Dictionary) -> bool:
		return e.amount == 0 and e.get("absorbed") == 1 and e.hp == 30), true)
	_check("block: and the battle runs out of turns", blocked.reason, Battle.OUT_OF_TURNS)

	var states: Dictionary = {}
	_battle("demo", func(s: Dictionary) -> Dictionary:
		if not states.has(s.self.id):
			states[s.self.id] = s
		return {"action": "pass"}).run()
	var knight: Dictionary = states.knight
	_check("the state shows intents as commands", knight.enemies.map(func(e: Dictionary) -> Variant: return e.intent),
		["drain cleric", "attack cleric", "attack cleric"])
	var cleave_view: Dictionary = knight.self.moves.filter(func(m: Dictionary) -> bool: return m.id == "cleave")[0]
	_check("the state says how many targets a move takes", [cleave_view.targets, knight.self.moves[-1].targets], [2, 0])
	_check("the state shows stats", [knight.self.strength, knight.self.magic, knight.self.speed], [6, 0, 4])


## Fastest first; equal speed keeps side order. Damage is a percent of a stat.
func _stats() -> void:
	var demo := _battle("demo", _demo_win).run()
	var first_turn := demo.events.filter(func(e: Dictionary) -> bool: return e.type == "action" and e.turn == 1)
	_check("demo turn 1: wraith (7), cleric (6), knight (4), goblins (3)",
		first_turn.map(func(e: Dictionary) -> String: return e.unit), ["e3", "cleric", "knight", "e1", "e2"])

	var smite: Dictionary = demo.events.filter(func(e: Dictionary) -> bool: return e.type == "damage" and e.move == "smite")[0]
	_check("smite: 170% of the knight's 6 strength", smite.amount, 10)
	var drain: Dictionary = demo.events.filter(func(e: Dictionary) -> bool: return e.type == "damage" and e.move == "drain")[0]
	_check("drain: 100% of the wraith's 3 magic", drain.amount, 3)

	var level: Level = load("res://data/levels/demo.tres")
	var battle := level.create_battle({StudentController.CONTEXT_KEY: ScriptedStudentCode.new(_pass)})
	battle.find("knight").stats.strength = 99
	var knight_def: UnitDef = load("res://data/units/knight.tres")
	_check("a combatant's stats are its own copy", knight_def.stats.strength, 6)


func _student_errors() -> void:
	var threw := _battle("smoke", func(_s: Dictionary) -> Dictionary:
		return {"action": null, "error": {"kind": "threw", "exception": "java.lang.IllegalStateException",
			"message": "boom", "in": "decide"}}).run()
	_check("student threw: error", threw.error, "Your decide() for Hero threw java.lang.IllegalStateException: boom")
	_check("student threw: lost", threw.won, false)

	var nulled := _battle("smoke", func(_s: Dictionary) -> Dictionary:
		return {"action": null, "error": {"kind": "returned_null", "message": "decide() returned null"}}).run()
	_check_contains("student returned null: error", nulled.error, "returned null for Hero")

	var timed := _battle("smoke", func(_s: Dictionary) -> Dictionary:
		return {"action": null, "error": {"kind": "timeout",
			"message": "did not return within 1000 ms; is there an infinite loop?"}}).run()
	_check("student timed out: error", timed.error,
		"Your decide() for Hero did not return within 1000 ms; is there an infinite loop?")

	var empty := _battle("smoke", func(_s: Dictionary) -> Dictionary:
		return {"action": "   "}).run()
	_check("empty command: error", empty.error,
		"Your decide() for Hero returned an empty command. Return \"pass\" to do nothing.")

	var level: Level = load("res://data/levels/smoke.tres")
	var client := ScriptedStudentCode.new(_first_enemy, {"error": {"kind": "threw",
		"exception": "java.lang.IllegalStateException", "message": "not ready", "in": "constructor"}})
	var ctor := level.create_battle({StudentController.CONTEXT_KEY: client}).run()
	_check("constructor threw: error", ctor.error,
		"Your Submission constructor threw java.lang.IllegalStateException: not ready")
	_check("constructor threw: ends on turn 1", ctor.events[-1].turn, 1)

	var gone := ScriptedStudentCode.new(func(_s: Dictionary) -> Dictionary: return {"abort": "no server"})
	var aborted := level.create_battle({StudentController.CONTEXT_KEY: gone}).run()
	_check("service gone mid-battle: aborted", aborted.abort.get("abort"), "no server")


func _seeded() -> void:
	var first := JSON.stringify(_battle("demo", _demo_win).run().to_dict(), "", false)
	var again := JSON.stringify(_battle("demo", _demo_win).run().to_dict(), "", false)
	_check("demo: the same code gives the same battle", first == again, true)
	var other: Level = (load("res://data/levels/demo.tres") as Level).duplicate()
	other.rng_seed += 1
	var client := ScriptedStudentCode.new(_demo_win)
	var reseeded := JSON.stringify(other.create_battle({StudentController.CONTEXT_KEY: client}).run().to_dict(), "", false)
	_check("demo: another seed gives another battle", first != reseeded, true)


## The same UnitDefs work on either side.
func _swapped() -> void:
	var result := _battle("swapped", _first_enemy).run()
	var spawns := result.events.filter(func(e: Dictionary) -> bool: return e.type == "spawn")
	_check("swapped: the goblin is on the hero side", spawns[0].name + "/" + spawns[0].team, "Goblin/hero")
	_check("swapped: the knight is on the enemy side", spawns[1].name + "/" + spawns[1].team, "Knight/enemy")
	var intent: Dictionary = result.events.filter(func(e: Dictionary) -> bool: return e.type == "intent")[0]
	_check("swapped: the knight telegraphs at the goblin", intent.target, "goblin")
	_check("swapped: ends", result.events[-1].type, "end")
	print("  swapped: %s" % result.reason)


## A right crit answer adds the move's crit effects; a wrong, missing or garbled one is a plain hit, never an error.
func _crits() -> void:
	for level_id: String in ["worm_test", "swarm_test"]:
		var answer := _worm_answer if level_id == "worm_test" else _swarm_answer
		var commands := {
			"right": func(s: Dictionary) -> String: return "attack e1 | crit %s" % JSON.stringify(answer.call(s.enemies[0].body)),
			"wrong": func(s: Dictionary) -> String: return "attack e1 | crit %d" % (answer.call(s.enemies[0].body) + 1000),
			"none": func(_s: Dictionary) -> String: return "attack e1",
			"garbled": func(_s: Dictionary) -> String: return "attack e1 | crit [oops",
		}
		var damage := {}
		for kind: String in commands:
			var command: Callable = commands[kind]
			var result := _battle(level_id, func(s: Dictionary) -> Dictionary: return {"action": command.call(s)}).run()
			_check("%s, %s answer: no error" % [level_id, kind], result.error, "")
			damage[kind] = _damage_on(result, "e1", 1)
		_check("%s: right 6 + 3 crit, wrong 6, none 6, garbled 6" % level_id,
			[damage.right, damage.wrong, damage.none, damage.garbled], [9, 6, 6, 6])

		# Right every turn: the body re-rolls after each crit, and the student keeps up.
		var bodies: Array = []
		var every := _battle(level_id, func(s: Dictionary) -> Dictionary:
			bodies.append(s.enemies[0].body)
			return {"action": "attack e1 | crit %s" % JSON.stringify(answer.call(s.enemies[0].body))}).run()
		_check("%s: a crit every turn" % level_id, [1, 2, 3].map(func(t: int) -> int: return _damage_on(every, "e1", t)), [9, 9, 9])
		_check("%s: the body re-rolls after a crit" % level_id, bodies[0] != bodies[1] and bodies[1] != bodies[2], true)
		var again := _battle(level_id, func(s: Dictionary) -> Dictionary:
			return {"action": "attack e1 | crit %s" % JSON.stringify(answer.call(s.enemies[0].body))}).run()
		_check("%s: the same code gives the same battle" % level_id,
			JSON.stringify(every.to_dict()) == JSON.stringify(again.to_dict()), true)

	var states: Array = []
	_battle("worm_test", func(s: Dictionary) -> Dictionary:
		states.append(s)
		return {"action": "pass"}).run()
	var worm: Dictionary = states[0].enemies[0]
	_check("the state shows a body and its crit", [worm.body.kind, worm.crit.id], ["linked_list", "middle"])
	_check("a unit without a body shows null", [states[0].self.body, states[0].self.crit], [null, null])
	_check("a level without rules shows none", states[0].rules, [])
	var demo_state: Array = []
	_battle("demo", func(s: Dictionary) -> Dictionary:
		demo_state.append(s)
		return {"action": "pass"}).run()
	_check("existing units have no body", demo_state[0].enemies.map(func(e: Dictionary) -> Variant: return e.body), [null, null, null])


## A gate bounces a move whose answer is wrong; a bonus adds to a right one. Only the player's side is judged.
func _level_rules() -> void:
	var median := func(s: Dictionary) -> String: return JSON.stringify(_median_of_bodies(s))
	var gate := {
		"right": func(s: Dictionary) -> String: return "attack e1 | median " + median.call(s),
		"wrong": func(s: Dictionary) -> String: return "attack e1 | median %s" % (_median_of_bodies(s) + 1000),
		"none": func(_s: Dictionary) -> String: return "attack e1",
		"with a crit": func(s: Dictionary) -> String:
			return "attack e1 | crit %d | median %s" % [_worm_answer(s.enemies[0].body), median.call(s)],
	}
	var outcomes := {}
	for kind: String in gate:
		var command: Callable = gate[kind]
		var result := _battle("median_gate_test", func(s: Dictionary) -> Dictionary: return {"action": command.call(s)}).run()
		_check("median gate, %s: no error" % kind, result.error, "")
		var bounced := result.events.any(func(e: Dictionary) -> bool: return e.type == "blocked" and e.turn == 1)
		outcomes[kind] = [_damage_on(result, "e1", 1), bounced]
	_check("median gate: right lands, wrong and none bounce, a crit stacks",
		[outcomes.right, outcomes.wrong, outcomes.none, outcomes["with a crit"]], [[6, false], [0, true], [0, true], [9, false]])
	var bounce := _battle("median_gate_test", func(_s: Dictionary) -> Dictionary: return {"action": "attack e1"}).run()
	var blocked: Dictionary = bounce.events.filter(func(e: Dictionary) -> bool: return e.type == "blocked")[0]
	_check("median gate: the bounce names the move and says why", [blocked.unit, blocked.move, blocked.reason],
		["e1", "attack", "The median was wrong, so the attack bounced off."])
	_check("median gate: the enemies still hit back", _damage_on(bounce, "hero", 1), 4)
	var rule_state: Array = []
	_battle("median_gate_test", func(s: Dictionary) -> Dictionary:
		rule_state.append(s)
		return {"action": "pass"}).run()
	_check("the state lists the rules", rule_state[0].rules.map(func(r: Dictionary) -> Array: return [r.id, r.answer]),
		[["median", true]])

	var lowest := _battle("lowest_first_test", func(_s: Dictionary) -> Dictionary: return {"action": "attack e1"}).run()
	var other := _battle("lowest_first_test", func(_s: Dictionary) -> Dictionary: return {"action": "attack e2"}).run()
	_check("lowest first: the goblin (least hp) takes 6 + 3, the worm 6", [_damage_on(lowest, "e1", 1), _damage_on(other, "e2", 1)], [9, 6])
	_check("lowest first: no answer needed, no error", [lowest.error, other.error], ["", ""])
	_check("lowest first: the enemies get no bonus", _damage_on(lowest, "hero", 1), 3 + 2)


## Each campaign level is won faster with its new idea; the gatehouse is not won without it at all.
func _campaign() -> void:
	var starter := func(s: Dictionary) -> Dictionary: return {"action": "attack " + s.enemies[0].id}
	_check("camp: the starter code wins", _battle("camp", starter).run().won, true)
	for level_id: String in ["burrow", "nest", "pecking_order"]:
		var slow := _battle(level_id, _campaign_student.bind("answers" if level_id == "pecking_order" else "naive")).run()
		var fast := _battle(level_id, _campaign_student.bind("lowest")).run()
		_check("%s: wins with and without its idea" % level_id, [slow.won, fast.won], [true, true])
		_check("%s: its idea wins in fewer turns (%d vs %d)" % [level_id, _turns(fast), _turns(slow)],
			_turns(fast) < _turns(slow), true)
	_check("gatehouse: no median, no win", _battle("gatehouse", _campaign_student.bind("naive")).run().won, false)
	_check("gatehouse: the median wins", _battle("gatehouse", _campaign_student.bind("lowest")).run().won, true)


## Returns the turn a battle ended on.
func _turns(result: BattleResult) -> int:
	return result.events[-1].get("turn", 0)


## Returns the hp a unit lost on one turn, summed over every damage event.
func _damage_on(result: BattleResult, unit_id: String, at_turn: int) -> int:
	var total := 0
	for event in result.events:
		if event.type == "damage" and event.unit == unit_id and event.turn == at_turn:
			total += event.amount
	return total


func _battle(level_id: String, decide: Callable) -> Battle:
	var level: Level = load("res://data/levels/%s.tres" % level_id)
	return level.create_battle({StudentController.CONTEXT_KEY: ScriptedStudentCode.new(decide)})


# --- Students ---

func _first_enemy(state: Dictionary) -> Dictionary:
	return {"action": "attack " + state.enemies[0].id}


func _pass(_state: Dictionary) -> Dictionary:
	return {"action": "pass"}


## fixtures/demo_win.java: smite the first enemy; the cleric heals whoever is badly hurt.
func _demo_win(state: Dictionary) -> Dictionary:
	var me: Dictionary = state.self
	if _knows(me, "heal"):
		var worst: Variant = null
		for ally: Dictionary in state.allies:
			if worst == null or ally.maxHp - ally.hp > worst.maxHp - worst.hp:
				worst = ally
		if worst != null and worst.hp * 5 < worst.maxHp * 3:
			return {"action": "heal " + worst.id}
	var target: String = state.enemies[0].id
	return {"action": ("smite " if _knows(me, "smite") else "attack ") + target}


## The knight passes; the cleric chips away alone.
func _demo_lose(state: Dictionary) -> Dictionary:
	if state.self.id == "knight":
		return {"action": "pass"}
	return {"action": "attack " + state.enemies[0].id}


## Uses an ally's heal as if it were its own.
func _borrows_heal(state: Dictionary) -> Dictionary:
	for ally: Dictionary in state.allies:
		if _knows(ally, "heal"):
			return {"action": "heal " + state.self.id}
	return {"action": "pass"}


## Heals an enemy.
func _heals_enemy(state: Dictionary) -> Dictionary:
	var enemy: String = state.enemies[0].id
	return {"action": ("heal " if _knows(state.self, "heal") else "attack ") + enemy}


## fixtures/worm_crit.java: attacks the worm with its middle value every turn.
func _worm_crit(state: Dictionary) -> Dictionary:
	return {"action": "attack e1 | crit %d" % _worm_answer(state.enemies[0].body)}


## Follows next from head, as a student has to, and returns the middle value.
func _worm_answer(body: Dictionary) -> int:
	var found := _follow(body)
	return found[found.size() / 2]


func _swarm_answer(body: Dictionary) -> int:
	var found: Array = body.values
	return found.find(found.min())


func _follow(body: Dictionary) -> Array:
	var found: Array = []
	var at: Variant = body.head
	while at != null:
		found.append(body.nodes[at].value)
		at = body.nodes[at].next
	return found


func _median_of_bodies(state: Dictionary) -> float:
	var found: Array = []
	for enemy: Dictionary in state.enemies:
		found.append_array(_follow(enemy.body) if enemy.body.kind == "linked_list" else enemy.body.values)
	found.sort()
	var half := found.size() / 2
	return found[half] if found.size() % 2 == 1 else (found[half - 1] + found[half]) / 2.0


## The cleric heals anyone under half hp; the rest attack, "naive" the first enemy, "answers" it with every answer, "lowest" the least hp with every answer.
func _campaign_student(state: Dictionary, kind: String) -> Dictionary:
	var me: Dictionary = state.self
	if _knows(me, "heal"):
		for ally: Dictionary in state.allies + [me]:
			if ally.hp * 2 < ally.maxHp:
				return {"action": "heal " + ally.id}
	var target: Dictionary = state.enemies[0]
	if kind == "lowest":
		for enemy: Dictionary in state.enemies:
			if enemy.hp < target.hp:
				target = enemy
	var command: String = "attack " + target.id
	if kind == "naive":
		return {"action": command}
	if target.crit != null:
		command += " | crit %d" % (_worm_answer(target.body) if target.crit.id == "middle" else _swarm_answer(target.body))
	for rule: Dictionary in state.rules:
		if rule.id == "median":
			command += " | median " + JSON.stringify(_median_of_bodies(state))
	return {"action": command}


func _knows(unit: Dictionary, move_id: String) -> bool:
	return unit.moves.any(func(m: Dictionary) -> bool: return m.id == move_id)


# --- Checks ---

func _check(label: String, actual: Variant, expected: Variant) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		print("ok: ", label)
	else:
		_failures += 1
		print("FAIL: %s (got %s, want %s)" % [label, actual, expected])


func _check_contains(label: String, actual: String, needle: String) -> void:
	_check(label + " (contains \"%s\")" % needle, needle in actual, true)


## Same events, same keys, same order, same values.
func _check_events(label: String, actual: Array, expected: Array) -> void:
	for i in maxi(actual.size(), expected.size()):
		var got := JSON.stringify(actual[i], "", false) if i < actual.size() else "<nothing>"
		var want := JSON.stringify(expected[i], "", false) if i < expected.size() else "<nothing>"
		if got != want:
			_failures += 1
			print("FAIL: %s: event %d\n  got  %s\n  want %s" % [label, i, got, want])
			return
	print("ok: %s: all %d events match" % [label, expected.size()])

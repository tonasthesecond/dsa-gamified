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
	print("ALL BATTLE CHECKS PASSED" if _failures == 0 else "%d BATTLE CHECK(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## The recorded fixtures must match the same strategies written in GDScript.
func _pipeline_recordings() -> void:
	for level: String in ["smoke", "demo"]:
		var path := "res://tests/fixtures/%s.json" % level
		if not FileAccess.file_exists(path):
			print("skipped: %s is not recorded; see dev/smoke_submit.gd" % path)
			continue
		var recorded: Dictionary = Simulation._whole_numbers_to_int(
			JSON.parse_string(FileAccess.get_file_as_string(path)))
		var result := _battle(level, _first_enemy if level == "smoke" else _demo_win).run()
		_check_events("%s, recorded through the server" % level, result.events, recorded.result.events)


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

	var encounter: Encounter = load("res://data/levels/demo.tres")
	var battle := encounter.create_battle({StudentController.CONTEXT_KEY: ScriptedStrategyClient.new(_pass)})
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

	var encounter: Encounter = load("res://data/levels/smoke.tres")
	var client := ScriptedStrategyClient.new(_first_enemy, {"error": {"kind": "threw",
		"exception": "java.lang.IllegalStateException", "message": "not ready", "in": "constructor"}})
	var ctor := encounter.create_battle({StudentController.CONTEXT_KEY: client}).run()
	_check("constructor threw: error", ctor.error,
		"Your Submission constructor threw java.lang.IllegalStateException: not ready")
	_check("constructor threw: ends on turn 1", ctor.events[-1].turn, 1)

	var gone := ScriptedStrategyClient.new(func(_s: Dictionary) -> Dictionary: return {"abort": "no server"})
	var aborted := encounter.create_battle({StudentController.CONTEXT_KEY: gone}).run()
	_check("service gone mid-battle: aborted", aborted.abort.get("abort"), "no server")


func _seeded() -> void:
	var first := JSON.stringify(_battle("demo", _demo_win).run().to_dict(), "", false)
	var again := JSON.stringify(_battle("demo", _demo_win).run().to_dict(), "", false)
	_check("demo: the same code gives the same battle", first == again, true)
	var other: Encounter = (load("res://data/levels/demo.tres") as Encounter).duplicate()
	other.rng_seed += 1
	var client := ScriptedStrategyClient.new(_demo_win)
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


func _battle(level: String, decide: Callable) -> Battle:
	var encounter: Encounter = load("res://data/levels/%s.tres" % level)
	return encounter.create_battle({StudentController.CONTEXT_KEY: ScriptedStrategyClient.new(decide)})


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

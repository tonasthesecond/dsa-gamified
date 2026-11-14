extends Node
## The save file, the campaign's locks and the map's zones, no server; exits 1 on failure.

const FILE := "user://smoke_progress.json"

var _failures := 0


func _ready() -> void:
	_clean()
	_save_file()
	_broken_files()
	_campaign()
	await _map()
	_clean()
	Progress.use_file(Progress.DEFAULT_PATH)
	print("ALL PROGRESS CHECKS PASSED" if _failures == 0 else "%d PROGRESS CHECK(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Clears and drafts survive a reload; a slower win never replaces a faster one.
func _save_file() -> void:
	Progress.use_file(FILE)
	_check("fresh: nothing cleared", Progress.is_cleared("camp"), false)
	_check("fresh: no best turns", Progress.best_turns("camp"), 0)
	_check("fresh: the draft is the fallback", Progress.draft("camp", "starter"), "starter")
	Progress.mark_cleared("camp", 5)
	Progress.mark_cleared("camp", 7)
	_check("a slower win keeps the best", Progress.best_turns("camp"), 5)
	Progress.mark_cleared("camp", 3)
	_check("a faster win replaces it", Progress.best_turns("camp"), 3)
	Progress.save_draft("camp", "class Submission {}")
	Progress.use_file(FILE)
	_check("reload: still cleared", [Progress.is_cleared("camp"), Progress.best_turns("camp")], [true, 3])
	_check("reload: the draft is kept", Progress.draft("camp", "starter"), "class Submission {}")
	_check("reload: other levels untouched", Progress.is_cleared("burrow"), false)
	_check("no temp file left", FileAccess.file_exists(FILE + ".tmp"), false)


## A corrupt or foreign file starts fresh and is kept as .bak, never lost.
func _broken_files() -> void:
	for contents: String in ["{not json", "[1, 2]", "{\"version\": 99, \"cleared\": {}, \"drafts\": {}}",
			"{\"version\": 1, \"cleared\": [], \"drafts\": {}}"]:
		_write(FILE, contents)
		Progress.use_file(FILE)
		_check("broken %s: starts fresh" % contents, Progress.is_cleared("camp"), false)
		_check("broken %s: kept as .bak" % contents, FileAccess.get_file_as_string(FILE + ".bak"), contents)
		Progress.mark_cleared("camp", 4)
		_check("broken %s: saves again" % contents, FileAccess.file_exists(FILE), true)
		DirAccess.remove_absolute(FILE + ".bak")


## Each stage opens once what it requires is cleared; every stage names a real level.
func _campaign() -> void:
	var campaign: Campaign = load("res://data/campaign.tres")
	var cleared: Dictionary = {}
	var is_cleared := func(level_id: String) -> bool: return cleared.has(level_id)
	_check("the first stage is open", campaign.is_unlocked(campaign.stages[0].level, is_cleared), true)
	var known: Array[String] = []
	for stage in campaign.stages:
		_check("%s: its level exists" % stage.level, ResourceLoader.exists("res://data/levels/%s.tres" % stage.level), true)
		for required in stage.requires:
			_check("%s: requires an earlier stage (%s)" % [stage.level, required], required in known, true)
		if not stage.requires.is_empty():
			_check("%s: locked before its requirements" % stage.level, campaign.is_unlocked(stage.level, is_cleared), false)
		for required in stage.requires:
			cleared[required] = true
		_check("%s: open after them" % stage.level, campaign.is_unlocked(stage.level, is_cleared), true)
		known.append(stage.level)
		var spec: Level = load("res://data/levels/%s.tres" % stage.level)
		_check("%s: has starter code" % stage.level, FileAccess.file_exists(spec.starter_code), true)
		if FileAccess.file_exists(spec.starter_code):
			_check_contains("%s: the starter is a Submission" % stage.level,
				FileAccess.get_file_as_string(spec.starter_code), "public class Submission implements Strategy")
	_check("a level outside the campaign is open", campaign.is_unlocked("demo", is_cleared), true)


## Every zone is a campaign stage and the other way round, painted from Progress.
func _map() -> void:
	_clean()
	Progress.use_file(FILE)
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var stages: Array = main.campaign.stages.map(func(stage: CampaignStage) -> String: return stage.level)
	var zoned: Array = main.zones().map(func(zone: Area2D) -> String: return zone.get_meta("level"))
	stages.sort()
	zoned.sort()
	_check("every stage has a zone and every zone a stage", zoned, stages)
	_check("fresh map: camp open, burrow locked", [main.is_open("camp"), main.is_open("burrow")], [true, false])
	var burrow_name: Label = main.get_node("Overworld/BurrowZone/Name")
	_check_contains("fresh map: burrow says locked", burrow_name.text, "(locked)")
	Progress.mark_cleared("camp", 4)
	main.paint_zones()
	_check("after camp: burrow open", main.is_open("burrow"), true)
	_check("after camp: burrow no longer locked", "(locked)" in burrow_name.text, false)
	_check_contains("after camp: camp shows its turns", main.get_node("Overworld/CampZone/Name").text, "4 turns")
	_check("after camp: camp is green", main.get_node("Overworld/CampZone/Fill").color, main.CLEARED_COLOR)
	var screen: BattleScreen = main.get_node("%BattleScreen")
	screen.open("burrow")
	_check("no draft: the editor shows the level's starter", screen.code_panel.source(),
		FileAccess.get_file_as_string("res://data/starters/burrow.java"))
	screen.open("demo")
	_check("no starter: the editor shows CodePanel's", screen.code_panel.source(), screen.code_panel.starter)
	screen.open("camp")
	Progress.save_draft("camp", "// mine")
	screen.open("camp")
	_check("a draft: the editor shows it", screen.code_panel.source(), "// mine")
	screen.code_panel.set_source("// edited")
	screen.code_panel.get_node("%Leave").pressed.emit()
	_check("leaving saves the draft", Progress.draft("camp", ""), "// edited")
	main.queue_free()


func _clean() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(FILE + suffix):
			DirAccess.remove_absolute(FILE + suffix)


func _write(file_path: String, contents: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


# --- Checks ---

func _check(label: String, actual: Variant, expected: Variant) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		print("ok: ", label)
	else:
		_failures += 1
		print("FAIL: %s (got %s, want %s)" % [label, actual, expected])


func _check_contains(label: String, actual: String, needle: String) -> void:
	_check(label + " (contains \"%s\")" % needle, needle in actual, true)

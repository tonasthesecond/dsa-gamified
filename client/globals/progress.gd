extends Node
## The save file: cleared levels and code drafts, in user:// (IndexedDB on web).

const VERSION := 1
const DEFAULT_PATH := "user://progress.json"

var path: String = DEFAULT_PATH
var _data: Dictionary = _fresh()


func _ready() -> void:
	use_file(DEFAULT_PATH)


## Switches to another save file and loads it; tests use their own.
func use_file(file_path: String) -> void:
	path = file_path
	_data = _read(file_path)


## True once a battle on this level has been won.
func is_cleared(level_id: String) -> bool:
	return _data.cleared.has(level_id)


## The fewest turns a win on this level took, or 0 if it is not cleared.
func best_turns(level_id: String) -> int:
	return int(_data.cleared.get(level_id, {}).get("turns", 0))


## Records a win, keeping the fewest turns.
func mark_cleared(level_id: String, turns: int) -> void:
	var best := best_turns(level_id)
	if best > 0 and best <= turns:
		return
	_data.cleared[level_id] = {"turns": turns, "at": Time.get_datetime_string_from_system(true)}
	_save()


## The player's last code for this level, or `fallback` if there is none.
func draft(level_id: String, fallback: String) -> String:
	return _data.drafts.get(level_id, fallback)


## Keeps the player's code for this level.
func save_draft(level_id: String, source: String) -> void:
	if _data.drafts.get(level_id) == source:
		return
	_data.drafts[level_id] = source
	_save()


# --- File ---

func _fresh() -> Dictionary:
	return {"version": VERSION, "cleared": {}, "drafts": {}}


func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return _fresh()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if parsed is Dictionary and parsed.get("version") == float(VERSION) \
			and parsed.get("cleared") is Dictionary and parsed.get("drafts") is Dictionary:
		return parsed
	# Unreadable or from another version: keep it aside rather than lose it.
	DirAccess.rename_absolute(file_path, file_path + ".bak")
	push_warning("progress: %s was unreadable, kept as %s.bak" % [file_path, file_path])
	return _fresh()


func _save() -> void:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("progress: could not write %s: %s" % [temp, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	DirAccess.rename_absolute(temp, path)

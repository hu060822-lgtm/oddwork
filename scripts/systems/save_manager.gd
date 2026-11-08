class_name SaveManager
extends RefCounted
## JSON save with basic safety: write to a temp file then swap, keep the last
## good file as .bak, and quarantine a corrupt file instead of crashing.

var path: String = "user://misrule_save.json"
var last_error: String = ""


func _init(p_path: String = "") -> void:
	if p_path != "":
		path = p_path


func load_data(defaults: Dictionary) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		return defaults.duplicate(true)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "open failed: %s" % error_string(FileAccess.get_open_error())
		return defaults.duplicate(true)
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		last_error = "corrupt save, moved aside"
		DirAccess.rename_absolute(path, path + ".corrupt")
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			var fb := FileAccess.open(bak, FileAccess.READ)
			if fb:
				var j2 := JSON.new()
				if j2.parse(fb.get_as_text()) == OK and j2.data is Dictionary:
					return _merge(defaults, j2.data)
		return defaults.duplicate(true)
	return _merge(defaults, json.data)


func save_data(data: Dictionary) -> bool:
	last_error = ""
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "write failed: %s" % error_string(FileAccess.get_open_error())
		push_warning("MISRULE save failed: " + last_error)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		last_error = "rename failed: %s" % error_string(err)
		push_warning("MISRULE save failed: " + last_error)
		return false
	return true


## Fill in keys missing from older saves without losing anything.
static func _merge(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	for k in loaded:
		if out.has(k) and out[k] is Dictionary and loaded[k] is Dictionary:
			out[k] = _merge(out[k], loaded[k])
		else:
			out[k] = loaded[k]
	return out

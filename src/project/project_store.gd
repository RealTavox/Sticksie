class_name ProjectStore
## Saves and loads projects as JSON files and remembers the last opened one, so the app resumes
## where the user stopped.

## Folder of the project files and of the note which one was open last. Tests and screenshot
## runs point it elsewhere, so they never touch the user's projects.
static var directory := "user://projects"

## Ends the name of an exported project file. Still a .json, which every device's file picker
## knows.
const EXPORT_SUFFIX := ".sticksie.json"


## Saves `project`, giving it a new file name on its first save.
static func save(project: StitchProject) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	if project.path.is_empty():
		project.path = _new_path(project.name)
	return _write_json(project.path, project.to_dict())


## The project saved at `path`, or null if it can't be read.
static func load_project(path: String) -> StitchProject:
	var data: Variant = _read_json(path)
	if not data is Dictionary:
		return null
	var project := StitchProject.from_dict(data)
	if project != null:
		project.path = path
	return project


## Saved projects, most recently saved first: [{path, name, saved_at, width, height, preview}],
## `preview` an Image or null (see preview()).
static func list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for file_name in DirAccess.get_files_at(directory):
		if not file_name.ends_with(".json"):
			continue
		var path := directory.path_join(file_name)
		var data: Variant = _read_json(path)
		if data is Dictionary:
			var pattern_data: Variant = data.get("pattern", {})
			if not pattern_data is Dictionary:
				pattern_data = {}
			result.append({"path": path, "name": str(data.get("name", file_name)),
					"saved_at": str(data.get("saved_at", "")),
					"width": int(pattern_data.get("width", 0)),
					"height": int(pattern_data.get("height", 0)),
					"preview": preview(data)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.saved_at > b.saved_at)
	return result


## The picture shown for a saved project (its `to_dict()` form) in the project list, or null.
## For now the pixel art the project was made from; the place to switch to a picture of the
## stitching progress later.
static func preview(data: Dictionary) -> Image:
	var png := Marshalls.base64_to_raw(str(data.get("image_png", "")))
	var image := Image.new()
	if png.is_empty() or image.load_png_from_buffer(png) != OK:
		return null
	return image


## Gives the project saved at `path` a new name. The file keeps its name and its save time, so
## the list order stays.
static func rename(path: String, new_name: String) -> Error:
	new_name = new_name.strip_edges()
	if new_name.is_empty():
		return ERR_INVALID_PARAMETER
	var data: Variant = _read_json(path)
	if not data is Dictionary:
		return ERR_FILE_CORRUPT
	data.name = new_name
	return _write_json(path, data)


## The file name an exported project gets: "Hypsi Anhänger" becomes "hypsi_anhaenger.sticksie.json".
static func export_name(project_name: String) -> String:
	return _slug(project_name) + EXPORT_SUFFIX


## A project file someone exported (a saved project's JSON as it is), not yet saved here; null if
## it isn't a project this app can read. Saving it gives it a file of its own, even if a project
## of the same name exists.
static func read_export(bytes: PackedByteArray) -> StitchProject:
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return null
	return StitchProject.from_dict(json.data)


## Deletes the project saved at `path` for good; forgets it as the last opened project.
static func delete(path: String) -> Error:
	var error := DirAccess.remove_absolute(path)
	if error == OK and last_project_path() == path:
		remember_last("")
	return error


static func last_project_path() -> String:
	var config := ConfigFile.new()
	if config.load(Preferences.path()) != OK:
		return ""
	return str(config.get_value("projects", "last", ""))


static func remember_last(path: String) -> void:
	var config := ConfigFile.new()
	config.load(Preferences.path())  # Missing file: start empty.
	config.set_value("projects", "last", path)
	config.save(Preferences.path())


## Writes to a temporary file first, so a crash while saving leaves the previous save intact.
static func _write_json(path: String, data: Dictionary) -> Error:
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(temp_path, path)


static func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("%s is not valid JSON: %s" % [path, json.get_error_message()])
		return null
	return json.data


## A file name from the project name that isn't taken yet: "Hypsi Anhänger" becomes
## "hypsi_anhaenger.json", then "hypsi_anhaenger_2.json", …
static func _new_path(project_name: String) -> String:
	var slug := _slug(project_name)
	var path := directory.path_join(slug + ".json")
	var number := 2
	while FileAccess.file_exists(path):
		path = directory.path_join("%s_%d.json" % [slug, number])
		number += 1
	return path


## The project name as a file name: lower case, umlauts spelt out, anything else but letters and
## digits as "_"; "projekt" if nothing is left.
static func _slug(project_name: String) -> String:
	var slug := ""
	var name := project_name.to_lower().replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
	for ch in name:
		slug += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	slug = slug.strip_edges().trim_prefix("_").trim_suffix("_")
	return "projekt" if slug.is_empty() else slug

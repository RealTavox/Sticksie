class_name ProjectStore
## Saves and loads projects as JSON files and remembers the last opened one, so the app resumes
## where the user stopped.

## Folder of the project files and of the note which one was open last. Tests and screenshot
## runs point it elsewhere, so they never touch the user's projects.
static var directory := "user://projects"


## Saves `project`, giving it a new file name on its first save. Writes to a temporary file
## first, so a crash while saving leaves the previous save intact.
static func save(project: StitchProject) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	if project.path.is_empty():
		project.path = _new_path(project.name)
	var temp_path := project.path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(project.to_dict()))
	error = file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(temp_path, project.path)


## The project saved at `path`, or null if it can't be read.
static func load_project(path: String) -> StitchProject:
	var data: Variant = _read_json(path)
	if not data is Dictionary:
		return null
	var project := StitchProject.from_dict(data)
	if project != null:
		project.path = path
	return project


## Saved projects, most recently saved first: [{path, name, saved_at}].
static func list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for file_name in DirAccess.get_files_at(directory):
		if not file_name.ends_with(".json"):
			continue
		var path := directory.path_join(file_name)
		var data: Variant = _read_json(path)
		if data is Dictionary:
			result.append({"path": path, "name": str(data.get("name", file_name)),
					"saved_at": str(data.get("saved_at", ""))})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.saved_at > b.saved_at)
	return result


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
	var slug := ""
	var name := project_name.to_lower().replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
	for ch in name:
		slug += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	slug = slug.strip_edges().trim_prefix("_").trim_suffix("_")
	if slug.is_empty():
		slug = "projekt"
	var path := directory.path_join(slug + ".json")
	var number := 2
	while FileAccess.file_exists(path):
		path = directory.path_join("%s_%d.json" % [slug, number])
		number += 1
	return path

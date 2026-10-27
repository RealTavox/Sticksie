class_name Preferences
## App-wide user preferences (DESIGN.md "Einstellungen"), kept in settings.cfg next to the
## project files, so test runs with another ProjectStore.directory don't touch them.


## Most cells the thread may skip on the back before the app asks for a new thread;
## StitchPlanner.UNLIMITED (the default) means never.
static func max_skip() -> int:
	return int(_load().get_value("stitching", "max_skip", StitchPlanner.UNLIMITED))


static func set_max_skip(value: int) -> void:
	_store("max_skip", value)


## Whether rows are worked from the top down (default) or from the bottom up.
static func top_to_bottom() -> bool:
	return bool(_load().get_value("stitching", "top_to_bottom", true))


## Whether stitching starts on the left (default) or on the right side.
static func start_left() -> bool:
	return bool(_load().get_value("stitching", "start_left", true))


## Sets the start corner: the row order and the start side together.
static func set_direction(p_top_to_bottom: bool, p_start_left: bool) -> void:
	_store("top_to_bottom", p_top_to_bottom)
	_store("start_left", p_start_left)


static func path() -> String:
	return ProjectStore.directory.path_join("settings.cfg")


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(path())  # Missing file: defaults.
	return config


static func _store(key: String, value: Variant) -> void:
	var config := _load()
	config.set_value("stitching", key, value)
	DirAccess.make_dir_recursive_absolute(ProjectStore.directory)
	config.save(path())

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


## Whether crosses are stitched one by one (English) instead of the Danish method (default).
static func english() -> bool:
	return bool(_load().get_value("stitching", "english", false))


static func set_english(value: bool) -> void:
	_store("english", value)


## Advanced: whether the user fixed the leg order and needle direction (see StitchStyle); off by
## default, then the app picks the cleanest back.
static func needle_fixed() -> bool:
	return bool(_load().get_value("stitching", "needle_fixed", false))


## With a fixed style: "/" first (default) or "\" first.
static func slash_first() -> bool:
	return bool(_load().get_value("stitching", "slash_first", true))


## With a fixed style: every leg from the top hole instead of the bottom one (default).
static func needle_from_top() -> bool:
	return bool(_load().get_value("stitching", "needle_from_top", false))


static func set_stitch_style(fixed: bool, p_slash_first: bool, from_top: bool) -> void:
	_store("needle_fixed", fixed)
	_store("slash_first", p_slash_first)
	_store("needle_from_top", from_top)


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

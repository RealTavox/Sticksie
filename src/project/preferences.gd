class_name Preferences
## App-wide user preferences (DESIGN.md "Einstellungen"), kept in settings.cfg next to the
## project files, so test runs with another ProjectStore.directory don't touch them.


## Most cells the thread may skip on the back before the app asks for a new thread;
## StitchPlanner.UNLIMITED (the default) means never.
static func max_skip() -> int:
	return int(_load().get_value("stitching", "max_skip", StitchPlanner.UNLIMITED))


static func set_max_skip(value: int) -> void:
	var config := _load()
	config.set_value("stitching", "max_skip", value)
	DirAccess.make_dir_recursive_absolute(ProjectStore.directory)
	config.save(path())


static func path() -> String:
	return ProjectStore.directory.path_join("settings.cfg")


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(path())  # Missing file: defaults.
	return config

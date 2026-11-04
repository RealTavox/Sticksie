class_name Preferences
## App-wide user preferences (DESIGN.md "Einstellungen"), kept in settings.cfg next to the
## project files, so test runs with another ProjectStore.directory don't touch them.

const DEFAULT_LIGHT_AZIMUTH := 315.0
const DEFAULT_LIGHT_ELEVATION := 55.0


## The skip limit unless the user chose another: a new thread after more than 3 cells, the usual
## choice and the one with the least thread.
const DEFAULT_MAX_SKIP := 3


## Most cells the thread may skip on the back before the app asks for a new thread
## (DEFAULT_MAX_SKIP by default); StitchPlanner.UNLIMITED means never.
static func max_skip() -> int:
	return int(_load().get_value("stitching", "max_skip", DEFAULT_MAX_SKIP))


static func set_max_skip(value: int) -> void:
	_store("max_skip", value)


## Most holes from the one the thread last went down through that counting still starts there
## (PositionHint.DEFAULT_MAX_HOLES by default); further away it starts at a findable stitch.
static func max_hole_count() -> int:
	return int(_load().get_value("stitching", "max_hole_count", PositionHint.DEFAULT_MAX_HOLES))


static func set_max_hole_count(value: int) -> void:
	_store("max_hole_count", value)


## Whether rows are worked from the top down (default) or from the bottom up.
static func top_to_bottom() -> bool:
	return bool(_load().get_value("stitching", "top_to_bottom", true))


## Whether stitching starts on the left (default) or on the right side.
static func start_left() -> bool:
	return bool(_load().get_value("stitching", "start_left", true))


## Whether the app picks the start corner per thread for the least thread on the back
## (default) instead of top_to_bottom() and start_left().
static func auto_start() -> bool:
	return bool(_load().get_value("stitching", "auto_start", true))


## Sets the start corner: the row order and the start side together, or `auto`.
static func set_direction(p_top_to_bottom: bool, p_start_left: bool, auto := false) -> void:
	_store("top_to_bottom", p_top_to_bottom)
	_store("start_left", p_start_left)
	_store("auto_start", auto)


## Whether crosses are stitched one by one (English) instead of the Danish method (default).
static func english() -> bool:
	return bool(_load().get_value("stitching", "english", false))


static func set_english(value: bool) -> void:
	_store("english", value)


## Whether the Danish return pass goes over every run of adjacent cells in one step (default)
## instead of blocks of at most max_block().
static func whole_back() -> bool:
	return bool(_load().get_value("stitching", "whole_back", true))


static func set_whole_back(value: bool) -> void:
	_store("whole_back", value)


## Most stitches in one block (default StitchPlanner.DEFAULT_MAX_BLOCK).
static func max_block() -> int:
	return maxi(int(_load().get_value("stitching", "max_block", StitchPlanner.DEFAULT_MAX_BLOCK)), 1)


static func set_max_block(value: int) -> void:
	_store("max_block", value)


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


## Where the light on fabric and thread comes from: degrees clockwise from the top of the
## screen (default from the top left) and degrees above the fabric (default fairly high).
static func light_azimuth() -> float:
	return float(_load().get_value("view", "light_azimuth", DEFAULT_LIGHT_AZIMUTH))


static func light_elevation() -> float:
	return float(_load().get_value("view", "light_elevation", DEFAULT_LIGHT_ELEVATION))


static func set_light(azimuth: float, elevation: float) -> void:
	_store("light_azimuth", azimuth, "view")
	_store("light_elevation", elevation, "view")


## Whether the stitching screen shows the symbol window (StepSymbols); on by default.
static func step_symbols() -> bool:
	return bool(_load().get_value("ui", "step_symbols", true))


static func set_step_symbols(value: bool) -> void:
	_store("step_symbols", value, "ui")


## Whether the symbol window shows its cards' last frames at once instead of animating them.
static func step_symbols_still() -> bool:
	return bool(_load().get_value("ui", "step_symbols_still", false))


static func set_step_symbols_still(value: bool) -> void:
	_store("step_symbols_still", value, "ui")


## How much faster than normal the symbol window's animations play (1 = normal).
static func step_symbols_speed() -> float:
	return float(_load().get_value("ui", "step_symbols_speed", 1.0))


static func set_step_symbols_speed(value: float) -> void:
	_store("step_symbols_speed", value, "ui")


## Whether the screen is laid out for touch (a full-screen view with round buttons that open
## overlays) instead of the desktop layout with toolbar and side panel. Defaults to touch on
## phones and tablets, in the app or in their browser.
static func touch_mode() -> bool:
	var handheld := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	return bool(_load().get_value("ui", "touch", handheld))


static func set_touch_mode(value: bool) -> void:
	_store("touch", value, "ui")


## How much bigger than normal everything on screen is drawn (1 = as designed): text, buttons,
## windows and the pattern alike.
static func ui_scale() -> float:
	return float(_load().get_value("ui", "scale", 1.0))


static func set_ui_scale(value: float) -> void:
	_store("scale", value, "ui")


## Which touch panels are open while stitching: the stitching buttons' and the texts'. Closed
## until the user opens them; each stays as it was left for the next time.
static func stitch_list_open() -> bool:
	return bool(_load().get_value("ui", "stitch_list_open", false))


static func stitch_text_open() -> bool:
	return bool(_load().get_value("ui", "stitch_text_open", false))


static func set_stitch_panels(list_open: bool, text_open: bool) -> void:
	_store("stitch_list_open", list_open, "ui")
	_store("stitch_text_open", text_open, "ui")


## Whether the introduction was seen to its end or cancelled; until then it opens by itself.
static func tutorial_seen() -> bool:
	return bool(_load().get_value("ui", "tutorial_seen", false))


static func set_tutorial_seen(value: bool) -> void:
	_store("tutorial_seen", value, "ui")


## Developer mode (Entwicklertools in the settings): shows the developer button under the menu
## button. Only in debug builds; release builds leave the developer tools out.
static func developer_mode() -> bool:
	return OS.is_debug_build() and bool(_load().get_value("dev", "developer_mode", false))


static func set_developer_mode(value: bool) -> void:
	_store("developer_mode", value, "dev")


static func path() -> String:
	return ProjectStore.directory.path_join("settings.cfg")


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(path())  # Missing file: defaults.
	return config


static func _store(key: String, value: Variant, section := "stitching") -> void:
	var config := _load()
	config.set_value(section, key, value)
	DirAccess.make_dir_recursive_absolute(ProjectStore.directory)
	config.save(path())

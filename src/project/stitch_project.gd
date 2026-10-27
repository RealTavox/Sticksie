class_name StitchProject
extends RefCounted
## One stitching project: the source image, the colours left as fabric, the pattern and the
## progress. Saved as JSON by ProjectStore; see to_dict() for the format.

## Save format version. A file with a higher number comes from a newer app and is not loaded.
## 1: first version. 2: adds progress.max_skip and progress.manual_thread_starts (format 1 files
## get no limit and no manual thread changes).
const FORMAT := 2

var name: String
## Where the project is saved (user://…), empty until it has been saved once.
var path := ""
var image: Image
## Thread codes the user marked as fabric (not stitched).
var fabric_codes := PackedStringArray()
## The pattern without the fabric colours: what gets stitched.
var pattern: Pattern
var session: StitchSession


static func create(p_name: String, p_image: Image, palette: FlossPalette) -> StitchProject:
	var project := StitchProject.new()
	project.name = p_name
	project.image = p_image
	project.rebuild(palette)
	return project


## Rebuilds the pattern from the image and the fabric choice. Starts a new session, so earlier
## progress is gone.
func rebuild(palette: FlossPalette) -> void:
	pattern = PatternImporter.from_image(image, palette, fabric_codes)
	session = StitchSession.new(pattern)


## The pattern with every colour of the image, fabric colours included.
func full_pattern(palette: FlossPalette) -> Pattern:
	return PatternImporter.from_image(image, palette)


## Whole crosses stitched, over all threads.
func finished_crosses() -> int:
	var total := 0
	for thread in pattern.thread_codes.size():
		total += session.finished_crosses(thread)
	return total


## The saved form. The pattern is stored as well as the image, so a later change of the thread
## palette or the colour matching can't change a pattern that is already being stitched. Progress
## is restored from the cell states (see StitchSession.restore()); `done_steps` (finished steps
## per thread) is only informational. Also stored: the skip limit and manual thread changes.
func to_dict() -> Dictionary:
	var done := {}
	for thread in pattern.thread_codes.size():
		if session.done_count(thread) > 0:
			done[pattern.thread_codes[thread]] = session.done_count(thread)
	return {
		"format": FORMAT,
		"name": name,
		"saved_at": Time.get_datetime_string_from_system(),
		"image_png": Marshalls.raw_to_base64(image.save_png_to_buffer()),
		"fabric_codes": Array(fabric_codes),
		"pattern": {
			"width": pattern.width,
			"height": pattern.height,
			"thread_codes": Array(pattern.thread_codes),
			"cells": Marshalls.raw_to_base64(pattern.cells.to_byte_array()),
		},
		"progress": {
			"top_to_bottom": session.top_to_bottom,
			"start_left": session.start_left,
			"max_skip": session.max_skip,
			"manual_thread_starts": session.manual_starts_by_code(),
			"done_steps": done,
			"cell_states": Marshalls.raw_to_base64(session.cell_states()),
		},
	}


## Reads the saved form; returns null (and logs why) if it is incomplete, inconsistent or from a
## newer app.
static func from_dict(data: Dictionary) -> StitchProject:
	var format := int(data.get("format", 0))
	if format < 1 or format > FORMAT:
		push_warning("Project format %d not supported (this app reads 1–%d)." % [format, FORMAT])
		return null
	var pattern_data: Dictionary = data.get("pattern", {})
	var progress: Dictionary = data.get("progress", {})
	var image := Image.new()
	var png := Marshalls.base64_to_raw(str(data.get("image_png", "")))
	if png.is_empty() or image.load_png_from_buffer(png) != OK:
		push_warning("Project image could not be read.")
		return null

	var pattern := Pattern.new()
	pattern.width = int(pattern_data.get("width", 0))
	pattern.height = int(pattern_data.get("height", 0))
	pattern.thread_codes = PackedStringArray(pattern_data.get("thread_codes", []))
	pattern.cells = Marshalls.base64_to_raw(str(pattern_data.get("cells", ""))).to_int32_array()
	var cell_count := pattern.width * pattern.height
	if cell_count <= 0 or pattern.cells.size() != cell_count:
		push_warning("Project pattern has %d cells, expected %d." % [pattern.cells.size(), cell_count])
		return null
	for index in pattern.cells:
		if index < Pattern.EMPTY or index >= pattern.thread_codes.size():
			push_warning("Project pattern refers to thread %d of %d." % [index, pattern.thread_codes.size()])
			return null
	var states := Marshalls.base64_to_raw(str(progress.get("cell_states", "")))
	if states.size() != cell_count:
		push_warning("Project progress has %d cells, expected %d." % [states.size(), cell_count])
		return null

	var project := StitchProject.new()
	project.name = str(data.get("name", "Projekt"))
	project.image = image
	project.fabric_codes = PackedStringArray(data.get("fabric_codes", []))
	project.pattern = pattern
	project.session = StitchSession.new(pattern)
	project.session.top_to_bottom = bool(progress.get("top_to_bottom", true))
	project.session.start_left = bool(progress.get("start_left", true))
	project.session.max_skip = int(progress.get("max_skip", StitchPlanner.UNLIMITED))
	var manual_starts: Variant = progress.get("manual_thread_starts", {})
	if manual_starts is Dictionary:
		project.session.restore_manual_starts(manual_starts)
	project.session.restore(states)
	return project

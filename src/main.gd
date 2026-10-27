extends Control
## Start screen: open a pixel-art image, show it as a cross-stitch pattern with its threads, and
## stitch one thread at a time with step-by-step guidance. Every change is saved right away; on
## start the last project opens again.
##
## Command line (after `--`): `--projects-dir=<path>` keeps projects in another folder (for test
## runs), `--open=<path>` opens an image as a new project, `--stitch=<code>` starts stitching that
## thread, `--steps=<n>` confirms n steps, `--screenshot=<png path>` saves a screenshot after a few
## frames and quits.

const SAMPLE_PATH := "res://samples/hypsi_anhaenger.png"
## Images bigger than this on either side are refused (most likely a photo, not pixel art).
const MAX_SIDE := 500
const BUTTON_HEIGHT := 48.0
const SWATCH_SIZE := Vector2(28, 28)
## Smallest cell size when stitching starts, so the current block is easy to see.
const STITCH_CELL_PX := 24.0
const CREDIT := "Garnfarben: craft-color-codes von MakeBead (makebead.com), CC BY 4.0"

var _palette: FlossPalette
var _project: StitchProject
## Pattern with every colour of the image, for the colour list.
var _full_pattern: Pattern
## Thread index in the project's pattern being stitched, or -1 on the overview.
var _stitch_thread := -1

var _open_button: Button
var _sample_button: Button
var _projects_button: MenuButton
## Project file paths, indexed like the items of the projects menu.
var _project_paths: Array[String] = []
var _overview_button: Button
var _info_label: Label
var _body: BoxContainer
var _view: PatternView
var _side: VBoxContainer
var _color_list: VBoxContainer
var _stitch_panel: StitchPanel
var _file_dialog: FileDialog


func _ready() -> void:
	_palette = FlossPalette.dmc()
	_build_ui()
	resized.connect(_update_layout)
	_update_layout()
	var opens_image := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--projects-dir="):
			ProjectStore.directory = arg.trim_prefix("--projects-dir=")
		opens_image = opens_image or arg.begins_with("--open=")
	if not opens_image:
		var last := ProjectStore.last_project_path()
		if not last.is_empty() and FileAccess.file_exists(last):
			_open_project(last)
	_handle_cmdline()


func _build_ui() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.png ; PNG-Bilder"])
	_file_dialog.use_native_dialog = true
	_file_dialog.file_selected.connect(_open_image)
	add_child(_file_dialog)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)

	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	_open_button = _make_toolbar_button("Bild öffnen…", _file_dialog.popup_centered_ratio.bind(0.8))
	toolbar.add_child(_open_button)
	_sample_button = _make_toolbar_button("Beispiel", _open_image.bind(SAMPLE_PATH))
	toolbar.add_child(_sample_button)
	_projects_button = MenuButton.new()
	_projects_button.text = "Projekte"
	_projects_button.flat = false
	_projects_button.custom_minimum_size.y = BUTTON_HEIGHT
	_projects_button.focus_mode = Control.FOCUS_NONE
	_projects_button.about_to_popup.connect(_fill_projects_menu)
	_projects_button.get_popup().id_pressed.connect(
			func(id: int) -> void: _open_project(_project_paths[id]))
	toolbar.add_child(_projects_button)
	_overview_button = _make_toolbar_button("◂ Übersicht", _leave_stitching)
	_overview_button.visible = false
	toolbar.add_child(_overview_button)
	_info_label = Label.new()
	_info_label.text = "Öffne ein Pixelart-Bild (PNG). Ein Pixel wird ein Kreuzstich."
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar.add_child(_info_label)

	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	_view = PatternView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.tapped.connect(_on_view_tapped)
	_body.add_child(_view)

	_side = VBoxContainer.new()
	_body.add_child(_side)
	var heading := Label.new()
	heading.text = "Garnfarben (DMC) · Stiche"
	_side.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(scroll)
	_color_list = VBoxContainer.new()
	_color_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_color_list)
	var credit := Label.new()
	credit.text = CREDIT
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit.add_theme_font_size_override("font_size", 12)
	credit.modulate.a = 0.6
	_side.add_child(credit)

	_stitch_panel = StitchPanel.new()
	_stitch_panel.visible = false
	_stitch_panel.next_pressed.connect(_next_step)
	_stitch_panel.previous_pressed.connect(_previous_step)
	_body.add_child(_stitch_panel)


func _make_toolbar_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


## Portrait: pattern above the side panel; landscape: side panel on the right.
func _update_layout() -> void:
	var portrait := size.y > size.x
	_body.vertical = portrait
	var side_size := Vector2(0.0, size.y * 0.38) if portrait else Vector2(minf(380.0, size.x * 0.4), 0.0)
	_side.custom_minimum_size = side_size
	_stitch_panel.custom_minimum_size = side_size


func _unhandled_key_input(event: InputEvent) -> void:
	if _stitch_thread < 0 or not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_SPACE:
		_next_step()
		get_viewport().set_input_as_handled()
	elif key == KEY_BACKSPACE:
		_previous_step()
		get_viewport().set_input_as_handled()


func _open_image(path: String) -> void:
	var image: Image
	if path.begins_with("res://"):
		image = load(path) as Image
	else:
		image = Image.load_from_file(path)
	if image == null or image.is_empty():
		_info_label.text = "Bild konnte nicht geladen werden."
		return
	if image.get_width() > MAX_SIDE or image.get_height() > MAX_SIDE:
		_info_label.text = "Bild ist zu groß (%d × %d), höchstens %d Pixel pro Seite." % [
				image.get_width(), image.get_height(), MAX_SIDE]
		return
	if image.is_compressed():
		image.decompress()
	_set_project(StitchProject.create(path.get_file().get_basename(), image, _palette))
	_save()


func _open_project(path: String) -> void:
	var project := ProjectStore.load_project(path)
	if project == null:
		_info_label.text = "Projekt konnte nicht geladen werden."
		return
	_set_project(project)
	ProjectStore.remember_last(path)


func _set_project(project: StitchProject) -> void:
	_leave_stitching()
	_project = project
	_full_pattern = project.full_pattern(_palette)
	_show_pattern(false)


func _show_pattern(keep_view: bool) -> void:
	_view.show_pattern(_project.pattern, _palette, keep_view)
	_show_info()
	_fill_color_list()


## Saves the project; called after every change, so nothing is lost when the app closes.
func _save() -> void:
	var error := ProjectStore.save(_project)
	if error != OK:
		_info_label.text = "Speichern fehlgeschlagen: %s" % error_string(error)
		return
	ProjectStore.remember_last(_project.path)


func _show_info() -> void:
	var pattern := _project.pattern
	var text := "%s · %d × %d Felder · %d Farben · %d Stiche" % [_project.name,
			pattern.width, pattern.height, pattern.thread_codes.size(), pattern.total_stitches()]
	var done := _project.finished_crosses()
	if done > 0:
		text += " · %d %% fertig" % floori(100.0 * done / pattern.total_stitches())
	_info_label.text = text


func _fill_projects_menu() -> void:
	var popup := _projects_button.get_popup()
	popup.clear()
	_project_paths.clear()
	for entry in ProjectStore.list():
		popup.add_item("%s  (%s)" % [entry.name, str(entry.saved_at).replace("T", " ").left(16)],
				_project_paths.size())
		_project_paths.append(entry.path)
	if _project_paths.is_empty():
		popup.add_item("Noch keine Projekte")
		popup.set_item_disabled(0, true)


## One row per thread of the image, most stitches first.
func _fill_color_list() -> void:
	for child in _color_list.get_children():
		child.queue_free()
	var counts := _full_pattern.stitch_counts()
	var order := range(counts.size())
	order.sort_custom(func(a: int, b: int) -> bool: return counts[a] > counts[b])
	for i: int in order:
		var floss := _palette.find_code(_full_pattern.thread_codes[i])
		_color_list.add_child(_make_color_row(floss, counts[i]))


func _make_color_row(floss: FlossColor, count: int) -> Control:
	var session := _project.session
	var thread := _project.pattern.thread_codes.find(floss.code)
	var row := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = floss.color
	swatch.custom_minimum_size = SWATCH_SIZE
	row.add_child(swatch)
	var code_label := Label.new()
	code_label.text = floss.code
	code_label.custom_minimum_size.x = 56.0
	row.add_child(code_label)
	var name_label := Label.new()
	name_label.text = floss.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	var count_label := Label.new()
	count_label.text = str(count)
	if thread >= 0 and session.done_count(thread) > 0:
		count_label.text = "%d / %d" % [session.finished_crosses(thread), count]
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size.x = 56.0
	row.add_child(count_label)
	var fabric_box := CheckBox.new()
	fabric_box.text = "Stoff"
	fabric_box.button_pressed = _project.fabric_codes.has(floss.code)
	fabric_box.focus_mode = Control.FOCUS_NONE
	# Changing the fabric rebuilds the pattern, which would lose the stitching progress.
	fabric_box.disabled = session.has_progress()
	fabric_box.tooltip_text = ("Geht nicht mehr, es wurde schon gestickt." if fabric_box.disabled
			else "Diese Farbe nicht sticken, hier bleibt der Stoff frei.")
	fabric_box.toggled.connect(_on_fabric_toggled.bind(floss.code))
	row.add_child(fabric_box)
	var stitch_button := Button.new()
	stitch_button.text = "Sticken ▸"
	stitch_button.focus_mode = Control.FOCUS_NONE
	stitch_button.disabled = thread < 0
	stitch_button.pressed.connect(_enter_stitching.bind(thread))
	row.add_child(stitch_button)
	return row


func _on_fabric_toggled(pressed: bool, code: String) -> void:
	var fabric_codes := _project.fabric_codes
	if pressed and not fabric_codes.has(code):
		fabric_codes.append(code)
	elif not pressed and fabric_codes.has(code):
		fabric_codes.remove_at(fabric_codes.find(code))
	_project.fabric_codes = fabric_codes
	_project.rebuild(_palette)
	_show_pattern(true)
	_save()


func _enter_stitching(thread: int) -> void:
	_stitch_thread = thread
	_side.visible = false
	_stitch_panel.visible = true
	_open_button.visible = false
	_sample_button.visible = false
	_projects_button.visible = false
	_overview_button.visible = true
	var step := _project.session.current_step(thread)
	if step != null:
		_view.focus_step(step, STITCH_CELL_PX)
	# After zooming, so the reference stitch is panned into view as well.
	_refresh_stitching()


func _leave_stitching() -> void:
	if _stitch_thread < 0:
		return
	_stitch_thread = -1
	_stitch_panel.visible = false
	_side.visible = true
	_open_button.visible = true
	_sample_button.visible = true
	_projects_button.visible = true
	_overview_button.visible = false
	_view.show_preview()
	_show_info()
	_fill_color_list()


func _refresh_stitching() -> void:
	var thread := _stitch_thread
	var session := _project.session
	var pattern := _project.pattern
	var step := session.current_step(thread)
	var states := session.cell_states()
	var hint: PositionHint = null
	var position_text := ""
	if step != null:
		hint = PositionHint.find(pattern, states, step, session.last_cell(thread))
		position_text = StitchPanel.describe_position(step, hint, pattern, states)
	_view.show_progress(states, step, hint)
	if step != null:
		_view.ensure_visible(step, hint)
	var floss := _palette.find_code(pattern.thread_codes[thread])
	_stitch_panel.show_step(floss, step, position_text, session.done_count(thread),
			session.steps(thread).size(), session.finished_crosses(thread),
			pattern.stitch_counts()[thread])
	_info_label.text = ""


func _next_step() -> void:
	if _stitch_thread >= 0 and _project.session.current_step(_stitch_thread) != null:
		_project.session.advance(_stitch_thread)
		_refresh_stitching()
		_save()


func _previous_step() -> void:
	if _stitch_thread >= 0 and _project.session.done_count(_stitch_thread) > 0:
		_project.session.go_back(_stitch_thread)
		_refresh_stitching()
		_save()


func _on_view_tapped() -> void:
	_next_step()


func _handle_cmdline() -> void:
	var screenshot_path := ""
	var stitch_code := ""
	var steps := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--open="):
			_open_image(arg.trim_prefix("--open="))
		elif arg.begins_with("--stitch="):
			stitch_code = arg.trim_prefix("--stitch=")
		elif arg.begins_with("--steps="):
			steps = arg.trim_prefix("--steps=").to_int()
		elif arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
	if not stitch_code.is_empty() and _project != null and _project.pattern.thread_codes.has(stitch_code):
		await get_tree().process_frame  # Let the screen lay out first, as before a real tap.
		_enter_stitching(_project.pattern.thread_codes.find(stitch_code))
		for i in steps:
			_next_step()
	if screenshot_path.is_empty():
		return
	for i in 3:
		await get_tree().process_frame
	# Low processor mode draws only when something changed, so ask for one more frame.
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	get_tree().quit()

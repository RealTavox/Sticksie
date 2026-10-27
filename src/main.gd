extends Control
## Start screen: open a pixel-art image, show it as a cross-stitch pattern with its threads, and
## stitch one thread at a time with step-by-step guidance. Every change is saved right away; on
## start the last project opens again.
##
## Command line (after `--`): `--projects-dir=<path>` keeps projects in another folder (for test
## runs), `--open=<path>` opens an image as a new project, `--max-skip=<n>` sets the skip limit
## (-1: none), `--start=<corner>` sets the start corner (top-left, top-right, bottom-left,
## bottom-right), `--settings` opens the settings dialog (`--advanced`: with the advanced part open),
## `--method=<english|danish>` sets the stitch method, `--needle=<auto|bottom|top>` and
## `--first-leg=<slash|backslash>` the stitch style (bottom/top/first-leg fix it), `--projects` the project list, `--stitch=<code>` starts stitching that thread, `--steps=<n>` confirms n steps, `--back` shows the back while stitching, `--screenshot=<png path>` saves a screenshot after a few
## frames and quits.

const SAMPLE_PATH := "res://samples/hypsi_anhaenger.png"
## Images bigger than this on either side are refused (most likely a photo, not pixel art).
const MAX_SIDE := 500
const BUTTON_HEIGHT := 48.0
const SWATCH_SIZE := Vector2(28, 28)
## Smallest cell size when stitching starts, so the current block is easy to see.
const STITCH_CELL_PX := 24.0
## Start corners in the settings: label and (top_to_bottom, start_left).
const START_CORNERS := [
	["Oben links: Reihen nach rechts, dann nach unten", true, true],
	["Oben rechts: Reihen nach links, dann nach unten", true, false],
	["Unten links: Reihen nach rechts, dann nach oben", false, true],
	["Unten rechts: Reihen nach links, dann nach oben", false, false],
]
const METHODS := [
	"Dänisch: erst die Halbstiche einer Reihe, dann zurück die Gegenstiche",
	"Englisch: jedes Kreuz gleich ganz fertig, eins nach dem anderen",
]
const NEEDLE_MODES := [
	"Automatisch: so, dass die Rückseite am saubersten wird (empfohlen)",
	"Fest: Reihenfolge und Richtung selbst wählen",
]
const LEG_ORDERS := ["Erst / dann \\", "Erst \\ dann /"]
const NEEDLE_STARTS := ["Nadel immer unten hoch (Schenkel von unten nach oben)",
		"Nadel immer oben hoch (Schenkel von oben nach unten)"]
const CREDIT := "Garnfarben: craft-color-codes von MakeBead (makebead.com), CC BY 4.0"

var _palette: FlossPalette
var _project: StitchProject
## Pattern with every colour of the image, for the colour list.
var _full_pattern: Pattern
## Thread index in the project's pattern being stitched, or -1 on the overview.
var _stitch_thread := -1
var _style := StitchStyle.new()

var _open_button: Button
var _sample_button: Button
var _projects_button: Button
var _project_browser: ProjectBrowser
var _settings_dialog: AcceptDialog
var _limit_box: CheckBox
var _corner_option: OptionButton
var _limit_spin: SpinBox
var _method_option: OptionButton
var _advanced_button: Button
var _advanced_box: VBoxContainer
var _needle_option: OptionButton
var _leg_option: OptionButton
var _needle_start_option: OptionButton
var _overview_button: Button
var _side_button: Button
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
	_apply_style()
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
	_projects_button = _make_toolbar_button("Projekte", _show_projects)
	toolbar.add_child(_projects_button)
	toolbar.add_child(_make_toolbar_button("Einstellungen", _show_settings))
	_overview_button = _make_toolbar_button("◂ Übersicht", _leave_stitching)
	_overview_button.visible = false
	toolbar.add_child(_overview_button)
	_side_button = _make_toolbar_button("Rückseite", _toggle_back_side)
	_side_button.visible = false
	toolbar.add_child(_side_button)
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
	_stitch_panel.new_thread_toggled.connect(_toggle_new_thread)
	_body.add_child(_stitch_panel)
	_build_settings_dialog()
	_project_browser = ProjectBrowser.new()
	_project_browser.open_requested.connect(_open_project)
	_project_browser.project_renamed.connect(_on_project_renamed)
	_project_browser.project_deleted.connect(_on_project_deleted)
	add_child(_project_browser)


func _build_settings_dialog() -> void:
	_settings_dialog = AcceptDialog.new()
	_settings_dialog.title = "Einstellungen"
	_settings_dialog.ok_button_text = "Übernehmen"
	_settings_dialog.add_cancel_button("Abbrechen")
	_settings_dialog.confirmed.connect(_apply_settings)
	add_child(_settings_dialog)
	var content := VBoxContainer.new()
	_settings_dialog.add_child(content)
	var method_label := Label.new()
	method_label.text = "Stichmethode:"
	content.add_child(method_label)
	_method_option = _make_option(METHODS)
	content.add_child(_method_option)
	content.add_child(HSeparator.new())
	var corner_label := Label.new()
	corner_label.text = "Anfangen in der Ecke:"
	content.add_child(corner_label)
	_corner_option = _make_option(START_CORNERS.map(func(corner: Array) -> String: return corner[0]))
	content.add_child(_corner_option)
	var corner_note := Label.new()
	corner_note.text = ("Fläche für Fläche: Die Ecke bestimmt, wo es losgeht und welcher Abschnitt\n"
			+ "bei gleichem Abstand zuerst kommt. Eine Reihe beginnt trotzdem am näheren Ende,\n"
			+ "wenn der Faden dort schon ist.")
	corner_note.modulate.a = 0.7
	content.add_child(corner_note)
	content.add_child(HSeparator.new())
	_limit_box = CheckBox.new()
	_limit_box.text = "Faden automatisch wechseln, wenn er auf der Rückseite mehr als"
	content.add_child(_limit_box)
	var row := HBoxContainer.new()
	content.add_child(row)
	_limit_spin = SpinBox.new()
	_limit_spin.min_value = 0
	_limit_spin.max_value = 30
	_limit_spin.value = 3
	row.add_child(_limit_spin)
	var unit := Label.new()
	unit.text = "Felder überspringen müsste."
	row.add_child(unit)
	var note := Label.new()
	note.text = ("Aus: Der Faden wird nie automatisch gewechselt, er darf beliebig weit springen.\n"
			+ "Üblich sind 2–3 Felder: längere Fäden auf der Rückseite verhaken sich und scheinen durch.\n"
			+ "Einen neuen Faden kannst du beim Sticken jederzeit selbst nehmen.")
	note.modulate.a = 0.7
	content.add_child(note)
	_limit_box.toggled.connect(func(on: bool) -> void: _limit_spin.editable = on)
	content.add_child(HSeparator.new())
	_build_advanced_settings(content)


## The advanced part, closed at first so the dialog stays short: how each cross is worked.
func _build_advanced_settings(content: VBoxContainer) -> void:
	_advanced_button = Button.new()
	_advanced_button.toggle_mode = true
	_advanced_button.flat = true
	_advanced_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_advanced_button.custom_minimum_size.y = BUTTON_HEIGHT
	_advanced_button.toggled.connect(_show_advanced)
	content.add_child(_advanced_button)
	_advanced_box = VBoxContainer.new()
	content.add_child(_advanced_box)
	var needle_label := Label.new()
	needle_label.text = "Stichführung (welcher Schenkel zuerst, wo die Nadel hochkommt):"
	_advanced_box.add_child(needle_label)
	_needle_option = _make_option(NEEDLE_MODES)
	_needle_option.item_selected.connect(func(_index: int) -> void: _update_needle_options())
	_advanced_box.add_child(_needle_option)
	_leg_option = _make_option(LEG_ORDERS)
	_advanced_box.add_child(_leg_option)
	_needle_start_option = _make_option(NEEDLE_STARTS)
	_advanced_box.add_child(_needle_start_option)
	var note := Label.new()
	note.text = ("Automatisch: erst /, dann \\. Die Nadel kommt immer so hoch, dass auf der Rückseite\n"
			+ "nur kurze senkrechte Stiche bleiben, in beide Richtungen.\n"
			+ "Fest: jeder Schenkel genau so, wie gewählt. Auf der Rückseite kann der Faden dann\n"
			+ "schräg über zwei Felder laufen. Nicht mitten im Projekt wechseln, sonst liegen die\n"
			+ "oberen Schenkel nicht mehr gleich.")
	note.modulate.a = 0.7
	_advanced_box.add_child(note)
	_show_advanced(false)


func _show_advanced(open: bool) -> void:
	_advanced_button.set_pressed_no_signal(open)
	_advanced_button.text = ("▾ " if open else "▸ ") + "Erweitert"
	_advanced_box.visible = open
	_settings_dialog.reset_size()


## Leg order and needle start only count for a fixed style.
func _update_needle_options() -> void:
	var fixed := _needle_option.selected == 1
	_leg_option.disabled = not fixed
	_needle_start_option.disabled = not fixed


func _make_option(items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size.y = BUTTON_HEIGHT
	for item: String in items:
		option.add_item(item)
	return option


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


func _show_settings() -> void:
	var limit := Preferences.max_skip()
	_limit_box.button_pressed = limit != StitchPlanner.UNLIMITED
	_limit_spin.editable = _limit_box.button_pressed
	if limit != StitchPlanner.UNLIMITED:
		_limit_spin.value = limit
	_corner_option.selected = _corner_index(Preferences.top_to_bottom(), Preferences.start_left())
	_method_option.selected = 1 if Preferences.english() else 0
	_needle_option.selected = 1 if Preferences.needle_fixed() else 0
	_leg_option.selected = 0 if Preferences.slash_first() else 1
	_needle_start_option.selected = 1 if Preferences.needle_from_top() else 0
	_update_needle_options()
	_settings_dialog.popup_centered()


## Index into START_CORNERS of a row order and start side.
static func _corner_index(top_to_bottom: bool, start_left: bool) -> int:
	return (0 if top_to_bottom else 2) + (0 if start_left else 1)


## Stores the preferences and replans the open project; stitched cells stay stitched.
func _apply_settings() -> void:
	var limit := int(_limit_spin.value) if _limit_box.button_pressed else StitchPlanner.UNLIMITED
	Preferences.set_max_skip(limit)
	var corner: Array = START_CORNERS[_corner_option.selected]
	Preferences.set_direction(corner[1], corner[2])
	Preferences.set_english(_method_option.selected == 1)
	Preferences.set_stitch_style(_needle_option.selected == 1, _leg_option.selected == 0,
			_needle_start_option.selected == 1)
	_apply_style()
	if _project == null:
		return
	_apply_preferences()
	_save()
	if _stitch_thread >= 0:
		_refresh_stitching()
	else:
		_fill_color_list()


## Replans the open project for the current preferences; stitched cells stay stitched.
func _apply_preferences() -> void:
	_project.session.set_max_skip(Preferences.max_skip())
	_project.session.set_direction(Preferences.top_to_bottom(), Preferences.start_left())
	_project.session.set_english(Preferences.english())


## Hands the leg order and needle holes from the preferences to the view and the guide texts.
func _apply_style() -> void:
	_style = StitchStyle.from_preferences()
	_view.style = _style
	_stitch_panel.style = _style


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
	_apply_preferences()
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


func _show_projects() -> void:
	_project_browser.current_path = _project.path if _project != null else ""
	_project_browser.open()


## The project list renamed a file; the open project takes the name, or its next save would
## bring the old one back.
func _on_project_renamed(path: String, new_name: String) -> void:
	if _project != null and _project.path == path:
		_project.name = new_name
		_show_info()


## The project list deleted a file; if it was the open project, the screen goes back to empty.
func _on_project_deleted(path: String) -> void:
	if _project == null or _project.path != path:
		return
	_leave_stitching()
	_project = null
	_full_pattern = null
	_view.clear()
	for child in _color_list.get_children():
		child.queue_free()
	_info_label.text = "Projekt gelöscht. Öffne ein Bild oder ein anderes Projekt."


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
	_apply_preferences()
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
	_side_button.visible = true
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
	_side_button.visible = false
	_set_back_side(false)
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
	var thread_start := StitchSession.ThreadStart.NONE
	if step != null:
		hint = PositionHint.find(pattern, states, step, session.last_cell(thread))
		thread_start = session.thread_start(thread, session.current_index(thread))
		position_text = StitchPanel.describe_position(step, hint, pattern, states, _style)
		var thread_text := StitchPanel.describe_thread(step, thread_start, session.max_skip)
		if not thread_text.is_empty():
			position_text = thread_text + "\n" + position_text
	# Mark the old thread's end when a new one starts here or the colour is finished, and the
	# new thread's start.
	var thread_end := Vector2i(-1, -1)
	if (step == null or thread_start in [StitchSession.ThreadStart.AUTO, StitchSession.ThreadStart.MANUAL]):
		thread_end = session.last_cell(thread)
	var new_thread := step != null and thread_start != StitchSession.ThreadStart.NONE
	_view.show_progress(states, step, hint, thread_end, new_thread)
	if _view.back_side:
		_show_back(step)
	if step != null:
		_view.ensure_visible(step, hint, thread_end)
	var floss := _palette.find_code(pattern.thread_codes[thread])
	_stitch_panel.show_step(floss, step, position_text, session.done_count(thread),
			session.steps(thread).size(), session.finished_crosses(thread),
			pattern.stitch_counts()[thread], thread_start)
	_info_label.text = ""


func _toggle_back_side() -> void:
	_set_back_side(not _view.back_side)
	if _stitch_thread >= 0:
		_refresh_stitching()


func _set_back_side(back: bool) -> void:
	_view.back_side = back
	_side_button.text = "Vorderseite" if back else "Rückseite"


## Hands the back of every colour to the view, and the current step's part still to stitch,
## joined to where the needle is unless a new thread starts. Only worked out while the back is
## shown, since it goes over every finished step.
func _show_back(step: StitchStep) -> void:
	var session := _project.session
	var lines: Array[PackedVector2Array] = []
	var starts := PackedVector2Array()
	var ends := PackedVector2Array()
	for thread in _project.pattern.thread_codes.size():
		lines.append(BackSide.thread_segments(session, thread, _style))
		var marks := BackSide.thread_ends(session, thread, _style)
		starts.append_array(marks.starts)
		ends.append_array(marks.ends)
	var ghost := PackedVector2Array()
	if step != null:
		var thread := _stitch_thread
		var index := session.current_index(thread)
		var from := Vector2(NAN, NAN)
		if (index > 0 and session.is_done(thread, index - 1)
				and session.thread_start(thread, index) == StitchSession.ThreadStart.NONE):
			from = BackSide.last_hole(session.steps(thread)[index - 1], _style)
		ghost = BackSide.step_segments(step, _style, from)
	_view.show_back(lines, ghost, starts, ends)


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


func _toggle_new_thread() -> void:
	if _stitch_thread >= 0:
		_project.session.toggle_manual_start(_stitch_thread)
		_refresh_stitching()
		_save()


func _on_view_tapped() -> void:
	_next_step()


func _handle_cmdline() -> void:
	var screenshot_path := ""
	var stitch_code := ""
	var steps := 0
	var back := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--open="):
			_open_image(arg.trim_prefix("--open="))
		elif arg.begins_with("--stitch="):
			stitch_code = arg.trim_prefix("--stitch=")
		elif arg.begins_with("--steps="):
			steps = arg.trim_prefix("--steps=").to_int()
		elif arg == "--settings":
			_show_settings.call_deferred()
		elif arg == "--advanced":
			_show_advanced.call_deferred(true)
		elif arg.begins_with("--method="):
			Preferences.set_english(arg.trim_prefix("--method=") == "english")
			if _project != null:
				_apply_preferences()
		elif arg.begins_with("--needle="):
			var needle := arg.trim_prefix("--needle=")
			Preferences.set_stitch_style(needle != "auto", Preferences.slash_first(), needle == "top")
			_apply_style()
		elif arg.begins_with("--first-leg="):
			Preferences.set_stitch_style(true, arg.trim_prefix("--first-leg=") == "slash",
					Preferences.needle_from_top())
			_apply_style()
		elif arg == "--back":
			back = true
		elif arg == "--projects":
			_show_projects.call_deferred()
		elif arg.begins_with("--max-skip="):
			Preferences.set_max_skip(arg.trim_prefix("--max-skip=").to_int())
			if _project != null:
				_apply_preferences()
		elif arg.begins_with("--start="):
			var corner := arg.trim_prefix("--start=")
			Preferences.set_direction(not corner.begins_with("bottom"), not corner.ends_with("right"))
			if _project != null:
				_apply_preferences()
		elif arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
	if not stitch_code.is_empty() and _project != null and _project.pattern.thread_codes.has(stitch_code):
		await get_tree().process_frame  # Let the screen lay out first, as before a real tap.
		_enter_stitching(_project.pattern.thread_codes.find(stitch_code))
		for i in steps:
			_next_step()
		if back:
			_toggle_back_side()
	if screenshot_path.is_empty():
		return
	for i in 3:
		await get_tree().process_frame
	# Low processor mode draws only when something changed, so ask for one more frame.
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	get_tree().quit()

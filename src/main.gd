extends Control
## Start screen: open a pixel-art image, show it as a cross-stitch pattern with its threads, and
## stitch one thread at a time with step-by-step guidance. Every change is saved right away; on
## start the last project opens again.
##
## Command line (after `--`): `--projects-dir=<path>` keeps projects in another folder (for test
## runs), `--open=<path>` opens an image as a new project, `--max-skip=<n>` sets the skip limit
## (-1: none), `--start=<corner>` sets the start corner (auto, top-left, top-right, bottom-left,
## bottom-right), `--settings` opens the settings dialog (`--advanced`: with the advanced part open),
## `--method=<english|danish>` sets the stitch method, `--back-pass=<whole|blocks>` the Danish
## return pass, `--max-block=<n>` the most stitches per block, `--needle=<auto|bottom|top>` and
## `--first-leg=<slash|backslash>` the stitch style (bottom/top/first-leg fix it), `--projects` the project list, `--stitch=<code>` starts stitching that thread, `--steps=<n>` confirms n steps, `--back` shows the back while stitching, `--screenshot=<png path>` saves a screenshot after a few
## frames and quits (`--wait=<seconds>` waits that much longer, e.g. into an animation).
## `--finish` stitches the rest of the `--stitch` colour (the celebration comes in),
## `--dismiss` then taps it away to the overview. `--finale` shows the show for a finished project. `--ui=<touch|desktop>` sets the layout, `--overlays=<menu,pin,list,text>`
## opens touch overlays (pin: the menu pinned), `--tooltip=<menu|list|text>` shows a round
## button's tooltip, `--safe-area=<left>,<top>,<right>,<bottom>` pretends the screen has a notch
## or island (canvas pixels), `--picker=<code>` opens the colour picker for that colour of the
## list, `--picker-view=<list,project>` shows it as a list and/or only the project's colours,
## and `--pick=<code>` chooses a colour in it.
##
## Two layouts (Preferences.touch_mode()): desktop has a toolbar on top and a side panel; touch
## shows the pattern on the whole screen with three round buttons: the menu (the toolbar,
## top left; it closes itself when the view is used unless pinned), the colour list or stitching
## buttons (bottom left) and the texts (bottom right). The same widgets move between the two.

const SAMPLE_PATH := "res://samples/hypsi_anhaenger.png"
## Images bigger than this on either side are refused (most likely a photo, not pixel art).
const MAX_SIDE := 500
const BUTTON_HEIGHT := 48.0
## Length of the needle on the stitch button of each colour.
const NEEDLE_ICON_PX := 96
## Rows of left-out colours are faded to this.
const LEFT_OUT_ALPHA := 0.35
## Height of the progress bar between the bottom buttons (or under the desktop layout).
const PROGRESS_HEIGHT := 16.0
## Smallest cell size when stitching starts, so the current block is easy to see.
const STITCH_CELL_PX := 24.0
## After each step the light swings once around the fabric on an oval (StitchScene.orbit()), as
## a little reward; during a celebration it keeps going round.
const LIGHT_SPIN_SECONDS := 0.9
const LIGHT_LOOP_SECONDS := 2.4
## Start corners in the settings: label and (top_to_bottom, start_left, auto).
const START_CORNERS := [
	["Automatisch: wo der Faden auf der Rückseite am kürzesten bleibt (empfohlen)", true, true, true],
	["Oben links: Reihen nach rechts, dann nach unten", true, true, false],
	["Oben rechts: Reihen nach links, dann nach unten", true, false, false],
	["Unten links: Reihen nach rechts, dann nach oben", false, true, false],
	["Unten rechts: Reihen nach links, dann nach oben", false, false, false],
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
const UI_MODES := [
	"Touch: Muster über den ganzen Bildschirm, runde Knöpfe und Gesten",
	"Desktop: Werkzeugleiste oben, Seitenleiste daneben",
]
## Touch layout: round button size, distance from the screen edge (inside the safe area), and
## overlay panel width on wide screens.
const ROUND_BUTTON_PX := 72.0
const PIN_BUTTON_PX := 52.0
const TOUCH_MARGIN := 12.0
const OVERLAY_MAX_WIDTH := 480.0
## Opening a touch overlay: it slides in this far (the menu from above, the others from below)
## while fading in; closing goes the same way back, faster.
const MENU_SLIDE_PX := 16.0
const DOCK_SLIDE_PX := 24.0
const MENU_OPEN_SECONDS := 0.18
const DOCK_OPEN_SECONDS := 0.2
const OVERLAY_CLOSE_SECONDS := 0.12
## Swapping the colour list for the colour picker and back.
const PICKER_SWIPE_SECONDS := 0.35
## After a touch closed the menu, taps within this time only closed it.
const CLOSE_SWALLOW_MSEC := 700

var _palette: FlossPalette
var _project: StitchProject
## Pattern with every colour of the image, for the colour list.
var _full_pattern: Pattern
## Thread index in the project's pattern being stitched, or -1 on the overview.
var _stitch_thread := -1
var _style := StitchStyle.new()
var _touch := false
## Screen parts kept free for a notch, island or home bar, in canvas pixels: left, top, right,
## bottom. Read from the display on phones, or set with --safe-area.
var _safe := Vector4.ZERO
var _safe_from_cmdline := false
## The step, hint and thread end last shown, kept visible when overlays open.
var _shown_step: StitchStep
var _shown_hint: PositionHint
var _shown_thread_end := Vector2i(-1, -1)
## A touch on the view closed the menu; the tap it makes is dropped.
var _swallow_tap := false
var _swallow_msec := 0
## Overlay animations: the running tween per panel, a count per panel so an older call that
## waits for a frame gives way to a newer one, the panels moving right now, and where the menu
## rests when open.
var _overlay_tweens := {}
var _overlay_calls := {}
var _overlay_moving := {}
var _menu_home := Vector2.ZERO

var _open_button: Button
var _projects_button: Button
var _project_browser: ProjectBrowser
var _settings_dialog: OverlayWindow
## Touch overlays closed while the file dialog, the project list or the settings are open, as
## [panel, button] pairs; they open again when it closes.
var _hidden_overlays: Array[Array] = []
var _limit_box: CheckBox
var _corner_option: OptionButton
var _limit_spin: SpinBox
var _method_option: OptionButton
var _whole_back_box: CheckBox
var _block_spin: SpinBox
var _advanced_button: Button
var _advanced_box: VBoxContainer
var _needle_option: OptionButton
var _leg_option: OptionButton
var _needle_start_option: OptionButton
var _overview_button: Button
var _side_button: Button
var _info_label: Label
var _toolbar: HFlowContainer
var _desktop_root: MarginContainer
var _desktop_column: VBoxContainer
var _body: BoxContainer
var _touch_root: Control
var _menu_panel: PanelContainer
var _menu_content: VBoxContainer
var _menu_pin: RoundButton
var _dock: BoxContainer
var _dock_spacer: Control
var _list_panel: PanelContainer
var _list_content: VBoxContainer
var _text_panel: PanelContainer
var _text_content: VBoxContainer
var _menu_button: RoundButton
var _list_button: RoundButton
var _text_button: RoundButton
var _ui_option: OptionButton
var _view: PatternView
var _light_azimuth: HSlider
var _light_elevation: HSlider
var _side: VBoxContainer
## Holds the colour list (_side) and the colour picker, which swipe past each other.
var _list_host: Control
var _picker: ThreadPicker
var _picker_open := false
var _picker_tween: Tween
var _color_list: VBoxContainer
var _stitch_panel: StitchPanel
var _file_dialog: FileDialog
## Progress of the colour being stitched, or of the whole project in the overview.
var _progress: ProgressStrip
var _celebration: Celebration
var _finale: Finale
## Degrees the light is turned on top of the test slider, while it spins.
var _light_spin := 0.0:
	set(value):
		_light_spin = value
		_apply_light()
var _light_tween: Tween
## Whether the light keeps going round (celebrations).
var _light_looping := false
## When stitching began: the whole project's progress and whether the colour was finished, for
## the overview's show on the way back.
var _overall_before := 0.0
var _thread_done_before := false
## The colour just finished, struck through in the list once the overview's bar has filled.
var _strike_code := ""
var _strikes := {}  # code -> StrikeLine


func _ready() -> void:
	var opens_image := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--projects-dir="):
			ProjectStore.directory = arg.trim_prefix("--projects-dir=")
		opens_image = opens_image or arg.begins_with("--open=")
	_palette = FlossPalette.dmc()
	_build_ui()
	resized.connect(_update_layout)
	_apply_ui_mode()
	_apply_light()
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
	_file_dialog.file_selected.connect(func(path: String) -> void:
		_restore_overlays()
		_open_image(path))
	_file_dialog.canceled.connect(_restore_overlays)
	add_child(_file_dialog)

	# These open a window, which closes the menu itself (and opens it again afterwards).
	_toolbar = HFlowContainer.new()
	_open_button = _make_toolbar_button("Bild öffnen…", _show_open_image, ButtonIcons.Icon.IMAGE, false)
	_toolbar.add_child(_open_button)
	_projects_button = _make_toolbar_button("Projekte", _show_projects, ButtonIcons.Icon.PROJECTS, false)
	_toolbar.add_child(_projects_button)
	_toolbar.add_child(_make_toolbar_button("Einstellungen", _show_settings, ButtonIcons.Icon.GEAR, false))
	_overview_button = _make_toolbar_button("◂ Übersicht", _leave_stitching)
	_overview_button.visible = false
	_toolbar.add_child(_overview_button)
	_side_button = _make_toolbar_button("Rückseite", _toggle_back_side)
	_side_button.visible = false
	_toolbar.add_child(_side_button)
	_info_label = Label.new()
	_info_label.text = "Öffne ein Pixelart-Bild (PNG). Ein Pixel wird ein Kreuzstich."
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_view = PatternView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.tapped.connect(_on_view_gesture.bind(_next_step))
	_view.double_tapped.connect(_on_view_gesture.bind(_previous_step))
	_view.two_finger_double_tapped.connect(_on_view_gesture.bind(_toggle_new_thread))
	_view.swiped_from_right.connect(_on_view_gesture.bind(_swipe_side))
	_view.swiped_from_left.connect(_on_view_gesture.bind(_leave_stitching))
	_view.touched.connect(_on_view_touched)

	_side = VBoxContainer.new()
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_list_host = Control.new()
	_list_host.clip_contents = true
	_list_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_host.resized.connect(_fit_list_host)
	_list_host.add_child(_side)
	_picker = ThreadPicker.new()
	_picker.visible = false
	_picker.confirmed.connect(_close_picker)
	_picker.cancelled.connect(_close_picker.bind("", ""))
	_list_host.add_child(_picker)

	_progress = ProgressStrip.new()
	_progress.visible = false

	_stitch_panel = StitchPanel.new()
	_stitch_panel.visible = false
	_stitch_panel.next_pressed.connect(_next_step)
	_stitch_panel.previous_pressed.connect(_previous_step)
	_stitch_panel.new_thread_toggled.connect(_toggle_new_thread)
	_build_desktop_shell()
	_build_touch_shell()
	_build_settings_dialog()
	_project_browser = ProjectBrowser.new()
	_project_browser.open_requested.connect(_open_project)
	_project_browser.project_renamed.connect(_on_project_renamed)
	_project_browser.project_deleted.connect(_on_project_deleted)
	_project_browser.closed.connect(_restore_overlays)
	add_child(_project_browser)


## Toolbar on top, pattern and side panel below (beside each other in landscape); the widgets
## are put in by _apply_ui_mode().
func _build_desktop_shell() -> void:
	_desktop_root = MarginContainer.new()
	_desktop_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		_desktop_root.add_theme_constant_override("margin_" + side, 8)
	add_child(_desktop_root)
	_desktop_column = VBoxContainer.new()
	_desktop_root.add_child(_desktop_column)
	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desktop_column.add_child(_body)
	_body.add_child(_stitch_panel)


## The pattern on the whole screen, overlay panels and the three round buttons above it. Only
## the panels and buttons take input; the rest goes through to the view.
func _build_touch_shell() -> void:
	_touch_root = Control.new()
	_touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_root)

	_menu_panel = _make_overlay_panel()
	_menu_panel.anchor_right = 1.0
	_touch_root.add_child(_menu_panel)
	var menu_row := HBoxContainer.new()
	_menu_panel.add_child(menu_row)
	_menu_content = VBoxContainer.new()
	_menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_row.add_child(_menu_content)
	_menu_pin = RoundButton.new(ButtonIcons.Icon.PIN, "Menü anheften: bleibt offen, auch wenn du das Muster bedienst",
			PIN_BUTTON_PX)
	_menu_pin.toggle_mode = true
	_menu_pin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	menu_row.add_child(_menu_pin)

	_dock = BoxContainer.new()
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.anchor_top = 1.0
	_dock.anchor_right = 1.0
	_dock.anchor_bottom = 1.0
	_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dock.resized.connect(func() -> void: _update_cover.call_deferred())
	_touch_root.add_child(_dock)
	_text_panel = _make_overlay_panel()
	_dock.add_child(_text_panel)
	_text_content = VBoxContainer.new()
	_text_panel.add_child(_text_content)
	_dock_spacer = Control.new()
	_dock_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock.add_child(_dock_spacer)
	_list_panel = _make_overlay_panel()
	_dock.add_child(_list_panel)
	_list_content = VBoxContainer.new()
	_list_panel.add_child(_list_content)

	_menu_button = _make_round_button(ButtonIcons.Icon.MENU, "Menü: Bilder, Projekte, Einstellungen", _menu_panel)
	_list_button = _make_round_button(ButtonIcons.Icon.SPOOL, "", _list_panel)
	_text_button = _make_round_button(ButtonIcons.Icon.TEXT, "", _text_panel)


func _make_overlay_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", OverlayWindow.panel_style())
	panel.visible = false
	panel.visibility_changed.connect(func() -> void: _update_cover.call_deferred())
	return panel


## A round button in the touch layout that opens and closes `panel`.
func _make_round_button(icon: ButtonIcons.Icon, tooltip: String, panel: Control) -> RoundButton:
	var button := RoundButton.new(icon, tooltip, ROUND_BUTTON_PX)
	button.toggle_mode = true
	button.toggled.connect(func(on: bool) -> void: _set_overlay(panel, button, on))
	_touch_root.add_child(button)
	return button


## Opens or closes a touch overlay together with its button; with `animate` it slides and
## fades (the view keeps the current step clear of it once it has arrived).
func _set_overlay(panel: Control, button: RoundButton, open: bool, animate := true) -> void:
	button.set_pressed_no_signal(open)
	var call: int = _overlay_calls.get(panel, 0) + 1
	_overlay_calls[panel] = call
	var tween: Tween = _overlay_tweens.get(panel)
	if tween != null:
		tween.kill()
		_overlay_tweens.erase(panel)
		_rest_overlay(panel)
	if not animate or not _touch or (open == panel.visible and tween == null):
		_overlay_moving.erase(panel)
		panel.visible = open
		_update_cover.call_deferred()
		return
	_overlay_moving[panel] = true
	var menu := panel == _menu_panel
	# Panels stacked with this one move along as if joined to it: each glides to `followers[it]`,
	# and this one slides as far as they do instead of DOCK_SLIDE_PX.
	var followers := {}
	var slide := Vector2(0.0, -MENU_SLIDE_PX if menu else DOCK_SLIDE_PX)
	if open and not panel.visible:
		var before := _dock_neighbours(panel)
		panel.modulate.a = 0.0
		panel.visible = true
		await get_tree().process_frame  # The dock places it first.
		if _overlay_calls[panel] != call:
			return
		# The dock grows upwards, so compare on screen, not inside it.
		for other: Control in before:
			if other.global_position != before[other]:
				followers[other] = other.global_position
				slide = before[other] - other.global_position
				other.global_position = before[other]
	elif not open and not menu and _dock.vertical:
		var shift := Vector2(0.0, panel.size.y + _dock.get_theme_constant("separation"))
		for other: Control in _dock_neighbours(panel):
			if other.position.y < panel.position.y:
				followers[other] = other.global_position + shift
				slide = shift
	var home := panel.global_position
	var away := home + slide
	var seconds := (MENU_OPEN_SECONDS if menu else DOCK_OPEN_SECONDS) if open else OVERLAY_CLOSE_SECONDS
	var easing := Tween.EASE_OUT if open else Tween.EASE_IN
	var trans := Tween.TRANS_BACK if open and not menu and followers.is_empty() else Tween.TRANS_CUBIC
	tween = create_tween().set_parallel()
	_overlay_tweens[panel] = tween
	if open:
		panel.global_position = away
	tween.tween_property(panel, "global_position", home if open else away, seconds).set_ease(easing).set_trans(trans)
	tween.tween_property(panel, "modulate:a", 1.0 if open else 0.0, seconds)
	for other: Control in followers:
		tween.tween_property(other, "global_position", followers[other], seconds).set_ease(easing).set_trans(trans)
	tween.chain().tween_callback(func() -> void:
		_overlay_tweens.erase(panel)
		_overlay_moving.erase(panel)
		if not open:
			panel.visible = false
		_rest_overlay(panel)
		_update_cover())


## The other open panels in the dock that aren't moving themselves, with their positions on
## screen.
func _dock_neighbours(panel: Control) -> Dictionary:
	var result := {}
	for other: Control in [_list_panel, _text_panel]:
		if other != panel and other.visible and not _overlay_moving.has(other):
			result[other] = other.global_position
	return result


## Puts a panel back where its layout wants it, fully opaque.
func _rest_overlay(panel: Control) -> void:
	panel.modulate.a = 1.0
	if panel == _menu_panel:
		panel.position = _menu_home
	else:
		_dock.queue_sort()


## Closes the menu in the touch layout unless it is pinned; true if it was open and closed.
func _close_menu_unless_pinned() -> bool:
	if not _touch or not _menu_panel.visible or _menu_pin.button_pressed:
		return false
	_set_overlay(_menu_panel, _menu_button, false)
	return true


## Closes every open touch overlay, the menu too, for a window (file dialog, project list,
## settings); _restore_overlays() opens them again.
func _hide_overlays() -> void:
	if not _touch:
		return
	for entry: Array in [[_menu_panel, _menu_button], [_list_panel, _list_button], [_text_panel, _text_button]]:
		var button: RoundButton = entry[1]
		if button.button_pressed and not _hidden_overlays.has(entry):
			_hidden_overlays.append(entry)
			_set_overlay(entry[0], button, false)


func _restore_overlays() -> void:
	for entry in _hidden_overlays:
		_set_overlay(entry[0], entry[1], true)
	_hidden_overlays.clear()


## Opens `window` in the safe area, with the touch overlays out of the way.
func _open_window(window: OverlayWindow) -> void:
	_hide_overlays()
	window.safe_area = _safe if _touch else Vector4.ZERO
	window.open()


## Moves the shared widgets into the desktop or the touch layout (Preferences.touch_mode()).
func _apply_ui_mode() -> void:
	_close_picker_now()
	_touch = Preferences.touch_mode()
	_desktop_root.visible = not _touch
	_touch_root.visible = _touch
	_stitch_panel.set_touch(_touch)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _touch else TextServer.AUTOWRAP_OFF
	_info_label.text_overrun_behavior = (TextServer.OVERRUN_NO_TRIMMING if _touch
			else TextServer.OVERRUN_TRIM_ELLIPSIS)
	if _touch:
		_place(_view, _touch_root, 0)
		_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_place(_toolbar, _menu_content, 0)
		_place(_info_label, _text_content, 0)
		_place(_stitch_panel.info, _text_content, 1)
		_place(_list_host, _list_content, 0)
		_place(_stitch_panel.controls, _list_content, 1)
		_place(_progress, _touch_root, 1)
		_progress.custom_minimum_size = Vector2.ZERO
		if _project == null:
			_set_overlay(_menu_panel, _menu_button, true)
	else:
		_place(_toolbar, _desktop_column, 0)
		_place(_info_label, _toolbar)
		_place(_view, _body, 0)
		_place(_list_host, _body, 1)
		_place(_stitch_panel.info, _stitch_panel, 0)
		_place(_stitch_panel.controls, _stitch_panel, 1)
		_place(_progress, _desktop_column)
		_progress.custom_minimum_size.y = PROGRESS_HEIGHT + _progress.margin * 2.0
	_update_visibility()
	_update_layout()


## Makes `node` a child of `parent` at `index` (last if -1), moving it from where it was.
static func _place(node: Node, parent: Node, index := -1) -> void:
	if node.get_parent() == null:
		parent.add_child(node)
	elif node.get_parent() != parent:
		node.reparent(parent, false)
	parent.move_child(node, index if index >= 0 else parent.get_child_count() - 1)


## Shows the widgets for the overview or for stitching, in the current layout.
func _update_visibility() -> void:
	var stitching := _stitch_thread >= 0
	_open_button.visible = not stitching
	_projects_button.visible = not stitching
	_overview_button.visible = stitching
	_side_button.visible = stitching
	_list_host.visible = not stitching
	_stitch_panel.visible = stitching and not _touch
	_info_label.visible = not (stitching and _touch)
	_stitch_panel.info.visible = stitching or not _touch
	_stitch_panel.controls.visible = stitching or not _touch
	if stitching:
		_list_button.icon = ButtonIcons.Icon.NEEDLE
		_list_button.tooltip = "Sticken: zurück, gestickt, neuer Faden"
		_text_button.tooltip = "Anleitung zum Schritt ein- und ausblenden"
	else:
		_list_button.icon = ButtonIcons.Icon.SPOOL
		_list_button.tooltip = "Garnfarben: eine Farbe zum Sticken wählen"
		_text_button.tooltip = "Projektinfo ein- und ausblenden"


## The light on fabric and thread in the advanced settings: where it comes from and how high
## above the fabric. Moving a slider shows it right away; Abbrechen puts the saved light back.
func _make_light_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Licht von:"
	row.add_child(label)
	_light_azimuth = _make_light_slider(0.0, 360.0, Preferences.light_azimuth())
	row.add_child(_light_azimuth)
	var height_label := Label.new()
	height_label.text = "Höhe:"
	row.add_child(height_label)
	_light_elevation = _make_light_slider(5.0, 90.0, Preferences.light_elevation())
	row.add_child(_light_elevation)
	return row


func _make_light_slider(from: float, to: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = from
	slider.max_value = to
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(_value: float) -> void: _apply_light())
	return slider


func _apply_light() -> void:
	var light := StitchScene.orbit(_light_azimuth.value, _light_elevation.value, _light_spin)
	_view.set_light(light.x, light.y)
	for button: RoundButton in [_menu_button, _list_button, _text_button, _menu_pin]:
		button.set_light(light.x, light.y)


## The light as saved, on the sliders and on screen (after Abbrechen or `--light`).
func _restore_light() -> void:
	_light_azimuth.set_value_no_signal(Preferences.light_azimuth())
	_light_elevation.set_value_no_signal(Preferences.light_elevation())
	_apply_light()


## Swings the light once around the fabric (unless it is going round anyway).
func _spin_light() -> void:
	if _light_looping:
		return
	if _light_tween != null:
		_light_tween.kill()
	_light_spin = 0.0
	_light_tween = create_tween()
	_light_tween.tween_property(self, "_light_spin", 360.0, LIGHT_SPIN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_light_tween.tween_callback(func() -> void: _light_spin = 0.0)


## Keeps the light going round (`on`) or lets it finish its turn and stop.
func _loop_light(on: bool) -> void:
	if on == _light_looping:
		return
	_light_looping = on
	if _light_tween != null:
		_light_tween.kill()
	_light_tween = create_tween()
	if on:
		var start := fposmod(_light_spin, 360.0)
		_light_tween.set_loops()
		_light_tween.tween_property(self, "_light_spin", start + 360.0, LIGHT_LOOP_SECONDS).from(start)
		return
	_light_spin = fposmod(_light_spin, 360.0)
	_light_tween.tween_property(self, "_light_spin", 360.0, LIGHT_LOOP_SECONDS * (1.0 - _light_spin / 360.0)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_light_tween.tween_callback(func() -> void: _light_spin = 0.0)


## The settings window. Übernehmen stores them; closing it any other way leaves them as they
## were and puts the saved light back (the sliders show theirs right away).
func _build_settings_dialog() -> void:
	_settings_dialog = OverlayWindow.new("Einstellungen")
	_settings_dialog.buttons.add_child(OverlayWindow.make_button("Abbrechen", ButtonIcons.Icon.CLOSE,
			_settings_dialog.close))
	_settings_dialog.buttons.add_child(OverlayWindow.make_button("Übernehmen", ButtonIcons.Icon.CHECK,
			func() -> void:
				_apply_settings()
				_settings_dialog.close()))
	_settings_dialog.closed.connect(func() -> void:
		_restore_light()
		_restore_overlays())
	add_child(_settings_dialog)
	var content := _settings_dialog.content
	var ui_label := Label.new()
	ui_label.text = "Bedienung:"
	content.add_child(ui_label)
	_ui_option = _make_option(UI_MODES)
	content.add_child(_ui_option)
	content.add_child(HSeparator.new())
	var method_label := Label.new()
	method_label.text = "Stichmethode:"
	content.add_child(method_label)
	_method_option = _make_option(METHODS)
	_method_option.item_selected.connect(func(index: int) -> void: _whole_back_box.disabled = index == 1)
	content.add_child(_method_option)
	_whole_back_box = CheckBox.new()
	_whole_back_box.text = "Dänisch: Rückweg in einem Zug bis zur nächsten Lücke (statt in Blöcken)"
	_whole_back_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_whole_back_box)
	var block_row := HBoxContainer.new()
	content.add_child(block_row)
	var block_label := Label.new()
	block_label.text = "Höchstens"
	block_row.add_child(block_label)
	_block_spin = SpinBox.new()
	_block_spin.min_value = 1
	_block_spin.max_value = 30
	block_row.add_child(_block_spin)
	var block_unit := Label.new()
	block_unit.text = "Stiche pro Block (üblich: 5)"
	block_row.add_child(block_unit)
	content.add_child(HSeparator.new())
	var corner_label := Label.new()
	corner_label.text = "Anfangen in der Ecke:"
	content.add_child(corner_label)
	_corner_option = _make_option(START_CORNERS.map(func(corner: Array) -> String: return corner[0]))
	content.add_child(_corner_option)
	content.add_child(_make_note("Fläche für Fläche: Die Ecke bestimmt, wo es losgeht und welcher Abschnitt "
			+ "bei gleichem Abstand zuerst kommt. Eine Reihe beginnt trotzdem am näheren Ende, "
			+ "wenn der Faden dort schon ist. Automatisch probiert jede Farbe in allen vier Ecken "
			+ "und nimmt die, bei der am wenigsten Faden hinten weiterläuft oder neu nötig ist."))
	content.add_child(HSeparator.new())
	_limit_box = CheckBox.new()
	_limit_box.text = "Faden automatisch wechseln, wenn er auf der Rückseite mehr als"
	_limit_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	content.add_child(_make_note("Aus: Der Faden wird nie automatisch gewechselt, er darf beliebig weit springen. "
			+ "Üblich sind 2–3 Felder: längere Fäden auf der Rückseite verhaken sich und scheinen durch. "
			+ "Einen neuen Faden kannst du beim Sticken jederzeit selbst nehmen."))
	_limit_box.toggled.connect(func(on: bool) -> void: _limit_spin.editable = on)
	content.add_child(HSeparator.new())
	_build_advanced_settings(content)


## The advanced part, closed at first so the window stays short: how each cross is worked, the
## light, and the sample image.
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
	_advanced_box.add_child(_make_note("Stichführung (welcher Schenkel zuerst, wo die Nadel hochkommt):", 1.0))
	_needle_option = _make_option(NEEDLE_MODES)
	_needle_option.item_selected.connect(func(_index: int) -> void: _update_needle_options())
	_advanced_box.add_child(_needle_option)
	_leg_option = _make_option(LEG_ORDERS)
	_advanced_box.add_child(_leg_option)
	_needle_start_option = _make_option(NEEDLE_STARTS)
	_advanced_box.add_child(_needle_start_option)
	_advanced_box.add_child(_make_note("Automatisch: erst /, dann \\. Die Nadel kommt immer so hoch, dass auf der "
			+ "Rückseite nur kurze senkrechte Stiche bleiben, in beide Richtungen. "
			+ "Fest: jeder Schenkel genau so, wie gewählt. Auf der Rückseite kann der Faden dann "
			+ "schräg über zwei Felder laufen. Nicht mitten im Projekt wechseln, sonst liegen die "
			+ "oberen Schenkel nicht mehr gleich."))
	_advanced_box.add_child(HSeparator.new())
	_advanced_box.add_child(_make_light_row())
	_advanced_box.add_child(_make_note("Richtung im Uhrzeigersinn von oben (315 = oben links) und Höhe über "
			+ "dem Stoff (90 = genau von oben). Nach jedem Schritt kreist das Licht einmal auf einem Oval."))
	_advanced_box.add_child(HSeparator.new())
	# Opening the sample leaves the settings unchanged, like Abbrechen.
	var sample_button := OverlayWindow.make_button("Beispielbild öffnen", ButtonIcons.Icon.IMAGE, func() -> void:
		_settings_dialog.close()
		_open_image(SAMPLE_PATH))
	sample_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_advanced_box.add_child(sample_button)
	_advanced_box.add_child(_make_note("Ein kleines Muster zum Ausprobieren, als neues Projekt."))
	_show_advanced(false)


## A wrapped explanation in the settings, faded to `alpha`.
static func _make_note(text: String, alpha := 0.7) -> Label:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate.a = alpha
	return note


func _show_advanced(open: bool) -> void:
	_advanced_button.set_pressed_no_signal(open)
	_advanced_button.text = ("▾ " if open else "▸ ") + "Erweitert"
	_advanced_box.visible = open


## Leg order and needle start only count for a fixed style.
func _update_needle_options() -> void:
	var fixed := _needle_option.selected == 1
	_leg_option.disabled = not fixed
	_needle_start_option.disabled = not fixed


func _make_option(items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size.y = BUTTON_HEIGHT
	# Long choices are cut short on narrow screens; the list shows them whole.
	option.fit_to_longest_item = false
	option.clip_text = true
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for item: String in items:
		option.add_item(item)
	return option


## A toolbar button with an optional symbol (ButtonIcons.Icon, -1 for none); pressing it closes
## the menu unless pinned, if `closes_menu`.
func _make_toolbar_button(text: String, on_pressed: Callable, icon := -1, closes_menu := true) -> Button:
	return OverlayWindow.make_button(text, icon, func() -> void:
		if closes_menu:
			_close_menu_unless_pinned()
		on_pressed.call())


func _update_layout() -> void:
	if _touch:
		_layout_touch()
		return
	_view.set_covered(0.0, 0.0)
	# Portrait: pattern above the side panel; landscape: side panel on the right.
	var portrait := size.y > size.x
	_body.vertical = portrait
	var side_size := Vector2(0.0, size.y * 0.38) if portrait else Vector2(minf(560.0, size.x * 0.4), 0.0)
	_list_host.custom_minimum_size = side_size
	_stitch_panel.custom_minimum_size = side_size


## Round buttons in three corners inside the safe area; the menu right of its button, the
## other panels above the bottom buttons: stacked in portrait (texts on top), side by side in
## landscape.
func _layout_touch() -> void:
	_read_safe_area()
	var portrait := size.y > size.x
	var left := _safe.x + TOUCH_MARGIN
	var right := size.x - _safe.z - TOUCH_MARGIN
	var bottom_row := size.y - _safe.w - TOUCH_MARGIN - ROUND_BUTTON_PX
	_menu_button.position = Vector2(left, _safe.y + TOUCH_MARGIN)
	_list_button.position = Vector2(left, bottom_row)
	_text_button.position = Vector2(right - ROUND_BUTTON_PX, bottom_row)
	for button: Control in [_menu_button, _list_button, _text_button]:
		button.size = button.custom_minimum_size
	var bar_left := left + ROUND_BUTTON_PX + TOUCH_MARGIN
	_progress.place_bar(Rect2(bar_left, bottom_row + (ROUND_BUTTON_PX - PROGRESS_HEIGHT) / 2.0,
			maxf(right - ROUND_BUTTON_PX - TOUCH_MARGIN - bar_left, 0.0), PROGRESS_HEIGHT))

	_menu_panel.offset_left = left + ROUND_BUTTON_PX + TOUCH_MARGIN * 0.5
	_menu_panel.offset_right = -_safe.z - TOUCH_MARGIN
	_menu_panel.offset_top = _safe.y + TOUCH_MARGIN
	_menu_panel.offset_bottom = _menu_panel.offset_top
	_menu_home = _menu_panel.position

	_dock.vertical = portrait
	_dock.offset_left = left
	_dock.offset_right = -_safe.z - TOUCH_MARGIN
	_dock.offset_bottom = bottom_row - size.y - TOUCH_MARGIN * 0.5
	_dock.offset_top = _dock.offset_bottom
	_dock_spacer.visible = not portrait
	var width := 0.0 if portrait else minf(OVERLAY_MAX_WIDTH, (right - left - TOUCH_MARGIN) / 2.0)
	for panel: Control in [_list_panel, _text_panel]:
		panel.custom_minimum_size.x = width
		panel.size_flags_vertical = Control.SIZE_FILL if portrait else Control.SIZE_SHRINK_END
	# Portrait: texts above the buttons' panel; landscape: buttons' panel left, texts right.
	_dock.move_child(_text_panel, 0 if portrait else 2)
	_dock.move_child(_list_panel, 2 if portrait else 0)
	var room := bottom_row - _safe.y - TOUCH_MARGIN * 2.0
	_list_host.custom_minimum_size = Vector2(0.0, room * (0.45 if portrait else 0.75))
	_update_cover.call_deferred()


## The screen's safe area in canvas pixels; only phones and tablets report one.
func _read_safe_area() -> void:
	if _safe_from_cmdline or not OS.has_feature("mobile"):
		return
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var to_canvas := get_viewport().get_final_transform().affine_inverse()
	var top_left := to_canvas * safe.position
	var bottom_right := to_canvas * safe.end
	var screen := get_viewport_rect().size
	_safe = Vector4(maxf(top_left.x, 0.0), maxf(top_left.y, 0.0),
			maxf(screen.x - bottom_right.x, 0.0), maxf(screen.y - bottom_right.y, 0.0))


## Tells the view what the open overlays cover, and keeps the current step clear of them.
func _update_cover() -> void:
	if not _touch or not _overlay_moving.is_empty():
		return  # A moving overlay calls again when it has arrived.
	var top := _safe.y
	if _menu_panel.visible:
		top = _menu_panel.get_rect().end.y
	var bottom := size.y - _list_button.position.y
	if _list_panel.visible or _text_panel.visible:
		bottom = size.y - _dock.get_rect().position.y
	_view.set_covered(top, bottom)
	if _stitch_thread >= 0 and _shown_step != null:
		_view.ensure_visible(_shown_step, _shown_hint, _shown_thread_end, true)


## Any touch on the view closes the menu unless it is pinned; the tap that closed it does
## nothing else.
func _on_view_touched() -> void:
	var now := Time.get_ticks_msec()
	if _close_menu_unless_pinned():
		_swallow_tap = true
		_swallow_msec = now
	elif now - _swallow_msec > CLOSE_SWALLOW_MSEC:
		_swallow_tap = false


func _on_view_gesture(action: Callable) -> void:
	if _swallow_tap:
		_swallow_tap = false
		return
	action.call()


## The overview in the touch layout starts with the colour list and the project info open.
func _open_overview_panels() -> void:
	if _touch and _project != null:
		_set_overlay(_list_panel, _list_button, true)
		_set_overlay(_text_panel, _text_button, true)


func _swipe_side() -> void:
	if _stitch_thread >= 0:
		_toggle_back_side()


## A message for the user: in the info line, which the touch layout opens if it is closed.
func _show_message(text: String) -> void:
	_info_label.text = text
	if _touch and _stitch_thread < 0:
		_set_overlay(_text_panel, _text_button, true)


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
		_show_message("Bild konnte nicht geladen werden.")
		return
	if image.get_width() > MAX_SIDE or image.get_height() > MAX_SIDE:
		_show_message("Bild ist zu groß (%d × %d), höchstens %d Pixel pro Seite." % [
				image.get_width(), image.get_height(), MAX_SIDE])
		return
	if image.is_compressed():
		image.decompress()
	_set_project(StitchProject.create(path.get_file().get_basename(), image, _palette))
	_save()


## The file dialog for a new image, with the touch overlays out of the way until it closes.
func _show_open_image() -> void:
	_hide_overlays()
	_file_dialog.popup_centered_ratio(0.8)


func _show_settings() -> void:
	_ui_option.selected = 0 if Preferences.touch_mode() else 1
	var limit := Preferences.max_skip()
	_limit_box.button_pressed = limit != StitchPlanner.UNLIMITED
	_limit_spin.editable = _limit_box.button_pressed
	if limit != StitchPlanner.UNLIMITED:
		_limit_spin.value = limit
	_corner_option.selected = _corner_index(Preferences.top_to_bottom(), Preferences.start_left(),
			Preferences.auto_start())
	_method_option.selected = 1 if Preferences.english() else 0
	_whole_back_box.button_pressed = Preferences.whole_back()
	_whole_back_box.disabled = Preferences.english()
	_block_spin.value = Preferences.max_block()
	_needle_option.selected = 1 if Preferences.needle_fixed() else 0
	_leg_option.selected = 0 if Preferences.slash_first() else 1
	_needle_start_option.selected = 1 if Preferences.needle_from_top() else 0
	_update_needle_options()
	_open_window(_settings_dialog)


## Index into START_CORNERS of a row order and start side, or of the automatic choice.
static func _corner_index(top_to_bottom: bool, start_left: bool, auto: bool) -> int:
	if auto:
		return 0
	return 1 + (0 if top_to_bottom else 2) + (0 if start_left else 1)


## Stores the preferences and replans the open project; stitched cells stay stitched.
func _apply_settings() -> void:
	Preferences.set_light(_light_azimuth.value, _light_elevation.value)
	if (_ui_option.selected == 0) != Preferences.touch_mode():
		Preferences.set_touch_mode(_ui_option.selected == 0)
		_apply_ui_mode()
	var limit := int(_limit_spin.value) if _limit_box.button_pressed else StitchPlanner.UNLIMITED
	Preferences.set_max_skip(limit)
	var corner: Array = START_CORNERS[_corner_option.selected]
	Preferences.set_direction(corner[1], corner[2], corner[3])
	Preferences.set_english(_method_option.selected == 1)
	Preferences.set_whole_back(_whole_back_box.button_pressed)
	Preferences.set_max_block(int(_block_spin.value))
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
	_update_progress()


## Replans the open project for the current preferences; stitched cells stay stitched.
func _apply_preferences() -> void:
	_project.session.set_max_skip(Preferences.max_skip())
	_project.session.set_direction(Preferences.top_to_bottom(), Preferences.start_left(),
			Preferences.auto_start())
	_project.session.set_english(Preferences.english())
	_project.session.set_whole_back(Preferences.whole_back())
	_project.session.set_max_block(Preferences.max_block())


## Hands the leg order and needle holes from the preferences to the view and the guide texts.
func _apply_style() -> void:
	_style = StitchStyle.from_preferences()
	_view.style = _style
	_stitch_panel.style = _style


func _open_project(path: String) -> void:
	var project := ProjectStore.load_project(path)
	if project == null:
		_show_message("Projekt konnte nicht geladen werden.")
		return
	_set_project(project)
	ProjectStore.remember_last(path)


func _set_project(project: StitchProject) -> void:
	_close_picker_now()
	_leave_stitching()
	_close_menu_unless_pinned()
	_project = project
	_apply_preferences()
	_full_pattern = project.full_pattern(_palette)
	_show_pattern(false)
	_open_overview_panels()


func _show_pattern(keep_view: bool) -> void:
	_view.show_pattern(_project.pattern, _palette, keep_view)
	_show_info()
	_fill_color_list()
	_update_progress()


## Saves the project; called after every change, so nothing is lost when the app closes.
func _save() -> void:
	var error := ProjectStore.save(_project)
	if error != OK:
		_show_message("Speichern fehlgeschlagen: %s" % error_string(error))
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
	_open_window(_project_browser)


## The project list renamed a file; the open project takes the name, or its next save would
## bring the old one back.
func _on_project_renamed(path: String, new_name: String) -> void:
	if _project != null and _project.path == path:
		_project.name = new_name
		_show_info()


## The project list deleted a file; if it was the open project, the screen goes back to empty.
func _on_project_deleted(path: String) -> void:
	_close_picker_now()
	if _project == null or _project.path != path:
		return
	_leave_stitching()
	_project = null
	_full_pattern = null
	_view.clear()
	_update_progress()
	for child in _color_list.get_children():
		child.queue_free()
	_show_message("Projekt gelöscht. Öffne ein Bild oder ein anderes Projekt.")


## One row per thread of the image, most stitches first.
func _fill_color_list() -> void:
	for child in _color_list.get_children():
		child.queue_free()
	_strikes.clear()
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
	var left_out := _project.fabric_codes.has(floss.code)
	var swatch := SkeinSwatch.new(floss.color)
	swatch.clickable = true
	swatch.tooltip_text = "Farbe ersetzen"
	row.add_child(swatch)
	var code_label := Label.new()
	code_label.text = floss.code
	code_label.custom_minimum_size.x = 56.0
	code_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(code_label)
	var name_label := Label.new()
	name_label.text = floss.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	swatch.pressed.connect(_open_picker.bind(floss, swatch, name_label))
	if thread >= 0 and session.current_step(thread) == null:
		var strike := StrikeLine.new(name_label, floss.code != _strike_code)
		code_label.add_child(strike)
		_strikes[floss.code] = strike
	var count_label := Label.new()
	count_label.text = str(count)
	if thread >= 0 and session.done_count(thread) > 0:
		count_label.text = "%d / %d" % [session.finished_crosses(thread), count]
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size.x = 56.0
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count_label)
	var fabric_box := CheckBox.new()
	fabric_box.text = "Auslassen"
	fabric_box.button_pressed = left_out
	fabric_box.focus_mode = Control.FOCUS_NONE
	fabric_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Changing the fabric rebuilds the pattern, which would lose the stitching progress.
	fabric_box.disabled = session.has_progress()
	fabric_box.tooltip_text = ("Geht nicht mehr, es wurde schon gestickt." if fabric_box.disabled
			else "Diese Farbe nicht sticken, hier bleibt der Stoff frei.")
	fabric_box.toggled.connect(_on_fabric_toggled.bind(floss.code))
	row.add_child(fabric_box)
	var stitch_button := Button.new()
	# Drawn at three times the size it shows, scaled down smoothly, so it stays sharp on dense screens.
	stitch_button.icon = ButtonIcons.needle_icon(NEEDLE_ICON_PX * 3)
	stitch_button.add_theme_constant_override("icon_max_width", NEEDLE_ICON_PX)
	stitch_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stitch_button.tooltip_text = "Diese Farbe sticken"
	stitch_button.custom_minimum_size = Vector2(NEEDLE_ICON_PX + 20, 40)
	stitch_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stitch_button.focus_mode = Control.FOCUS_NONE
	stitch_button.disabled = thread < 0
	stitch_button.pressed.connect(_enter_stitching.bind(thread))
	row.add_child(stitch_button)
	# A left-out colour stays fabric: the whole row fades, only the box stays clear to undo it.
	if left_out:
		for child: Control in row.get_children():
			if child != fabric_box:
				child.modulate.a = LEFT_OUT_ALPHA
	return row


## Keeps the colour list and the picker as big as their host; only their x moves when they swipe.
func _fit_list_host() -> void:
	for child: Control in [_side, _picker]:
		child.position.y = 0.0
		child.size = _list_host.size


## Turns the colour list into the colour picker: the list swipes out to the right, the picker
## comes in from the left, and the tapped colour and its name fly up into the picker's header,
## growing a little.
func _open_picker(floss: FlossColor, swatch: Control, name_label: Control) -> void:
	if _picker_open or _project == null:
		return
	_picker_open = true
	_picker.open(floss, _palette, _full_pattern.thread_codes)
	var width := _list_host.size.x
	_picker.position.x = -width
	_picker.visible = true
	_picker.header_swatch.modulate.a = 0.0
	_picker.header_name.modulate.a = 0.0
	var name_flyer := Label.new()
	name_flyer.text = floss.name
	var flyers: Array[Control] = [SkeinSwatch.new(floss.color), name_flyer]
	var parts: Array[Control] = [swatch, name_label]
	for i in flyers.size():
		flyers[i].top_level = true
		flyers[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flyers[i])
		flyers[i].global_position = parts[i].global_position
		parts[i].modulate.a = 0.0
	await get_tree().process_frame  # The picker lays out its header first.
	if not _picker_open:
		for flyer in flyers:
			flyer.queue_free()
		return
	var offset := _list_host.global_position - _picker.global_position
	_picker_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_picker_tween.tween_property(_side, "position:x", width, PICKER_SWIPE_SECONDS)
	_picker_tween.tween_property(_picker, "position:x", 0.0, PICKER_SWIPE_SECONDS)
	var targets: Array[Control] = [_picker.header_swatch, _picker.header_name]
	for i in flyers.size():
		_picker_tween.tween_property(flyers[i], "global_position", targets[i].global_position + offset,
				PICKER_SWIPE_SECONDS)
		_picker_tween.tween_property(flyers[i], "scale", Vector2.ONE * ThreadPicker.HEADER_SCALE,
				PICKER_SWIPE_SECONDS)
	_picker_tween.chain().tween_callback(func() -> void:
		for flyer in flyers:
			flyer.queue_free()
		_picker.header_swatch.modulate.a = 1.0
		_picker.header_name.modulate.a = 1.0
		_side.visible = false)


## Back from the picker to the colour list, which swipes in from the right; with a `new_code`
## the colour `old_code` is replaced first, so the list comes back with it.
func _close_picker(old_code: String, new_code: String) -> void:
	if not _picker_open:
		return
	_picker_open = false
	if _picker_tween != null:
		_picker_tween.kill()
	if not new_code.is_empty():
		_project.replace_color(old_code, new_code, _palette)
		_apply_preferences()
		_full_pattern = _project.full_pattern(_palette)
		_show_pattern(true)
		_save()
	else:
		_fill_color_list()
	var width := _list_host.size.x
	_side.visible = true
	_side.position.x = width
	_picker_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_picker_tween.tween_property(_picker, "position:x", -width, PICKER_SWIPE_SECONDS)
	_picker_tween.tween_property(_side, "position:x", 0.0, PICKER_SWIPE_SECONDS)
	_picker_tween.chain().tween_callback(func() -> void: _picker.visible = false)


## Leaves the picker at once, without animation (another screen or project).
func _close_picker_now() -> void:
	if _picker == null:
		return
	if _picker_tween != null:
		_picker_tween.kill()
		_picker_tween = null
	var was_open := _picker_open
	_picker_open = false
	_picker.visible = false
	_side.visible = true
	_side.position.x = 0.0
	if was_open and _project != null:
		_fill_color_list()


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
	_close_picker_now()
	_overall_before = _project.session.leg_progress()
	_thread_done_before = _project.session.current_step(thread) == null
	_strike_code = ""
	_stitch_thread = thread
	_update_visibility()
	var step := _project.session.current_step(thread)
	if step != null:
		_view.focus_step(step, STITCH_CELL_PX)
	# After zooming, so the reference stitch is panned into view as well.
	_refresh_stitching()
	_update_progress()


## Back to the overview. Its bar starts where the project was when stitching began and fills up
## to now; a colour finished meanwhile is struck through in the list after that.
func _leave_stitching() -> void:
	if _stitch_thread < 0:
		return
	var thread := _stitch_thread
	var finished := _project.session.current_step(thread) == null and not _thread_done_before
	_strike_code = _project.pattern.thread_codes[thread] if finished else ""
	if _celebration != null:
		_celebration.queue_free()
		_celebration = null
		_loop_light(false)
	_stitch_thread = -1
	_shown_step = null
	_update_visibility()
	_set_back_side(false)
	_view.show_preview()
	_show_info()
	_fill_color_list()
	_open_overview_panels()
	_progress.set_color(ProgressStrip.DEFAULT_COLOR)
	_progress.set_value(_overall_before)
	_show_overall_progress.call_deferred()


## Fills the overview's bar up to the project's progress, then strikes through the colour just
## finished.
func _show_overall_progress() -> void:
	if _project == null or _stitch_thread >= 0:
		return
	_update_progress(true)
	if _strike_code.is_empty():
		return
	if _progress.is_filling():
		await _progress.fill_finished
	var strike: StrikeLine = _strikes.get(_strike_code)
	_strike_code = ""
	if strike == null or not is_instance_valid(strike) or _stitch_thread >= 0:
		return
	var struck := strike.strike()
	if _project.session.is_finished():
		await struck.finished
		if _stitch_thread < 0:
			_show_finale()


## The whole project is stitched: the big show, ending in a choice of what to do next.
func _show_finale() -> void:
	if _finale != null or _project == null:
		return
	if _touch:
		for entry in [[_menu_panel, _menu_button], [_list_panel, _list_button], [_text_panel, _text_button]]:
			_set_overlay(entry[0], entry[1], false, false)
		_view.set_covered(Finale.covered_top(size), Finale.covered_bottom())
	_view.fit_to_view()
	_finale = Finale.new()
	add_child(_finale)
	_finale.chosen.connect(_on_finale_chosen)
	_loop_light(true)
	_finale.play(_project.name, _project.pattern.total_stitches(), _project.pattern.thread_codes.size(),
			_view.pattern_rect())


## After the finale: back to the overview, or on to a new image or another project.
func _on_finale_chosen(choice: Finale.Choice) -> void:
	_finale = null
	_loop_light(false)
	_update_cover()
	match choice:
		Finale.Choice.OVERVIEW:
			_open_overview_panels()
			_view.fit_to_view()
		Finale.Choice.NEW_PROJECT:
			_show_open_image()
		Finale.Choice.OPEN_PROJECT:
			_show_projects()


## The bar shows the colour being stitched (in the colour of its block) or the whole project (in
## blue); the round buttons light up in the same colour when switched on. `animate` plays the
## bar's fill show.
func _update_progress(animate := false) -> void:
	_progress.visible = _project != null
	if _project == null:
		return
	var color := ProgressStrip.DEFAULT_COLOR
	var value := _project.session.leg_progress()
	if _stitch_thread >= 0:
		color = PatternView.block_color(_palette.find_code(_project.pattern.thread_codes[_stitch_thread]).color)
		value = _project.session.leg_progress(_stitch_thread)
	_progress.set_color(color, animate)
	_progress.set_value(value, animate)
	for button: RoundButton in [_menu_button, _list_button, _text_button, _menu_pin]:
		button.tint_color = color


## The colour is finished: once the bar is full, the celebration takes over the screen; a tap on
## it goes back to the overview.
func _celebrate() -> void:
	var thread := _stitch_thread
	if _progress.is_filling():
		await _progress.fill_finished
	if _stitch_thread != thread or _celebration != null or _project.session.current_step(thread) != null:
		return
	_celebration = Celebration.new()
	add_child(_celebration)
	_celebration.dismissed.connect(func() -> void:
		_celebration = null
		_loop_light(false)
		_leave_stitching())
	_loop_light(true)
	_celebration.play(_palette.find_code(_project.pattern.thread_codes[thread]),
			_project.pattern.stitch_counts()[thread], _progress.color, _progress.bar_rect())


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
	_shown_step = step
	_shown_hint = hint
	_shown_thread_end = thread_end
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
	_set_back_side(not _view.back_side, true)
	if _stitch_thread >= 0:
		_refresh_stitching()


## Shows the back or the front; with `animate` the fabric turns over on screen.
func _set_back_side(back: bool, animate := false) -> void:
	_view.set_back_side(back, animate)
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
		_update_progress(true)
		_spin_light()
		if _project.session.current_step(_stitch_thread) == null:
			_celebrate()


func _previous_step() -> void:
	if _stitch_thread >= 0 and _project.session.done_count(_stitch_thread) > 0:
		_project.session.go_back(_stitch_thread)
		_refresh_stitching()
		_save()
		_update_progress(true)


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
	var flip := -1.0
	var zoom := 0.0
	var overlays := PackedStringArray()
	var tooltip := ""
	var picker_code := ""
	var pick_code := ""
	var picker_view := PackedStringArray()
	var finish := false
	var finale := false
	var dismiss := false
	var wait := 0.0
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
		elif arg.begins_with("--back-pass="):
			Preferences.set_whole_back(arg.trim_prefix("--back-pass=") == "whole")
			if _project != null:
				_apply_preferences()
		elif arg.begins_with("--max-block="):
			Preferences.set_max_block(arg.trim_prefix("--max-block=").to_int())
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
		elif arg == "--finish":
			finish = true
		elif arg == "--finale":
			finale = true
		elif arg == "--dismiss":
			dismiss = true
		elif arg.begins_with("--wait="):
			wait = arg.trim_prefix("--wait=").to_float()
		elif arg.begins_with("--zoom="):
			zoom = arg.trim_prefix("--zoom=").to_float()
		elif arg.begins_with("--flip="):
			flip = arg.trim_prefix("--flip=").to_float()
		elif arg.begins_with("--light="):
			var light := arg.trim_prefix("--light=").split(",")
			Preferences.set_light(light[0].to_float(),
					light[1].to_float() if light.size() > 1 else Preferences.light_elevation())
			_restore_light()
		elif arg == "--projects":
			_show_projects.call_deferred()
		elif arg.begins_with("--max-skip="):
			Preferences.set_max_skip(arg.trim_prefix("--max-skip=").to_int())
			if _project != null:
				_apply_preferences()
		elif arg.begins_with("--start="):
			var corner := arg.trim_prefix("--start=")
			Preferences.set_direction(not corner.begins_with("bottom"), not corner.ends_with("right"),
					corner == "auto")
			if _project != null:
				_apply_preferences()
		elif arg.begins_with("--ui="):
			Preferences.set_touch_mode(arg.trim_prefix("--ui=") == "touch")
			_apply_ui_mode()
		elif arg.begins_with("--picker="):
			picker_code = arg.trim_prefix("--picker=")
		elif arg.begins_with("--picker-view="):
			picker_view = arg.trim_prefix("--picker-view=").split(",")
		elif arg.begins_with("--pick="):
			pick_code = arg.trim_prefix("--pick=")
		elif arg.begins_with("--overlays="):
			overlays = arg.trim_prefix("--overlays=").split(",")
		elif arg.begins_with("--tooltip="):
			tooltip = arg.trim_prefix("--tooltip=")
		elif arg.begins_with("--safe-area="):
			var sides := arg.trim_prefix("--safe-area=").split(",")
			if sides.size() == 4:
				_safe = Vector4(sides[0].to_float(), sides[1].to_float(), sides[2].to_float(), sides[3].to_float())
				_safe_from_cmdline = true
				_update_layout()
		elif arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
	if not stitch_code.is_empty() and _project != null and _project.pattern.thread_codes.has(stitch_code):
		await get_tree().process_frame  # Let the screen lay out first, as before a real tap.
		_enter_stitching(_project.pattern.thread_codes.find(stitch_code))
		for i in steps:
			_next_step()
		if finish:
			while _stitch_thread >= 0 and _project.session.current_step(_stitch_thread) != null:
				_next_step()
			while _stitch_thread >= 0 and (_celebration == null or _celebration.is_arriving()):
				await get_tree().process_frame
			if dismiss and _celebration != null:
				await get_tree().create_timer(Celebration.TAP_DELAY_SECONDS).timeout
				_celebration.leave()
				while _stitch_thread >= 0:
					await get_tree().process_frame
		var step := _project.session.current_step(_stitch_thread) if _stitch_thread >= 0 else null
		if zoom > 0.0 and step != null:
			_view.focus_step(step, zoom)
		if back:
			_toggle_back_side()
			if flip >= 0.0:
				_view.hold_flip(flip)
	if _touch and (not overlays.is_empty() or not tooltip.is_empty()):
		_set_overlay(_menu_panel, _menu_button, overlays.has("menu") or overlays.has("pin"), false)
		_menu_pin.button_pressed = overlays.has("pin")
		_set_overlay(_list_panel, _list_button, overlays.has("list"), false)
		_set_overlay(_text_panel, _text_button, overlays.has("text"), false)
		var tooltip_button: RoundButton = {"menu": _menu_button, "list": _list_button,
				"text": _text_button}.get(tooltip)
		if tooltip_button != null:
			await get_tree().process_frame
			tooltip_button.show_tooltip()
	if not picker_code.is_empty() and _project != null and _stitch_thread < 0:
		await get_tree().process_frame
		for row in _color_list.get_children():
			if row.get_child(1) is Label and (row.get_child(1) as Label).text == picker_code:
				_open_picker(_palette.find_code(picker_code), row.get_child(0), row.get_child(2))
		while _picker_tween == null or _picker_tween.is_running():
			await get_tree().process_frame
		if not picker_view.is_empty():
			_picker.set_view(picker_view.has("list"), picker_view.has("project"))
			while _picker.is_animating():
				await get_tree().process_frame
		if not pick_code.is_empty():
			_picker.choose(pick_code)
			while _picker.is_animating():
				await get_tree().process_frame
	if finale and _project != null:
		await get_tree().process_frame
		_show_finale()
	if screenshot_path.is_empty():
		return
	while (not _overlay_moving.is_empty() or _view.is_panning() or _settings_dialog.is_animating()
			or _project_browser.is_animating()):
		await get_tree().process_frame
	if _view.is_flipping() and flip < 0.0:
		await _view.flip_finished
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	else:
		while _progress.is_filling():
			await get_tree().process_frame
	for i in 3:
		await get_tree().process_frame
	# Low processor mode draws only when something changed, so ask for one more frame.
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	get_tree().quit()

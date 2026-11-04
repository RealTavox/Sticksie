extends Control
## Start screen: open a pixel-art image, show it as a cross-stitch pattern with its threads, and
## stitch one thread at a time with step-by-step guidance. Every change is saved right away; on
## start the last project opens again.
##
## Command line (after `--`): `--projects-dir=<path>` keeps projects in another folder (for test
## runs), `--max-holes=<n>` how far from the last hole counting still starts there (saved),
## `--open=<path>` opens an image as a new project, `--import=<path>` imports an exported
## project file, `--export=<path>` writes the open project's export file there,
## `--storage=<safe|may-clear|not-kept>` pretends the browser keeps the projects that safely
## (BrowserStorage, for the warnings), `--max-skip=<n>` sets the skip limit
## (-1: none), `--start=<corner>` sets the start corner (auto, top-left, top-right, bottom-left,
## bottom-right), `--settings` opens the settings dialog (`--advanced`: with the advanced part open),
## `--method=<english|danish>` sets the stitch method, `--back-pass=<whole|blocks>` the Danish
## return pass, `--max-block=<n>` the most stitches per block, `--needle=<auto|bottom|top>` and
## `--first-leg=<slash|backslash>` the stitch style (bottom/top/first-leg fix it), `--projects` the project list, `--legal` the Impressum & Datenschutz window (`--legal-notices`: with the licence texts open), `--stitch=<code>` starts stitching that thread, `--steps=<n>` confirms n steps, `--back` shows the back while stitching, `--loading=<text>` or `--loading=still,<text>` holds the loading hint, `--screenshot=<png path>` saves a screenshot after a few
## frames and quits (`--wait=<seconds>` waits that much longer, e.g. into an animation).
## `--keys=<key>[:<seconds>],…` presses keys one after the other (held that long), after the steps.
## `--finish` stitches the rest of the `--stitch` colour (the celebration comes in),
## `--dismiss` then taps it away to the overview. `--finale` shows the show for a finished project. `--ui=<touch|desktop>` sets the layout, `--ui-scale=<factor>` the UI-Skalierung (both saved), `--overlays=<menu,pin,list,text>`
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
const MAX_SIDE := 1000
## Big work gets done in parts this long (microseconds), so the loading hint keeps moving.
const LOADING_SLICE_USEC := 25000
## From how many stitches a pattern's changes show the hint at once and a thread is planned apart
## from the frames.
const BIG_PATTERN_STITCHES := 40000
const BIG_THREAD_STITCHES := 5000
## A project file of this size (bytes) takes noticeably long to read.
const BIG_PROJECT_BYTES := 500000
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
## Tempo of the symbol window's animations in the settings: label and speed factor.
const SYMBOL_SPEEDS := [["Normal", 1.0], ["Schneller (1,5×)", 1.5], ["Schnell (2×)", 2.0], ["Sehr schnell (3×)", 3.0]]
## UI-Skalierung in the settings: label and factor (Preferences.ui_scale()). Phones in portrait
## are 720 canvas pixels wide at 100 %; at 175 % (411) the windows still fit, at 200 % they don't.
const UI_SCALES := [["100 % (normal)", 1.0], ["125 %", 1.25], ["150 %", 1.5], ["175 %", 1.75]]
const LEG_ORDERS := ["Erst / dann \\", "Erst \\ dann /"]
const NEEDLE_STARTS := ["Nadel immer unten hoch (Schenkel von unten nach oben)",
		"Nadel immer oben hoch (Schenkel von oben nach unten)"]
const CREDIT := "Garnfarben: craft-color-codes von MakeBead (makebead.com), CC BY 4.0"
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
## How fast held WASD or arrow keys move the view, in canvas pixels per second.
const KEY_PAN_SPEED := 700.0
## Zoom per press of + or −.
const KEY_ZOOM := 1.25
## Keys that move the view and the way it goes (the pattern moves the other way).
const PAN_KEYS := {
	KEY_W: Vector2.UP, KEY_UP: Vector2.UP, KEY_S: Vector2.DOWN, KEY_DOWN: Vector2.DOWN,
	KEY_A: Vector2.LEFT, KEY_LEFT: Vector2.LEFT, KEY_D: Vector2.RIGHT, KEY_RIGHT: Vector2.RIGHT,
}
## The keys for zooming and moving, small under the colour list in the mouse-and-keyboard layout
## (StitchPanel.DESKTOP_HINT names them all while stitching).
const KEYS_HINT := "Mausrad oder + / −: zoomen · rechte Maustaste ziehen, WASD oder Pfeiltasten: verschieben"

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
var _legal_window: LegalWindow
## Touch overlays closed while the file dialog, the project list or the settings are open, as
## [panel, button] pairs; they open again when it closes.
var _hidden_overlays: Array[Array] = []
var _limit_box: CheckBox
## Warnings under the settings with a recommended choice, shown only while another one is chosen.
var _method_warning: Label
var _corner_warning: Label
var _guide_warning: Label
var _limit_warning: Label
var _corner_option: OptionButton
var _limit_spin: SpinBox
var _method_cards: ChoiceCards
## Pictures under the settings that follow their choice, and the symbol window's preview with its tip.
var _corner_picture: SettingPicture
var _guide_picture: SettingPicture
var _limit_picture: SettingPicture
var _hole_spin: SpinBox
var _hole_picture: SettingPicture
var _symbols_preview: StepSymbols
var _symbols_tip: Label
var _whole_back_box: CheckBox
var _block_spin: SpinBox
## Entwicklertools in the settings, only in debug builds: the light, the sample image and the
## developer mode.
var _dev_tools_button: Button
var _dev_tools_box: VBoxContainer
var _dev_mode_box: CheckBox
## Shown under the menu button in developer mode; a toggle without a job yet.
var _dev_button: RoundButton
## The symbol window at the top of the stitching screen, its switch in the advanced settings,
## and whether it has been put in place since it last appeared (then it glides when it moves).
var _symbols: StepSymbols
var _symbols_box: CheckBox
var _symbols_still_box: CheckBox
var _symbols_speed_option: OptionButton
var _symbols_placed := false
## How far below the pattern's upper edge it was last put (the safe area or the open menu).
var _symbols_top := 0.0
var _symbols_tween: Tween
var _needle_option: OptionButton
var _leg_option: OptionButton
var _needle_start_option: OptionButton
var _overview_button: Button
var _side_button: Button
var _info_label: Label
var _keys_hint: Label
## Pan keys (PAN_KEYS) pressed on the screen and maybe still held; _process() moves the view.
var _held_pan_keys := {}
var _toolbar: HFlowContainer
var _shell_root: Control
var _menu_panel: PanelContainer
var _menu_content: VBoxContainer
var _menu_pin: RoundButton
## Top of the bottom row: the round buttons and the bar (touch) or just the bar.
var _bottom_row := 0.0
var _dock: BoxContainer
var _dock_spacer: Control
var _list_panel: PanelContainer
var _list_content: VBoxContainer
var _text_panel: PanelContainer
var _text_content: VBoxContainer
var _menu_button: RoundButton
var _list_button: RoundButton
var _text_button: RoundButton
var _ui_cards: ChoiceCards
var _ui_scale_option: OptionButton
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
var _files: FileExchange
var _loading: LoadingHint
## Whether the browser was asked to keep the projects this session (BrowserStorage.request()).
var _storage_requested := false
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
## A touch outside the open colour picker closed it; the rest of that touch (and its emulated
## mouse twin) is swallowed.
var _eating_pointer := false
## Zoom and position of the overview when stitching began, so going back shows it as it was
## (and as the picture the page slides used).
var _overview_view := []


func _ready() -> void:
	var opens_image := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--projects-dir="):
			ProjectStore.directory = arg.trim_prefix("--projects-dir=")
		opens_image = opens_image or arg.begins_with("--open=")
	set_process(false)  # Only while pan keys are held.
	_palette = FlossPalette.dmc()
	BrowserStorage.check()
	_apply_ui_scale(Preferences.ui_scale())
	_build_ui()
	resized.connect(_update_layout)
	get_window().files_dropped.connect(_on_files_dropped)
	_apply_ui_mode()
	_apply_light()
	_apply_style()
	if not opens_image:
		var last := ProjectStore.last_project_path()
		if not last.is_empty() and FileAccess.file_exists(last):
			await _open_project(last)
	if BrowserStorage.safety == BrowserStorage.Safety.NOT_KEPT:
		_show_message(BrowserStorage.warning())
	_handle_cmdline()


func _build_ui() -> void:
	_files = FileExchange.new()
	# The project list keeps the overlays hidden until it closes itself.
	_files.closed.connect(func() -> void:
		if not _project_browser.is_open():
			_restore_overlays())
	_files.failed.connect(_report)
	add_child(_files)

	# These open a window, which closes the menu itself (and opens it again afterwards).
	_toolbar = HFlowContainer.new()
	_open_button = _make_toolbar_button("Neu", _show_open_image, ButtonIcons.Icon.IMAGE, false)
	_toolbar.add_child(_open_button)
	_projects_button = _make_toolbar_button("Projekte", _show_projects, ButtonIcons.Icon.PROJECTS, false)
	_toolbar.add_child(_projects_button)
	_overview_button = _make_toolbar_button("Übersicht", _slide_to_overview, ButtonIcons.Icon.OVERVIEW)
	_overview_button.visible = false
	_toolbar.add_child(_overview_button)
	_side_button = _make_toolbar_button("Rückseite", _toggle_back_side, ButtonIcons.Icon.FLIP)
	_side_button.visible = false
	_toolbar.add_child(_side_button)
	# Last, so it comes after Rückseite while stitching.
	_toolbar.add_child(_make_toolbar_button("Einstellungen", _show_settings, ButtonIcons.Icon.GEAR, false))
	_toolbar.add_child(_make_toolbar_button("Impressum & Datenschutz", _show_legal, ButtonIcons.Icon.INFO, false))
	_info_label = Label.new()
	_info_label.text = "Öffne ein Pixelart-Bild. Ein Pixel wird ein Kreuzstich."
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_view = PatternView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.tapped.connect(_on_view_gesture.bind(_next_step))
	_view.double_tapped.connect(_on_view_gesture.bind(_previous_step))
	_view.two_finger_double_tapped.connect(_on_view_gesture.bind(_toggle_new_thread))
	_view.swiped_from_right.connect(_on_view_gesture.bind(_swipe_side))
	# The swipe back already slid the page away, so it counts even after a touch closed the menu.
	_view.swiped_from_left.connect(func() -> void:
		_swallow_tap = false
		_leave_stitching())
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
	_keys_hint = Label.new()
	_keys_hint.text = KEYS_HINT
	_keys_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_hint.add_theme_font_size_override("font_size", 12)
	_keys_hint.modulate.a = 0.6
	_side.add_child(_keys_hint)
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
	# Its wrapped labels first measure themselves at no width, a word a line, and only shrink
	# once laid out; fit again then, or the list keeps that height and they end up out of sight.
	_side.minimum_size_changed.connect(func() -> void: _fit_list_host.call_deferred())
	_picker = ThreadPicker.new()
	_picker.visible = false
	_picker.confirmed.connect(_close_picker)
	_picker.cancelled.connect(_close_picker.bind("", ""))
	_list_host.add_child(_picker)

	_progress = ProgressStrip.new()
	_progress.visible = false

	_stitch_panel = StitchPanel.new()
	_stitch_panel.visible = false  # Only holds the signals; its texts and buttons go in the panels.
	_stitch_panel.next_pressed.connect(_next_step)
	_stitch_panel.previous_pressed.connect(_previous_step)
	_stitch_panel.new_thread_toggled.connect(_toggle_new_thread)
	add_child(_stitch_panel)
	_build_shell()
	# Above the pattern and the touch panels, below the windows.
	_symbols = StepSymbols.new()
	_symbols.still = Preferences.step_symbols_still()
	_symbols.speed = Preferences.step_symbols_speed()
	_symbols.visible = false
	add_child(_symbols)
	_build_settings_dialog()
	_project_browser = ProjectBrowser.new()
	_project_browser.open_requested.connect(_open_project)
	_project_browser.project_renamed.connect(_on_project_renamed)
	_project_browser.project_deleted.connect(_on_project_deleted)
	_project_browser.export_requested.connect(_export_project)
	_project_browser.import_requested.connect(_files.pick.bind(FileExchange.Kind.PROJECT, _import_project))
	_project_browser.closed.connect(_restore_overlays)
	add_child(_project_browser)
	_legal_window = LegalWindow.new()
	_legal_window.closed.connect(_restore_overlays)
	add_child(_legal_window)
	_loading = LoadingHint.new()
	add_child(_loading)


## The pattern on the whole screen, the progress bar and the overlay panels above it: the menu
## (the toolbar), the texts and the colour list or stitching buttons; in the touch layout also
## the three round buttons that open and close them. Only the panels and buttons take input; the
## rest goes through to the view.
func _build_shell() -> void:
	_shell_root = Control.new()
	_shell_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shell_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shell_root)
	_shell_root.add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shell_root.add_child(_progress)

	_menu_panel = _make_overlay_panel()
	_menu_panel.anchor_right = 1.0
	_shell_root.add_child(_menu_panel)
	var menu_row := HBoxContainer.new()
	_menu_panel.add_child(menu_row)
	_menu_content = VBoxContainer.new()
	_menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_row.add_child(_menu_content)
	_menu_content.add_child(_toolbar)
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
	_shell_root.add_child(_dock)
	_text_panel = _make_overlay_panel()
	_dock.add_child(_text_panel)
	_text_content = VBoxContainer.new()
	_text_panel.add_child(_text_content)
	_text_content.add_child(_info_label)
	_place(_stitch_panel.info, _text_content)
	_dock_spacer = Control.new()
	_dock_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock.add_child(_dock_spacer)
	_list_panel = _make_overlay_panel()
	_dock.add_child(_list_panel)
	_list_content = VBoxContainer.new()
	_list_panel.add_child(_list_content)
	_list_content.add_child(_list_host)
	_place(_stitch_panel.controls, _list_content)

	_menu_button = _make_round_button(ButtonIcons.Icon.MENU, "Menü: Neu, Projekte, Einstellungen", _menu_panel)
	_list_button = _make_round_button(ButtonIcons.Icon.SPOOL, "", _list_panel)
	_text_button = _make_round_button(ButtonIcons.Icon.TEXT, "", _text_panel)
	_dev_button = RoundButton.new(ButtonIcons.Icon.WRENCH, "Entwicklermodus (noch ohne Funktion)", ROUND_BUTTON_PX)
	_dev_button.toggle_mode = true
	_shell_root.add_child(_dev_button)
	# In the mouse-and-keyboard layout it sits under the menu, which may wrap to more rows.
	_menu_panel.resized.connect(_place_dev_button)


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
	button.toggled.connect(func(on: bool) -> void:
		_set_overlay(panel, button, on)
		if _stitch_thread >= 0 and panel != _menu_panel:
			Preferences.set_stitch_panels(_list_button.button_pressed, _text_button.button_pressed))
	_shell_root.add_child(button)
	return button


## Opens or closes a touch overlay together with its button; with `animate` it slides and
## fades (the view keeps the current step clear of it once it has arrived).
func _set_overlay(panel: Control, button: RoundButton, open: bool, animate := true) -> void:
	button.set_pressed_no_signal(open)
	var tween: Tween = _overlay_tweens.get(panel)
	if open and panel.visible and tween == null and _overlay_moving.has(panel):
		# An opening waiting for the dock's layout does it already (taking it over would leave the
		# panel see-through: it is already visible, so this call would think it open).
		return
	var call: int = _overlay_calls.get(panel, 0) + 1
	_overlay_calls[panel] = call
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
	window.safe_area = _safe
	window.open()


## Switches between the touch layout and the one for mouse and keyboard
## (Preferences.touch_mode()). Both show the same panels on the pattern; touch opens and closes
## them with round buttons, mouse and keyboard has them always open, and its hints name keys and
## clicks instead of gestures.
func _apply_ui_mode() -> void:
	_close_picker_now()
	_touch = Preferences.touch_mode()
	_stitch_panel.set_touch(_touch)
	_keys_hint.visible = not _touch
	if not _touch:
		_open_all_panels()
	elif _project == null:
		_set_overlay(_menu_panel, _menu_button, true)
	_update_visibility()
	_update_layout()


## The panels of the mouse-and-keyboard layout, which has no buttons to open them.
func _open_all_panels() -> void:
	for entry: Array in [[_menu_panel, _menu_button], [_list_panel, _list_button], [_text_panel, _text_button]]:
		_set_overlay(entry[0], entry[1], true, false)


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
	_update_symbols()
	_open_button.visible = not stitching
	_projects_button.visible = not stitching
	_overview_button.visible = stitching
	_side_button.visible = stitching
	_list_host.visible = not stitching
	_info_label.visible = not stitching
	_stitch_panel.info.visible = stitching
	_stitch_panel.controls.visible = stitching
	if stitching:
		_list_button.icon = ButtonIcons.Icon.NEEDLE
		_list_button.tooltip = "Sticken: zurück, gestickt, neuer Faden"
		_text_button.tooltip = "Anleitung zum Schritt ein- und ausblenden"
	else:
		_list_button.icon = ButtonIcons.Icon.SPOOL
		_list_button.tooltip = "Garnfarben: eine Farbe zum Sticken wählen"
		_text_button.tooltip = "Projektinfo ein- und ausblenden"


## The light on fabric and thread in the developer tools: where it comes from and how high
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
	for button: RoundButton in [_menu_button, _list_button, _text_button, _menu_pin, _dev_button]:
		button.set_light(light.x, light.y)


## The light as saved, on the sliders and on screen (after Abbrechen or `--light`).
func _restore_light() -> void:
	_light_azimuth.set_value_no_signal(Preferences.light_azimuth())
	_light_elevation.set_value_no_signal(Preferences.light_elevation())
	_apply_light()


## Draws everything `factor` times as big as designed (UI-Skalierung). The overview fits the
## pattern to the screen's new size; while stitching the view keeps its zoom.
func _apply_ui_scale(factor: float) -> void:
	if is_equal_approx(get_window().content_scale_factor, factor):
		return
	get_window().content_scale_factor = factor
	if _project != null and _stitch_thread < 0:
		await get_tree().process_frame
		_view.fit_to_view()


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
## were and puts the saved light and UI-Skalierung back (both show right away). Choices with two
## sides are big picture cards (ChoiceCards); the other settings show a picture of what they do
## under them (SettingPicture), and the symbol window's settings play all its cards.
func _build_settings_dialog() -> void:
	_settings_dialog = OverlayWindow.new("Einstellungen")
	_settings_dialog.buttons.add_child(OverlayWindow.make_button("Abbrechen", ButtonIcons.Icon.CLOSE,
			_settings_dialog.close))
	_settings_dialog.buttons.add_child(OverlayWindow.make_primary(OverlayWindow.make_button("Übernehmen",
			ButtonIcons.Icon.CHECK, func() -> void:
				_apply_settings()
				_settings_dialog.close())))
	_settings_dialog.closed.connect(func() -> void:
		_restore_light()
		_apply_ui_scale(Preferences.ui_scale())
		_restore_overlays())
	add_child(_settings_dialog)
	var content := _settings_dialog.content
	content.add_theme_constant_override("separation", 8)
	content.add_child(_make_heading("Bedienung"))
	_ui_cards = ChoiceCards.new([["Touch", SettingPicture.Kind.TOUCH],
			["Maus + Tastatur", SettingPicture.Kind.MOUSE_KEYBOARD]])
	content.add_child(_ui_cards)
	content.add_child(HSeparator.new())
	content.add_child(_make_heading("UI-Skalierung"))
	_ui_scale_option = _make_option(UI_SCALES.map(func(choice: Array) -> String: return choice[0]))
	_ui_scale_option.item_selected.connect(func(index: int) -> void: _apply_ui_scale(UI_SCALES[index][1]))
	content.add_child(_ui_scale_option)
	content.add_child(_make_note("Macht Schrift, Knöpfe, Fenster und Muster größer. Wirkt sofort, "
			+ "Abbrechen nimmt es zurück."))
	content.add_child(HSeparator.new())
	_build_symbol_settings(content)
	content.add_child(HSeparator.new())
	content.add_child(_make_heading("Stichmethode"))
	_method_cards = ChoiceCards.new([["Dänisch", SettingPicture.Kind.DANISH],
			["Englisch", SettingPicture.Kind.ENGLISH]])
	content.add_child(_method_cards)
	var method_note := _make_note(METHODS[0])
	content.add_child(method_note)
	content.add_child(_make_note("Empfohlen: Dänisch."))
	_method_warning = _make_warning()
	content.add_child(_method_warning)
	_method_cards.selected_changed.connect(func(index: int) -> void:
		method_note.text = METHODS[index]
		_whole_back_box.disabled = index == 1
		_update_warnings())
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
	content.add_child(_make_heading("Anfangen in der Ecke"))
	_corner_option = _make_option(START_CORNERS.map(func(corner: Array) -> String: return corner[0]))
	content.add_child(_corner_option)
	_corner_picture = SettingPicture.new(SettingPicture.Kind.CORNER, true)
	content.add_child(_corner_picture)
	_corner_option.item_selected.connect(func(index: int) -> void:
		_corner_picture.corner = index
		_update_warnings())
	content.add_child(_make_note("Empfohlen: Automatisch. Jede Farbe beginnt dort und läuft so, dass "
			+ "am wenigsten Faden hinten weiterläuft oder neu nötig ist. Mit einer Ecke geht es dort "
			+ "los, jede Reihe läuft von dieser Seite aus und die Reihen kommen in dieser Richtung dran "
			+ "(Fläche für Fläche, so weit es geht)."))
	_corner_warning = _make_warning()
	content.add_child(_corner_warning)
	content.add_child(HSeparator.new())
	_build_guide_settings(content)
	content.add_child(HSeparator.new())
	content.add_child(_make_heading("Zählen"))
	var hole_row := HBoxContainer.new()
	content.add_child(hole_row)
	var hole_text := Label.new()
	hole_text.text = "Vom letzten Loch des Fadens zählen bis"
	hole_row.add_child(hole_text)
	_hole_spin = SpinBox.new()
	_hole_spin.min_value = 1
	_hole_spin.max_value = 30
	_hole_spin.value = PositionHint.DEFAULT_MAX_HOLES
	_hole_spin.value_changed.connect(func(value: float) -> void: _hole_picture.hole_limit = int(value))
	hole_row.add_child(_hole_spin)
	var hole_unit := Label.new()
	hole_unit.text = "Löcher"
	hole_row.add_child(hole_unit)
	_hole_picture = SettingPicture.new(SettingPicture.Kind.HOLE_LIMIT, true)
	content.add_child(_hole_picture)
	content.add_child(_make_note(("Bis dahin zählst du ab dem Loch, durch das dein Faden zuletzt nach "
			+ "hinten ging. Liegt der nächste Stich weiter weg, zählst du ab einem markanten Stich, etwa "
			+ "dem Ende einer Reihe; das Symbolfenster zeigt dann ein Warnschild. Empfohlen: %d.")
			% PositionHint.DEFAULT_MAX_HOLES))
	content.add_child(HSeparator.new())
	content.add_child(_make_heading("Fadenwechsel"))
	_limit_box = CheckBox.new()
	_limit_box.text = "Faden automatisch wechseln, wenn er auf der Rückseite mehr als"
	_limit_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_limit_box)
	var row := HBoxContainer.new()
	content.add_child(row)
	_limit_spin = SpinBox.new()
	_limit_spin.min_value = 0
	_limit_spin.max_value = 30
	_limit_spin.value = Preferences.DEFAULT_MAX_SKIP
	row.add_child(_limit_spin)
	var unit := Label.new()
	unit.text = "Felder überspringen müsste."
	row.add_child(unit)
	_limit_picture = SettingPicture.new(SettingPicture.Kind.THREAD_LIMIT, true)
	content.add_child(_limit_picture)
	content.add_child(_make_note("Empfohlen: an, %d Felder. Aus: Der Faden wird nie automatisch gewechselt, "
			% Preferences.DEFAULT_MAX_SKIP
			+ "er darf beliebig weit springen. Längere Fäden auf der Rückseite verhaken sich und scheinen "
			+ "durch. Einen neuen Faden kannst du beim Sticken jederzeit selbst nehmen."))
	_limit_warning = _make_warning()
	content.add_child(_limit_warning)
	_limit_box.toggled.connect(func(on: bool) -> void:
		_limit_spin.editable = on
		_limit_picture.limit_on = on
		_update_warnings())
	_limit_spin.value_changed.connect(func(_value: float) -> void: _update_warnings())
	var light_row := _make_light_row()
	if OS.is_debug_build():
		_build_dev_tools(content, light_row)


## The symbol window: on or off, still pictures or how fast; while on, every card plays here once
## at the chosen tempo (a tap plays one again).
func _build_symbol_settings(content: VBoxContainer) -> void:
	content.add_child(_make_heading("Symbolfenster"))
	_symbols_box = CheckBox.new()
	_symbols_box.text = "Beim Sticken Symbole zeigen (Vernähen, Einfädeln, Zählen, Anfangen, Stich)"
	_symbols_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_symbols_box)
	var preview_row := CenterContainer.new()
	content.add_child(preview_row)
	_symbols_preview = StepSymbols.new()
	preview_row.add_child(_symbols_preview)
	preview_row.resized.connect(func() -> void: _symbols_preview.max_width = preview_row.size.x)
	_symbols_tip = _make_note("Tippe auf ein Symbol, um es noch einmal abzuspielen.")
	_symbols_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_symbols_tip)
	_symbols_still_box = CheckBox.new()
	_symbols_still_box.text = "Als Standbild (gleich das fertige Bild, ohne Animation)"
	_symbols_still_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_symbols_still_box)
	var speed_row := HBoxContainer.new()
	var speed_label := Label.new()
	speed_label.text = "Tempo der Animationen:"
	speed_row.add_child(speed_label)
	_symbols_speed_option = _make_option(SYMBOL_SPEEDS.map(func(speed: Array) -> String: return speed[0]))
	_symbols_speed_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_row.add_child(_symbols_speed_option)
	content.add_child(speed_row)
	_symbols_box.toggled.connect(func(_on: bool) -> void: _update_symbol_options(true))
	_symbols_still_box.toggled.connect(func(_on: bool) -> void: _update_symbol_options(true))
	_symbols_speed_option.item_selected.connect(func(_index: int) -> void: _update_symbol_options(true))


## Greys out what doesn't count (without the window, or as still pictures) and shows the preview
## as chosen; `replay` plays it from the start.
func _update_symbol_options(replay: bool) -> void:
	var on := _symbols_box.button_pressed
	_symbols_still_box.disabled = not on
	_symbols_speed_option.disabled = not on or _symbols_still_box.button_pressed
	_symbols_preview.get_parent().visible = on
	_symbols_tip.visible = on
	_symbols_preview.speed = SYMBOL_SPEEDS[_symbols_speed_option.selected][1]
	_symbols_preview.still = _symbols_still_box.button_pressed
	if on and replay:
		_symbols_preview.show_preview()


## How each cross is worked: automatic or fixed leg order and needle start, with a Danish pass
## over two cells worked that way.
func _build_guide_settings(content: VBoxContainer) -> void:
	content.add_child(_make_heading("Stickführung"))
	content.add_child(_make_note("Welcher Schenkel zuerst, wo die Nadel hochkommt:", 1.0))
	_needle_option = _make_option(NEEDLE_MODES)
	_needle_option.item_selected.connect(func(_index: int) -> void: _update_needle_options())
	content.add_child(_needle_option)
	_leg_option = _make_option(LEG_ORDERS)
	_leg_option.item_selected.connect(func(_index: int) -> void: _update_needle_options())
	content.add_child(_leg_option)
	_needle_start_option = _make_option(NEEDLE_STARTS)
	_needle_start_option.item_selected.connect(func(_index: int) -> void: _update_needle_options())
	content.add_child(_needle_start_option)
	_guide_picture = SettingPicture.new(SettingPicture.Kind.STITCH_GUIDE, true)
	content.add_child(_guide_picture)
	content.add_child(_make_note("Punkt: Die Nadel kommt hoch, Pfeil: bis dahin, Zahl: Reihenfolge, gestrichelt: "
			+ "der Faden auf der Rückseite. Empfohlen: Automatisch, erst /, dann \\. Die Nadel kommt immer "
			+ "so hoch, dass auf der Rückseite nur kurze Stiche von einem Loch zum nächsten bleiben. "
			+ "Fest: jeder Schenkel genau so, wie gewählt. Auf der Rückseite kann der Faden dann "
			+ "schräg über zwei Felder laufen. Nicht mitten im Projekt wechseln, sonst liegen die "
			+ "oberen Schenkel nicht mehr gleich."))
	_guide_warning = _make_warning()
	content.add_child(_guide_warning)


## A section title in the settings.
static func _make_heading(text: String) -> Label:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 17)
	return heading


## Tools for development, closed at first: the light, the sample image and the developer mode.
## Only in debug builds (editor and debug exports); the light sliders exist anyway, as they
## hold the saved light.
func _build_dev_tools(content: VBoxContainer, light_row: Control) -> void:
	content.add_child(HSeparator.new())
	_dev_tools_button = _make_section_button(_show_dev_tools)
	content.add_child(_dev_tools_button)
	_dev_tools_box = VBoxContainer.new()
	content.add_child(_dev_tools_box)
	_dev_tools_box.add_child(light_row)
	_dev_tools_box.add_child(_make_note("Richtung im Uhrzeigersinn von oben (315 = oben links) und Höhe über "
			+ "dem Stoff (90 = genau von oben). Nach jedem Schritt kreist das Licht einmal auf einem Oval."))
	_dev_tools_box.add_child(HSeparator.new())
	# Opening the sample leaves the settings unchanged, like Abbrechen.
	var sample_button := OverlayWindow.make_button("Beispielbild öffnen", ButtonIcons.Icon.IMAGE, func() -> void:
		_settings_dialog.close()
		_open_image(SAMPLE_PATH))
	sample_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_dev_tools_box.add_child(sample_button)
	_dev_tools_box.add_child(_make_note("Ein kleines Muster zum Ausprobieren, als neues Projekt."))
	_dev_tools_box.add_child(HSeparator.new())
	_dev_mode_box = CheckBox.new()
	_dev_mode_box.text = "Entwicklermodus"
	_dev_tools_box.add_child(_dev_mode_box)
	_dev_tools_box.add_child(_make_note("Zeigt im Touch-Layout einen Knopf unter dem Menüknopf (noch ohne Funktion)."))
	_show_dev_tools(false)


## A flat button that opens and closes a part of the settings.
func _make_section_button(on_toggled: Callable) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.toggled.connect(on_toggled)
	return button


func _show_dev_tools(open: bool) -> void:
	if _dev_tools_button == null:
		return
	_dev_tools_button.set_pressed_no_signal(open)
	_dev_tools_button.text = ("▾ " if open else "▸ ") + "Entwicklertools"
	_dev_tools_box.visible = open


## Shows each warning only while its setting differs from the recommended choice.
func _update_warnings() -> void:
	if _limit_warning == null or _guide_warning == null:
		return  # still building the window
	_method_warning.visible = _method_cards.selected != 0
	_corner_warning.visible = _corner_option.selected != 0
	_guide_warning.visible = _needle_option.selected != 0
	_limit_warning.visible = (not _limit_box.button_pressed
			or int(_limit_spin.value) != Preferences.DEFAULT_MAX_SKIP)


## The note under the settings that have a recommended choice.
static func _make_warning() -> Label:
	var warning := _make_note("Abweichend vom Empfohlenen braucht das Sticken deutlich mehr Faden, "
			+ "und der Weg ist nicht so gründlich optimiert wie mit der Automatik.", 0.9)
	warning.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	return warning


## A wrapped explanation in the settings, faded to `alpha`.
static func _make_note(text: String, alpha := 0.7) -> Label:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate.a = alpha
	return note


## Leg order and needle start only count for a fixed style; the picture shows the style chosen.
func _update_needle_options() -> void:
	var fixed := _needle_option.selected == 1
	_leg_option.disabled = not fixed
	_needle_start_option.disabled = not fixed
	_guide_picture.style = _chosen_style()
	_update_warnings()


## The stitch style as the settings window shows it.
func _chosen_style() -> StitchStyle:
	if _needle_option.selected == 0:
		return StitchStyle.new()
	return StitchStyle.create(StitchStyle.Needle.FROM_TOP if _needle_start_option.selected == 1
			else StitchStyle.Needle.FROM_BOTTOM, _leg_option.selected == 0)


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


## Everything inside the safe area: the menu at the top, the other panels above the bottom row,
## stacked in portrait (texts on top), side by side in landscape. Touch: round buttons in three
## corners, the menu right of its button and the bar between the bottom two. Mouse and keyboard:
## no round buttons, the menu across the top and the bar along the whole bottom.
func _update_layout() -> void:
	_read_safe_area()
	var portrait := size.y > size.x
	var left := _safe.x + TOUCH_MARGIN
	var right := size.x - _safe.z - TOUCH_MARGIN
	var bottom_row := size.y - _safe.w - TOUCH_MARGIN - (ROUND_BUTTON_PX if _touch else PROGRESS_HEIGHT)
	_bottom_row = bottom_row
	_menu_button.position = Vector2(left, _safe.y + TOUCH_MARGIN)
	_list_button.position = Vector2(left, bottom_row)
	_text_button.position = Vector2(right - ROUND_BUTTON_PX, bottom_row)
	for button: Control in [_menu_button, _list_button, _text_button]:
		button.size = button.custom_minimum_size
		button.visible = _touch
	# Pinning only means something where the menu closes itself.
	_menu_pin.visible = _touch
	if _touch:
		var bar_left := left + ROUND_BUTTON_PX + TOUCH_MARGIN
		_progress.place_bar(Rect2(bar_left, bottom_row + (ROUND_BUTTON_PX - PROGRESS_HEIGHT) / 2.0,
				maxf(right - ROUND_BUTTON_PX - TOUCH_MARGIN - bar_left, 0.0), PROGRESS_HEIGHT))
	else:
		_progress.place_bar(Rect2(left, bottom_row, maxf(right - left, 0.0), PROGRESS_HEIGHT))

	_menu_panel.offset_left = left + ROUND_BUTTON_PX + TOUCH_MARGIN * 0.5 if _touch else left
	_menu_panel.offset_right = -_safe.z - TOUCH_MARGIN
	_menu_panel.offset_top = _safe.y + TOUCH_MARGIN
	_menu_panel.offset_bottom = _menu_panel.offset_top
	_menu_home = _menu_panel.position
	_place_dev_button()

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


## The developer button (developer mode only): under the menu button in the touch layout, under
## the menu where there is no menu button.
func _place_dev_button() -> void:
	_dev_button.visible = Preferences.developer_mode()
	_dev_button.size = _dev_button.custom_minimum_size
	if _touch:
		_dev_button.position = _menu_button.position + Vector2(0.0, ROUND_BUTTON_PX + TOUCH_MARGIN)
	else:
		_dev_button.position = Vector2(_menu_panel.position.x,
				_menu_panel.position.y + _menu_panel.size.y + TOUCH_MARGIN)


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
	if not _overlay_moving.is_empty():
		return  # A moving overlay calls again when it has arrived.
	var top := _safe.y
	if _menu_panel.visible:
		top = _menu_panel.get_rect().end.y
	var bottom := size.y - _bottom_row
	if _list_panel.visible or _text_panel.visible:
		bottom = size.y - _dock.get_rect().position.y
	_view.set_covered(top + _symbols_room(), bottom)
	_place_symbols(top)
	if _stitch_thread >= 0 and _shown_step != null:
		_view.ensure_visible(_shown_step, _shown_hint, _shown_thread_end, true)


## Shows the symbol window while stitching (if switched on and it has something to show) and
## makes room for it.
func _update_symbols() -> void:
	var show := _stitch_thread >= 0 and Preferences.step_symbols() and _symbols.has_cards()
	if show == _symbols.visible:
		_place_symbols(_symbols_top)  # It may have grown or shrunk with its cards.
		return
	_symbols.visible = show
	_symbols_placed = false
	_update_cover()


## Height the symbol window takes from the top of the pattern, with its gap (and the round
## buttons on the left it goes under when there is no room beside them).
func _symbols_room() -> float:
	if not _symbols.visible:
		return 0.0
	return StepSymbols.SIDE + TOUCH_MARGIN + _symbols_drop(_symbols_top)


## How far the symbol window goes down from `top` to pass under the round buttons on the left
## (menu button, developer button) when it is too wide to sit beside them.
func _symbols_drop(top: float) -> float:
	var buttons := _left_buttons()
	if buttons.is_empty() or _symbols.size.x <= size.x - _safe.z - TOUCH_MARGIN - _symbols_left_limit():
		return 0.0
	return maxf(buttons.back().get_rect().end.y - top, 0.0)


## Left edge the symbol window keeps clear of: the round buttons' column, if there is one.
func _symbols_left_limit() -> float:
	var buttons := _left_buttons()
	return buttons.back().get_rect().end.x + TOUCH_MARGIN if not buttons.is_empty() else 0.0


## The round buttons at the top left, top to bottom: the menu's (touch layout) and the developer
## button (developer mode).
func _left_buttons() -> Array[Control]:
	var buttons: Array[Control] = []
	for button: Control in [_menu_button, _dev_button]:
		if button.visible:
			buttons.append(button)
	return buttons


## Puts the symbol window (as wide as its cards) in the middle at the top of the pattern, `top`
## below its upper edge (the safe area or the open menu in the touch layout), where a tap on it
## is far from the thumb working the pattern; it glides there when it moves.
func _place_symbols(top: float) -> void:
	_symbols_top = top
	if not _symbols.visible:
		return
	var view := _view.get_global_rect()
	var drop := _symbols_drop(top)
	var x := view.get_center().x - _symbols.size.x / 2.0
	if drop == 0.0:
		x = maxf(x, _symbols_left_limit())
	var target := Vector2(x, view.position.y + top + drop + TOUCH_MARGIN).round()
	if _symbols_tween != null:
		_symbols_tween.kill()
	if not _symbols_placed:
		_symbols.position = target
		_symbols_placed = true
	elif _symbols.position != target:
		_symbols_tween = create_tween()
		_symbols_tween.tween_property(_symbols, "position", target, DOCK_OPEN_SECONDS).set_trans(
				Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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
	if not _touch:
		_open_all_panels()
	elif _project != null:
		_set_overlay(_list_panel, _list_button, true)
		_set_overlay(_text_panel, _text_button, true)


## Stitching starts with the touch panels open or closed as they were left last time.
func _open_stitch_panels() -> void:
	if not _touch:
		_open_all_panels()
	else:
		_set_overlay(_list_panel, _list_button, Preferences.stitch_list_open())
		_set_overlay(_text_panel, _text_button, Preferences.stitch_text_open())


func _swipe_side() -> void:
	if _stitch_thread >= 0:
		_toggle_back_side()


## A message for the user: in the info line, which the touch layout opens if it is closed.
func _show_message(text: String) -> void:
	_info_label.text = text
	if _touch and _stitch_thread < 0:
		_set_overlay(_text_panel, _text_button, true)


## While the colour picker is open, a touch outside it cancels it and does nothing else.
func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag
			or event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if _eating_pointer:
		get_viewport().set_input_as_handled()
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.is_pressed():
			# Its twin (touch or emulated mouse) comes in the same frame.
			(func() -> void: _eating_pointer = false).call_deferred()
		return
	var press: bool = ((event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT))
	if not press or not _picker_open or _list_host.get_global_rect().has_point(event.position):
		return
	_eating_pointer = true
	get_viewport().set_input_as_handled()
	_close_picker("", "")


## Keys that no window or text field took: + and − zoom, WASD and the arrows move the view while
## held; while stitching Space is the next step, Backspace or Delete the one before, Enter a new
## thread, Tab the other side and Q the overview. Combinations with Ctrl, Cmd or Alt stay the
## system's and the browser's.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if (not key.pressed or _project == null or _finale != null or _celebration != null
			or key.ctrl_pressed or key.meta_pressed or key.alt_pressed):
		return
	var code := key.keycode
	if PAN_KEYS.has(code):
		_held_pan_keys[code] = true
		set_process(true)
	elif code in [KEY_PLUS, KEY_KP_ADD, KEY_EQUAL]:
		_view.zoom_by(KEY_ZOOM)
	elif code in [KEY_MINUS, KEY_KP_SUBTRACT]:
		_view.zoom_by(1.0 / KEY_ZOOM)
	elif _stitch_thread < 0 or key.echo:
		return
	elif code == KEY_SPACE:
		_next_step()
	elif code in [KEY_BACKSPACE, KEY_DELETE]:
		_previous_step()
	elif code in [KEY_ENTER, KEY_KP_ENTER]:
		_toggle_new_thread()
	elif code == KEY_TAB:
		_toggle_back_side()
	elif code == KEY_Q:
		_slide_to_overview()
	else:
		return
	get_viewport().set_input_as_handled()


## Moves the view while pan keys are held; asks the keyboard itself, so a release that a window
## took still stops it.
func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	for code: Key in _held_pan_keys.keys():
		if Input.is_key_pressed(code):
			direction += PAN_KEYS[code]
		else:
			_held_pan_keys.erase(code)
	if _held_pan_keys.is_empty():
		set_process(false)
	elif direction != Vector2.ZERO:
		_view.pan_by(-direction.normalized() * KEY_PAN_SPEED * delta)


func _open_image(path: String) -> void:
	if path.begins_with("res://"):
		await _start_project(path.get_file().get_basename(), load(path) as Image)
	else:
		await _open_image_data(path.get_file(), FileAccess.get_file_as_bytes(path))


## An image file the user picked: on the web its bytes are all the app gets.
func _open_image_data(file_name: String, bytes: PackedByteArray) -> void:
	# The canvas of a GIF, which is decoded here in the app, is checked before it takes the time.
	if not _is_too_big(GifDecoder.canvas_size(bytes)):
		await _start_project(file_name.get_basename(), ImageReader.read(file_name, bytes))


## Calls `step` with the time to stop at until it says it is done, drawing frames in between.
func _work_off(step: Callable) -> void:
	var slice := LOADING_SLICE_USEC
	while not step.call(Time.get_ticks_usec() + slice):
		slice = await _next_slice()


## Waits for the next frame and returns how long the next part of the work may take: as long as
## the wait took, if that was long, so slow frames (a window that is covered, a weak device) don't
## make the work take many times as long.
func _next_slice() -> int:
	var waiting_since := Time.get_ticks_usec()
	await get_tree().process_frame
	return maxi(LOADING_SLICE_USEC, Time.get_ticks_usec() - waiting_since)


## A new project from the pixel art `image` (null if it couldn't be read), saved right away.
func _start_project(project_name: String, image: Image) -> void:
	if image == null or image.is_empty():
		_show_message("Bild konnte nicht geladen werden. Es muss ein %s sein." % ImageReader.FORMAT_NAMES)
		return
	if _is_too_big(image.get_size()):
		return
	if image.is_compressed():
		image.decompress()
	if _loading.active:
		return
	_loading.begin("Muster wird erstellt …")
	var job := PatternImporter.Job.new(image, _palette, PackedStringArray(), {})
	await _work_off(job.run)
	var project := StitchProject.new()
	project.name = project_name
	project.image = image
	project.take_pattern(job.pattern)
	await _set_project(project)
	_save()
	_loading.finish()


## Whether an image of `size` is over the limit; tells the user if so.
func _is_too_big(size: Vector2i) -> bool:
	if maxi(size.x, size.y) <= MAX_SIDE:
		return false
	_show_message("Bild ist zu groß (%d × %d), höchstens %d Pixel pro Seite." % [size.x, size.y, MAX_SIDE])
	return true


## The file picker for a new image. The app's own dialog keeps the touch overlays out of the way
## until it closes; the browser's covers none of them, so only the menu closes.
func _show_open_image() -> void:
	if FileExchange.in_browser():
		_close_menu_unless_pinned()
	else:
		_hide_overlays()
	_files.pick(FileExchange.Kind.IMAGE, _open_image_data)


## Hands the project saved at `path` out as a file, to keep it safe or take it to another device:
## the saved JSON as it is, which is up to date as every change is saved at once.
func _export_project(path: String, project_name: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_report("Exportieren fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return
	_files.save_text(ProjectStore.export_name(project_name), text)


## A project file someone exported becomes a new project here and opens.
func _import_project(file_name: String, bytes: PackedByteArray) -> void:
	var project := ProjectStore.read_export(bytes)
	if project == null:
		_report("„%s“ ist kein Projekt, das diese App lesen kann." % file_name)
		return
	if _project_browser.is_open():
		_project_browser.close()
	if _loading.active:
		return
	_loading.begin("Projekt wird geöffnet …")
	await _set_project(project)
	_save()
	_loading.finish()


## Files dragged onto the window (on a computer, also in the browser): an image starts a project,
## a project file is imported. In the browser they are gone once this returns.
func _on_files_dropped(paths: PackedStringArray) -> void:
	var path := paths[0]
	if path.get_extension().to_lower() == "json":
		_import_project(path.get_file(), FileAccess.get_file_as_bytes(path))
	else:
		_open_image(path)


## A message where the user is looking: under the project list while it is open, else in the info
## line.
func _report(text: String) -> void:
	if _project_browser.is_open():
		_project_browser.show_status(text)
	else:
		_show_message(text)


func _show_settings() -> void:
	_ui_cards.selected = 0 if Preferences.touch_mode() else 1
	var scales: Array = UI_SCALES.map(func(choice: Array) -> float: return choice[1])
	_ui_scale_option.selected = maxi(scales.find(Preferences.ui_scale()), 0)
	_hole_spin.value = Preferences.max_hole_count()
	_hole_picture.hole_limit = Preferences.max_hole_count()
	var limit := Preferences.max_skip()
	_limit_box.button_pressed = limit != StitchPlanner.UNLIMITED
	_limit_spin.editable = _limit_box.button_pressed
	_limit_picture.limit_on = _limit_box.button_pressed
	if limit != StitchPlanner.UNLIMITED:
		_limit_spin.value = limit
	_corner_option.selected = _corner_index(Preferences.top_to_bottom(), Preferences.start_left(),
			Preferences.auto_start())
	_corner_picture.corner = _corner_option.selected
	_method_cards.selected = 1 if Preferences.english() else 0
	_method_cards.selected_changed.emit(_method_cards.selected)
	_whole_back_box.button_pressed = Preferences.whole_back()
	_symbols_box.button_pressed = Preferences.step_symbols()
	_symbols_still_box.button_pressed = Preferences.step_symbols_still()
	var speeds: Array = SYMBOL_SPEEDS.map(func(speed: Array) -> float: return speed[1])
	_symbols_speed_option.selected = maxi(speeds.find(Preferences.step_symbols_speed()), 0)
	_update_symbol_options(true)
	_whole_back_box.disabled = Preferences.english()
	_block_spin.value = Preferences.max_block()
	_needle_option.selected = 1 if Preferences.needle_fixed() else 0
	_leg_option.selected = 0 if Preferences.slash_first() else 1
	_needle_start_option.selected = 1 if Preferences.needle_from_top() else 0
	_update_needle_options()
	if _dev_mode_box != null:
		_dev_mode_box.button_pressed = Preferences.developer_mode()
	_open_window(_settings_dialog)


## Index into START_CORNERS of a row order and start side, or of the automatic choice.
static func _corner_index(top_to_bottom: bool, start_left: bool, auto: bool) -> int:
	if auto:
		return 0
	return 1 + (0 if top_to_bottom else 2) + (0 if start_left else 1)


## Stores the preferences and replans the open project; stitched cells stay stitched.
func _apply_settings() -> void:
	Preferences.set_light(_light_azimuth.value, _light_elevation.value)
	if _dev_mode_box != null:
		Preferences.set_developer_mode(_dev_mode_box.button_pressed)
		_dev_button.visible = Preferences.developer_mode()
	if (_ui_cards.selected == 0) != Preferences.touch_mode():
		Preferences.set_touch_mode(_ui_cards.selected == 0)
		_apply_ui_mode()
	Preferences.set_ui_scale(UI_SCALES[_ui_scale_option.selected][1])
	var limit := int(_limit_spin.value) if _limit_box.button_pressed else StitchPlanner.UNLIMITED
	Preferences.set_max_skip(limit)
	Preferences.set_max_hole_count(int(_hole_spin.value))
	var corner: Array = START_CORNERS[_corner_option.selected]
	Preferences.set_direction(corner[1], corner[2], corner[3])
	Preferences.set_english(_method_cards.selected == 1)
	Preferences.set_whole_back(_whole_back_box.button_pressed)
	Preferences.set_step_symbols(_symbols_box.button_pressed)
	Preferences.set_step_symbols_still(_symbols_still_box.button_pressed)
	Preferences.set_step_symbols_speed(SYMBOL_SPEEDS[_symbols_speed_option.selected][1])
	_symbols.still = Preferences.step_symbols_still()
	_symbols.speed = Preferences.step_symbols_speed()
	_update_symbols()
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
	_project.session.set_style(_style)


## Hands the leg order and needle holes from the preferences to the view, the guide texts and the
## planner.
func _apply_style() -> void:
	_style = StitchStyle.from_preferences()
	_view.style = _style
	_stitch_panel.style = _style
	if _project != null:
		_project.session.set_style(_style)


func _open_project(path: String) -> void:
	if _loading.active:
		return
	_loading.begin("Projekt wird geöffnet …")
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null and file.get_length() >= BIG_PROJECT_BYTES:
		await _loading.wait_until_drawn()
	var project := ProjectStore.load_project(path)
	if project == null:
		_loading.finish()
		_show_message("Projekt konnte nicht geladen werden.")
		return
	await _set_project(project)
	ProjectStore.remember_last(path)
	_loading.finish()


func _set_project(project: StitchProject) -> void:
	_close_picker_now()
	_leave_stitching()
	_close_menu_unless_pinned()
	_project = project
	if not _storage_requested:
		_storage_requested = true
		BrowserStorage.request()
	_apply_preferences()
	_full_pattern = project.full_pattern(_palette)
	await _show_pattern_in_parts(false)
	_open_overview_panels()


func _show_pattern(keep_view: bool) -> void:
	_view.show_pattern(_project.pattern, _palette, keep_view)
	_show_info()
	_fill_color_list()
	_update_progress()


## Like _show_pattern(), for a whole new pattern: big ones go in parts while the hint shows.
func _show_pattern_in_parts(keep_view: bool) -> void:
	_view.prepare(_project.pattern, _palette)
	await _work_off(_view.run_prepare)
	_view.show_pattern(_project.pattern, _palette, keep_view)
	_show_info()
	await _fill_color_list_in_parts()
	_update_progress()


## A change of colours has made a new pattern: shows it and saves.
func _show_changed_pattern() -> void:
	if _loading.active:
		return
	_loading.begin("Muster wird erstellt …")
	await _show_pattern_in_parts(true)
	_save()
	_loading.finish()


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


func _show_legal() -> void:
	_open_window(_legal_window)


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
	_fill_color_list_in_parts(PatternImporter.Job.NO_LIMIT)


## With `until_usec`, the time the first part ends; later parts take LOADING_SLICE_USEC.
func _fill_color_list_in_parts(until_usec := Time.get_ticks_usec() + LOADING_SLICE_USEC) -> void:
	for child in _color_list.get_children():
		child.queue_free()
	_strikes.clear()
	var counts := _full_pattern.stitch_counts()
	var order := range(counts.size())
	order.sort_custom(func(a: int, b: int) -> bool: return counts[a] > counts[b])
	for i: int in order:
		var floss := _palette.find_code(_full_pattern.thread_codes[i])
		_color_list.add_child(_make_color_row(floss, counts[i]))
		if Time.get_ticks_usec() >= until_usec:
			var slice := await _next_slice()
			until_usec = Time.get_ticks_usec() + slice


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
	if thread >= 0 and session.is_thread_done(thread):
		var strike := StrikeLine.new(name_label, floss.code != _strike_code)
		code_label.add_child(strike)
		_strikes[floss.code] = strike
	var count_label := Label.new()
	count_label.text = str(count)
	if thread >= 0 and session.has_stitches(thread):
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
	stitch_button.pressed.connect(_start_stitching.bind(thread))
	OverlayWindow.make_primary(stitch_button)
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
		_show_changed_pattern()
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
	_show_changed_pattern()


## Gets ready to stitch `thread`, with the loading hint on a big pattern, then enters it.
func _start_stitching(thread: int) -> void:
	if _loading.active:
		return
	var session := _project.session
	var big_plan := not session.is_planned(thread) and _project.pattern.stitch_count(thread) >= BIG_THREAD_STITCHES
	var big_pattern := _project.pattern.total_stitches() >= BIG_PATTERN_STITCHES
	if big_plan or big_pattern:
		_loading.begin("Stichfolge wird geplant …")
	if big_plan:
		await _plan_thread(thread)
	if big_pattern:
		_loading.update("Muster wird vorbereitet …")
		# Stitched cells only, instead of changing every cell of the finished preview.
		_view.prepare(_project.pattern, _palette, session.cell_states())
		await _work_off(_view.run_prepare)
	_loading.finish()
	_enter_stitching(thread)


## Plans `thread` on a thread of its own, so frames go on, or where there are no threads (a web
## export) with the hint standing still.
func _plan_thread(thread: int) -> void:
	var session := _project.session
	if not OS.has_feature("threads"):
		_loading.update("Stichfolge wird geplant …", false)
		await _loading.wait_until_drawn()
		session.steps(thread)
		return
	var worker := Thread.new()
	worker.start(session.steps.bind(thread))
	while worker.is_alive():
		await get_tree().process_frame
	worker.wait_to_finish()


## The stitching page slides in from the right over a picture of the overview, which a swipe
## from the left edge or Übersicht brings back.
func _enter_stitching(thread: int) -> void:
	_close_picker_now()
	var overview := _view.snapshot()
	_overview_view = _view.view_state()
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
	_open_stitch_panels()
	_view.back_page = overview
	_view.slide_in(overview)


## Übersicht: the stitching page slides away to the right, then the overview takes over.
func _slide_to_overview() -> void:
	if _stitch_thread < 0 or _view.is_page_sliding():
		return
	await _view.slide_back()
	await _return_to_overview()


## Back to the overview, with the loading hint on a big pattern.
func _return_to_overview() -> void:
	if _project.pattern.total_stitches() >= BIG_PATTERN_STITCHES and not _loading.active:
		_loading.begin("Muster wird vorbereitet …")
		_view.prepare(_project.pattern, _palette)
		await _work_off(_view.run_prepare)
		_loading.finish()
	_leave_stitching()


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
	_view.back_page = null
	if not _overview_view.is_empty():
		_view.set_view_state(_overview_view)
		_overview_view = []
	_view.end_page_slide()
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
	if not _touch:
		_open_all_panels()
	_update_cover()
	match choice:
		Finale.Choice.OVERVIEW:
			_open_overview_panels()
			_view.fit_to_view()
		Finale.Choice.NEW_PROJECT:
			_show_open_image()
		Finale.Choice.OPEN_PROJECT:
			_show_projects()


## Presses a key as the keyboard would, for `--keys`: `entry` is its name (OS key names: Tab,
## Space, Enter, Backspace, Plus, Minus, Up, W, Q, …), held for `:<seconds>` if given.
func _press_key(entry: String) -> void:
	var parts := entry.split(":")
	var press := InputEventKey.new()
	press.keycode = OS.find_keycode_from_string(parts[0])
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	if parts.size() > 1:
		await get_tree().create_timer(parts[1].to_float()).timeout
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


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
	for button: RoundButton in [_menu_button, _list_button, _text_button, _menu_pin, _dev_button]:
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
		_return_to_overview())
	_loop_light(true)
	_celebration.play(_palette.find_code(_project.pattern.thread_codes[thread]),
			_project.pattern.stitch_count(thread), _progress.color, _progress.bar_rect())


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
		hint = PositionHint.find(pattern, states, step, session.last_cell(thread),
				Vector2i(_style.needle_holes(step)[0].round()), session.last_hole(thread),
				Preferences.max_hole_count())
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
			pattern.stitch_count(thread), thread_start)
	_symbols.show_step(step, hint, _style, new_thread, thread_end.x >= 0)
	_update_symbols()
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
		# A thread nothing is stitched of has no back yet and needn't be planned for it.
		if not session.has_stitches(thread):
			lines.append(PackedVector2Array())
			continue
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
	var loading_text := ""
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
	var scroll := 0
	var symbols_card := PackedStringArray()
	var keys := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--open="):
			await _open_image(arg.trim_prefix("--open="))
		elif arg.begins_with("--import="):
			var import_path := arg.trim_prefix("--import=")
			await _import_project(import_path.get_file(), FileAccess.get_file_as_bytes(import_path))
		elif arg.begins_with("--loading="):
			# Holds the hint for a screenshot: <text>, or still,<text> for the version without animation.
			loading_text = arg.trim_prefix("--loading=")
		elif arg.begins_with("--export="):
			if _project != null:
				_files.write_text(arg.trim_prefix("--export="), FileAccess.get_file_as_string(_project.path))
		elif arg.begins_with("--storage="):
			BrowserStorage.safety = {"may-clear": BrowserStorage.Safety.MAY_BE_CLEARED,
					"not-kept": BrowserStorage.Safety.NOT_KEPT}.get(arg.trim_prefix("--storage="),
					BrowserStorage.Safety.SAFE)
		elif arg.begins_with("--stitch="):
			stitch_code = arg.trim_prefix("--stitch=")
		elif arg.begins_with("--steps="):
			steps = arg.trim_prefix("--steps=").to_int()
		elif arg == "--settings":
			_show_settings.call_deferred()
		elif arg == "--dev-tools":
			_show_dev_tools.call_deferred(true)
		elif arg.begins_with("--dev="):
			Preferences.set_developer_mode(arg.trim_prefix("--dev=") == "on")
			_dev_button.visible = Preferences.developer_mode()
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
		elif arg.begins_with("--symbols="):
			var symbols := arg.trim_prefix("--symbols=").split(",")
			if symbols[0] in ["on", "off"]:
				Preferences.set_step_symbols(symbols[0] == "on")
			elif symbols[0] in ["still", "animated"]:
				Preferences.set_step_symbols_still(symbols[0] == "still")
				_symbols.still = symbols[0] == "still"
			else:
				symbols_card = symbols
		elif arg == "--back":
			back = true
		elif arg == "--finish":
			finish = true
		elif arg == "--finale":
			finale = true
		elif arg == "--dismiss":
			dismiss = true
		elif arg.begins_with("--scroll="):
			scroll = arg.trim_prefix("--scroll=").to_int()
		elif arg.begins_with("--keys="):
			keys = arg.trim_prefix("--keys=").split(",")
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
		elif arg == "--legal":
			_show_legal.call_deferred()
		elif arg == "--legal-notices":
			_legal_window.show_notices()
			_show_legal.call_deferred()
		elif arg.begins_with("--max-holes="):
			Preferences.set_max_hole_count(arg.trim_prefix("--max-holes=").to_int())
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
		elif arg.begins_with("--ui-scale="):
			Preferences.set_ui_scale(arg.trim_prefix("--ui-scale=").to_float())
			_apply_ui_scale(Preferences.ui_scale())
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
		await _start_stitching(_project.pattern.thread_codes.find(stitch_code))
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
		if not symbols_card.is_empty():
			var card: int = ["secure", "thread", "anchor", "count", "stitch"].find(symbols_card[0])
			if card >= 0:
				_symbols.hold(card as StepSymbols.Card, symbols_card[1].to_float() if symbols_card.size() > 1 else 1.0)
		var step := _project.session.current_step(_stitch_thread) if _stitch_thread >= 0 else null
		if zoom > 0.0 and step != null:
			_view.focus_step(step, zoom)
		if back:
			_toggle_back_side()
			if flip >= 0.0:
				_view.hold_flip(flip)
	while not keys.is_empty() and _view.is_page_sliding():
		await get_tree().process_frame  # Entering stitching slides the page in first.
	for entry in keys:
		await _press_key(entry)
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
	while (not _overlay_moving.is_empty() or _view.is_panning() or _view.is_page_sliding()
			or _settings_dialog.is_animating()
			or _project_browser.is_animating()
			or _legal_window.is_animating()):
		await get_tree().process_frame
	if _view.is_flipping() and flip < 0.0:
		await _view.flip_finished
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	else:
		while _progress.is_filling():
			await get_tree().process_frame
	if scroll > 0:
		for window: OverlayWindow in [_settings_dialog, _project_browser, _legal_window]:
			if window.is_open():
				window.scroll_to(scroll)
	for i in 3:
		await get_tree().process_frame
	# Low processor mode draws only when something changed, so ask for one more frame.
	queue_redraw()
	if not loading_text.is_empty():
		var still := loading_text.begins_with("still,")
		_loading.begin(loading_text.trim_prefix("still,"), not still, true)
		await get_tree().create_timer(0.7).timeout
		_loading.queue_redraw()  # Still, it draws nothing by itself.
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	get_tree().quit()

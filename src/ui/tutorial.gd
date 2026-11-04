class_name Tutorial
extends OverlayWindow
## The introduction on first opening, and again from the settings: one window, a page per thing to
## know, each mostly an animated picture (TutorialScene, on its page about the symbol window the
## real StepSymbols) and a sentence. Weiter skips on at any time, Zurück returns, Abbrechen or the
## close button end the whole introduction. Swiping the picture turns the page too and a tap on
## it plays it again. Touch and mouse-and-keyboard get their own gestures and words.

## Shortest and tallest the picture gets, and what the rest of the window needs of the height.
const STAGE_MIN_HEIGHT := 110.0
const STAGE_MAX_HEIGHT := 280.0
const WINDOW_CHROME_HEIGHT := 222.0
## The panel's margins left and right together.
const PANEL_PADDING := 24.0
const TEXT_FONT_SIZE := 16
## Room for two lines of text.
const TEXT_MIN_HEIGHT := 46.0
const NEXT_BUTTON_WIDTH := 110.0
const PAGE_FADE_SECONDS := 0.15
## A drag this far sideways on the picture turns the page; less than TAP_PX is a tap.
const SWIPE_PX := 60.0
const TAP_PX := 12.0

## The current page, from 0.
var page := 0
var pages: Array[Dictionary] = []
var back_button: Button
var next_button: Button
var cancel_button: Button

var _touch := true
var _english := false
var _stage := MarginContainer.new()
var _scene := TutorialScene.new()
var _symbols_box := CenterContainer.new()
var _symbols := StepSymbols.new()
var _text := Label.new()
var _crosses := PageCrosses.new()
var _press_at := Vector2.ZERO
var _pressing := false
var _fade: Tween


func _init() -> void:
	super("Einführung")
	max_width = 640.0
	set_panel_alpha(LoadingHint.PANEL_ALPHA)
	content.add_theme_constant_override("separation", 8)
	_stage.custom_minimum_size.y = STAGE_MIN_HEIGHT
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_on_stage_input)
	content.add_child(_stage)
	_stage.add_child(_scene)
	_stage.add_child(_symbols_box)
	_symbols_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_symbols_box.add_child(_symbols)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	_text.custom_minimum_size.y = TEXT_MIN_HEIGHT  # So the window keeps its height from page to page.
	content.add_child(_text)
	content.add_child(_crosses)
	cancel_button = make_button("Abbrechen", ButtonIcons.Icon.CLOSE, close)
	buttons.add_child(cancel_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	back_button = make_button("Zurück", ButtonIcons.Icon.BACK, previous_page)
	buttons.add_child(back_button)
	next_button = make_primary(make_button("Weiter", -1, next_page))
	next_button.custom_minimum_size.x = NEXT_BUTTON_WIDTH
	buttons.add_child(next_button)
	resized.connect(_fit_stage)


## The pages for a layout and stitch method: `scene` (TutorialScene.Kind), `title` and `text`.
static func pages_for(touch: bool, english := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var add := func(scene: TutorialScene.Kind, title: String, on_touch: String, on_desktop := "") -> void:
		result.append({"scene": scene, "title": title,
				"text": on_touch if touch or on_desktop.is_empty() else on_desktop})
	add.call(TutorialScene.Kind.OPEN, "Bild öffnen",
			"Im Menü auf „Neu“ tippen und ein Pixelbild wählen. Jedes Pixel wird ein Kreuzstich.",
			"Oben auf „Neu“ klicken oder ein Bild ins Fenster ziehen. Jedes Pixel wird ein Kreuzstich.")
	if touch:
		add.call(TutorialScene.Kind.BUTTONS, "Runde Knöpfe", "Sie öffnen und schließen Menü, Farben und Texte.")
	add.call(TutorialScene.Kind.COLOR, "Farbe wählen",
			"Tippe auf die Nadel in der Liste oder direkt auf das Motiv.",
			"Klicke auf die Nadel in der Liste oder direkt auf das Motiv.")
	add.call(TutorialScene.Kind.STITCH, "Stich für Stich",
			("Am Punkt kommt die Nadel hoch, am Ring geht sie runter. Kreuz für Kreuz." if english
			else "Am Punkt kommt die Nadel hoch, am Ring geht sie runter. Erst hin, dann zurück."))
	add.call(TutorialScene.Kind.SYMBOLS, "Symbolfenster",
			"Oben siehst du jeden Handgriff. Tippe ein Symbol an, um es nochmal zu sehen.",
			"Oben siehst du jeden Handgriff. Klicke ein Symbol an, um es nochmal zu sehen.")
	add.call(TutorialScene.Kind.COUNT, "Löcher zählen", "Zähle ab dem Ring von Loch zu Loch bis zum nächsten Stich.")
	add.call(TutorialScene.Kind.NEXT, "Weiter und zurück",
			"Einmal tippen: Schritt erledigt. Doppelt tippen: zurück.",
			"Leertaste oder Klick: Schritt erledigt. Rücktaste oder Doppelklick: zurück.")
	add.call(TutorialScene.Kind.MOVE, "Ansicht bewegen",
			"Mit zwei Fingern zoomen, mit einem oder zwei verschieben.",
			"Mausrad zoomt. WASD, Pfeiltasten oder rechte Maustaste verschieben.")
	add.call(TutorialScene.Kind.BACK_SIDE, "Rückseite",
			"Vom rechten Rand wischen dreht den Stoff um.",
			"Tab dreht den Stoff um.")
	add.call(TutorialScene.Kind.OVERVIEW, "Übersicht",
			"Vom linken Rand wischen führt zur Übersicht. Dort wählst du die nächste Farbe.",
			"Q führt zur Übersicht. Dort wählst du die nächste Farbe.")
	add.call(TutorialScene.Kind.NEW_THREAD, "Neuer Faden",
			"Mit zwei Fingern doppelt tippen, wenn der Faden zu Ende geht.",
			"Enter oder rechter Doppelklick, wenn der Faden zu Ende geht.")
	add.call(TutorialScene.Kind.DONE, "Fertig",
			"Alles speichert sich von selbst. Diese Einführung findest du in den Einstellungen.")
	return result


## Prepares the first page for this layout and stitch method; open() shows it.
func setup(touch: bool, english := false) -> void:
	_touch = touch
	_english = english
	pages = pages_for(touch, english)
	_crosses.count = pages.size()
	go_to(0, false)


func next_page() -> void:
	if page >= pages.size() - 1:
		close()
	else:
		go_to(page + 1)


func previous_page() -> void:
	if page > 0:
		go_to(page - 1)


## Shows page `index`; with `fade` the picture and text come in softly.
func go_to(index: int, fade := true) -> void:
	page = clampi(index, 0, pages.size() - 1)
	var entry: Dictionary = pages[page]
	set_title(entry.title)
	_text.text = entry.text
	var symbols: bool = entry.scene == TutorialScene.Kind.SYMBOLS
	_scene.visible = not symbols
	_symbols_box.visible = symbols
	if symbols:
		_fit_stage()
		_symbols.speed = Preferences.step_symbols_speed()
		_symbols.show_preview()
	_scene.play(entry.scene, _touch, _english)
	_crosses.current = page
	var last := page == pages.size() - 1
	back_button.disabled = page == 0
	cancel_button.visible = not last
	next_button.text = "Los geht’s" if last else "Weiter"
	if last:
		set_icon(next_button, ButtonIcons.Icon.CHECK)
	else:
		next_button.icon = null
	if _fade != null:
		_fade.kill()
	if fade:
		_stage.modulate.a = 0.0
		_text.modulate.a = 0.0
		_fade = create_tween().set_parallel()
		_fade.tween_property(_stage, "modulate:a", 1.0, PAGE_FADE_SECONDS)
		_fade.tween_property(_text, "modulate:a", 1.0, PAGE_FADE_SECONDS)
	else:
		_stage.modulate.a = 1.0
		_text.modulate.a = 1.0


## Holds the current page's picture `progress` (0..1) into its animation, for screenshots.
func hold(progress: float) -> void:
	if pages[page].scene == TutorialScene.Kind.SYMBOLS:
		_symbols.hold(StepSymbols.Card.STITCH, progress)
	else:
		_scene.hold(progress)


func open() -> void:
	_fit_stage()
	super()


## As big as the screen allows, in the picture's proportions, so the window needs no scrolling.
## The symbol window's cards wrap to the same width; left wide they would push the window off
## a small screen.
func _fit_stage() -> void:
	var room_width := minf(max_width, size.x - safe_area.x - safe_area.z - MARGIN * 2.0) - PANEL_PADDING
	_symbols.max_width = room_width
	var room_height := size.y - safe_area.y - safe_area.w - MARGIN * 2.0 - WINDOW_CHROME_HEIGHT
	var wanted := room_width * TutorialScene.HEIGHT / TutorialScene.WIDTH
	_stage.custom_minimum_size.y = clampf(minf(wanted, room_height), STAGE_MIN_HEIGHT, STAGE_MAX_HEIGHT)


## A tap on the picture plays it again; a swipe sideways turns the page.
func _on_stage_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse.pressed:
		_press_at = mouse.position
		_pressing = true
		return
	if not _pressing:
		return
	_pressing = false
	var drag := mouse.position - _press_at
	if absf(drag.x) >= SWIPE_PX and absf(drag.x) > absf(drag.y) * 1.5:
		if drag.x < 0.0:
			if page < pages.size() - 1:
				next_page()
		else:
			previous_page()
	elif drag.length() < TAP_PX:
		_scene.replay()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if is_open() and key != null and key.pressed and not key.echo:
		if key.keycode in [KEY_RIGHT, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			next_page()
		elif key.keycode in [KEY_LEFT, KEY_BACKSPACE]:
			previous_page()
	super(event)


## How far the introduction has come, in the loading hint's look: a cross per page, those seen
## white, the current one orange, the rest faint.
class PageCrosses:
	extends Control

	const SIDE := 14.0
	const GAP := 5.0

	var count := 0:
		set(value):
			count = value
			queue_redraw()
	var current := 0:
		set(value):
			current = value
			queue_redraw()


	func _init() -> void:
		custom_minimum_size.y = SIDE + 4.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	func _draw() -> void:
		var left := (size.x - count * SIDE - (count - 1) * GAP) / 2.0
		for i in count:
			var ink := Color(1.0, 1.0, 1.0, 0.25)
			if i == current:
				ink = LoadingHint.NEW_LEG_COLOR
			elif i < current:
				ink = Color.WHITE
			var cell := Rect2(left + i * (SIDE + GAP), 2.0, SIDE, SIDE)
			draw_line(Vector2(cell.position.x, cell.end.y), Vector2(cell.end.x, cell.position.y), ink, 2.0, true)
			draw_line(cell.position, cell.end, ink, 2.0, true)

class_name StitchPanel
extends VBoxContainer
## Guided stitching controls: which thread, what the current step is, progress, back/next, and
## starting a new thread by hand. The buttons never take focus, so the space bar always reaches
## the screen's key handling.

signal next_pressed
signal previous_pressed
signal new_thread_toggled

const BUTTON_HEIGHT := 64.0
const STEP_FONT_SIZE := 24

var _swatch: ColorRect
var _thread_label: Label
var _step_label: Label
var _detail_label: Label
var _progress_bar: ProgressBar
var _progress_label: Label
var _previous_button: Button
var _next_button: Button
var _new_thread_button: Button


func _init() -> void:
	var header := HBoxContainer.new()
	add_child(header)
	_swatch = ColorRect.new()
	_swatch.custom_minimum_size = Vector2(32, 32)
	header.add_child(_swatch)
	_thread_label = Label.new()
	_thread_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thread_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_thread_label)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", STEP_FONT_SIZE)
	_step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_step_label)
	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_detail_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	add_child(_progress_bar)
	_progress_label = Label.new()
	_progress_label.modulate.a = 0.7
	add_child(_progress_label)

	var buttons := HBoxContainer.new()
	add_child(buttons)
	_previous_button = _make_button("◂ Zurück")
	_previous_button.pressed.connect(previous_pressed.emit)
	buttons.add_child(_previous_button)
	_next_button = _make_button("Gestickt ▸")
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.pressed.connect(next_pressed.emit)
	buttons.add_child(_next_button)
	_new_thread_button = _make_button("Neuer Faden ab hier")
	_new_thread_button.toggle_mode = true
	_new_thread_button.custom_minimum_size.y = BUTTON_HEIGHT * 0.75
	_new_thread_button.tooltip_text = "Der Faden ist zu kurz oder verknotet: vor diesem Schritt einen neuen Faden nehmen."
	_new_thread_button.pressed.connect(new_thread_toggled.emit)
	add_child(_new_thread_button)
	var hint := Label.new()
	hint.text = "Weiter: Knopf, Tippen aufs Muster oder Leertaste"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate.a = 0.6
	add_child(hint)


## `step` is null when the thread is finished; `position_text` comes from describe_position();
## `step_index` counts the finished steps; `thread_start` says whether the step begins with a new
## thread.
func show_step(floss: FlossColor, step: StitchStep, position_text: String, step_index: int,
		step_count: int, crosses_done: int, cross_count: int,
		thread_start := StitchSession.ThreadStart.NONE) -> void:
	_swatch.color = floss.color
	_thread_label.text = "DMC %s · %s" % [floss.code, floss.name]
	if step == null:
		_step_label.text = "Fertig!"
		_detail_label.text = "Alle %d Kreuze in dieser Farbe sind gestickt. Faden auf der Rückseite vernähen." % cross_count
	else:
		_step_label.text = describe_step(step)
		_detail_label.text = position_text
	_progress_bar.max_value = maxi(step_count, 1)
	_progress_bar.value = step_index
	_progress_label.text = "Schritt %d von %d · %d von %d Kreuzen fertig" % [
			mini(step_index + 1, step_count), step_count, crosses_done, cross_count]
	_previous_button.disabled = step_index == 0
	_next_button.disabled = step == null
	# The first step and steps after a too long way start a new thread anyway.
	_new_thread_button.disabled = step == null or thread_start in [
			StitchSession.ThreadStart.FIRST, StitchSession.ThreadStart.AUTO]
	_new_thread_button.set_pressed_no_signal(thread_start != StitchSession.ThreadStart.NONE)


static func describe_step(step: StitchStep) -> String:
	var count := step.cells.size()
	var side := "rechts" if step.direction > 0 else "links"
	match step.kind:
		StitchStep.Kind.HALF:
			return "%d %s nach %s  ( / )" % [count, "Halbstich" if count == 1 else "Halbstiche", side]
		StitchStep.Kind.BACK:
			return "Zurück: %d %s nach %s  ( \\ )" % [count, "Gegenstich" if count == 1 else "Gegenstiche", side]
		_:
			return "Ein einzelnes ganzes Kreuz  ( X )"


## What happens with the thread before the step: a new one (and why), or how far to carry the
## old one on the back. `max_skip` is the user's skip limit, for the reason of an automatic change.
static func describe_thread(step: StitchStep, thread_start: StitchSession.ThreadStart,
		max_skip: int) -> String:
	const FINISH := "Alten Faden auf der Rückseite unter 3–5 Stichen vernähen, dann neu anfangen."
	match thread_start:
		StitchSession.ThreadStart.FIRST:
			return "Faden einfädeln und auf der Rückseite befestigen (Schlaufe oder unter den ersten Stichen)."
		StitchSession.ThreadStart.AUTO:
			return "Neuer Faden: der Weg hierher wären %d Felder, erlaubt sind %d. %s" % [
					step.travel_before, max_skip, FINISH]
		StitchSession.ThreadStart.MANUAL:
			return "Neuer Faden (von dir gewählt). " + FINISH
	if step.travel_before > 0:
		return "Faden auf der Rückseite %d %s weiterführen." % [
				step.travel_before, "Feld" if step.travel_before == 1 else "Felder"]
	return ""


## Where the step starts: relative to the reference stitch of `hint` (marked in the picture),
## over its own half stitches for a return pass, or freely chosen for the very first stitch.
## `states` are the cell states before the step.
static func describe_position(step: StitchStep, hint: PositionHint, pattern: Pattern,
		states: PackedByteArray) -> String:
	var text := ""
	if step.kind == StitchStep.Kind.BACK:
		text = "Auf den eigenen Halbstichen zurück."
	elif hint == null:
		text = ("Erster Stich: Stelle auf dem Stoff frei wählen. Links davon braucht das Muster "
				+ "noch %d %s, darüber %d %s (ganzes Muster %d × %d).") % [
				step.cells[0], "Feld" if step.cells[0] == 1 else "Felder",
				step.row, "Reihe" if step.row == 1 else "Reihen", pattern.width, pattern.height]
	else:
		text = describe_offset(hint.offset(), describe_reference(hint, pattern, states))
	match step.kind:
		StitchStep.Kind.HALF:
			text += "\nNadel unten links im ersten Feld hoch (Punkt)."
		StitchStep.Kind.BACK:
			text += "\nNadel unten rechts im ersten Feld hoch (Punkt), die Kreuze werden fertig."
		_:
			text += "\nErst / dann \\, Nadel unten links hoch (Punkt)."
	text += "\n(Reihe %d, Feld %d des Musters)" % [step.row + 1, step.cells[0] + 1]
	return text


## The reference stitch in the dative, saying what makes it findable, e.g. "dem markierten Kreuz
## (DMC 310) am linken Ende" or "deinem letzten Stich".
static func describe_reference(hint: PositionHint, pattern: Pattern, states: PackedByteArray) -> String:
	if hint.landmark == PositionHint.Landmark.LAST:
		return "deinem letzten Stich"
	var full := states[hint.reference.y * pattern.width + hint.reference.x] == StitchSession.Cell.FULL
	var stitch := "%s (DMC %s)" % ["Kreuz" if full else "Halbstich",
			pattern.thread_codes[pattern.get_cell(hint.reference.x, hint.reference.y)]]
	match hint.landmark:
		PositionHint.Landmark.LEFT_END:
			return "dem markierten %s am linken Ende" % stitch
		PositionHint.Landmark.RIGHT_END:
			return "dem markierten %s am rechten Ende" % stitch
		_:
			return "dem markierten einzelnen %s" % stitch


## `offset` from the reference to the target in cells; `reference` names the stitch in the
## dative (see describe_reference()). Counting goes along the longer direction first, as in the
## picture.
static func describe_offset(offset: Vector2i, reference: String) -> String:
	var horizontal := "rechts" if offset.x > 0 else "links"
	var vertical := "unter" if offset.y > 0 else "über"
	var steps := absi(offset.x) + absi(offset.y)
	if steps == 1:
		if offset.y == 0:
			return "Direkt %s neben %s." % [horizontal, reference]
		return "Direkt %s %s." % [vertical, reference]
	if absi(offset.x) == 1 and absi(offset.y) == 1:
		return "Schräg %s %s %s." % [horizontal, vertical, reference]
	var legs: Array[String] = []
	if offset.x != 0:
		legs.append("%d nach %s" % [absi(offset.x), horizontal])
	if offset.y != 0:
		legs.append("%d nach %s" % [absi(offset.y), "unten" if offset.y > 0 else "oben"])
	if absi(offset.y) > absi(offset.x):
		legs.reverse()
	return "Ab %s zählen: %s." % [reference, ", dann ".join(legs)]


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = BUTTON_HEIGHT
	return button

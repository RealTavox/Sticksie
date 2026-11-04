class_name LoadingHint
extends Control
## Says that the app is working, over a dimmed screen that takes every touch and key meanwhile. It
## only shows when the work takes a while, so short work doesn't flicker. A row of crosses is
## stitched over and over, half stitches there and back as in the Danish method: only where the
## app keeps drawing frames. Work that blocks them gets the still version (`moving` false), as an
## animation that stands still would look as if the app had hung.

const PANEL_SIZE := Vector2(260.0, 132.0)
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.5)
const PANEL_ALPHA := 0.97
## Work shorter than this shows nothing.
const SHOW_AFTER_SECONDS := 0.2
const FADE_SECONDS := 0.15
const CROSSES := 5
const CELL_PX := 26.0
const LINE_WIDTH := 3.0
const NEW_LEG_COLOR := Color(1.0, 0.56, 0.2)
## One leg's share of the time is drawn, the whole row then stands for HOLD_LEGS legs' time.
const LEG_SECONDS := 0.16
const HOLD_LEGS := 4
const FPS := 30.0
const TEXT_FONT_SIZE := 16
const TEXT_TOP := 84.0

## Whether begin() was called and finish() not yet.
var active := false

var _moving := true
var _started_usec := 0
var _shown := false
var _alpha := 0.0
var _time := 0.0
var _since_draw := 0.0
var _label := Label.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	add_child(_label)


## Starts blocking input with `text`. With `at_once` it shows from the next frame on: for work
## that blocks frames right away, after waiting two frames (see wait_until_drawn()).
func begin(text: String, moving := true, at_once := false) -> void:
	active = true
	_label.text = text
	_moving = moving
	_started_usec = Time.get_ticks_usec()
	_shown = at_once
	_alpha = 1.0 if at_once else 0.0
	_time = 0.0
	modulate.a = _alpha
	visible = true
	set_process(true)
	queue_redraw()


## Switches to `text`, and to the still or moving version, for the next part of the work.
func update(text: String, moving := true) -> void:
	_label.text = text
	_moving = moving
	queue_redraw()


## Makes sure a frame with the hint is on screen, before work that blocks frames.
func wait_until_drawn() -> void:
	_shown = true
	_alpha = 1.0
	modulate.a = 1.0
	await get_tree().process_frame
	await get_tree().process_frame


func finish() -> void:
	active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not _shown and Time.get_ticks_usec() - _started_usec >= SHOW_AFTER_SECONDS * 1000000.0:
		_shown = true
	if _shown and _alpha < 1.0:
		_alpha = minf(1.0, _alpha + delta / FADE_SECONDS)
		modulate.a = _alpha
	if not _shown or not _moving:
		return
	_time += delta
	_since_draw += delta
	if _since_draw >= 1.0 / FPS:
		_since_draw = 0.0
		queue_redraw()


## Takes keys as well as the touches the full-screen control gets anyway.
func _input(event: InputEvent) -> void:
	if active and event is InputEventKey:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_label()


func _place_label() -> void:
	var panel := _panel_rect()
	_label.position = panel.position + Vector2(12.0, TEXT_TOP)
	_label.size = Vector2(panel.size.x - 24.0, PANEL_SIZE.y - TEXT_TOP - 8.0)


func _panel_rect() -> Rect2:
	return Rect2((size - PANEL_SIZE) / 2.0, PANEL_SIZE)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIM_COLOR)
	var panel := _panel_rect()
	var style := OverlayWindow.panel_style()
	style.bg_color.a = PANEL_ALPHA  # Text behind it would run into its own.
	draw_style_box(style, panel)
	var left := panel.get_center().x - CROSSES * CELL_PX / 2.0
	var top := panel.position.y + 26.0
	# The legs in stitching order: "/" to the right, then "\" back to the left.
	var legs := CROSSES * 2
	var drawn := legs
	var part := 1.0
	if _moving:
		var position_in_loop := fmod(_time / LEG_SECONDS, float(legs + HOLD_LEGS))
		drawn = mini(int(position_in_loop), legs)
		part = position_in_loop - drawn if drawn < legs else 0.0
	for leg in mini(drawn + 1, legs):
		var outward := leg < CROSSES
		var column := leg if outward else legs - 1 - leg
		var cell := Rect2(left + column * CELL_PX + 4.0, top + 4.0, CELL_PX - 8.0, CELL_PX - 8.0)
		var from := Vector2(cell.position.x, cell.end.y) if outward else Vector2(cell.end.x, cell.end.y)
		var to := Vector2(cell.end.x, cell.position.y) if outward else cell.position
		var growing := leg == drawn
		draw_line(from, from.lerp(to, part) if growing else to, NEW_LEG_COLOR if growing else Color.WHITE,
				LINE_WIDTH, true)

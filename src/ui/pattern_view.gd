class_name PatternView
extends Control
## Shows a pattern on fabric. The fabric and thread are 3D (StitchScene, rendered into a
## SubViewport and drawn first); the marks for the current step are drawn on top in 2D, with the
## same mapping from grid to screen. Preview mode shows every cell as a finished cross; progress
## mode only the stitched legs plus the current step and its stitch count; with `back_side` it
## shows the back instead, mirrored as when the fabric is turned over (set_back_side() can turn
## it over with an animation).
##
## Gestures, each also doable with the mouse (left clicks arrive as touches through
## emulate_touch_from_mouse): drag with one or two fingers or the right mouse button to pan;
## pinch, trackpad or mouse wheel to zoom; tap or click for `tapped` (held back until a double
## tap is ruled out), double tap for `double_tapped`, double tap with two fingers or double right
## click for `two_finger_double_tapped`; a swipe in from the left or right edge for
## `swiped_from_left` / `swiped_from_right`. `touched` comes at the start of every gesture.

signal tapped
signal double_tapped
signal two_finger_double_tapped
signal swiped_from_left
signal swiped_from_right
signal touched
## A flip animation has ended.
signal flip_finished

## Background of labels and counts (light Aida fabric).
const FABRIC_COLOR := StitchScene.FABRIC_COLOR
const HIGHLIGHT_COLOR := Color(1.0, 0.5, 0.05)
## Reference stitch of the position hint, and the left/right leg of its counting path.
const HINT_COLOR := Color(0.1, 0.45, 0.95)
## The up/down leg of the counting path.
const HINT_VERTICAL_COLOR := Color(0.7, 0.1, 0.65)
## Below this cell size the counting path shows dots instead of numbers.
const MIN_NUMBER_CELL_PX := 14.0
## Where the old thread ends (to be secured) and where a new one begins.
const THREAD_END_COLOR := Color(0.85, 0.15, 0.15)
const THREAD_START_COLOR := Color(0.1, 0.6, 0.25)
## Below this cell size the thread markers have no text labels.
const MIN_LABEL_CELL_PX := 14.0
const MIN_CELL_PX := 2.0
const MAX_CELL_PX := 96.0
const FIT_MARGIN := 16.0
const WHEEL_ZOOM := 1.15
## A touch that moves less than this is a tap.
const TAP_SLOP := 12.0
## Longest touch that still counts as a tap, and longest wait for the second tap of a double tap.
const TAP_SECONDS := 0.35
const DOUBLE_TAP_SECONDS := 0.32
## The second tap of a double tap lands at most this far from the first.
const DOUBLE_TAP_SLOP := 48.0
## A one-finger touch starting this close to the left or right edge and moving at least SWIPE_PX
## inwards, mostly sideways, is an edge swipe.
const EDGE_PX := 40.0
const SWIPE_PX := 90.0
const FLIP_SECONDS := 0.7
## ensure_visible(…, true) glides there in this time.
const PAN_SECONDS := 0.3

var pattern: Pattern
## Show the back of the fabric (progress mode only): the thread between the holes, mirrored
## left to right. Set the thread with show_back().
## Leg order and where the needle comes up.
var style := StitchStyle.new():
	set(value):
		style = value
		if pattern != null:
			_scene.set_pattern(pattern, _colors, style.slash_first)
			_scene.set_states(_states)
			_scene.set_ghost(_highlight)
		queue_redraw()
var back_side: bool:
	get:
		return _back_side
	set(value):
		set_back_side(value, false)

var _back_side := false
var _viewport := SubViewport.new()
var _scene := StitchScene.new()
## While the fabric turns over: progress 0..1, and the view as it was when the flip began
## (origin, and the world x of the column in the middle, the axis it turns about).
var _flipping := false
var _turn := 0.0:
	set(value):
		_turn = value
		queue_redraw()
var _turn_origin := Vector2.ZERO
var _turn_pivot := 0.0
var _flip_tween: Tween
var _pan_tween: Tween
var _colors: Array[Color] = []
## StitchSession.Cell per cell in progress mode; empty in preview mode.
var _states := PackedByteArray()
var _highlight: StitchStep
var _hint: PositionHint
## Last stitch of a thread that has to be secured now, or (-1, -1).
var _thread_end := Vector2i(-1, -1)
## Whether the highlighted step begins with a new thread.
var _new_thread := false
## Size of one cell on screen, in pixels.
var _cell_px := 10.0
## Top left corner of the grid, in local coordinates.
var _origin := Vector2.ZERO
var _touches := {}  # touch index -> position
var _touch_starts := {}  # touch index -> where it went down
## The gesture running since the first finger went down: most fingers at once, whether any
## moved past TAP_SLOP, when it began, and the edge it began at (-1 left, 1 right, 0 none).
var _gesture_fingers := 0
var _gesture_moved := false
var _gesture_start_msec := 0
var _gesture_edge := 0
## A tap waiting to see whether a second one follows; the count stops older timers.
var _tap_pending := false
var _tap_count := 0
var _tap_position := Vector2.ZERO
var _two_finger_tap_msec := -100000
## Parts of the view covered by overlays (top and bottom, in pixels): steps are kept clear of them.
var _cover_top := 0.0
var _cover_bottom := 0.0
## Where threads start and end on the back, holes in grid units (BackSide).
var _back_starts := PackedVector2Array()
var _back_ends := PackedVector2Array()
## Size at the last layout, to keep the centre when the view is resized.
var _laid_out_size := Vector2.ZERO
## focus_step() called before the first layout: [step, min_cell_px], applied on layout.
var _pending_focus := []


func _init() -> void:
	clip_contents = true
	resized.connect(_on_resized)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.gui_disable_input = true
	# Renders whenever the app draws a frame; low processor mode only draws on change.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.add_child(_scene)
	add_child(_viewport)


## Shows `p` in preview mode; with `keep_view` the zoom and position stay as they are.
func show_pattern(p: Pattern, palette: FlossPalette, keep_view := false) -> void:
	pattern = p
	_colors.clear()
	for code in p.thread_codes:
		_colors.append(palette.find_code(code).color)
	_states = PackedByteArray()
	_highlight = null
	_hint = null
	_scene.set_pattern(p, _colors, style.slash_first)
	_scene.set_states(_states)
	_scene.set_ghost(null)
	_scene.set_back([], PackedVector2Array(), -1)
	if not keep_view:
		fit_to_view()
	queue_redraw()


## Switches to progress mode: `states` holds a StitchSession.Cell per cell, `highlight` is the
## step to do next and `hint` where to count it from (either may be null). `thread_end` is the
## last stitch of a thread to secure now ((-1, -1) if none); `new_thread` marks the highlighted
## step as the start of a new thread.
func show_progress(states: PackedByteArray, highlight: StitchStep, hint: PositionHint = null,
		thread_end := Vector2i(-1, -1), new_thread := false) -> void:
	_states = states
	_highlight = highlight
	_hint = hint
	_thread_end = thread_end
	_new_thread = new_thread
	_scene.set_states(states)
	_scene.set_ghost(highlight)
	queue_redraw()


## Shows nothing (no project open).
func clear() -> void:
	pattern = null
	show_preview()


## The back for the back side view; `lines` holds the finished segments per thread index,
## `ghost` the current step's, `starts` and `ends` the holes where threads begin and end.
func show_back(lines: Array[PackedVector2Array], ghost: PackedVector2Array,
		starts: PackedVector2Array, ends: PackedVector2Array) -> void:
	_back_starts = starts
	_back_ends = ends
	_scene.set_back(lines, ghost, _highlight.thread if _highlight != null else -1)
	queue_redraw()


func show_preview() -> void:
	_states = PackedByteArray()
	_highlight = null
	_hint = null
	_thread_end = Vector2i(-1, -1)
	_new_thread = false
	if pattern != null:
		_scene.set_states(_states)
		_scene.set_ghost(null)
	queue_redraw()


## Shows the back (or the front again); with `animate` the fabric turns over on screen.
func set_back_side(value: bool, animate: bool) -> void:
	if value == _back_side:
		return
	_stop_flip()
	_stop_pan()
	if pattern != null:
		var middle := size.x / 2.0
		if animate and _is_laid_out():
			_flipping = true
			_turn_origin = _origin
			_turn_pivot = (middle - _origin.x) / _cell_px
			_turn = 0.0
			_flip_tween = create_tween()
			_flip_tween.tween_property(self, "_turn", 1.0, FLIP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_flip_tween.finished.connect(_stop_flip)
		# Keep the column in the middle of the view in the middle once mirrored.
		_origin.x = middle - (pattern.width - (middle - _origin.x) / _cell_px) * _cell_px
	_back_side = value
	queue_redraw()


## Holds a running flip at `progress` (0..1), for screenshots.
func hold_flip(progress: float) -> void:
	if _flip_tween != null:
		_flip_tween.kill()
		_flip_tween = null
	_turn = progress


func is_flipping() -> bool:
	return _flipping


## Light for the fabric and thread, see StitchScene.set_light().
func set_light(azimuth: float, elevation: float) -> void:
	_scene.set_light(azimuth, elevation)
	queue_redraw()


func _stop_flip() -> void:
	if not _flipping:
		return
	if _flip_tween != null:
		_flip_tween.kill()
		_flip_tween = null
	_flipping = false
	queue_redraw()
	flip_finished.emit()


## Zooms so the whole pattern fits, centred.
func fit_to_view() -> void:
	if pattern == null or pattern.width == 0 or size.x <= 0.0 or size.y <= 0.0:
		return
	_stop_pan()
	var free := _free_rect()
	var available := free.size - Vector2.ONE * FIT_MARGIN * 2.0
	_cell_px = clampf(minf(available.x / pattern.width, available.y / pattern.height),
			MIN_CELL_PX, MAX_CELL_PX)
	_origin = free.get_center() - Vector2(pattern.width, pattern.height) * _cell_px / 2.0
	queue_redraw()


## Zooms in to at least `min_cell_px` (if the screen allows) and centres `step`.
func focus_step(step: StitchStep, min_cell_px: float) -> void:
	if not _is_laid_out():
		_pending_focus = [step, min_cell_px]
		return
	_stop_pan()
	_cell_px = clampf(maxf(_cell_px, min_cell_px), MIN_CELL_PX, MAX_CELL_PX)
	var rect := _step_rect(step)
	_origin += _free_rect().get_center() - rect.get_center()
	queue_redraw()


## Pans so the cells of `step` (and the reference stitch of `hint`, and `extra` if given) are on
## screen, if they aren't already.
## With `animate` the view glides there instead of jumping.
func ensure_visible(step: StitchStep, hint: PositionHint = null, extra := Vector2i(-1, -1),
		animate := false) -> void:
	if not _is_laid_out():
		return
	_stop_pan()
	var rect := _step_rect(step)
	if hint != null:
		rect = rect.merge(_cell_rect(hint.reference.x, hint.reference.y))
	if extra.x >= 0:
		rect = rect.merge(_cell_rect(extra.x, extra.y))
	var view := _free_rect().grow(-FIT_MARGIN)
	if view.encloses(rect):
		return
	var target := _origin + view.get_center() - rect.get_center()
	if not animate or not is_inside_tree():
		_set_origin(target)
		return
	_pan_tween = create_tween()
	_pan_tween.tween_method(_set_origin, _origin, target, PAN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_panning() -> bool:
	return _pan_tween != null and _pan_tween.is_running()


func _set_origin(origin: Vector2) -> void:
	_origin = origin
	queue_redraw()


## Stops a glide from ensure_visible(); anything else that moves the view comes first.
func _stop_pan() -> void:
	if _pan_tween != null:
		_pan_tween.kill()
		_pan_tween = null


## Tells the view which parts overlays cover; the next ensure_visible() keeps steps clear of them.
func set_covered(top: float, bottom: float) -> void:
	_cover_top = top
	_cover_bottom = bottom


## The part of the view not covered by overlays, or all of it if too little is left.
func _free_rect() -> Rect2:
	var free := Rect2(0.0, _cover_top, size.x, size.y - _cover_top - _cover_bottom)
	return free if free.size.y > FIT_MARGIN * 6.0 else Rect2(Vector2.ZERO, size)


func _is_laid_out() -> bool:
	return size.x > FIT_MARGIN * 2.0 and size.y > FIT_MARGIN * 2.0


## The first layout fits the pattern; later resizes (rotation, side panel switch) keep zoom
## and centre.
func _on_resized() -> void:
	if not _is_laid_out():
		return
	if _laid_out_size == Vector2.ZERO:
		fit_to_view()
	else:
		_origin += (size - _laid_out_size) / 2.0
		queue_redraw()
	_laid_out_size = size
	if not _pending_focus.is_empty():
		var focus := _pending_focus
		_pending_focus = []
		focus_step(focus[0], focus[1])


func _draw() -> void:
	if pattern == null:
		return
	_update_scene()
	draw_texture_rect(_viewport.get_texture(), Rect2(Vector2.ZERO, size), false)
	if _flipping or _states.is_empty():
		return
	if back_side:
		_draw_back()
	else:
		if _highlight != null:
			_draw_highlight(_highlight)
		if _hint != null:
			_draw_hint(_hint)
		if _thread_end.x >= 0:
			_draw_thread_end(_thread_end)
		if _highlight != null and _new_thread:
			_draw_thread_start(_highlight)
		if _highlight != null:
			_draw_block_count(_highlight)


## Matches the 3D camera to the 2D mapping (grid point g at _origin + g * _cell_px, mirrored on
## the back), and turns the fabric while it flips. The viewport renders at the screen's pixel
## density, so the thread stays sharp under canvas_items stretching.
func _update_scene() -> void:
	var density := get_viewport().get_final_transform().get_scale().x
	_viewport.size = Vector2i((size * density).round().max(Vector2.ONE))
	var origin := _turn_origin if _flipping else _origin
	_scene.set_view((size / 2.0 - origin) / _cell_px, size.y / _cell_px)
	if _flipping:
		_scene.set_turn(not back_side, PI * _turn, _turn_pivot, size.x / _cell_px)
	else:
		_scene.set_turn(back_side, 0.0, 0.0, size.x / _cell_px)


## The marks on the back (the thread itself is 3D): small knots where threads start (green) and
## end (red), and the frame, needle dot, thread markers and stitch count of the current step as
## on the front.
func _draw_back() -> void:
	if _highlight != null:
		_draw_frame(_highlight)
	var knot := maxf(2.0, _cell_px * 0.14)
	for hole in _back_starts:
		draw_circle(_hole_point(hole), knot, THREAD_START_COLOR)
	for hole in _back_ends:
		draw_circle(_hole_point(hole), knot, THREAD_END_COLOR)
	if _highlight != null:
		draw_circle(_needle_start(_highlight), maxf(3.0, _cell_px * 0.15), HIGHLIGHT_COLOR)
	if _thread_end.x >= 0:
		_draw_thread_end(_thread_end)
	if _highlight != null and _new_thread:
		_draw_thread_start(_highlight)
	if _highlight != null:
		_draw_block_count(_highlight)


## The current step (its legs still to stitch are see-through in 3D): a frame around its cells
## and a dot where the needle comes up first.
func _draw_highlight(step: StitchStep) -> void:
	_draw_frame(step)
	draw_circle(_needle_start(step), maxf(3.0, _cell_px * 0.15), HIGHLIGHT_COLOR)


func _draw_frame(step: StitchStep) -> void:
	var rect := _step_rect(step).grow(maxf(2.0, _cell_px * 0.1))
	draw_rect(rect, Color(HIGHLIGHT_COLOR, 0.12))
	draw_rect(rect, HIGHLIGHT_COLOR, false, 3.0)


## How many stitches the current step has, in a badge just past the end the needle moves
## towards (right of a single cross), so it stays clear of the start dot. Drawn last and at a
## readable size even when cells are small.
func _draw_block_count(step: StitchStep) -> void:
	var rect := _step_rect(step).grow(maxf(2.0, _cell_px * 0.1))
	var font := get_theme_default_font()
	var font_size := clampi(int(_cell_px * 0.55), 12, 22)
	var text := str(step.cells.size())
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var radius := maxf(text_size.x, font.get_height(font_size)) * 0.5 + 3.0
	var offset := radius + 4.0
	var towards_left := (step.direction < 0) != back_side
	var center := Vector2(rect.position.x - offset if towards_left else rect.end.x + offset,
			rect.get_center().y)
	draw_circle(center, radius, HIGHLIGHT_COLOR)
	draw_string(font, center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - font.get_height(font_size) / 2.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## A ring around the reference stitch, a line along the counting path ending in an arrow, and
## the count in every cell of the path. Each leg has its own colour (left/right, up/down) and
## counts from 1 again: "1, 2 down, then 1, 2, 3 right".
func _draw_hint(hint: PositionHint) -> void:
	var reference := _cell_rect(hint.reference.x, hint.reference.y)
	var line_width := maxf(2.0, _cell_px * 0.08)
	draw_arc(reference.get_center(), _cell_px * 0.62, 0.0, TAU, 32, HINT_COLOR, line_width)
	if hint.path.is_empty():
		return
	var corners: Array[Vector2i] = [hint.reference]
	var corner := hint.corner()
	if corner != hint.reference and corner != hint.target:
		corners.append(corner)
	corners.append(hint.target)
	for i in range(1, corners.size()):
		var from := _cell_rect(corners[i - 1].x, corners[i - 1].y).get_center()
		var to := _cell_rect(corners[i].x, corners[i].y).get_center()
		draw_line(from, to, Color(_leg_color(corners[i] - corners[i - 1]), 0.6), line_width)
	var last_leg := corners[-1] - corners[-2]
	var target := _cell_rect(hint.target.x, hint.target.y).get_center()
	var direction := Vector2(last_leg).normalized()
	var tip := target - direction * _cell_px * 0.1
	var side := direction.orthogonal() * _cell_px * 0.2
	var back := tip - direction * _cell_px * 0.3
	draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), _leg_color(last_leg))
	if hint.path.size() < 2:
		return  # Directly adjacent: nothing to count.
	var font := get_theme_default_font()
	var font_size := int(_cell_px * 0.42)
	var count := 0
	var previous := hint.reference
	var previous_step := Vector2i.ZERO
	for cell in hint.path:
		var step := cell - previous
		count = count + 1 if step == previous_step else 1
		previous = cell
		previous_step = step
		var color := _leg_color(step)
		var center := _cell_rect(cell.x, cell.y).get_center()
		if _cell_px < MIN_NUMBER_CELL_PX:
			draw_circle(center, maxf(1.5, _cell_px * 0.12), color)
			continue
		var text := str(count)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := center + Vector2(-text_size.x / 2.0, -text_size.y / 2.0 + font.get_ascent(font_size))
		draw_circle(center, _cell_px * 0.3, Color(FABRIC_COLOR, 0.85))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Colour of a counting leg going along `offset`: one for left/right, one for up/down.
func _leg_color(offset: Vector2i) -> Color:
	return HINT_VERTICAL_COLOR if offset.x == 0 else HINT_COLOR


## The old thread ends here: a red ring with a knot across the last stitch, labelled
## "vernähen".
func _draw_thread_end(cell: Vector2i) -> void:
	var center := _cell_rect(cell.x, cell.y).get_center()
	var radius := maxf(4.0, _cell_px * 0.55)
	var width := maxf(2.0, _cell_px * 0.1)
	draw_arc(center, radius, 0.0, TAU, 32, THREAD_END_COLOR, width)
	draw_line(center - Vector2(radius, radius) * 0.6, center + Vector2(radius, radius) * 0.6, THREAD_END_COLOR, width)
	_draw_label(center + Vector2(0.0, -radius - 4.0), "vernähen", THREAD_END_COLOR)


## A new thread starts with this step: a green ring around the needle's first hole, labelled
## "neuer Faden".
func _draw_thread_start(step: StitchStep) -> void:
	var start := _needle_start(step)
	var radius := maxf(5.0, _cell_px * 0.35)
	draw_arc(start, radius, 0.0, TAU, 32, THREAD_START_COLOR, maxf(2.0, _cell_px * 0.1))
	_draw_label(start + Vector2(0.0, radius + 4.0 + _label_size() * 0.8), "neuer Faden", THREAD_START_COLOR)


## A short label centred at `position` (its baseline), on a light background so it reads over
## stitches. Left out when cells are too small.
func _draw_label(position: Vector2, text: String, color: Color) -> void:
	if _cell_px < MIN_LABEL_CELL_PX:
		return
	var font := get_theme_default_font()
	var font_size := _label_size()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := position - Vector2(text_size.x / 2.0, 0.0)
	var box := Rect2(baseline + Vector2(-3.0, -font.get_ascent(font_size) - 1.0), text_size + Vector2(6.0, 2.0))
	draw_rect(box, Color(FABRIC_COLOR, 0.9))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _label_size() -> int:
	return clampi(int(_cell_px * 0.5), 10, 18)


func _cell_rect(x: int, y: int) -> Rect2:
	return Rect2(_origin + Vector2(_column_x(x + 1) if back_side else x, y) * _cell_px, Vector2.ONE * _cell_px)


## Where grid line `x` (the left edge of column x) is drawn, in cells from the left: mirrored on
## the back.
func _column_x(x: float) -> float:
	return pattern.width - x if back_side else x


## A hole (BackSide grid units) on screen.
func _hole_point(hole: Vector2) -> Vector2:
	return _origin + Vector2(_column_x(hole.x), hole.y) * _cell_px


## The hole where the needle comes up first in `step` (see StitchStyle).
func _needle_start(step: StitchStep) -> Vector2:
	return _hole_point(style.needle_holes(step)[0])


func _step_rect(step: StitchStep) -> Rect2:
	var rect := _cell_rect(step.cells[0], step.row)
	for x in step.cells:
		rect = rect.merge(_cell_rect(x, step.row))
	return rect


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif _flipping:
		pass
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		_pan(-event.delta * 8.0)
	elif event is InputEventMouseButton and event.pressed:
		# The left button arrives as touches.
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				touched.emit()
				_zoom_at(event.position, WHEEL_ZOOM)
			MOUSE_BUTTON_WHEEL_DOWN:
				touched.emit()
				_zoom_at(event.position, 1.0 / WHEEL_ZOOM)
			MOUSE_BUTTON_RIGHT:
				touched.emit()
				if event.double_click:
					two_finger_double_tapped.emit()
			_:
				return
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_pan(event.relative)
	else:
		return
	accept_event()


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touches.is_empty():
			touched.emit()
			_gesture_fingers = 0
			_gesture_moved = _flipping
			_gesture_start_msec = Time.get_ticks_msec()
			_gesture_edge = 0
			if event.position.x < EDGE_PX:
				_gesture_edge = -1
			elif event.position.x > size.x - EDGE_PX:
				_gesture_edge = 1
		_touches[event.index] = event.position
		_touch_starts[event.index] = event.position
		_gesture_fingers = maxi(_gesture_fingers, _touches.size())
		return
	if not _touches.has(event.index):
		return
	var start: Vector2 = _touch_starts[event.index]
	_touches.erase(event.index)
	_touch_starts.erase(event.index)
	if event.canceled or event.position.distance_to(start) > TAP_SLOP:
		_gesture_moved = true
	if _touches.is_empty():
		_end_gesture(start, event.position)


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var before: Dictionary = _touches.duplicate()
	_touches[event.index] = event.position
	if event.position.distance_to(_touch_starts[event.index]) > TAP_SLOP:
		_gesture_moved = true
	if _flipping or (_gesture_edge != 0 and _gesture_fingers == 1):
		return  # An edge swipe doesn't pan.
	if _touches.size() == 1:
		_pan(event.relative)
	elif _touches.size() >= 2 and before.size() >= 2:
		var keys := _touches.keys()
		var old_a: Vector2 = before.get(keys[0], _touches[keys[0]])
		var old_b: Vector2 = before.get(keys[1], _touches[keys[1]])
		var new_a: Vector2 = _touches[keys[0]]
		var new_b: Vector2 = _touches[keys[1]]
		var old_distance := old_a.distance_to(old_b)
		if old_distance > 0.0:
			_zoom_at((new_a + new_b) / 2.0, new_a.distance_to(new_b) / old_distance)
		_pan((new_a + new_b - old_a - old_b) / 2.0)


## All fingers are up: an edge swipe, a tap or a two-finger tap, or nothing (panned, held).
func _end_gesture(start: Vector2, end: Vector2) -> void:
	if _flipping:
		return
	if _gesture_edge != 0 and _gesture_fingers == 1:
		var travel := end - start
		if -travel.x * _gesture_edge >= SWIPE_PX and absf(travel.x) > absf(travel.y) * 1.5:
			(swiped_from_left if _gesture_edge < 0 else swiped_from_right).emit()
			return
	var now := Time.get_ticks_msec()
	if _gesture_moved or now - _gesture_start_msec > TAP_SECONDS * 1000.0:
		return
	if _gesture_fingers == 1:
		_on_tap(end)
	elif _gesture_fingers == 2:
		if now - _two_finger_tap_msec <= (DOUBLE_TAP_SECONDS + TAP_SECONDS) * 1000.0:
			_two_finger_tap_msec = -100000
			two_finger_double_tapped.emit()
		else:
			_two_finger_tap_msec = now


## A tap waits for a second one; together they make a double tap.
func _on_tap(position: Vector2) -> void:
	if _tap_pending:
		_tap_pending = false
		if position.distance_to(_tap_position) <= DOUBLE_TAP_SLOP:
			double_tapped.emit()
			return
		tapped.emit()
	_tap_pending = true
	_tap_position = position
	_tap_count += 1
	var count := _tap_count
	get_tree().create_timer(DOUBLE_TAP_SECONDS).timeout.connect(func() -> void:
		if _tap_pending and count == _tap_count:
			_tap_pending = false
			tapped.emit())


func _pan(delta: Vector2) -> void:
	_stop_pan()
	_origin += delta
	queue_redraw()


## Zooms by `factor`, keeping the point under `focus` in place.
func _zoom_at(focus: Vector2, factor: float) -> void:
	_stop_pan()
	var new_cell_px := clampf(_cell_px * factor, MIN_CELL_PX, MAX_CELL_PX)
	_origin = focus - (focus - _origin) * (new_cell_px / _cell_px)
	_cell_px = new_cell_px
	queue_redraw()

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
##
## Pages: with a `back_page` (a picture of the overview while stitching) the swipe from the left
## edge drags the page shown to the right, following the finger and standing still when it
## does, with the back page coming in beneath; let go far or fast enough and it goes all the way
## (then `swiped_from_left`), otherwise it springs back. slide_in() and slide_back() play the
## same move on their own.

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
## The current step: orange, or the blue of the round buttons where that stands out more from
## the thread (see contrast_color()).
const HIGHLIGHT_COLOR := Color(1.0, 0.5, 0.05)
const HIGHLIGHT_ALT_COLOR := RoundButton.DEFAULT_TINT
## Reference stitch of the position hint, and the left/right leg of its counting path:
## turquoise, apart from both colours of the block.
const HINT_COLOR := Color(0.0, 0.62, 0.64)
## The up/down leg of the counting path.
const HINT_VERTICAL_COLOR := Color(0.7, 0.1, 0.65)
## Below this cell size the counting path shows dots instead of numbers.
const MIN_NUMBER_CELL_PX := 14.0
## Where the old thread ends (to be secured) and where a new one begins, each with a second
## colour for threads closer than MARK_MIN_DELTA_E to the first.
const THREAD_END_COLOR := Color(0.85, 0.15, 0.15)
const THREAD_END_ALT_COLOR := Color(0.12, 0.12, 0.16)
const THREAD_START_COLOR := Color(0.1, 0.6, 0.25)
const THREAD_START_ALT_COLOR := Color(0.8, 0.15, 0.6)
## A thread mark keeps its usual colour while it differs at least this much from the thread
## (CIEDE2000), so the colours keep their meaning where they can.
const MARK_MIN_DELTA_E := 30.0
## Below this cell size the thread markers have no text labels.
const MIN_LABEL_CELL_PX := 14.0
## Below this cell size the current step shows no arrows along its legs.
const MIN_ARROW_CELL_PX := 12.0
const MIN_CELL_PX := 2.0
const MAX_CELL_PX := 96.0
const FIT_MARGIN := 16.0
## Shown together with its counting path, the step keeps at least this share of the view away
## from the view's edges; a path too long for that runs off screen and the step is centred.
const STEP_EDGE_SHARE := 0.15
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
## Page slides: the time for a whole screen width; the page beneath moves at this share of the
## speed and is darkened up to PAGE_DIM while covered; a shadow this wide at the page's edge.
const PAGE_SECONDS := 0.32
const PAGE_PARALLAX := 0.3
const PAGE_DIM := 0.35
const PAGE_SHADOW_PX := 24.0
## A swipe back goes through when let go past this share of the width or flicked to the right
## faster than PAGE_FLICK_SPEED (pixels per second).
const PAGE_COMMIT_SHARE := 0.4
const PAGE_FLICK_SPEED := 700.0

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

## Picture of the page a swipe from the left edge goes back to; null: the swipe only emits
## swiped_from_left at its end.
var back_page: Texture2D

var _back_side := false
var _viewport := SubViewport.new()
## The page beneath while pages slide, and how far the page shown is moved to the right.
var _under_page: Texture2D
var _page_shift := 0.0:
	set(value):
		_page_shift = value
		queue_redraw()
var _page_tween: Tween
## A swipe from the left edge is dragging the page; its last speed to the right.
var _page_dragging := false
var _page_speed := 0.0
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
## Screen rects of the badges and labels drawn so far this frame, so labels can avoid them.
var _taken: Array[Rect2] = []
## Colours of the marks for the threads shown now (see contrast_color()).
var _highlight_color := HIGHLIGHT_COLOR
var _thread_end_color := THREAD_END_COLOR
var _thread_start_color := THREAD_START_COLOR
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
	_highlight_color = HIGHLIGHT_COLOR
	_thread_start_color = THREAD_START_COLOR
	if highlight != null:
		var thread := _colors[highlight.thread]
		_highlight_color = block_color(thread)
		_thread_start_color = contrast_color(thread, THREAD_START_COLOR, THREAD_START_ALT_COLOR,
				MARK_MIN_DELTA_E)
	_thread_end_color = THREAD_END_COLOR
	if thread_end.x >= 0:
		_thread_end_color = contrast_color(_colors[pattern.get_cell(thread_end.x, thread_end.y)],
				THREAD_END_COLOR, THREAD_END_ALT_COLOR, MARK_MIN_DELTA_E)
	_scene.set_states(states)
	_scene.set_ghost(highlight)
	queue_redraw()


## The colour of the current block (and of everything matching it) for a thread of `thread`
## colour: orange or the button blue, whichever stands out more.
static func block_color(thread: Color) -> Color:
	return contrast_color(thread, HIGHLIGHT_COLOR, HIGHLIGHT_ALT_COLOR)


## `main`, or `alternative` if that differs more from `thread` (CIEDE2000). With `enough`,
## `main` stays whenever it differs at least that much.
static func contrast_color(thread: Color, main: Color, alternative: Color, enough := INF) -> Color:
	var lab := ColorLab.from_color(thread)
	var main_delta := ColorLab.delta_e(lab, ColorLab.from_color(main))
	if main_delta < enough and ColorLab.delta_e(lab, ColorLab.from_color(alternative)) > main_delta:
		return alternative
	return main


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


## A picture of the fabric as shown now, without the 2D marks (the overview has none); null
## where nothing is rendered (headless).
func snapshot() -> ImageTexture:
	if DisplayServer.get_name() == "headless":
		return null
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


## Zoom and position, to put back with set_view_state(); a different size fits the pattern
## instead.
func view_state() -> Array:
	return [_origin, _cell_px, size]


func set_view_state(state: Array) -> void:
	if state[2] != size:
		fit_to_view()
		return
	_stop_pan()
	_origin = state[0]
	_cell_px = state[1]
	queue_redraw()


## The page shown now comes in from the right over `from` (a picture of the page before, may
## be null), which moves away to the left.
func slide_in(from: Texture2D) -> void:
	_under_page = from
	_page_shift = size.x
	_animate_page(0.0)


## The page shown now moves out to the right, uncovering `back_page`; returns once it has gone.
## The page stays out until end_page_slide().
func slide_back() -> void:
	_under_page = back_page
	await _animate_page(size.x)


## Shows the page as it is again, after slide_back() or a swipe back.
func end_page_slide() -> void:
	if _page_tween != null:
		_page_tween.kill()
	_page_dragging = false
	_under_page = null
	_page_shift = 0.0


func is_page_sliding() -> bool:
	return _page_dragging or (_page_tween != null and _page_tween.is_running())


## Moves the page to `target` (0: in place, size.x: gone), slower the further it goes.
func _animate_page(target: float) -> void:
	if _page_tween != null:
		_page_tween.kill()
	var seconds := maxf(PAGE_SECONDS * absf(target - _page_shift) / maxf(size.x, 1.0), 0.01)
	_page_tween = create_tween()
	_page_tween.tween_property(self, "_page_shift", target, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _page_tween.finished
	if target == 0.0:
		_under_page = null


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


## Where the whole pattern is on screen (global).
func pattern_rect() -> Rect2:
	if pattern == null:
		return Rect2()
	return Rect2(global_position + _origin, Vector2(pattern.width, pattern.height) * _cell_px)


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
## screen, if they aren't already. Where showing them all would push the step towards an edge of
## the view (STEP_EDGE_SHARE), the step is centred on that axis instead.
## With `animate` the view glides there instead of jumping.
func ensure_visible(step: StitchStep, hint: PositionHint = null, extra := Vector2i(-1, -1),
		animate := false) -> void:
	if not _is_laid_out():
		return
	_stop_pan()
	# Room for the badges beside the step and the path.
	var margin := _badge_gap() + _badge_radius("00") * 2.0
	var own := _step_rect(step).grow(margin)
	var rect := own
	if hint != null:
		rect = rect.merge(_cell_rect(hint.reference.x, hint.reference.y).grow(margin))
	if extra.x >= 0:
		rect = rect.merge(_cell_rect(extra.x, extra.y).grow(margin))
	var view := _free_rect().grow(-FIT_MARGIN)
	if view.encloses(rect):
		return
	var shift := view.get_center() - rect.get_center()
	var inset := view.size * STEP_EDGE_SHARE
	var inner := view.grow_individual(-inset.x, -inset.y, -inset.x, -inset.y)
	for axis in 2:
		if own.position[axis] + shift[axis] < inner.position[axis] or own.end[axis] + shift[axis] > inner.end[axis]:
			shift[axis] = view.get_center()[axis] - own.get_center()[axis]
	var target := _origin + shift
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
	if _page_shift != 0.0:
		_draw_under_page()
		draw_set_transform(Vector2(_page_shift, 0.0))
	draw_texture_rect(_viewport.get_texture(), Rect2(Vector2.ZERO, size), false)
	_taken.clear()
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


## While pages slide: the page beneath (moved less and darkened while covered), the background
## of the page shown, and its shadow on the page beneath.
func _draw_under_page() -> void:
	var background := RenderingServer.get_default_clear_color()
	var covered := 1.0 - clampf(_page_shift / maxf(size.x, 1.0), 0.0, 1.0)
	var tint := Color.WHITE.darkened(PAGE_DIM * covered)
	var under := Rect2(Vector2((_page_shift - size.x) * PAGE_PARALLAX, 0.0), size)
	draw_rect(under, background * tint)
	if _under_page != null:
		draw_texture_rect(_under_page, under, false, tint)
	var edge := _page_shift
	var shadow := Color(0.0, 0.0, 0.0, 0.35 * covered)
	draw_polygon(PackedVector2Array([Vector2(edge - PAGE_SHADOW_PX, 0.0), Vector2(edge, 0.0),
			Vector2(edge, size.y), Vector2(edge - PAGE_SHADOW_PX, size.y)]),
			PackedColorArray([Color(shadow, 0.0), shadow, shadow, Color(shadow, 0.0)]))
	draw_rect(Rect2(Vector2(edge, 0.0), size), background)


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
		draw_circle(_needle_start(_highlight), maxf(3.0, _cell_px * 0.15), _highlight_color)
	if _thread_end.x >= 0:
		_draw_thread_end(_thread_end)
	if _highlight != null and _new_thread:
		_draw_thread_start(_highlight)
	if _highlight != null:
		_draw_block_count(_highlight)


## The current step (its legs still to stitch are see-through in 3D): a frame around its cells,
## a dot where the needle comes up first and an arrow along every leg, from where the needle
## comes up to where it goes down.
func _draw_highlight(step: StitchStep) -> void:
	_draw_frame(step)
	_draw_leg_arrows(step)
	draw_circle(_needle_start(step), maxf(3.0, _cell_px * 0.15), _highlight_color)


func _draw_frame(step: StitchStep) -> void:
	var rect := _step_rect(step).grow(maxf(2.0, _cell_px * 0.1))
	draw_rect(rect, Color(_highlight_color, 0.12))
	draw_rect(rect, _highlight_color, false, 3.0)


## A thin arrow along each leg of `step` (StitchStyle.needle_holes()), kept off the holes, on a
## light edge so it reads over dark thread too. Left out when cells are small.
func _draw_leg_arrows(step: StitchStep) -> void:
	if _cell_px < MIN_ARROW_CELL_PX:
		return
	var holes := style.needle_holes(step)
	var width := maxf(1.5, _cell_px * 0.045)
	var head := _cell_px * 0.16
	for i in range(0, holes.size() - 1, 2):
		var up := _hole_point(holes[i])
		var down := _hole_point(holes[i + 1])
		var direction := (down - up).normalized()
		var from := up.lerp(down, 0.2)
		var tip := up.lerp(down, 0.78)
		var back := tip - direction * head
		var side := direction.orthogonal() * head * 0.55
		var arrow := PackedVector2Array([tip, back + side, back - side])
		var edge := Color(FABRIC_COLOR, 0.75)
		draw_line(from, back, edge, width + 2.0)
		draw_colored_polygon(_grown_triangle(arrow, 2.0), edge)
		draw_line(from, back, _highlight_color, width)
		draw_colored_polygon(arrow, _highlight_color)


## `triangle` grown by `pixels` away from its centre, for an outline.
static func _grown_triangle(triangle: PackedVector2Array, pixels: float) -> PackedVector2Array:
	var center := (triangle[0] + triangle[1] + triangle[2]) / 3.0
	var grown := PackedVector2Array()
	for point in triangle:
		grown.append(point + (point - center).normalized() * pixels)
	return grown


## How many stitches the current step has, in a badge a little past the end the needle moves
## towards (right of a single cross), so it stays clear of the start dot and the thread next to
## the step. Drawn last and at a readable size even when cells are small.
func _draw_block_count(step: StitchStep) -> void:
	var rect := _step_rect(step).grow(maxf(2.0, _cell_px * 0.1))
	var text := str(step.cells.size())
	var offset := _badge_radius(text) + _badge_gap()
	var towards_left := _block_count_left(step)
	var center := Vector2(rect.position.x - offset if towards_left else rect.end.x + offset,
			rect.get_center().y)
	_draw_badge(center, text, _highlight_color)


## Whether the block count sits left of `step` on screen.
func _block_count_left(step: StitchStep) -> bool:
	return (step.direction < 0) != back_side


## Space between a badge and what it belongs to.
func _badge_gap() -> float:
	return maxf(10.0, _cell_px * 0.6)


func _badge_font_size() -> int:
	return clampi(int(_cell_px * 0.55), 12, 22)


func _badge_radius(text: String) -> float:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _badge_font_size())
	return maxf(text_size.x, font.get_height(_badge_font_size())) * 0.5 + 3.0


## A number in white on a disc of `color`, as for the block count.
func _draw_badge(center: Vector2, text: String, color: Color) -> void:
	var font := get_theme_default_font()
	var font_size := _badge_font_size()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var radius := _badge_radius(text)
	_taken.append(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
	draw_circle(center, radius, color)
	draw_string(font, center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - font.get_height(font_size) / 2.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## A ring around the reference stitch (before the first stitch: around the pattern's corner
## hole), a line along the counting path ending in an arrow, and the count at every hole of the
## path. Counting goes from hole to hole (PositionHint.holes): from the reference's hole nearest
## to where the needle comes up in the step, to that hole, so each hop is one cell. Each leg has its own colour (left/right, up/down)
## and counts from 1 again: "1, 2 down, then 1, 2, 3 right".
func _draw_hint(hint: PositionHint) -> void:
	var line_width := maxf(2.0, _cell_px * 0.08)
	var start := _hole_point(Vector2(hint.start))
	if hint.landmark == PositionHint.Landmark.CORNER:
		# The pattern's corner hole itself, where the user places the pattern on the fabric.
		var radius := _cell_px * 0.4
		draw_arc(start, radius, 0.0, TAU, 32, HINT_COLOR, line_width)
		_taken.append(Rect2(start - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
	else:
		var reference := _cell_rect(hint.reference.x, hint.reference.y)
		draw_arc(reference.get_center(), _cell_px * 0.62, 0.0, TAU, 32, HINT_COLOR, line_width)
		_taken.append(reference)
	draw_circle(start, maxf(2.0, _cell_px * 0.1), HINT_COLOR)
	if hint.holes.is_empty():
		return
	var number_radius := _cell_px * 0.24
	for hole in hint.holes:
		_taken.append(Rect2(_hole_point(Vector2(hole)) - Vector2.ONE * number_radius, Vector2.ONE * number_radius * 2.0))
	var corners: Array[Vector2i] = [hint.start]
	var bend := hint.bend()
	if bend != hint.start and bend != hint.needle:
		corners.append(bend)
	corners.append(hint.needle)
	for i in range(1, corners.size()):
		draw_line(_hole_point(Vector2(corners[i - 1])), _hole_point(Vector2(corners[i])),
				Color(_leg_color(corners[i] - corners[i - 1]), 0.6), line_width)
	var last_leg := corners[-1] - corners[-2]
	var target := _hole_point(Vector2(hint.needle))
	var direction := (target - _hole_point(Vector2(corners[-2]))).normalized()
	var tip := target - direction * _cell_px * 0.12
	var side := direction.orthogonal() * _cell_px * 0.18
	var back := tip - direction * _cell_px * 0.28
	draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), _leg_color(last_leg))
	if hint.holes.size() < 2:
		return  # The very next hole: nothing to count.
	var font := get_theme_default_font()
	var font_size := int(_cell_px * 0.36)
	var count := 0
	var previous := hint.start
	var previous_step := Vector2i.ZERO
	for hole in hint.holes:
		var step := hole - previous
		count = count + 1 if step == previous_step else 1
		previous = hole
		previous_step = step
		if hole == hint.needle:
			continue  # The arrow points at the needle's hole; its count is in the badge.
		var color := _leg_color(step)
		var center := _hole_point(Vector2(hole))
		if _cell_px < MIN_NUMBER_CELL_PX:
			draw_circle(center, maxf(1.5, _cell_px * 0.1), color)
			continue
		var text := str(count)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := center + Vector2(-text_size.x / 2.0, -text_size.y / 2.0 + font.get_ascent(font_size))
		draw_circle(center, number_radius, Color(FABRIC_COLOR, 0.9))
		draw_arc(center, number_radius, 0.0, TAU, 24, Color(color, 0.7), 1.0)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	_draw_leg_totals(corners)


## The count of each counting leg once more, big as the block count, beside the hole where the
## leg ends, clear of the step's row: a first leg up or down goes on past its end, a first leg
## left or right gets it on the side away from the next leg; the last leg (ending at the step)
## left or right has it on the side away from where counting began, up or down away from the
## block count.
func _draw_leg_totals(corners: Array[Vector2i]) -> void:
	for i in range(1, corners.size()):
		var leg := corners[i] - corners[i - 1]
		var start := _hole_point(Vector2(corners[i - 1]))
		var end := _hole_point(Vector2(corners[i]))
		var side := Vector2.UP
		if i + 1 < corners.size():
			var next := _hole_point(Vector2(corners[i + 1]))
			side = (end - start if leg.x == 0 else end - next).normalized()
		elif leg.x == 0:
			side = Vector2.RIGHT if _highlight != null and _block_count_left(_highlight) else Vector2.LEFT
		elif corners[0].y < corners[i].y:
			side = Vector2.DOWN
		var text := str(maxi(absi(leg.x), absi(leg.y)))
		_draw_badge(end + side * (_cell_px * 0.6 + _badge_gap() + _badge_radius(text)), text,
				_leg_color(leg))


## Colour of a counting leg going along `offset`: one for left/right, one for up/down.
func _leg_color(offset: Vector2i) -> Color:
	return HINT_VERTICAL_COLOR if offset.x == 0 else HINT_COLOR


## The old thread ends here: a red ring (dark for reddish threads) with a knot across the last
## stitch, labelled "vernähen" well above it.
func _draw_thread_end(cell: Vector2i) -> void:
	var center := _cell_rect(cell.x, cell.y).get_center()
	var radius := maxf(4.0, _cell_px * 0.55)
	var width := maxf(2.0, _cell_px * 0.1)
	draw_arc(center, radius, 0.0, TAU, 32, _thread_end_color, width)
	draw_line(center - Vector2(radius, radius) * 0.6, center + Vector2(radius, radius) * 0.6, _thread_end_color, width)
	_draw_label(center, radius, -1.0, "vernähen", _thread_end_color)


## A new thread starts with this step: a green ring (pink for greenish threads) around the
## needle's first hole, labelled "neuer Faden" well below it.
func _draw_thread_start(step: StitchStep) -> void:
	var start := _needle_start(step)
	var radius := maxf(5.0, _cell_px * 0.35)
	draw_arc(start, radius, 0.0, TAU, 32, _thread_start_color, maxf(2.0, _cell_px * 0.1))
	_draw_label(start, radius, 1.0, "neuer Faden", _thread_start_color)


## A short label for the mark at `center` (a ring of `radius`): above it (`vertical` -1) or below
## (1), a good cell away so it leaves the stitches around the mark free, joined to the ring by a
## thin line; on a light background so it reads over stitches. It takes the other side, or goes
## further out, when a badge, label or counting number is in the way. Left out when cells are
## too small.
func _draw_label(center: Vector2, radius: float, vertical: float, text: String, color: Color) -> void:
	if _cell_px < MIN_LABEL_CELL_PX:
		return
	var font := get_theme_default_font()
	var font_size := _label_size()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var gap := maxf(18.0, _cell_px * 1.1)
	var box_height := font.get_height(font_size) + 2.0
	var box := Rect2()
	var preferred := vertical
	# Tried in turn: the preferred side, the other one, then both twice as far; else the first.
	var attempts: Array[Vector2] = [Vector2(preferred, 1.0), Vector2(-preferred, 1.0),
			Vector2(preferred, 2.0), Vector2(-preferred, 2.0), Vector2(preferred, 1.0)]
	for attempt in attempts:
		vertical = attempt.x
		var away := radius + gap * attempt.y
		var box_top := center.y + away if vertical > 0.0 else center.y - away - box_height
		box = Rect2(center.x - text_size.x / 2.0 - 3.0, box_top, text_size.x + 6.0, box_height)
		if not _taken.any(func(taken: Rect2) -> bool: return taken.intersects(box)):
			break
	var line_start := center + Vector2(0.0, radius * vertical)
	var line_end := Vector2(center.x, box.position.y if vertical > 0.0 else box.end.y)
	# No line through a badge or number on the way; the label then stands on its own.
	var line_rect := Rect2(line_start, Vector2.ZERO).expand(line_end).grow(1.0)
	if not _taken.any(func(taken: Rect2) -> bool: return taken.intersects(line_rect)):
		draw_line(line_start, line_end, color, maxf(1.5, _cell_px * 0.05))
	_taken.append(box)
	draw_rect(box, Color(FABRIC_COLOR, 0.9))
	draw_rect(box, color, false, 1.5)
	draw_string(font, Vector2(box.position.x + 3.0, box.position.y + 1.0 + font.get_ascent(font_size)),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


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
			_gesture_moved = _flipping or is_page_sliding()
			_gesture_start_msec = Time.get_ticks_msec()
			_gesture_edge = 0
			if event.position.x < EDGE_PX:
				_gesture_edge = -1
				if back_page != null and not _gesture_moved:
					_page_dragging = true
					_page_speed = 0.0
					_under_page = back_page
			elif event.position.x > size.x - EDGE_PX:
				_gesture_edge = 1
		_touches[event.index] = event.position
		_touch_starts[event.index] = event.position
		_gesture_fingers = maxi(_gesture_fingers, _touches.size())
		if _page_dragging and _touches.size() > 1:
			_page_dragging = false
			_animate_page(0.0)  # A second finger: not a swipe back after all.
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
	if _page_dragging:
		_page_shift = clampf(event.position.x - _touch_starts[event.index].x, 0.0, size.x)
		_page_speed = event.velocity.x
		return
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
	if _page_dragging:
		_page_dragging = false
		if _gesture_moved:
			_end_page_drag()
			return
		end_page_slide()  # Only a tap at the edge.
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


## The swipe back was let go: on through, or back.
func _end_page_drag() -> void:
	if _page_shift > size.x * PAGE_COMMIT_SHARE or _page_speed > PAGE_FLICK_SPEED:
		await _animate_page(size.x)
		swiped_from_left.emit()
	else:
		_animate_page(0.0)


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


## Zooms by `factor` around the middle of the part the overlays leave free (the + and − keys).
func zoom_by(factor: float) -> void:
	if not _flipping:
		_zoom_at(_free_rect().get_center(), factor)


## Moves the pattern by `delta` (the arrow and WASD keys).
func pan_by(delta: Vector2) -> void:
	if not _flipping:
		_pan(delta)


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

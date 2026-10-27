class_name PatternView
extends Control
## Shows a pattern as a grid. Preview mode draws every cell as a coloured square; progress mode
## draws only the stitched legs plus the current step. Drag to pan; pinch, trackpad or mouse
## wheel to zoom; a short tap emits `tapped`.

signal tapped

## Colour of empty cells (light Aida fabric).
const FABRIC_COLOR := Color8(245, 241, 230)
const GRID_COLOR := Color(0.0, 0.0, 0.0, 0.12)
## Every 10th line is darker, as on printed charts.
const GRID_MAJOR_COLOR := Color(0.0, 0.0, 0.0, 0.4)
const HIGHLIGHT_COLOR := Color(1.0, 0.5, 0.05)
## Reference stitch and counting path of the position hint.
const HINT_COLOR := Color(0.1, 0.45, 0.95)
## Below this cell size the counting path shows dots instead of numbers.
const MIN_NUMBER_CELL_PX := 14.0
## Opacity and relative thickness of the legs still to stitch in the current step.
const GHOST_ALPHA := 0.35
const GHOST_WIDTH := 0.5
const MIN_CELL_PX := 2.0
const MAX_CELL_PX := 96.0
## Below these cell sizes the grid lines are left out.
const MIN_MINOR_GRID_PX := 6.0
const MIN_MAJOR_GRID_PX := 3.0
const FIT_MARGIN := 16.0
const WHEEL_ZOOM := 1.15
## A touch that moves less than this is a tap.
const TAP_SLOP := 12.0
## Leg thickness and inset as parts of a cell.
const LEG_WIDTH := 0.2
const LEG_INSET := 0.12

var pattern: Pattern

var _texture: ImageTexture
var _colors: Array[Color] = []
## StitchSession.Cell per cell in progress mode; empty in preview mode.
var _states := PackedByteArray()
var _highlight: StitchStep
var _hint: PositionHint
## Size of one cell on screen, in pixels.
var _cell_px := 10.0
## Top left corner of the grid, in local coordinates.
var _origin := Vector2.ZERO
var _touches := {}  # touch index -> position
var _tap_possible := false
var _tap_start := Vector2.ZERO
## Size at the last layout, to keep the centre when the view is resized.
var _laid_out_size := Vector2.ZERO
## focus_step() called before the first layout: [step, min_cell_px], applied on layout.
var _pending_focus := []


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	resized.connect(_on_resized)


## Shows `p` in preview mode; with `keep_view` the zoom and position stay as they are.
func show_pattern(p: Pattern, palette: FlossPalette, keep_view := false) -> void:
	pattern = p
	_colors.clear()
	for code in p.thread_codes:
		_colors.append(palette.find_code(code).color)
	var image := Image.create_empty(p.width, p.height, false, Image.FORMAT_RGBA8)
	for y in p.height:
		for x in p.width:
			var index := p.get_cell(x, y)
			image.set_pixel(x, y, FABRIC_COLOR if index == Pattern.EMPTY else _colors[index])
	_texture = ImageTexture.create_from_image(image)
	_states = PackedByteArray()
	_highlight = null
	_hint = null
	if not keep_view:
		fit_to_view()
	queue_redraw()


## Switches to progress mode: `states` holds a StitchSession.Cell per cell, `highlight` is the
## step to do next and `hint` where to count it from (either may be null).
func show_progress(states: PackedByteArray, highlight: StitchStep, hint: PositionHint = null) -> void:
	_states = states
	_highlight = highlight
	_hint = hint
	queue_redraw()


func show_preview() -> void:
	_states = PackedByteArray()
	_highlight = null
	_hint = null
	queue_redraw()


## Zooms so the whole pattern fits, centred.
func fit_to_view() -> void:
	if pattern == null or pattern.width == 0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var available := size - Vector2.ONE * FIT_MARGIN * 2.0
	_cell_px = clampf(minf(available.x / pattern.width, available.y / pattern.height),
			MIN_CELL_PX, MAX_CELL_PX)
	_origin = (size - Vector2(pattern.width, pattern.height) * _cell_px) / 2.0
	queue_redraw()


## Zooms in to at least `min_cell_px` (if the screen allows) and centres `step`.
func focus_step(step: StitchStep, min_cell_px: float) -> void:
	if not _is_laid_out():
		_pending_focus = [step, min_cell_px]
		return
	_cell_px = clampf(maxf(_cell_px, min_cell_px), MIN_CELL_PX, MAX_CELL_PX)
	var rect := _step_rect(step)
	_origin += size / 2.0 - rect.get_center()
	queue_redraw()


## Pans so the cells of `step` (and the reference stitch of `hint`) are on screen, if they
## aren't already.
func ensure_visible(step: StitchStep, hint: PositionHint = null) -> void:
	if not _is_laid_out():
		return
	var rect := _step_rect(step)
	if hint != null:
		rect = rect.merge(_cell_rect(hint.reference.x, hint.reference.y))
	var view := Rect2(Vector2.ZERO, size).grow(-FIT_MARGIN)
	if view.encloses(rect):
		return
	_origin += view.get_center() - rect.get_center()
	queue_redraw()


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
	if pattern == null or _texture == null:
		return
	var grid_rect := Rect2(_origin, Vector2(pattern.width, pattern.height) * _cell_px)
	var progress := not _states.is_empty()
	if progress:
		draw_rect(grid_rect, FABRIC_COLOR)
	else:
		draw_texture_rect(_texture, grid_rect, false)
	_draw_grid(grid_rect)
	if progress:
		_draw_stitches()
		if _highlight != null:
			_draw_highlight(_highlight)
		if _hint != null:
			_draw_hint(_hint)
	draw_rect(grid_rect, GRID_MAJOR_COLOR, false, 2.0)


func _draw_grid(grid_rect: Rect2) -> void:
	if _cell_px < MIN_MAJOR_GRID_PX:
		return
	var minor := PackedVector2Array()
	var major := PackedVector2Array()
	for x in range(1, pattern.width):
		var px := _origin.x + x * _cell_px
		if x % 10 == 0:
			major.append_array([Vector2(px, grid_rect.position.y), Vector2(px, grid_rect.end.y)])
		elif _cell_px >= MIN_MINOR_GRID_PX:
			minor.append_array([Vector2(px, grid_rect.position.y), Vector2(px, grid_rect.end.y)])
	for y in range(1, pattern.height):
		var py := _origin.y + y * _cell_px
		if y % 10 == 0:
			major.append_array([Vector2(grid_rect.position.x, py), Vector2(grid_rect.end.x, py)])
		elif _cell_px >= MIN_MINOR_GRID_PX:
			minor.append_array([Vector2(grid_rect.position.x, py), Vector2(grid_rect.end.x, py)])
	if not minor.is_empty():
		draw_multiline(minor, GRID_COLOR)
	if not major.is_empty():
		draw_multiline(major, GRID_MAJOR_COLOR)


## Stitched legs of the visible cells, batched per thread colour.
func _draw_stitches() -> void:
	# Plain Arrays: they are references, so appending through `lines[thread]` works in place.
	var lines: Array[Array] = []
	for thread in _colors.size():
		lines.append([])
	var visible := _visible_cells()
	for y in range(visible.position.y, visible.end.y):
		for x in range(visible.position.x, visible.end.x):
			var state := _states[y * pattern.width + x]
			if state == StitchSession.Cell.NONE:
				continue
			var leg_rect := _leg_rect(x, y)
			var thread_lines: Array = lines[pattern.get_cell(x, y)]
			thread_lines.append_array(_bottom_leg(leg_rect))
			if state == StitchSession.Cell.FULL:
				thread_lines.append_array(_top_leg(leg_rect))
	var width := maxf(1.0, _cell_px * LEG_WIDTH)
	for thread in lines.size():
		if not lines[thread].is_empty():
			draw_multiline(PackedVector2Array(lines[thread]), _colors[thread], width)


## The current step: a frame around its cells, the legs still to stitch as ghosts, and a dot
## where the needle comes up first.
func _draw_highlight(step: StitchStep) -> void:
	var rect := _step_rect(step).grow(maxf(2.0, _cell_px * 0.1))
	draw_rect(rect, Color(HIGHLIGHT_COLOR, 0.15))
	draw_rect(rect, HIGHLIGHT_COLOR, false, 3.0)
	var ghost := PackedVector2Array()
	for x in step.cells:
		var leg_rect := _leg_rect(x, step.row)
		if step.kind != StitchStep.Kind.BACK:
			ghost.append_array(_bottom_leg(leg_rect))
		if step.kind != StitchStep.Kind.HALF:
			ghost.append_array(_top_leg(leg_rect))
	draw_multiline(ghost, Color(_colors[step.thread], GHOST_ALPHA),
			maxf(1.0, _cell_px * LEG_WIDTH * GHOST_WIDTH))
	# Legs come up through the bottom holes: "/" at the bottom left, "\" at the bottom right.
	var first := _leg_rect(step.cells[0], step.row)
	var start := first.position + Vector2(0.0, first.size.y)
	if step.kind == StitchStep.Kind.BACK:
		start = first.end
	draw_circle(start, maxf(3.0, _cell_px * 0.15), HIGHLIGHT_COLOR)


## A ring around the reference stitch, a line along the counting path ending in an arrow, and
## the count in every cell of the path.
func _draw_hint(hint: PositionHint) -> void:
	var reference := _cell_rect(hint.reference.x, hint.reference.y)
	var line_width := maxf(2.0, _cell_px * 0.08)
	draw_arc(reference.get_center(), _cell_px * 0.62, 0.0, TAU, 32, HINT_COLOR, line_width)
	if hint.path.is_empty():
		return
	var points := PackedVector2Array([reference.get_center()])
	var corner := hint.corner()
	if corner != hint.reference and corner != hint.target:
		points.append(_cell_rect(corner.x, corner.y).get_center())
	var target := _cell_rect(hint.target.x, hint.target.y).get_center()
	points.append(target)
	draw_polyline(points, Color(HINT_COLOR, 0.6), line_width)
	var direction := (points[-1] - points[-2]).normalized()
	var tip := target - direction * _cell_px * 0.1
	var side := direction.orthogonal() * _cell_px * 0.2
	var back := tip - direction * _cell_px * 0.3
	draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), HINT_COLOR)
	if hint.path.size() < 2:
		return  # Directly adjacent: nothing to count.
	var font := get_theme_default_font()
	var font_size := int(_cell_px * 0.42)
	for i in hint.path.size():
		var center := _cell_rect(hint.path[i].x, hint.path[i].y).get_center()
		if _cell_px < MIN_NUMBER_CELL_PX:
			draw_circle(center, maxf(1.5, _cell_px * 0.12), HINT_COLOR)
			continue
		var text := str(i + 1)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := center + Vector2(-text_size.x / 2.0, -text_size.y / 2.0 + font.get_ascent(font_size))
		draw_circle(center, _cell_px * 0.3, Color(FABRIC_COLOR, 0.85))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, HINT_COLOR)


func _cell_rect(x: int, y: int) -> Rect2:
	return Rect2(_origin + Vector2(x, y) * _cell_px, Vector2.ONE * _cell_px)


func _leg_rect(x: int, y: int) -> Rect2:
	return _cell_rect(x, y).grow(-_cell_px * LEG_INSET)


func _step_rect(step: StitchStep) -> Rect2:
	var rect := _cell_rect(step.cells[0], step.row)
	for x in step.cells:
		rect = rect.merge(_cell_rect(x, step.row))
	return rect


## Bottom leg "/": from the bottom left to the top right.
func _bottom_leg(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)])


## Top leg "\": from the top left to the bottom right.
func _top_leg(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, rect.end])


## Cells at least partly on screen.
func _visible_cells() -> Rect2i:
	var from := (-_origin / _cell_px).floor()
	var to := ((size - _origin) / _cell_px).ceil()
	var start := Vector2i(clampi(int(from.x), 0, pattern.width), clampi(int(from.y), 0, pattern.height))
	var end := Vector2i(clampi(int(to.x), 0, pattern.width), clampi(int(to.y), 0, pattern.height))
	return Rect2i(start, end - start)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_tap_possible = _touches.size() == 1
			_tap_start = event.position
		else:
			_touches.erase(event.index)
			if (_tap_possible and _touches.is_empty() and not event.canceled
					and event.position.distance_to(_tap_start) <= TAP_SLOP):
				tapped.emit()
			_tap_possible = false
		accept_event()
	elif event is InputEventScreenDrag:
		var before: Dictionary = _touches.duplicate()
		_touches[event.index] = event.position
		if event.position.distance_to(_tap_start) > TAP_SLOP:
			_tap_possible = false
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
		accept_event()
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
		accept_event()
	elif event is InputEventPanGesture:
		_pan(-event.delta * 8.0)
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, WHEEL_ZOOM)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / WHEEL_ZOOM)
			accept_event()


func _pan(delta: Vector2) -> void:
	_origin += delta
	queue_redraw()


## Zooms by `factor`, keeping the point under `focus` in place.
func _zoom_at(focus: Vector2, factor: float) -> void:
	var new_cell_px := clampf(_cell_px * factor, MIN_CELL_PX, MAX_CELL_PX)
	_origin = focus - (focus - _origin) * (new_cell_px / _cell_px)
	_cell_px = new_cell_px
	queue_redraw()

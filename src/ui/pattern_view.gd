class_name PatternView
extends Control
## Shows a pattern as a grid of coloured cells. Drag to pan; pinch, trackpad or mouse wheel
## to zoom.

## Colour of empty cells (light Aida fabric).
const FABRIC_COLOR := Color8(245, 241, 230)
const GRID_COLOR := Color(0.0, 0.0, 0.0, 0.12)
## Every 10th line is darker, as on printed charts.
const GRID_MAJOR_COLOR := Color(0.0, 0.0, 0.0, 0.4)
const MIN_CELL_PX := 2.0
const MAX_CELL_PX := 96.0
## Below these cell sizes the grid lines are left out.
const MIN_MINOR_GRID_PX := 6.0
const MIN_MAJOR_GRID_PX := 3.0
const FIT_MARGIN := 16.0
const WHEEL_ZOOM := 1.15

var pattern: Pattern

var _texture: ImageTexture
## Size of one cell on screen, in pixels.
var _cell_px := 10.0
## Top left corner of the grid, in local coordinates.
var _origin := Vector2.ZERO
var _touches := {}  # touch index -> position


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	resized.connect(fit_to_view)


## Shows `p`; with `keep_view` the zoom and position stay as they are (same pattern size).
func show_pattern(p: Pattern, palette: FlossPalette, keep_view := false) -> void:
	pattern = p
	var image := Image.create_empty(p.width, p.height, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = []
	for code in p.thread_codes:
		colors.append(palette.find_code(code).color)
	for y in p.height:
		for x in p.width:
			var index := p.get_cell(x, y)
			image.set_pixel(x, y, FABRIC_COLOR if index == Pattern.EMPTY else colors[index])
	_texture = ImageTexture.create_from_image(image)
	if not keep_view:
		fit_to_view()
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


func _draw() -> void:
	if pattern == null or _texture == null:
		return
	var grid_rect := Rect2(_origin, Vector2(pattern.width, pattern.height) * _cell_px)
	draw_texture_rect(_texture, grid_rect, false)
	if _cell_px >= MIN_MAJOR_GRID_PX:
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
	draw_rect(grid_rect, GRID_MAJOR_COLOR, false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		var before: Dictionary = _touches.duplicate()
		_touches[event.index] = event.position
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

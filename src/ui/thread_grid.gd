class_name ThreadGrid
extends Control
## Thread colours to choose from, as skeins standing on stairs: the loop points up, and the
## square is lengthened by the loop's length so the loop of the skein in front covers only that
## part and a whole square stays visible. As a grid, rows hold similar hues (greys first), each
## from light on the left to dark on the right; as a list, the same order one below the other
## with number and name. Optionally only the project's colours, moved together. Switching glides
## every skein to its new place and fades out the ones that go. Tapping a colour chooses it: the
## others shrink away and it gets its number and name; tapping again brings them back.

## A colour was chosen, or null when the choice was taken back.
signal chosen(floss: FlossColor)

const ACROSS := 34.0
const GAP := 6.0
## How much of the loop shows above its square, and the extra length of the square below.
const LOOP_SHOWN := SkeinSwatch.PICKER_LOOP - 2.0
## Colours this close to grey (Lab chroma) go in the grey rows.
const GREY_CHROMA := 7.0
## Hue where the rows start (Lab, degrees): just before red, so pinks and reds stay together.
const HUE_START := -30.0
const VANISH_SECONDS := 0.4
## Switching between grid and list, or the project filter.
const MORPH_SECONDS := 0.45
const LABEL_FONT_SIZE := 18
const LIST_FONT_SIZE := 16
const TEXT_GAP := 12.0
const TAP_SLOP := 12.0

var _colors: Array[FlossColor] = []
var _project_codes := PackedStringArray()
var _list := false
var _project_only := false
## The shown colours in layout order (in the grid with gaps after the greys).
var _cells: Array[FlossColor] = []
var _columns := 1
var _selected: FlossColor
## 0: all colours shown, 1: only the chosen one.
var _vanish := 0.0:
	set(value):
		_vanish = value
		_redraw()
var _tween: Tween
## Gliding between two layouts, 0..1: each colour's rect and opacity before and after, by
## code, and how far the list's text shows.
var _morph := 1.0:
	set(value):
		_morph = value
		_redraw()
var _morph_tween: Tween
var _from := {}
var _to := {}
var _from_alpha := {}
var _to_alpha := {}
var _text_from := 0.0
var _text_to := 0.0
var _press_position := Vector2.ZERO
## Draws numbers and names on top, without the skein tint shader.
var _label_layer := Control.new()


func _init() -> void:
	material = SkeinSwatch.shared_material()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_layout.bind(false))
	_label_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_layer.draw.connect(_draw_labels)
	add_child(_label_layer)


func _notification(what: int) -> void:
	# Only what is scrolled into view is drawn, so draw again when scrolling.
	if what == NOTIFICATION_PARENTED and get_parent() is ScrollContainer:
		(get_parent() as ScrollContainer).get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:
			_redraw())


## All colours to choose from, and the codes of the project's own.
func set_colors(colors: Array[FlossColor], project_codes: PackedStringArray) -> void:
	_colors = colors
	_project_codes = project_codes
	_selected = null
	_vanish = 0.0
	_from.clear()
	_to.clear()
	_layout(false)


## Grid or list, all colours or only the project's; the skeins glide there.
func set_view(list: bool, project_only: bool) -> void:
	_list = list
	_project_only = project_only
	if _selected != null and project_only and not _project_codes.has(_selected.code):
		_unselect()
	_layout(true)


## Chooses the colour with `code` as if tapped (for screenshots).
func choose(code: String) -> void:
	for floss in _cells:
		if floss != null and floss.code == code:
			_select(floss)
			return


func is_animating() -> bool:
	return (_tween != null and _tween.is_running()) or (_morph_tween != null and _morph_tween.is_running())


func selected_color() -> FlossColor:
	return _selected


## Rect of the chosen colour (or of everything) in the new layout, for scrolling it into view.
func selected_rect() -> Rect2:
	return _to.get(_selected.code, Rect2()) if _selected != null else Rect2(Vector2.ZERO, size)


## Greys first, from light to dark, then the colours by hue; cut into rows of `columns`, each
## row from light to dark. With `gap_after_greys` the grey rows end with gaps (null) rather
## than mixing in colours; without, everything moves together.
static func arrange(colors: Array[FlossColor], columns: int, gap_after_greys := true) -> Array[FlossColor]:
	var greys: Array[FlossColor] = []
	var hued: Array[FlossColor] = []
	for floss in colors:
		if Vector2(floss.lab.y, floss.lab.z).length() < GREY_CHROMA:
			greys.append(floss)
		else:
			hued.append(floss)
	greys.sort_custom(func(a: FlossColor, b: FlossColor) -> bool: return a.lab.x > b.lab.x)
	hued.sort_custom(func(a: FlossColor, b: FlossColor) -> bool: return _hue(a) < _hue(b))
	var result: Array[FlossColor] = []
	for group: Array[FlossColor] in [greys, hued]:
		for start in range(0, group.size(), columns):
			var row := group.slice(start, start + columns)
			row.sort_custom(func(a: FlossColor, b: FlossColor) -> bool: return a.lab.x > b.lab.x)
			result.append_array(row)
		if gap_after_greys and group == greys and result.size() % columns != 0:
			for i in columns - result.size() % columns:
				result.append(null)
	return result


static func _hue(floss: FlossColor) -> float:
	return fposmod(rad_to_deg(atan2(floss.lab.z, floss.lab.y)) - HUE_START, 360.0)


## Places the shown colours; with `animate` every colour glides from where it is now, colours
## that go fade out where they are, and new ones fade in at their place.
func _layout(animate: bool) -> void:
	var shown: Array[FlossColor] = []
	for floss in _colors:
		if not _project_only or _project_codes.has(floss.code):
			shown.append(floss)
	var grid_columns := maxi(1, int((size.x + GAP) / (ACROSS + GAP)))
	# The project's few colours sit together, without a gap after the greys.
	_cells = arrange(shown, grid_columns, not _project_only)
	if _list:
		_cells = _cells.filter(func(floss: FlossColor) -> bool: return floss != null)
	_columns = 1 if _list else grid_columns
	var targets := {}
	for i in _cells.size():
		if _cells[i] != null:
			targets[_cells[i].code] = _cell_rect(i)
	var progress := _ease(_morph)
	for floss in _colors:
		var code := floss.code
		var visible := targets.has(code)
		var now_alpha := 0.0
		var now_rect: Rect2 = targets.get(code, Rect2())
		if _to.has(code):
			now_alpha = lerpf(_from_alpha[code], _to_alpha[code], progress)
			now_rect = _lerp_rect(_from[code], _to[code], progress)
		var target: Rect2 = targets.get(code, now_rect)
		if not animate or now_alpha <= 0.0:
			now_rect = target
		if not animate:
			now_alpha = 1.0 if visible else 0.0
		_from[code] = now_rect
		_to[code] = target
		_from_alpha[code] = now_alpha
		_to_alpha[code] = 1.0 if visible else 0.0
	_text_from = lerpf(_text_from, _text_to, progress) if animate else (1.0 if _list else 0.0)
	_text_to = 1.0 if _list else 0.0
	var rows := ceili(float(_cells.size()) / _columns)
	custom_minimum_size.y = maxf(0.0, (rows - 1) * _row_pitch() + _template_size().y)
	if _morph_tween != null:
		_morph_tween.kill()
	if animate:
		_morph = 0.0
		_morph_tween = create_tween()
		_morph_tween.tween_property(self, "_morph", 1.0, MORPH_SECONDS)
	else:
		_morph = 1.0


func _row_pitch() -> float:
	return SkeinSwatch.SQUARE + LOOP_SHOWN


func _template_size() -> Vector2:
	return SkeinSwatch.template_size(SkeinSwatch.PICKER_LOOP, LOOP_SHOWN, ACROSS, true)


func _template() -> ImageTexture:
	return SkeinSwatch.template(SkeinSwatch.PICKER_LOOP, LOOP_SHOWN, ACROSS, true)


## The whole picture of layout cell `index`: loop on top, lengthened square below. The grid is
## centred; the list sits at the left with its text beside it.
func _cell_rect(index: int) -> Rect2:
	var pitch := ACROSS + GAP
	var left := GAP if _list else (size.x - (_columns * pitch - GAP)) / 2.0
	return Rect2(left + (index % _columns) * pitch, (index / _columns) * _row_pitch(), ACROSS, _template_size().y)


## The square of a skein drawn in `rect`, the part that stays visible in front of the stairs.
func _square_of(rect: Rect2) -> Rect2:
	var loop_top := rect.size.y - LOOP_SHOWN - SkeinSwatch.SQUARE
	return Rect2(rect.position.x + (ACROSS - SkeinSwatch.SQUARE) / 2.0, rect.position.y + loop_top,
			SkeinSwatch.SQUARE, SkeinSwatch.SQUARE)


## Ease in and out, as the cubic tweens elsewhere.
static func _ease(t: float) -> float:
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0


static func _lerp_rect(a: Rect2, b: Rect2, t: float) -> Rect2:
	return Rect2(a.position.lerp(b.position, t), a.size.lerp(b.size, t))


## Every colour as it shows right now: [floss, rect, opacity, scale], back rows first so each
## stands in front of the one above. Only those in the scrolled-to part.
func _shown_now() -> Array:
	var progress := _ease(_morph)
	var view := Rect2(Vector2.ZERO, size)
	var scroll := get_parent() as ScrollContainer
	if scroll != null:
		view = Rect2(0.0, scroll.scroll_vertical, size.x, scroll.size.y).grow(_template_size().y)
	var chosen_center: Vector2 = _to.get(_selected.code, Rect2()).get_center() if _selected != null else Vector2.ZERO
	var far := maxf(size.length(), 1.0)
	var result := []
	for floss in _colors:
		if not _to.has(floss.code):
			continue
		var alpha := lerpf(_from_alpha[floss.code], _to_alpha[floss.code], progress)
		var rect := _lerp_rect(_from[floss.code], _to[floss.code], progress)
		if alpha <= 0.0 or not view.intersects(rect):
			continue
		var scale := 1.0
		if _selected != null and floss != _selected:
			var delay := 0.5 * minf(rect.get_center().distance_to(chosen_center) / far * 2.0, 1.0)
			scale = 1.0 - smoothstep(delay, delay + 0.5, _vanish)
			if scale <= 0.0:
				continue
		result.append([floss, rect, alpha, scale])
	result.sort_custom(func(a: Array, b: Array) -> bool: return a[1].position.y < b[1].position.y)
	return result


func _draw() -> void:
	var texture := _template()
	for shown: Array in _shown_now():
		var rect: Rect2 = shown[1]
		draw_set_transform(rect.get_center(), 0.0, Vector2.ONE * shown[3])
		draw_texture_rect(texture, Rect2(-rect.size / 2.0, rect.size), false, Color(shown[0].color, shown[2]))
	draw_set_transform(Vector2.ZERO)


## In the list every colour's number and name; in the grid only the chosen one's, on the side
## with more room.
func _draw_labels() -> void:
	var font := get_theme_default_font()
	var text := lerpf(_text_from, _text_to, _ease(_morph))
	for shown: Array in _shown_now():
		var floss: FlossColor = shown[0]
		var square := _square_of(shown[1])
		var alpha: float = shown[2] * shown[3]
		if text > 0.0:
			var baseline := square.get_center().y + (font.get_ascent(LIST_FONT_SIZE) - font.get_descent(LIST_FONT_SIZE)) / 2.0
			var color := Color(1, 1, 1, alpha * text)
			_label_layer.draw_string(font, Vector2(square.end.x + TEXT_GAP, baseline), floss.code,
					HORIZONTAL_ALIGNMENT_LEFT, -1, LIST_FONT_SIZE, color)
			_label_layer.draw_string(font, Vector2(square.end.x + TEXT_GAP + 64.0, baseline), floss.name,
					HORIZONTAL_ALIGNMENT_LEFT, -1, LIST_FONT_SIZE, color)
		if floss == _selected and text < 1.0:
			_draw_choice_label(floss, square, smoothstep(0.5, 1.0, _vanish) * (1.0 - text))


func _draw_choice_label(floss: FlossColor, square: Rect2, alpha: float) -> void:
	var font := get_theme_default_font()
	var lines := ["DMC " + floss.code, floss.name]
	var width := 0.0
	for line: String in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x)
	var right_side := square.end.x + TEXT_GAP + width <= size.x
	var x := square.end.x + TEXT_GAP if right_side else square.position.x - TEXT_GAP - width
	var line_height := font.get_height(LABEL_FONT_SIZE)
	var y := square.get_center().y - line_height + font.get_ascent(LABEL_FONT_SIZE)
	for i in lines.size():
		_label_layer.draw_string(font, Vector2(x, y + i * line_height), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1,
				LABEL_FONT_SIZE, Color(1, 1, 1, alpha))


func _redraw() -> void:
	queue_redraw()
	_label_layer.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_press_position = event.position
		return
	if event.position.distance_to(_press_position) > TAP_SLOP:
		return
	accept_event()
	if _selected != null:
		_unselect()
		return
	var index := _hit(event.position)
	if index >= 0:
		_select(_cells[index])


func _select(floss: FlossColor) -> void:
	_selected = floss
	_set_vanish(1.0)
	chosen.emit(floss)


func _unselect() -> void:
	_set_vanish(0.0, func() -> void:
		_selected = null
		_redraw())
	chosen.emit(null)


## The layout cell whose visible square (or list row) is under `point`, or -1.
func _hit(point: Vector2) -> int:
	if _cells.is_empty():
		return -1
	var pitch := ACROSS + GAP
	var loop_top := _template_size().y - LOOP_SHOWN - SkeinSwatch.SQUARE
	var row := maxi(0, floori((point.y - loop_top) / _row_pitch()))
	var column := 0
	if not _list:
		column = floori((point.x - (size.x - (_columns * pitch - GAP)) / 2.0) / pitch)
	var index := row * _columns + column
	if column < 0 or column >= _columns or index >= _cells.size() or _cells[index] == null:
		return -1
	return index


func _set_vanish(target: float, done := Callable()) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_vanish", target, VANISH_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if done.is_valid():
		_tween.tween_callback(done)

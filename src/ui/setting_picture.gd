class_name SettingPicture
extends Control
## A picture for a setting in the symbol window's look (StepSymbols): white lines, dots, arrows and
## crosses, symbols rather than pictures of the real thing. In a ChoiceCards button it sits over
## the label; standing alone (`framed`) it draws its own see-through card and follows the
## setting's current value (`corner`, `limit_on`, `style`).

enum Kind { TOUCH, MOUSE_KEYBOARD, DANISH, ENGLISH, CORNER, THREAD_LIMIT, STITCH_GUIDE }

## Height of a picture standing alone under its setting.
const FRAMED_HEIGHT := 112.0
const PADDING := 10.0
const THREAD_WIDTH := 4.0
const DIM := Color(1.0, 1.0, 1.0, 0.4)
const CARD_COLOR := Color(1.0, 1.0, 1.0, 0.07)
const NUMBER_FONT_SIZE := 13

var kind: Kind
## Draws a see-through rounded card behind the picture.
var framed := false
## CORNER: index into the settings' start corners (0 automatic, then top left, top right, bottom
## left, bottom right).
var corner := 0:
	set(value):
		corner = value
		queue_redraw()
## THREAD_LIMIT: whether a long way on the back is cut (a new thread) or stays one thread.
var limit_on := false:
	set(value):
		limit_on = value
		queue_redraw()
## STITCH_GUIDE: the style whose needle holes it shows.
var style := StitchStyle.new():
	set(value):
		style = value
		queue_redraw()


func _init(p_kind: Kind, p_framed := false) -> void:
	kind = p_kind
	framed = p_framed
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if framed:
		custom_minimum_size.y = FRAMED_HEIGHT


func _draw() -> void:
	if framed:
		var card := StyleBoxFlat.new()
		card.bg_color = CARD_COLOR
		card.set_corner_radius_all(12)
		draw_style_box(card, Rect2(Vector2.ZERO, size))
	var box := Rect2(Vector2.ZERO, size).grow(-PADDING)
	match kind:
		Kind.TOUCH:
			_draw_touch(box)
		Kind.MOUSE_KEYBOARD:
			_draw_mouse_keyboard(box)
		Kind.DANISH:
			_draw_danish(box)
		Kind.ENGLISH:
			_draw_english(box)
		Kind.CORNER:
			_draw_corner(box)
		Kind.THREAD_LIMIT:
			_draw_thread_limit(box)
		Kind.STITCH_GUIDE:
			_draw_stitch_guide(box)


## A rounded outline.
func _outline(rect: Rect2, radius: float, ink: Color, width := 2.5) -> void:
	var line := StyleBoxFlat.new()
	line.draw_center = false
	line.border_color = ink
	line.set_border_width_all(int(width))
	line.set_corner_radius_all(int(radius))
	line.anti_aliasing = true
	draw_style_box(line, rect)


## A phone with a finger tapping it, ripples round the tap.
func _draw_touch(box: Rect2) -> void:
	var height := box.size.y
	var phone := Rect2(box.get_center() - Vector2(height * 0.28, height * 0.5), Vector2(height * 0.56, height))
	_outline(phone, 9.0, Color.WHITE)
	draw_line(Vector2(phone.get_center().x - 7.0, phone.position.y + 7.0),
			Vector2(phone.get_center().x + 7.0, phone.position.y + 7.0), Color.WHITE, 2.0)
	var tap := phone.get_center() + Vector2(0.0, -4.0)
	for radius in [11.0, 18.0]:
		draw_arc(tap, radius, PI * 0.9, PI * 2.1, 24, DIM, 2.0)
	draw_circle(tap, 5.0, Color.WHITE)
	# The finger from the bottom right, its tip on the tap.
	var tip := tap + Vector2(4.0, 10.0)
	draw_line(tip, tip + Vector2(24.0, 44.0), Color.WHITE, 13.0)
	draw_circle(tip, 6.5, Color.WHITE)


## A keyboard and beside it a mouse.
func _draw_mouse_keyboard(box: Rect2) -> void:
	var height := box.size.y * 0.9
	var keyboard := Vector2(height * 1.25, height * 0.5)
	var mouse := Vector2(height * 0.38, height * 0.6)
	var gap := height * 0.18
	var left := box.get_center().x - (keyboard.x + gap + mouse.x) / 2.0
	var base := box.get_center().y + height * 0.32
	var board := Rect2(left, base - keyboard.y, keyboard.x, keyboard.y)
	_outline(board, 6.0, Color.WHITE)
	var key := (keyboard.x - 12.0) / 7.0
	for row in 2:
		for column in 7:
			draw_rect(Rect2(board.position + Vector2(6.0 + column * key + 1.5, 6.0 + row * (key + 1.0)),
					Vector2(key - 3.0, key - 3.0)), DIM)
	draw_rect(Rect2(board.position + Vector2(6.0 + key * 1.5, 6.0 + 2.0 * (key + 1.0)),
			Vector2(key * 4.0, key - 3.0)), DIM)
	var body := Rect2(board.end.x + gap, base - mouse.y, mouse.x, mouse.y)
	_outline(body, mouse.x / 2.0, Color.WHITE)
	var split := body.position.y + body.size.y * 0.42
	draw_line(Vector2(body.position.x + 2.0, split), Vector2(body.end.x - 2.0, split), Color.WHITE, 2.0)
	draw_line(Vector2(body.get_center().x, body.position.y + 2.0), Vector2(body.get_center().x, split),
			Color.WHITE, 2.0)
	# The cable.
	var plug := Vector2(body.get_center().x, body.position.y)
	draw_polyline(PackedVector2Array([plug, plug + Vector2(0.0, -8.0), plug + Vector2(-10.0, -16.0)]),
			Color.WHITE, 2.0)


## Cells `count` wide from `origin`, each `side` long: a faint square with its holes.
func _cells(origin: Vector2, side: float, count: int) -> void:
	for i in count:
		draw_rect(Rect2(origin + Vector2(i * side, 0.0), Vector2.ONE * side), Color(DIM, 0.25), false, 1.5)
	for i in count + 1:
		for y in [0.0, side]:
			draw_circle(origin + Vector2(i * side, y), 2.0, DIM)


## One leg of the cell at `origin`: "/" (bottom left to top right) or "\".
func _leg(origin: Vector2, side: float, slash: bool, ink: Color) -> void:
	var inset := side * 0.14
	if slash:
		draw_line(origin + Vector2(inset, side - inset), origin + Vector2(side - inset, inset), ink, THREAD_WIDTH)
	else:
		draw_line(origin + Vector2(inset, inset), origin + Vector2(side - inset, side - inset), ink, THREAD_WIDTH)


## Danish: two half stitches on their own, an arrow, the same two finished as crosses.
func _draw_danish(box: Rect2) -> void:
	var side := minf(box.size.y * 0.5, box.size.x / 5.9)
	var arrow := side * 1.1
	var gap := side * 0.25
	var left := box.get_center().x - (side * 4.0 + gap * 2.0 + arrow) / 2.0
	var top := box.get_center().y - side / 2.0
	_cells(Vector2(left, top), side, 2)
	for i in 2:
		_leg(Vector2(left + i * side, top), side, true, Color.WHITE)
	var arrow_from := Vector2(left + side * 2.0 + gap, top + side / 2.0)
	StepSymbols.draw_arrow(self, arrow_from, arrow_from + Vector2(arrow, 0.0), Color.WHITE)
	var crosses := Vector2(arrow_from.x + arrow + gap, top)
	_cells(crosses, side, 2)
	for i in 2:
		_leg(crosses + Vector2(i * side, 0.0), side, true, Color.WHITE)
		_leg(crosses + Vector2(i * side, 0.0), side, false, Color.WHITE)


## English: two crosses, each finished at once.
func _draw_english(box: Rect2) -> void:
	var side := minf(box.size.y * 0.5, box.size.x / 5.9)
	var origin := box.get_center() - Vector2(side, side / 2.0)
	_cells(origin, side, 2)
	for i in 2:
		_leg(origin + Vector2(i * side, 0.0), side, true, Color.WHITE)
		_leg(origin + Vector2(i * side, 0.0), side, false, Color.WHITE)


## The start corner: a field of holes, a ring at the corner where stitching begins and an arrow
## along each row in stitching order, fading row by row, with an arrow down (or up) the start side.
## Automatic: a ring with its first row in every corner.
func _draw_corner(box: Rect2) -> void:
	var columns := 6
	var rows := 3
	var side := minf(box.size.x / (columns + 1.5), box.size.y / (rows + 0.3))
	var origin := box.get_center() - Vector2(columns, rows) * side / 2.0
	for x in columns + 1:
		for y in rows + 1:
			draw_circle(origin + Vector2(x, y) * side, 2.0, DIM)
	if corner == 0:
		for top: bool in [true, false]:
			for left: bool in [true, false]:
				_corner_rows(origin, side, columns, rows, top, left, 1, 0.75)
		return
	var from_top: bool = corner <= 2
	var from_left: bool = corner % 2 == 1
	_corner_rows(origin, side, columns, rows, from_top, from_left, rows, 1.0)
	var x := origin.x + (-0.6 if from_left else columns + 0.6) * side
	var first := origin.y + (0.5 if from_top else rows - 0.5) * side
	var last := origin.y + (rows - 0.5 if from_top else 0.5) * side
	StepSymbols.draw_arrow(self, Vector2(x, first), Vector2(x, last), DIM, 2.0)


## `count` rows from the corner (`top`, `left`): a ring on the corner hole, then arrows along the
## rows, each fainter than the one before; automatic draws only half a row per corner.
func _corner_rows(origin: Vector2, side: float, columns: int, rows: int, top: bool, left: bool,
		count: int, alpha: float) -> void:
	var corner_hole := origin + Vector2(0.0 if left else columns, 0.0 if top else rows) * side
	draw_arc(corner_hole, 6.0, 0.0, TAU, 20, Color(1, 1, 1, alpha), 2.0)
	var length := columns * side * (1.0 if count > 1 else 0.42)
	for i in count:
		var y := origin.y + (i + 0.5 if top else rows - i - 0.5) * side
		var start_x := origin.x + (0.25 * side if left else columns * side - 0.25 * side)
		var end_x := start_x + (length - 0.5 * side) * (1.0 if left else -1.0)
		StepSymbols.draw_arrow(self, Vector2(start_x, y), Vector2(end_x, y),
				Color(1, 1, 1, alpha * pow(0.65, i)), 3.0)


## The back of the fabric: two groups of stitches and the thread running on between them. With
## the limit on, scissors cut it, so the long way becomes a new thread.
func _draw_thread_limit(box: Rect2) -> void:
	var y := box.get_center().y + 8.0
	var width := minf(box.size.x, box.size.y * 3.4)
	var left := box.get_center().x - width / 2.0
	var bars: Array[float] = []
	for share in [0.04, 0.13, 0.22, 0.78, 0.87, 0.96]:
		bars.append(left + width * share)
	var cut := box.get_center().x
	if limit_on:
		draw_line(Vector2(bars[2], y), Vector2(cut - 5.0, y + 3.0), Color.WHITE, 2.5)
		draw_line(Vector2(cut + 5.0, y + 3.0), Vector2(bars[3], y), Color.WHITE, 2.5)
		# Open, the thread between the blades halfway along them.
		var direction := Vector2(-0.45, 1.0).normalized()
		StepSymbols.draw_scissors(self, Vector2(cut, y) - direction * 17.0, direction, deg_to_rad(24.0),
				Color.WHITE, 1.3)
	else:
		draw_line(Vector2(bars[2], y), Vector2(bars[3], y), Color.WHITE, 2.5)
	for x in bars:
		var bar := Rect2(x - 2.5, y - 14.0, 5.0, 28.0)
		draw_rect(bar, Color.WHITE)


## A Danish pass over two cells as the style works it: every leg an arrow from the hole the needle
## comes up through (a dot, numbered in stitching order) to where it goes down; dashed, the thread
## on the back from one leg to the next.
func _draw_stitch_guide(box: Rect2) -> void:
	var side := minf(box.size.y * 0.82, box.size.x / 2.6)
	var origin := box.get_center() - Vector2(side, side / 2.0)
	_cells(origin, side, 2)
	var holes := style.needle_holes(StitchStep.new(StitchStep.Kind.HALF, 0, 0, PackedInt32Array([0, 1]), 1))
	holes.append_array(style.needle_holes(StitchStep.new(StitchStep.Kind.BACK, 0, 0, PackedInt32Array([1, 0]), -1)))
	var font := get_theme_default_font()
	for leg in holes.size() / 2:
		var up := origin + holes[leg * 2] * side
		var down := origin + holes[leg * 2 + 1] * side
		var direction := (down - up).normalized()
		if leg > 0:
			draw_dashed_line(origin + holes[leg * 2 - 1] * side, up, DIM, 2.0, 5.0)
		StepSymbols.draw_arrow(self, up + direction * 6.0, down - direction * 6.0, Color.WHITE, 3.0)
		draw_circle(up, 4.0, Color.WHITE)
		var number_at := up.lerp(down, 0.3) + direction.orthogonal() * 11.0
		StepSymbols.draw_label(self, font, number_at, str(leg + 1), NUMBER_FONT_SIZE, Color.WHITE)

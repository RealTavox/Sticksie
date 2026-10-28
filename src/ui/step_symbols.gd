class_name StepSymbols
extends Control
## A small square window at the bottom of the stitching screen that shows the current step as
## symbols, one card after the other, each with a short animation that repeats: securing the old
## thread (the needle goes under the stitches on the back, then scissors cut it), threading a new
## one (the doubled thread goes through the needle's eye), counting holes (an arrow per direction
## with its count) and the stitch itself (one leg from the hole where the needle comes up to
## where it goes down, and how many). Symbols, not pictures: only white lines, dots and numbers
## on the overlays' see-through grey.

enum Card { SECURE, THREAD, COUNT, STITCH }

const SIDE := 120.0
const PADDING := 12.0
## How long each card plays, in seconds, and how long it fades in and out.
const CARD_SECONDS := {Card.SECURE: 3.6, Card.THREAD: 2.8, Card.COUNT: 2.4, Card.STITCH: 2.4}
const FADE_SECONDS := 0.25
## Animations redraw at most this often, to spare the battery.
const FRAMES_PER_SECOND := 30.0
const LINE_WIDTH := 2.5
const FONT_SIZE := 22
## Drawn behind white symbols that cross others, so they stay apart.
const GAP_COLOR := Color(0.13, 0.12, 0.11)
const NEEDLE_TEXTURE_PX := 512

var _cards: Array[Card] = []
var _card := 0
var _time := 0.0
var _since_draw := 0.0
## Held at a point of the current card's animation (0..1, for screenshots), or -1.
var _held := -1.0
## COUNT: the counting legs in holes, in order.
var _legs: Array[Vector2i] = []
## STITCH: per leg its up and down hole within the cell (0 or 1 on each axis), and how many
## stitches the step has.
var _stitch_legs: Array[PackedVector2Array] = []
var _stitch_count := 0
var _needle: ImageTexture
## Where the needle's eye is along it, from the head end, as a share of its length.
var _eye_at := 0.0
var _background := OverlayWindow.panel_style()


func _init() -> void:
	custom_minimum_size = Vector2.ONE * SIDE
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_needle = ButtonIcons.needle_icon(NEEDLE_TEXTURE_PX, true)
	_eye_at = (((ButtonIcons.NEEDLE_EYE_FROM.x + ButtonIcons.NEEDLE_EYE_TO.x) / 2.0 - ButtonIcons.NEEDLE_LEFT)
			/ (ButtonIcons.NEEDLE_RIGHT - ButtonIcons.NEEDLE_LEFT))


## The cards for `step` (null: the colour is finished): securing when the old thread ends here
## (`secure`), threading when a new one starts, counting when holes have to be counted, and the
## stitch. Starts again with the first card.
func show_step(step: StitchStep, hint: PositionHint, style: StitchStyle, new_thread: bool,
		secure: bool) -> void:
	_cards.clear()
	if secure:
		_cards.append(Card.SECURE)
	if step != null:
		if new_thread:
			_cards.append(Card.THREAD)
		if hint != null and hint.holes.size() >= 2:
			_cards.append(Card.COUNT)
			_legs.clear()
			for leg in [hint.bend() - hint.start, hint.needle - hint.bend()]:
				if leg != Vector2i.ZERO:
					_legs.append(leg)
		_cards.append(Card.STITCH)
		_stitch_legs.clear()
		var holes := style.needle_holes(step)
		var cell := Vector2(step.cells[0], step.row)
		for i in (2 if step.kind == StitchStep.Kind.CROSS else 1):
			_stitch_legs.append(PackedVector2Array([holes[i * 2] - cell, holes[i * 2 + 1] - cell]))
		_stitch_count = step.cells.size()
	_card = 0
	_time = 0.0
	queue_redraw()


func has_cards() -> bool:
	return not _cards.is_empty()


## Stops at `card` (if shown), `progress` (0..1) into its animation, for screenshots.
func hold(card: Card, progress: float) -> void:
	if _cards.has(card):
		_card = _cards.find(card)
		_held = progress
		queue_redraw()


func _process(delta: float) -> void:
	if _cards.is_empty() or _held >= 0.0 or not is_visible_in_tree():
		return
	_time += delta
	var seconds: float = CARD_SECONDS[_cards[_card]]
	if _time >= seconds:
		_time = fmod(_time, seconds)
		_card = (_card + 1) % _cards.size()
	_since_draw += delta
	if _since_draw >= 1.0 / FRAMES_PER_SECOND:
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	draw_style_box(_background, Rect2(Vector2.ZERO, size))
	if _cards.is_empty():
		return
	var card := _cards[_card]
	var seconds: float = CARD_SECONDS[card]
	var t := _held if _held >= 0.0 else _time / seconds
	var alpha := 1.0
	if _held < 0.0:
		alpha = clampf(minf(t * seconds, (1.0 - t) * seconds) / FADE_SECONDS, 0.0, 1.0)
	var ink := Color(1.0, 1.0, 1.0, alpha)
	var box := Rect2(Vector2.ONE * PADDING, size - Vector2.ONE * PADDING * 2.0)
	if _cards.size() > 1:
		_draw_card_dots()
		box.size.y -= 6.0
	match card:
		Card.SECURE:
			_draw_secure(box, t, ink)
		Card.THREAD:
			_draw_thread(box, t, ink)
		Card.COUNT:
			_draw_count(box, t, ink)
		Card.STITCH:
			_draw_stitch(box, t, ink)


## Which card is showing, as dots at the bottom.
func _draw_card_dots() -> void:
	const GAP := 9.0
	var left := size.x / 2.0 - GAP * (_cards.size() - 1) / 2.0
	for i in _cards.size():
		draw_circle(Vector2(left + GAP * i, size.y - 7.0), 2.0, Color(1, 1, 1, 1.0 if i == _card else 0.35))


## Securing the thread on the back: the needle slides under three stitches pulling the thread
## after it, then scissors snip the rest off and it falls away.
func _draw_secure(box: Rect2, t: float, ink: Color) -> void:
	var y := box.get_center().y
	var length := box.size.x * 1.3
	var head_x := lerpf(box.position.x - length, size.x, _ease(clampf(t / 0.5, 0.0, 1.0)))
	var eye_x := head_x + _eye_at * length
	var cut_x := box.position.x + box.size.x * 0.68
	# The thread from the left to the needle's eye; once cut, the end beyond the cut falls.
	var fall := clampf((t - 0.76) / 0.16, 0.0, 1.0)
	var thread_end := minf(eye_x, size.x)
	if fall > 0.0:
		thread_end = cut_x - 1.0
		var piece := Color(ink, ink.a * (1.0 - fall))
		var drop := Vector2(0.0, fall * 26.0)
		draw_line(Vector2(cut_x + 1.0, y) + drop, Vector2(size.x, y + fall * 6.0) + drop, piece, LINE_WIDTH)
	if thread_end > 0.0:
		draw_line(Vector2(0.0, y), Vector2(thread_end, y), ink, LINE_WIDTH)
	if t < 0.5:
		_draw_needle(Vector2(head_x, y), 0.0, length, ink)
	# The stitches on the back, on top of needle and thread.
	for share in [0.14, 0.32, 0.5]:
		var bar := Rect2(box.position.x + box.size.x * share - 2.5, y - 15.0, 5.0, 30.0)
		draw_rect(bar.grow(2.5), Color(GAP_COLOR, ink.a))
		draw_rect(bar, ink)
	if t >= 0.54 and t < 0.94:
		var open := 1.0 - clampf((t - 0.66) / 0.1, 0.0, 1.0)
		var shown := clampf((t - 0.54) / 0.08, 0.0, 1.0) * clampf((0.94 - t) / 0.08, 0.0, 1.0)
		_draw_scissors(Vector2(cut_x + 13.0, y), deg_to_rad(lerpf(3.0, 26.0, open)), Color(ink, ink.a * shown))


## Scissors pointing left with their pivot at `pivot`, the blades `angle` apart from the middle.
func _draw_scissors(pivot: Vector2, angle: float, ink: Color) -> void:
	for side in [-1.0, 1.0]:
		var blade := Vector2.LEFT.rotated(side * angle)
		var normal := blade.orthogonal()
		draw_colored_polygon(PackedVector2Array([pivot + normal * 3.0, pivot - normal * 3.0,
				pivot + blade * 26.0]), ink)
		draw_line(pivot, pivot - blade * 9.0, ink, 3.0)
		draw_arc(pivot - blade * 14.0, 5.0, 0.0, TAU, 20, ink, LINE_WIDTH)
	draw_circle(pivot, 2.0, Color(GAP_COLOR, ink.a))


## Threading: the needle stands with its eye at the top, the doubled thread comes in from the left
## and its fold goes through the eye.
func _draw_thread(box: Rect2, t: float, ink: Color) -> void:
	var length := box.size.y * 2.4
	var head := Vector2(box.position.x + box.size.x * 0.66, box.position.y + 2.0)
	var eye := head + Vector2(0.0, _eye_at * length)
	var tip := lerpf(box.position.x - 10.0, head.x + 26.0, _ease(clampf((t - 0.1) / 0.55, 0.0, 1.0)))
	# Two strands joined at the fold; the needle drawn after them hides them except in the eye.
	for strand in [-3.0, 3.0]:
		draw_line(Vector2(0.0, eye.y + strand), Vector2(tip, eye.y + strand), ink, 2.0)
	draw_arc(Vector2(tip, eye.y), 3.0, -PI / 2.0, PI / 2.0, 12, ink, 2.0)
	_draw_needle(head, PI / 2.0, length, ink)


## The needle from the user's drawing, flat white, its head end at `head`, pointing along `angle`.
func _draw_needle(head: Vector2, angle: float, length: float, ink: Color) -> void:
	var thickness := length * _needle.get_height() / _needle.get_width()
	draw_set_transform(head, angle)
	draw_texture_rect(_needle, Rect2(0.0, -thickness / 2.0, length, thickness), false, ink)
	draw_set_transform(Vector2.ZERO)


## Counting: from a ring (where counting starts) an arrow per direction grows over its holes, then
## its count shows beside it.
func _draw_count(box: Rect2, t: float, ink: Color) -> void:
	var points: Array[Vector2] = [Vector2.ZERO]
	for i in _legs.size():
		points.append(points[-1] + Vector2(_legs[i].sign()) * (1.0 if i == 0 else 0.7))
	var low := points[0]
	var high := points[0]
	for point in points:
		low = low.min(point)
		high = high.max(point)
	# Room round the arrows for the numbers.
	var inner := box.grow(-16.0)
	var extent := high - low
	var scale := INF
	if extent.x > 0.0:
		scale = inner.size.x / extent.x
	if extent.y > 0.0:
		scale = minf(scale, inner.size.y / extent.y)
	var offset := inner.get_center() - (low + high) / 2.0 * scale
	var font := get_theme_default_font()
	var start := points[0] * scale + offset
	draw_arc(start, 6.0, 0.0, TAU, 20, ink, 2.0)
	var span := 0.3 if _legs.size() > 1 else 0.45
	for i in _legs.size():
		var grown := clampf((t - i * span) / span, 0.0, 1.0)
		if grown <= 0.0:
			continue
		var from := points[i] * scale + offset
		var to := points[i + 1] * scale + offset
		# A dot per hole, at most four: a symbol, not the real count.
		var dots := mini(maxi(absi(_legs[i].x), absi(_legs[i].y)), 4)
		for hole in dots:
			var share := float(hole + 1) / dots
			if grown >= share:
				draw_circle(from.lerp(to, share), 3.5, ink)
		_draw_arrow(from, from.lerp(to, grown), ink)
		var shown := clampf((t - (i + 1) * span) / 0.1, 0.0, 1.0)
		if shown <= 0.0:
			continue
		# Beside the leg, on the side away from the other leg.
		var direction := Vector2(_legs[i].sign())
		var side := direction.orthogonal()
		if _legs.size() > 1:
			side = -Vector2(_legs[1].sign()) if i == 0 else Vector2(_legs[0].sign())
		elif direction.y == 0.0:
			side = Vector2.UP
		else:
			side = Vector2.LEFT
		var text := str(maxi(absi(_legs[i].x), absi(_legs[i].y)))
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var center := from.lerp(to, 0.5) + side * (6.0 + (text_size.x if side.y == 0.0 else text_size.y) / 2.0)
		_draw_text(font, center, text, FONT_SIZE, Color(ink, ink.a * shown))


## One stitch in a cell: the needle comes up at a dot, the leg grows to where it goes down (a
## ring); a cross shows its second leg after the first. Beside it how many stitches.
func _draw_stitch(box: Rect2, t: float, ink: Color) -> void:
	var side := minf(box.size.x * 0.56, box.size.y)
	var cell := Rect2(box.position + Vector2(0.0, (box.size.y - side) / 2.0), Vector2.ONE * side)
	var dim := Color(ink, ink.a * 0.4)
	draw_rect(cell, dim, false, 2.0)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		draw_circle(cell.position + corner * side, 2.5, dim)
	var starts := [0.05] if _stitch_legs.size() == 1 else [0.05, 0.42]
	for i in _stitch_legs.size():
		if t < starts[i]:
			continue
		var up := cell.position + _stitch_legs[i][0] * side
		var down := cell.position + _stitch_legs[i][1] * side
		draw_circle(up, 5.0, ink)
		var grown := clampf((t - starts[i] - 0.08) / 0.27, 0.0, 1.0)
		var direction := (down - up).normalized()
		if grown > 0.0:
			_draw_arrow(up + direction * 7.0, (up + direction * 7.0).lerp(down - direction * 9.0, grown), ink)
		if grown >= 1.0:
			draw_arc(down, 6.0, 0.0, TAU, 20, ink, 2.0)
	var right := Rect2(cell.end.x, box.position.y, box.end.x - cell.end.x, box.size.y)
	_draw_text(get_theme_default_font(), right.get_center(), "%d×" % _stitch_count, FONT_SIZE + 2, ink)


func _draw_arrow(from: Vector2, to: Vector2, ink: Color) -> void:
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var direction := (to - from) / length
	var head := minf(9.0, length)
	draw_line(from, to - direction * head * 0.7, ink, LINE_WIDTH)
	var side := direction.orthogonal() * head * 0.6
	draw_colored_polygon(PackedVector2Array([to, to - direction * head + side, to - direction * head - side]), ink)


func _draw_text(font: Font, center: Vector2, text: String, font_size: int, ink: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## Slow at both ends.
static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

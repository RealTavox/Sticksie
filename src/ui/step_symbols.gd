class_name StepSymbols
extends Control
## A small window at the bottom of the stitching screen that shows the current step as symbols,
## a square card per part of the step side by side, each with a short animation that plays once,
## one card after the other from left to right, then stays: securing the old thread (the needle
## goes under the stitches on the back, then scissors cut it), threading a new one (the doubled
## thread goes through the needle's eye), counting holes (an arrow per direction with its
## count), starting the thread with the loop (down through a hole bringing the loop, up through
## the next, through the loop and back down) and the stitch itself (one leg from the hole where the needle comes up to
## where it goes down, and how many). Symbols, not pictures: only white lines, dots and numbers
## on the overlays' see-through grey.

enum Card { SECURE, THREAD, ANCHOR, COUNT, STITCH }

## Height of the window; each card is a square of CARD with PADDING round it.
const SIDE := 120.0
const PADDING := 12.0
const CARD := SIDE - PADDING * 2.0
## How long each card's animation takes, in seconds.
const CARD_SECONDS := {Card.SECURE: 3.0, Card.THREAD: 2.0, Card.ANCHOR: 3.4, Card.COUNT: 1.6,
		Card.STITCH: 1.6}
## Cards still waiting for their turn are faded to this.
const WAITING_ALPHA := 0.35
## Animations redraw at most this often, to spare the battery.
const FRAMES_PER_SECOND := 30.0
const LINE_WIDTH := 2.5
const FONT_SIZE := 22
## Drawn behind white symbols that cross others, so they stay apart.
const GAP_COLOR := Color(0.13, 0.12, 0.11)
const NEEDLE_TEXTURE_PX := 512

var _cards: Array[Card] = []
var _views: Array[CardView] = []
## Seconds since the cards began; they have all played once after the sum of their times.
var _time := 0.0
var _since_draw := 0.0
var _held := false
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
	_needle = ButtonIcons.needle_icon(NEEDLE_TEXTURE_PX, true)
	_eye_at = (((ButtonIcons.NEEDLE_EYE_FROM.x + ButtonIcons.NEEDLE_EYE_TO.x) / 2.0 - ButtonIcons.NEEDLE_LEFT)
			/ (ButtonIcons.NEEDLE_RIGHT - ButtonIcons.NEEDLE_LEFT))


## The cards for `step` (null: the colour is finished), in this order: securing when the old
## thread ends here (`secure`), threading when a new one starts, counting when holes have to be
## counted, starting the new thread with the loop, and the stitch. The window grows to hold them, and they play from the
## start.
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
		if new_thread:
			_cards.append(Card.ANCHOR)
		_cards.append(Card.STITCH)
		_stitch_legs.clear()
		var holes := style.needle_holes(step)
		var cell := Vector2(step.cells[0], step.row)
		for i in (2 if step.kind == StitchStep.Kind.CROSS else 1):
			_stitch_legs.append(PackedVector2Array([holes[i * 2] - cell, holes[i * 2 + 1] - cell]))
		_stitch_count = step.cells.size()
	for view in _views:
		view.queue_free()
	_views.clear()
	for i in _cards.size():
		var view := CardView.new(self, _cards[i])
		view.position = Vector2(PADDING / 2.0 + i * (CARD + PADDING), PADDING / 2.0)
		view.size = Vector2.ONE * (CARD + PADDING)
		add_child(view)
		_views.append(view)
	custom_minimum_size = Vector2(PADDING + maxi(_cards.size(), 1) * (CARD + PADDING), SIDE)
	size = custom_minimum_size
	_time = 0.0
	_held = false
	_update_views()
	queue_redraw()


func has_cards() -> bool:
	return not _cards.is_empty()


## Stops at `card` (if shown), `progress` (0..1) into its animation, for screenshots.
func hold(card: Card, progress: float) -> void:
	var index := _cards.find(card)
	if index < 0:
		return
	_time = _start(index) + progress * CARD_SECONDS[card]
	_held = true
	_update_views()


## When the card at `index` begins, in seconds.
func _start(index: int) -> float:
	var seconds := 0.0
	for i in index:
		seconds += CARD_SECONDS[_cards[i]]
	return seconds


func _process(delta: float) -> void:
	var total := _start(_cards.size())
	if _cards.is_empty() or _held or _time >= total or not is_visible_in_tree():
		return
	_time = minf(_time + delta, total)
	_since_draw += delta
	if _since_draw >= 1.0 / FRAMES_PER_SECOND or _time >= total:
		_since_draw = 0.0
		_update_views()


## Hands each card its point in its animation: waiting, playing or done.
func _update_views() -> void:
	for i in _views.size():
		var start := _start(i)
		var view := _views[i]
		view.waiting = _time < start
		view.t = clampf((_time - start) / CARD_SECONDS[_cards[i]], 0.0, 1.0)
		view.queue_redraw()


func _draw() -> void:
	draw_style_box(_background, Rect2(Vector2.ZERO, size))
	for i in range(1, _cards.size()):
		var x := PADDING / 2.0 + i * (CARD + PADDING)
		draw_line(Vector2(x, PADDING * 1.5), Vector2(x, size.y - PADDING * 1.5), Color(1, 1, 1, 0.15), 1.0)


## One card, cut off at its edges, so a needle sliding in doesn't cross the next card.
class CardView:
	extends Control

	var symbols: StepSymbols
	var card: Card
	## How far its animation has got, 0..1, and whether it is still waiting for its turn.
	var t := 0.0
	var waiting := true


	func _init(p_symbols: StepSymbols, p_card: Card) -> void:
		symbols = p_symbols
		card = p_card
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


	func _draw() -> void:
		var ink := Color(1.0, 1.0, 1.0, WAITING_ALPHA if waiting else 1.0)
		var box := Rect2(Vector2.ONE * PADDING / 2.0, Vector2.ONE * CARD)
		match card:
			Card.SECURE:
				_draw_secure(box, t, ink)
			Card.THREAD:
				_draw_thread(box, t, ink)
			Card.ANCHOR:
				_draw_anchor(box, t, ink)
			Card.COUNT:
				_draw_count(box, t, ink)
			Card.STITCH:
				_draw_stitch(box, t, ink)


	## Securing the thread on the back: the needle slides under three stitches pulling the thread
	## after it, then scissors snip the rest off and it falls away; the scissors stay.
	func _draw_secure(box: Rect2, t: float, ink: Color) -> void:
		var y := box.get_center().y
		var length := box.size.x * 1.3
		var head_x := lerpf(box.position.x - length, size.x, _ease(clampf(t / 0.5, 0.0, 1.0)))
		var eye_x := head_x + symbols._eye_at * length
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
		if t >= 0.54:
			var open := 1.0 - clampf((t - 0.66) / 0.1, 0.0, 1.0)
			var shown := clampf((t - 0.54) / 0.08, 0.0, 1.0)
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
		var eye := head + Vector2(0.0, symbols._eye_at * length)
		var tip := lerpf(box.position.x - 10.0, head.x + 26.0, _ease(clampf((t - 0.1) / 0.55, 0.0, 1.0)))
		# Two strands joined at the fold; the needle drawn after them hides them except in the eye.
		for strand in [-3.0, 3.0]:
			draw_line(Vector2(0.0, eye.y + strand), Vector2(tip, eye.y + strand), ink, 2.0)
		draw_arc(Vector2(tip, eye.y), 3.0, -PI / 2.0, PI / 2.0, 12, ink, 2.0)
		_draw_needle(head, PI / 2.0, length, ink)


	## The needle from the user's drawing, flat white, its head end at `head`, pointing along `angle`.
	func _draw_needle(head: Vector2, angle: float, length: float, ink: Color) -> void:
		var thickness := length * symbols._needle.get_height() / symbols._needle.get_width()
		draw_set_transform(head, angle)
		draw_texture_rect(symbols._needle, Rect2(0.0, -thickness / 2.0, length, thickness), false, ink)
		draw_set_transform(Vector2.ZERO)


	## Counting: from a ring (where counting starts) an arrow per direction grows over its holes, then
	## its count shows beside it.
	func _draw_count(box: Rect2, t: float, ink: Color) -> void:
		var points: Array[Vector2] = [Vector2.ZERO]
		for i in symbols._legs.size():
			points.append(points[-1] + Vector2(symbols._legs[i].sign()) * (1.0 if i == 0 else 0.7))
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
		var span := 0.3 if symbols._legs.size() > 1 else 0.45
		for i in symbols._legs.size():
			var grown := clampf((t - i * span) / span, 0.0, 1.0)
			if grown <= 0.0:
				continue
			var from := points[i] * scale + offset
			var to := points[i + 1] * scale + offset
			# A dot per hole, at most four: a symbol, not the real count.
			var dots := mini(maxi(absi(symbols._legs[i].x), absi(symbols._legs[i].y)), 4)
			for hole in dots:
				var share := float(hole + 1) / dots
				if grown >= share:
					draw_circle(from.lerp(to, share), 3.5, ink)
			_draw_arrow(from, from.lerp(to, grown), ink)
			var shown := clampf((t - (i + 1) * span) / 0.1, 0.0, 1.0)
			if shown <= 0.0:
				continue
			# Beside the leg, on the side away from the other leg.
			var direction := Vector2(symbols._legs[i].sign())
			var side := direction.orthogonal()
			if symbols._legs.size() > 1:
				side = -Vector2(symbols._legs[1].sign()) if i == 0 else Vector2(symbols._legs[0].sign())
			elif direction.y == 0.0:
				side = Vector2.UP
			else:
				side = Vector2.LEFT
			var text := str(maxi(absi(symbols._legs[i].x), absi(symbols._legs[i].y)))
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
		var starts := [0.05] if symbols._stitch_legs.size() == 1 else [0.05, 0.42]
		for i in symbols._stitch_legs.size():
			if t < starts[i]:
				continue
			var up := cell.position + symbols._stitch_legs[i][0] * side
			var down := cell.position + symbols._stitch_legs[i][1] * side
			draw_circle(up, 5.0, ink)
			var grown := clampf((t - starts[i] - 0.08) / 0.27, 0.0, 1.0)
			var direction := (down - up).normalized()
			if grown > 0.0:
				_draw_arrow(up + direction * 7.0, (up + direction * 7.0).lerp(down - direction * 9.0, grown), ink)
			if grown >= 1.0:
				draw_arc(down, 6.0, 0.0, TAU, 20, ink, 2.0)
		var right := Rect2(cell.end.x, box.position.y, box.end.x - cell.end.x, box.size.y)
		_draw_text(get_theme_default_font(), right.get_center(), "%d×" % symbols._stitch_count, FONT_SIZE + 2, ink)


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

	## Starting with the loop (the doubled thread), seen from the side: the needle goes down
	## through a hole and brings the loop after it, which stays on top, an arch with both strands
	## going straight down into the hole; the needle comes up through the next hole, goes through
	## the loop and back down through that same hole, and the loop pulls tight.
	func _draw_anchor(box: Rect2, t: float, ink: Color) -> void:
		var y := box.get_center().y + 10.0
		var a := box.position.x + box.size.x * 0.3
		var b := box.position.x + box.size.x * 0.7
		var dim := Color(ink, ink.a * 0.5)
		for span in [[0.0, a - 4.0], [a + 4.0, b - 4.0], [b + 4.0, size.x]]:
			draw_line(Vector2(span[0], y), Vector2(span[1], y), dim, 5.0)
		var length := 110.0
		var below := y + 9.0
		var hole := Vector2(a, y)
		var tight := _ease(clampf((t - 0.8) / 0.2, 0.0, 1.0))
		var radius := lerpf(7.0, 3.0, tight)
		# Where the top of the loop's arch rests once it has come.
		var arch_top := lerpf(y - 28.0, y - 10.0, tight)
		# Where the strands go down to: the hole, or the eye while that is still above it.
		var strands_to := hole
		var point: Vector2
		var angle := PI / 2.0
		var threads: Array[PackedVector2Array] = []
		var through := false
		if t < 0.3:
			# Down through the first hole and on out of sight; the loop follows the eye.
			point = Vector2(a, lerpf(box.position.y - 6.0, y + 110.0, _ease(clampf(t / 0.28, 0.0, 1.0))))
			var eye := _eye(point, angle, length)
			arch_top = minf(eye.y - 30.0, arch_top)
			if eye.y < y:
				strands_to = eye
			else:
				threads.append(PackedVector2Array([hole, eye]))
		elif t < 0.55:
			# Under the fabric to the next hole and up through it.
			angle = -PI / 2.0
			point = Vector2(b, lerpf(y + 44.0, y - 30.0, _ease(clampf((t - 0.3) / 0.22, 0.0, 1.0))))
			threads.append(PackedVector2Array([hole, Vector2(a, below), Vector2(b, below),
					_eye(point, angle, length)]))
		elif t < 0.78:
			# Through the loop, between its strands.
			angle = PI
			through = true
			point = Vector2(lerpf(b - 6.0, a - 26.0, _ease(clampf((t - 0.55) / 0.2, 0.0, 1.0))),
					lerpf(arch_top + radius, y, 0.45))
			threads.append(PackedVector2Array([hole, Vector2(a, below), Vector2(b, below), Vector2(b, y),
					_eye(point, angle, length)]))
		else:
			# Back down through the same hole; the loop closes round the thread.
			point = Vector2(b, lerpf(y - 30.0, y + 30.0, _ease(clampf((t - 0.78) / 0.2, 0.0, 1.0))))
			threads.append(PackedVector2Array([hole, Vector2(a, below), Vector2(b, below)]))
			threads.append(PackedVector2Array([Vector2(a, lerpf(arch_top + radius, y, 0.45)),
					Vector2(b, y - 3.0), _eye(point, angle, length)]))
		var center := Vector2(a, arch_top + radius)
		# Both strands straight down from the arch, closing in only just above the hole (or eye).
		var left := PackedVector2Array([center + Vector2(-radius, 0.0)])
		var right := PackedVector2Array([center + Vector2(radius, 0.0)])
		if strands_to.y - center.y > 8.0:
			left.append(Vector2(a - radius, strands_to.y - 5.0))
			right.append(Vector2(a + radius, strands_to.y - 5.0))
		left.append(strands_to + Vector2(-1.5, 0.0))
		right.append(strands_to + Vector2(1.5, 0.0))
		draw_arc(center, radius, PI, TAU, 16, ink, 2.0)
		draw_polyline(right, ink, 2.0)
		if not through:
			draw_polyline(left, ink, 2.0)
		for thread in threads:
			draw_polyline(thread, ink, 2.0)
		_draw_needle(point - Vector2.from_angle(angle) * length, angle, length, ink)
		if through:
			# The near strand over the needle, the far one under it.
			draw_polyline(left, Color(GAP_COLOR, ink.a), 5.0)
			draw_polyline(left, ink, 2.0)


	## Where the eye is of a needle `length` long whose point is at `point`, pointing along `angle`.
	func _eye(point: Vector2, angle: float, length: float) -> Vector2:
		return point - Vector2.from_angle(angle) * length * (1.0 - symbols._eye_at)

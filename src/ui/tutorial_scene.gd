class_name TutorialScene
extends Control
## One animated picture of the introduction (Tutorial), in the look of the symbol window and the
## loading hint: white lines, dots, arrows and crosses on the overlays' see-through grey, the thing
## happening right now in the block orange. It plays, stands a moment, fades and plays again.
## Everything is drawn in a canvas of WIDTH × HEIGHT, scaled to fit. `touch` shows a finger and
## gestures, otherwise a mouse pointer and keys.

enum Kind { OPEN, BUTTONS, COLOR, STITCH, SYMBOLS, COUNT, NEXT, MOVE, BACK_SIDE, OVERVIEW, NEW_THREAD, DONE }

const WIDTH := 360.0
const HEIGHT := 200.0
const MAX_SCALE := 1.5
## How long each picture plays; SYMBOLS is the real symbol window, which keeps its own time.
const SECONDS := {Kind.OPEN: 4.5, Kind.BUTTONS: 4.5, Kind.COLOR: 5.0, Kind.STITCH: 5.0, Kind.SYMBOLS: 1.0,
		Kind.COUNT: 4.0, Kind.NEXT: 5.0, Kind.MOVE: 5.0, Kind.BACK_SIDE: 5.0, Kind.OVERVIEW: 4.5,
		Kind.NEW_THREAD: 5.0, Kind.DONE: 3.0}
## The finished picture stands this long, and it fades out and in this fast around the loop.
const HOLD_SECONDS := 1.4
const FADE_SECONDS := 0.2
## Redraws at most this often, to spare the battery.
const FRAMES_PER_SECOND := 30.0
const ACCENT := LoadingHint.NEW_LEG_COLOR
const DIM := Color(1.0, 1.0, 1.0, 0.4)
const FAINT := Color(1.0, 1.0, 1.0, 0.14)
const GAP_COLOR := StepSymbols.GAP_COLOR
const LINE_WIDTH := 2.5
const FONT_SIZE := 16
## How long a tap's ring spreads, as a share of the picture's time.
const RIPPLE := 0.09
## The motif: a little heart, a pixel or cross per X.
const MOTIF := [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
const MOTIF_SIZE := Vector2i(7, 6)
## Tips of the mouse pointer's shape, from its point.
const POINTER_SHAPE := [Vector2(0, 0), Vector2(0, 22), Vector2(6, 17), Vector2(10, 26), Vector2(14, 24),
		Vector2(10, 15), Vector2(17, 15)]

var kind := Kind.OPEN
var touch := true
## STITCH: crosses one by one instead of the Danish passes.
var english := false

var _time := 0.0
var _since_draw := 0.0
var _held := false
var _base := Transform2D.IDENTITY
var _needle := ButtonIcons.needle_icon(StepSymbols.NEEDLE_TEXTURE_PX, true)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Plays picture `p_kind` from the start.
func play(p_kind: Kind, p_touch: bool, p_english := false) -> void:
	kind = p_kind
	touch = p_touch
	english = p_english
	replay()


## Plays the picture from the start again.
func replay() -> void:
	_time = 0.0
	_held = false
	modulate.a = 0.0
	queue_redraw()


## Stops `progress` (0..1) into the picture, for screenshots.
func hold(progress: float) -> void:
	_time = progress * SECONDS[kind]
	_held = true
	modulate.a = 1.0
	queue_redraw()


## How far the picture has got, 0..1.
func progress() -> float:
	return minf(_time / SECONDS[kind], 1.0)


func _process(delta: float) -> void:
	if _held or kind == Kind.SYMBOLS or not is_visible_in_tree():
		return
	var total: float = SECONDS[kind] + HOLD_SECONDS
	_time += delta
	if _time >= total:
		_time = 0.0
	modulate.a = clampf(minf(_time, total - _time) / FADE_SECONDS, 0.0, 1.0)
	_since_draw += delta
	if _since_draw >= 1.0 / FRAMES_PER_SECOND:
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	var scale_factor := minf(minf(size.x / WIDTH, size.y / HEIGHT), MAX_SCALE)
	_base = Transform2D(0.0, Vector2.ONE * scale_factor, 0.0,
			(size - Vector2(WIDTH, HEIGHT) * scale_factor) / 2.0)
	draw_set_transform_matrix(_base)
	var t := progress()
	match kind:
		Kind.OPEN:
			_draw_open(t)
		Kind.BUTTONS:
			_draw_buttons(t)
		Kind.COLOR:
			_draw_color(t)
		Kind.STITCH:
			_draw_stitch(t)
		Kind.COUNT:
			_draw_count(t)
		Kind.NEXT:
			_draw_next(t)
		Kind.MOVE:
			_draw_move(t)
		Kind.BACK_SIDE:
			_draw_back_side(t)
		Kind.OVERVIEW:
			_draw_overview(t)
		Kind.NEW_THREAD:
			_draw_new_thread(t)
		Kind.DONE:
			_draw_done(t)


# ---- The pictures ----


## An image of pixels, then every pixel becomes a cross.
func _draw_open(t: float) -> void:
	var side := 20.0
	var top := 40.0
	var rows := _part(t, 0.0, 0.22) * MOTIF_SIZE.y
	for cell in _motif_cells():
		if rows > cell.y:
			draw_rect(Rect2(Vector2(16.0, top) + Vector2(cell) * side, Vector2.ONE * side).grow(-1.0), Color.WHITE)
	var arrow := _part(t, 0.24, 0.34)
	if arrow > 0.0:
		StepSymbols.draw_arrow(self, Vector2(162.0, 100.0), Vector2(162.0, 100.0).lerp(Vector2(198.0, 100.0), arrow),
				Color.WHITE)
	_motif(Vector2(204.0, top), side, _part(t, 0.36, 1.0))


## A phone with the three round buttons: each tap opens its panel.
func _draw_buttons(t: float) -> void:
	var phone := Rect2(115.0, 2.0, 130.0, 196.0)
	_outline(phone, 14.0, Color.WHITE)
	var spots := [phone.position + Vector2(24.0, 24.0), Vector2(phone.position.x + 24.0, phone.end.y - 24.0),
			phone.end - Vector2(24.0, 24.0)]
	var icons := [ButtonIcons.Icon.MENU, ButtonIcons.Icon.SPOOL, ButtonIcons.Icon.TEXT]
	var panels := [Rect2(phone.position + Vector2(8.0, 48.0), Vector2(114.0, 34.0)),
			Rect2(phone.position.x + 8.0, phone.end.y - 88.0, 54.0, 40.0),
			Rect2(phone.end.x - 62.0, phone.end.y - 88.0, 54.0, 40.0)]
	var pointer: Vector2 = phone.get_center()
	var ripple := 0.0
	for i in 3:
		var start := i / 3.0
		pointer = pointer.lerp(spots[i], _smooth(_part(t, start, start + 0.14)))
		ripple = maxf(ripple, _ripple(t, [start + 0.16]))
		var open := _part(t, start + 0.18, start + 0.26)
		if open > 0.0:
			var panel: Rect2 = panels[i]
			_fill(panel, 6.0, Color(1.0, 1.0, 1.0, 0.2 * open))
			for line in 2:
				var y := panel.position.y + panel.size.y * (0.35 + line * 0.3)
				draw_line(Vector2(panel.position.x + 8.0, y), Vector2(panel.end.x - 8.0, y),
						Color(1.0, 1.0, 1.0, 0.6 * open), 2.0)
		draw_circle(spots[i], 16.0, ACCENT if open > 0.0 else GAP_COLOR)
		draw_arc(spots[i], 16.0, 0.0, TAU, 32, Color.WHITE, 2.0, true)
		_icon(icons[i], spots[i], 24.0, Color.WHITE)
	_pointer(pointer, ripple, _part(t, 0.0, 0.05) - _part(t, 0.94, 1.0))


## The colour list and the motif: a colour is picked by its needle, then by tapping the motif.
func _draw_color(t: float) -> void:
	var inks := [Color.WHITE, Color(1.0, 1.0, 1.0, 0.65), Color(1.0, 1.0, 1.0, 0.38)]
	var chosen := -1
	if t >= 0.72:
		chosen = 2
	elif t >= 0.28 and t < 0.5:
		chosen = 1
	var buttons: Array[Rect2] = []
	for i in 3:
		var y := 36.0 + i * 46.0
		draw_rect(Rect2(12.0, y + 6.0, 24.0, 24.0), inks[i])
		draw_line(Vector2(46.0, y + 18.0), Vector2(104.0, y + 18.0), DIM, 3.0)
		var button := Rect2(114.0, y, 70.0, 36.0)
		buttons.append(button)
		_fill(button, 6.0, ACCENT if chosen == i else FAINT)
		_needle_at(button.position + Vector2(10.0, 18.0), 0.0, 50.0, Color.WHITE)
	var side := 19.0
	var origin := Vector2(212.0, 42.0)
	for cell in _motif_cells():
		var band := cell.y / 2
		_cross(origin + Vector2(cell) * side, side, 1.0, ACCENT if band == chosen else inks[band])
	var list_spot := buttons[1].get_center() + Vector2(14.0, 6.0)
	var motif_spot := origin + Vector2(3.5, 4.5) * side
	var pointer := Vector2(180.0, 190.0).lerp(list_spot, _smooth(_part(t, 0.03, 0.24)))
	pointer = pointer.lerp(motif_spot, _smooth(_part(t, 0.5, 0.68)))
	_pointer(pointer, _ripple(t, [0.26, 0.7]))


## The current block: the needle comes up at the dot and goes down at the ring, leg by leg, out
## and back (Danish) or cross by cross (English).
func _draw_stitch(t: float) -> void:
	var count := 5
	var side := 48.0
	var origin := Vector2((WIDTH - count * side) / 2.0, 62.0)
	_grid(origin, Vector2i(count, 1), side)
	var legs := _block_legs(count)
	var at := _part(t, 0.04, 0.96) * legs.size()
	for i in legs.size():
		var leg: Array = legs[i]
		var cell := origin + Vector2(leg[0] * side, 0.0)
		var slash: bool = leg[1]
		var up := cell + (Vector2(0.0, side) if slash else Vector2(side, side))
		var down := cell + (Vector2(side, 0.0) if slash else Vector2.ZERO)
		if i < int(at):
			draw_line(up, down, Color.WHITE, 3.5, true)
		elif i == int(at):
			var direction := (down - up).normalized()
			draw_line(up, up.lerp(down, at - i), ACCENT, 3.5, true)
			draw_circle(up, 6.0, Color.WHITE)
			draw_arc(down, 7.0, 0.0, TAU, 24, Color.WHITE, 2.0, true)
			StepSymbols.draw_arrow(self, up + direction * 8.0, up.lerp(down, at - i), ACCENT, 3.5)
	var block := Rect2(origin, Vector2(count * side, side)).grow(9.0)
	_outline(block, 8.0, ACCENT)
	var badge := block.position + Vector2(block.size.x, 0.0)
	draw_circle(badge, 14.0, ACCENT)
	StepSymbols.draw_label(self, get_theme_default_font(), badge, str(count), FONT_SIZE, Color.WHITE)


## The legs of a block in the order they are stitched: [column, whether it is "/"].
func _block_legs(count: int) -> Array:
	var legs := []
	if english:
		for column in count:
			legs.append([column, true])
			legs.append([column, false])
		return legs
	for column in count:
		legs.append([column, true])
	for column in range(count - 1, -1, -1):
		legs.append([column, false])
	return legs


## Finding the next stitch: from the hole the thread last went down through the path counts hole
## by hole, in the view's colours for across and down; there the needle comes up.
func _draw_count(t: float) -> void:
	var side := 32.0
	var origin := Vector2((WIDTH - 7.0 * side) / 2.0, 28.0)
	_grid(origin, Vector2i(7, 5), side)
	for column in 2:
		_cross(origin + Vector2(column * side, 0.0), side, 1.0)
	var holes := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)]
	var font := get_theme_default_font()
	var at := _part(t, 0.1, 0.78) * (holes.size() - 1)
	draw_arc(origin + Vector2(holes[0]) * side, 7.0, 0.0, TAU, 24, Color.WHITE, 2.0, true)
	for i in holes.size() - 1:
		var grown := clampf(at - i, 0.0, 1.0)
		if grown <= 0.0:
			break
		var from: Vector2 = origin + Vector2(holes[i]) * side
		var to: Vector2 = origin + Vector2(holes[i + 1]) * side
		var across: bool = holes[i].y == holes[i + 1].y
		draw_line(from, from.lerp(to, grown), PatternView.HINT_COLOR if across else PatternView.HINT_VERTICAL_COLOR,
				4.0, true)
		if grown >= 1.0:
			draw_circle(to, 4.0, Color.WHITE)
			var number := to + (Vector2(0.0, -14.0) if across else Vector2(-14.0, 0.0))
			StepSymbols.draw_label(self, font, number, str(i + 1), FONT_SIZE - 3, Color.WHITE)
	var leg := _part(t, 0.82, 1.0)
	if leg > 0.0:
		var up := origin + Vector2(5.0, 2.0) * side
		var down := origin + Vector2(6.0, 1.0) * side
		draw_circle(up, 6.0, ACCENT)
		StepSymbols.draw_arrow(self, up, up.lerp(down, leg), ACCENT, 3.5)


## A row: a tap (or Space) does the block, a second one the next, a double tap takes it back.
func _draw_next(t: float) -> void:
	var side := 38.0
	var origin := Vector2((WIDTH - 6.0 * side) / 2.0, 26.0)
	_grid(origin, Vector2i(6, 1), side)
	var first := _part(t, 0.15, 0.25)
	var second := _part(t, 0.45, 0.55) - _part(t, 0.8, 0.9)
	for column in 3:
		_half(origin + Vector2(column * side, 0.0), side, first, Color.WHITE if first >= 1.0 else ACCENT)
		_half(origin + Vector2((column + 3) * side, 0.0), side, second,
				Color.WHITE if t >= 0.55 and t < 0.8 else ACCENT)
	var block := 0 if t < 0.2 else 1
	if t >= 0.5 and t < 0.8:
		block = 2
	if block < 2:
		_outline(Rect2(origin + Vector2(block * 3 * side, 0.0), Vector2(3.0 * side, side)).grow(4.0), 6.0, ACCENT)
	var font := get_theme_default_font()
	var spot := Vector2(WIDTH / 2.0, origin.y + side + 40.0)
	_pointer(spot, _ripple(t, [0.13, 0.43, 0.72, 0.79]))
	if touch:
		var label := ""
		if t >= 0.12 and t < 0.6:
			label = "1×"
		elif t >= 0.71:
			label = "2×"
		StepSymbols.draw_label(self, font, spot + Vector2(0.0, 36.0), label, FONT_SIZE + 4, Color.WHITE)
	else:
		_key(Vector2(92.0, 176.0), "Leertaste", _pulse(t, [0.13, 0.43]))
		_key(Vector2(268.0, 176.0), "Rücktaste", _pulse(t, [0.72]))


## Moving the view: two fingers (or the wheel) zoom, one (or the keys) moves it.
func _draw_move(t: float) -> void:
	var zoom := _smooth(_part(t, 0.08, 0.42))
	var pan := _smooth(_part(t, 0.56, 0.9))
	var side := lerpf(11.0, 19.0, zoom)
	var motif_size := Vector2(MOTIF_SIZE) * side
	var center := Vector2(WIDTH / 2.0, HEIGHT / 2.0) + Vector2(pan * (34.0 if touch else 18.0), 0.0)
	_motif(center - motif_size / 2.0, side, 1.0)
	if touch:
		var alpha := _part(t, 0.0, 0.05)
		if t < 0.48:
			var spread := Vector2(1.0, -0.6) * lerpf(24.0, 76.0, zoom)
			alpha -= _part(t, 0.44, 0.48)
			for finger in [spread, -spread]:
				_pointer(Vector2(WIDTH / 2.0, HEIGHT / 2.0) + finger, 0.0, alpha)
		else:
			alpha = _part(t, 0.48, 0.54) - _part(t, 0.93, 1.0)
			_pointer(Vector2(WIDTH / 2.0, HEIGHT / 2.0 + 40.0) + Vector2(lerpf(-34.0, 34.0, pan), 0.0), 0.0, alpha)
		return
	_mouse(Vector2(44.0, 100.0), t >= 0.08 and t < 0.42 and fmod(t * 20.0, 1.0) < 0.6)
	var keys := {"W": Vector2(316.0, 74.0), "A": Vector2(286.0, 106.0), "S": Vector2(316.0, 106.0),
			"D": Vector2(346.0, 106.0)}
	for letter: String in keys:
		_key(keys[letter], letter, letter == "D" and t >= 0.56 and t < 0.9)


## The fabric turns over: its front with crosses, its back with the thread's little bars.
func _draw_back_side(t: float) -> void:
	var top := 22.0 if touch else 0.0
	var frame := Rect2(100.0, top, 160.0, 156.0)
	_outline(frame, 12.0, Color.WHITE)
	var turns := _smooth(_part(t, 0.2, 0.44)) + _smooth(_part(t, 0.66, 0.9))
	var squeeze := absf(cos(turns * PI))
	var back := turns >= 0.5 and turns < 1.5
	var side := 18.0
	var center := frame.get_center()
	draw_set_transform_matrix(_base * Transform2D(0.0, Vector2(maxf(squeeze, 0.02), 1.0), 0.0, center))
	var origin := -Vector2(MOTIF_SIZE) * side / 2.0
	for cell in _motif_cells():
		var at := origin + Vector2(cell) * side
		if back:
			for x in [side * 0.2, side * 0.8]:
				draw_line(at + Vector2(x, 2.0), at + Vector2(x, side - 2.0), Color.WHITE, 2.5)
		else:
			_cross(at, side, 1.0)
	draw_set_transform_matrix(_base)
	var edge := Vector2(frame.end.x + 12.0, center.y)
	if touch:
		for start: float in [0.08, 0.54]:
			var swipe := _part(t, start, start + 0.22)
			if swipe > 0.0 and swipe < 1.0:
				_pointer(edge.lerp(edge - Vector2(110.0, 0.0), _smooth(swipe)), 0.0, minf(swipe * 6.0, (1.0 - swipe) * 6.0))
	else:
		_key(Vector2(WIDTH / 2.0, 184.0), "Tab", _pulse(t, [0.18, 0.64]))


## The page with the current block slides off to the right, with the overview under it; there a
## tap on the motif picks a colour.
func _draw_overview(t: float) -> void:
	var top := 22.0 if touch else 0.0
	var frame := Rect2(100.0, top, 160.0, 156.0)
	var slide := _smooth(_part(t, 0.14, 0.42))
	var side := 18.0
	var origin := frame.get_center() - Vector2(MOTIF_SIZE) * side / 2.0
	var chosen := t >= 0.72
	for cell in _motif_cells():
		_cross(origin + Vector2(cell) * side, side, 1.0, ACCENT if chosen and cell.y / 2 == 1 else Color.WHITE)
	var left := lerpf(frame.position.x, frame.end.x, slide)
	if left < frame.end.x - 1.0:
		var page := Rect2(left, frame.position.y, frame.end.x - left, frame.size.y)
		_fill(page, 12.0, GAP_COLOR)
		var big := 44.0
		for row in 2:
			for column in 3:
				var at := Vector2(left + 14.0 + column * big, frame.position.y + 34.0 + row * big)
				if at.x + big <= frame.end.x:
					_cross(at, big, 1.0, ACCENT if row == 0 else Color.WHITE)
	_outline(frame, 12.0, Color.WHITE)
	var pointer_start := Vector2(frame.position.x - 12.0, frame.get_center().y)
	var spot := origin + Vector2(3.5, 2.5) * side
	if touch or t >= 0.46:
		var pointer := pointer_start.lerp(pointer_start + Vector2(120.0, 0.0), _smooth(_part(t, 0.12, 0.42)))
		pointer = pointer.lerp(spot, _smooth(_part(t, 0.46, 0.66)))
		_pointer(pointer, _ripple(t, [0.68]), _part(t, 0.0, 0.05) - _part(t, 0.92, 1.0))
	if not touch:
		_key(Vector2(WIDTH / 2.0, 184.0), "Q", _pulse(t, [0.1]))


## The thread comes to an end: the gesture (or Enter), scissors cut it, a new needle comes in
## with its thread, the start marked as in the view.
func _draw_new_thread(t: float) -> void:
	var y := 74.0
	var cut := Vector2(176.0, y)
	var cutting := _part(t, 0.3, 0.42)
	var fall := _part(t, 0.42, 0.56)
	draw_line(Vector2(20.0, y), cut, Color(1.0, 1.0, 1.0, 1.0 - _part(t, 0.56, 0.66)), 3.0)
	if fall < 1.0:
		var drop := Vector2(0.0, fall * 40.0)
		var piece := Color(1.0, 1.0, 1.0, 1.0 - fall)
		draw_line(cut + drop, Vector2(250.0, y) + drop, piece, 3.0)
		_needle_at(Vector2(238.0, y) + drop, 0.0, 96.0, piece)
	if t >= 0.2 and t < 0.56:
		var shown := _part(t, 0.2, 0.27) - _part(t, 0.5, 0.56)
		StepSymbols.draw_scissors(self, cut + Vector2(20.0, 0.0), Vector2.LEFT,
				deg_to_rad(lerpf(26.0, 3.0, cutting)), Color(1.0, 1.0, 1.0, shown), 1.5)
	var enter := _smooth(_part(t, 0.62, 0.92))
	if enter > 0.0:
		var head := Vector2(lerpf(-96.0, 150.0, enter), y)
		draw_line(Vector2(0.0, y), head + Vector2(10.0, 0.0), Color(ACCENT, enter), 3.0)
		_needle_at(head, 0.0, 96.0, Color(1.0, 1.0, 1.0, enter))
	var spot := Vector2(WIDTH / 2.0, 146.0)
	if touch:
		var ripple := _ripple(t, [0.06, 0.14])
		var alpha := 1.0 - _part(t, 0.24, 0.3)
		for shift in [-20.0, 20.0]:
			_pointer(spot + Vector2(shift, 0.0), ripple, alpha)
		return
	_key(spot + Vector2(0.0, 12.0), "Enter", _pulse(t, [0.08]))


## The finished motif, a tick (it saves itself) and the gear (here the introduction comes back).
func _draw_done(t: float) -> void:
	_motif(Vector2(60.0, 40.0), 20.0, _part(t, 0.0, 0.6))
	var saved := _part(t, 0.6, 0.72)
	var gear := _part(t, 0.78, 0.9)
	_icon(ButtonIcons.Icon.CHECK, Vector2(262.0, 66.0), 56.0, Color(ACCENT, saved))
	_icon(ButtonIcons.Icon.GEAR, Vector2(262.0, 134.0), 56.0, Color(1.0, 1.0, 1.0, gear))


# ---- Drawing helpers ----


## The motif as crosses, stitched up to `amount` (0..1) of all of them.
func _motif(origin: Vector2, side: float, amount: float, ink := Color.WHITE) -> void:
	var cells := _motif_cells()
	var at := amount * cells.size()
	for i in cells.size():
		_cross(origin + Vector2(cells[i]) * side, side, clampf(at - i, 0.0, 1.0), ink)


## One half stitch "/", `amount` (0..1) of it drawn.
func _half(origin: Vector2, side: float, amount: float, ink: Color) -> void:
	if amount <= 0.0:
		return
	var inset := side * 0.16
	var from := origin + Vector2(inset, side - inset)
	draw_line(from, from.lerp(origin + Vector2(side - inset, inset), amount), ink, LINE_WIDTH, true)


## A cross, `amount` (0..1) of its two legs drawn; while growing it is in the accent colour.
func _cross(origin: Vector2, side: float, amount: float, ink := Color.WHITE) -> void:
	if amount <= 0.0:
		return
	var colour := ink if amount >= 1.0 else ACCENT
	_half(origin, side, minf(amount * 2.0, 1.0), colour)
	if amount > 0.5:
		var inset := side * 0.16
		var from := origin + Vector2(side - inset, side - inset)
		draw_line(from, from.lerp(origin + Vector2(inset, inset), (amount - 0.5) * 2.0), colour, LINE_WIDTH, true)


## Faint cells with their holes.
func _grid(origin: Vector2, cells: Vector2i, side: float) -> void:
	for x in cells.x + 1:
		draw_line(origin + Vector2(x * side, 0.0), origin + Vector2(x * side, cells.y * side), FAINT, 1.5)
	for y in cells.y + 1:
		draw_line(origin + Vector2(0.0, y * side), origin + Vector2(cells.x * side, y * side), FAINT, 1.5)
	for x in cells.x + 1:
		for y in cells.y + 1:
			draw_circle(origin + Vector2(x, y) * side, 2.5, DIM)


## The finger (a round touch with a ring spreading on a tap, `ripple` 0..1) or the mouse pointer.
func _pointer(at: Vector2, ripple: float, alpha := 1.0) -> void:
	alpha = clampf(alpha, 0.0, 1.0)
	if alpha <= 0.0:
		return
	if ripple > 0.0:
		draw_arc(at, lerpf(12.0, 32.0, ripple), 0.0, TAU, 32, Color(ACCENT, alpha * (1.0 - ripple)), 3.0, true)
	if touch:
		draw_circle(at, 12.0, Color(GAP_COLOR, alpha * 0.6))
		draw_circle(at, 10.0, Color(1.0, 1.0, 1.0, alpha * 0.9))
		return
	var shape := PackedVector2Array()
	for point: Vector2 in POINTER_SHAPE:
		shape.append(at + point)
	draw_colored_polygon(shape, Color(1.0, 1.0, 1.0, alpha))
	shape.append(at)
	draw_polyline(shape, Color(GAP_COLOR, alpha), 1.5, true)


## A key with `text` on it, lit while pressed.
func _key(center: Vector2, text: String, down: bool) -> void:
	var font := get_theme_default_font()
	var width := maxf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2).x + 16.0, 28.0)
	var rect := Rect2(center - Vector2(width, 28.0) / 2.0, Vector2(width, 28.0))
	if down:
		_fill(rect, 6.0, ACCENT)
	_outline(rect, 6.0, Color.WHITE, 2)
	StepSymbols.draw_label(self, font, center, text, FONT_SIZE - 2, Color.WHITE)


## A mouse, its wheel lit while it turns.
func _mouse(center: Vector2, wheel: bool) -> void:
	var body := Rect2(center - Vector2(23.0, 34.0), Vector2(46.0, 68.0))
	_outline(body, 22.0, Color.WHITE)
	draw_line(center + Vector2(0.0, -22.0), center + Vector2(0.0, -8.0), ACCENT if wheel else Color.WHITE, 5.0)


## A rounded outline.
func _outline(rect: Rect2, radius: float, ink: Color, width := 2) -> void:
	var line := StyleBoxFlat.new()
	line.draw_center = false
	line.border_color = ink
	line.set_border_width_all(width)
	line.set_corner_radius_all(int(radius))
	line.anti_aliasing = true
	draw_style_box(line, rect)


## A rounded filled rectangle.
func _fill(rect: Rect2, radius: float, ink: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = ink
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, rect)


## A symbol of the buttons, `px` wide, centred on `center`.
func _icon(icon: ButtonIcons.Icon, center: Vector2, px: float, ink: Color) -> void:
	draw_texture_rect(ButtonIcons.button_icon(icon, 48), Rect2(center - Vector2.ONE * px / 2.0, Vector2.ONE * px), false, ink)


## The needle, its head end at `head`, pointing along `angle`, `length` long.
func _needle_at(head: Vector2, angle: float, length: float, ink: Color) -> void:
	var thickness := length * _needle.get_height() / _needle.get_width()
	draw_set_transform_matrix(_base * Transform2D(angle, head))
	draw_texture_rect(_needle, Rect2(0.0, -thickness / 2.0, length, thickness), false, ink)
	draw_set_transform_matrix(_base)


# ---- Timing ----


## The cells of the motif, row by row.
static func _motif_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in MOTIF.size():
		for x in String(MOTIF[y]).length():
			if String(MOTIF[y])[x] == "X":
				cells.append(Vector2i(x, y))
	return cells


## Where `t` is between `from` and `to`, 0..1.
static func _part(t: float, from: float, to: float) -> float:
	return clampf((t - from) / (to - from), 0.0, 1.0)


## Slow at both ends.
static func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## How far a tap's ring has spread at `t`, for taps at `times`; 0 when none is going on.
static func _ripple(t: float, times: Array) -> float:
	for at: float in times:
		if t >= at and t < at + RIPPLE:
			return (t - at) / RIPPLE
	return 0.0


## Whether a key pressed at `times` is down at `t`.
static func _pulse(t: float, times: Array) -> bool:
	for at: float in times:
		if t >= at and t < at + RIPPLE:
			return true
	return false

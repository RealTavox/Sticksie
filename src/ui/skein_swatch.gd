class_name SkeinSwatch
extends Control
## A thread colour: a square of the pure colour on the left, shaded like a paper band wrapped
## round the thread, with the thread coming straight out of it to the right as a single loop,
## shaded like a round strand.

const SIZE := Vector2(76, 40)
## Share of the height the thread fills where it leaves the square, and the square's side
## relative to that: a little bigger, about as tall as the loop.
const BUNDLE_HEIGHT := 0.6
const SQUARE_SCALE := 1.25

var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _init(p_color := Color.WHITE) -> void:
	color = p_color
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var bundle := size.y * BUNDLE_HEIGHT
	var side := bundle * SQUARE_SCALE
	var square := Rect2(0.0, (size.y - side) / 2.0, side, side)
	# The loop starts under the square, so it seems to come out of it.
	_draw_loop(square.end.x - 2.0, size.y / 2.0, bundle)
	draw_rect(Rect2(square.end.x, (size.y - bundle) / 2.0, 3.0, bundle), Color(0, 0, 0, 0.3))
	# The band: plain colour, darker where it bends away at top and bottom, a light crease
	# below the top bend and a lit right edge.
	draw_rect(square, color)
	var edge := side * 0.12
	draw_rect(Rect2(square.position, Vector2(side, edge)), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(square.position.x, square.end.y - edge, side, edge), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(square.position.x, square.position.y + edge, side, 1.5), Color(1, 1, 1, 0.25))
	draw_line(Vector2(square.end.x, square.position.y), square.end, Color(1, 1, 1, 0.35), 1.0)


## The thread's upper and lower half part at `joint` and meet again in a round end, as a tube
## (dark rim, colour, light ridge).
func _draw_loop(joint: float, middle: float, bundle: float) -> void:
	var half := bundle / 2.0
	var right := size.x - 1.0 - half / 2.0
	# Only a little taller than the thread: the fold leaves a narrow slit.
	var height := minf(bundle * 0.42, size.y / 2.0 - 1.0 - half / 2.0)
	# An ellipse whose left ends sit on the two halves of the thread at the joint.
	var start := PI - asin(clampf(half / 2.0 / height, 0.0, 1.0))
	var radius_x := (right - joint) / (1.0 - cos(start))
	var center_x := right - radius_x
	var points := PackedVector2Array()
	const STEPS := 40
	for i in STEPS + 1:
		var angle := lerpf(-start, start, float(i) / STEPS)
		points.append(Vector2(center_x + radius_x * cos(angle), middle + height * sin(angle)))
	draw_polyline(points, color.darkened(0.35), half, true)
	draw_polyline(points, color, half * 0.7, true)
	var ridge := PackedVector2Array()
	for point in points:
		ridge.append(point + (Vector2(center_x, middle) - point).normalized() * half * 0.15)
	draw_polyline(ridge, Color(color.lightened(0.45), 0.6), maxf(1.0, half * 0.15), true)

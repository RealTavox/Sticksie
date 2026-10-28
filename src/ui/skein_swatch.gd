class_name SkeinSwatch
extends Control
## A thread colour drawn like a skein of stranded cotton as it is sold: a twisted bundle with a
## paper band around it, here in the thread's pure colour on the left (cut off at the left
## edge), and the bundle running out to the right, where it opens into a single loop. The
## bundle is shaded like a round strand; the band stays the plain colour apart from its curved
## edges.

const SIZE := Vector2(128, 40)
## Share of the width the band covers, of the height the bundle fills, and of the width the
## loop takes at the right end.
const BAND_WIDTH := 0.36
const BUNDLE_HEIGHT := 0.6
const LOOP_WIDTH := 0.3
## Gap between the twist lines across the bundle, in pixels.
const TWIST_STEP := 4.0

var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _init(p_color := Color.WHITE) -> void:
	color = p_color
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var middle := h / 2.0
	var bundle := h * BUNDLE_HEIGHT
	var top := middle - bundle / 2.0
	var joint := w * (1.0 - LOOP_WIDTH)
	_draw_loop(joint, middle, bundle)

	# The bundle, from under the band to the loop: round across, twisted along.
	var body := Rect2(0.0, top, joint + 1.0, bundle)
	draw_rect(body, color)
	# Left of the band nothing shows, so the lines start under it.
	var x := size.x * BAND_WIDTH - bundle
	while x + bundle / 2.0 <= body.end.x:
		draw_line(Vector2(x, top), Vector2(x + bundle / 2.0, body.end.y), Color(color.darkened(0.4), 0.35), 1.0, true)
		x += TWIST_STEP
	_draw_round_shading(Rect2(body.position, body.size))

	# The band wrapped round the bundle: plain colour, darker where it bends away at top and
	# bottom, casting a thin shadow on the bundle to its right.
	var band := Rect2(0.0, h * 0.04, w * BAND_WIDTH, h * 0.92)
	draw_rect(Rect2(band.end.x, top, 3.0, bundle), Color(0, 0, 0, 0.3))
	draw_rect(band, color)
	var edge := band.size.y * 0.12
	draw_rect(Rect2(band.position, Vector2(band.size.x, edge)), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(band.position.x, band.end.y - edge, band.size.x, edge), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(band.position.x, band.position.y + edge, band.size.x, 1.5), Color(1, 1, 1, 0.25))
	draw_line(Vector2(band.end.x, band.position.y), band.end, Color(1, 1, 1, 0.35), 1.0)


## The end of the skein: the bundle's upper and lower half part at `joint` and meet again in a
## round end, as a tube (dark rim, colour, light ridge).
func _draw_loop(joint: float, middle: float, bundle: float) -> void:
	var half := bundle / 2.0
	var right := size.x - 1.0 - half / 2.0
	# Only a little taller than the bundle: the fold leaves a narrow slit.
	var height := minf(bundle * 0.42, size.y / 2.0 - 1.0 - half / 2.0)
	# An ellipse whose left ends sit on the two halves of the bundle at the joint.
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


## Darker at the top and bottom of `rect`, a light streak above the middle: a round strand.
func _draw_round_shading(rect: Rect2) -> void:
	var height := rect.size.y
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, height * 0.16)), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(rect.position.x, rect.position.y + height * 0.24, rect.size.x, height * 0.12),
			Color(1, 1, 1, 0.22))
	draw_rect(Rect2(rect.position.x, rect.end.y - height * 0.2, rect.size.x, height * 0.2), Color(0, 0, 0, 0.32))

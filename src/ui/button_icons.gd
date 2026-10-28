class_name ButtonIcons
## Symbols for RoundButton, drawn procedurally from distance functions into a greyscale mask
## (white = symbol), which the button's shader also uses as a height map; button_icon() draws the
## same symbols white on transparent for ordinary buttons. Coordinates are in
## units of the button's disc: (0, 0) is its centre, 1 its rim, y points down. Each mask is
## made once and cached.

enum Icon { MENU, TEXT, NEEDLE, SPOOL, PIN, IMAGE, FOLDER, PROJECTS, GEAR, PENCIL, TRASH, CLOSE, CHECK, OVERVIEW, FLIP, BACK, NEW_THREAD, LIST, FILTER, WRENCH }

const SIZE := 128

static var _cache := {}


## The mask of `icon` for a button whose disc fills `disc` of its rect (RoundButton.DISC).
static func texture(icon: Icon, disc: float) -> ImageTexture:
	var key := "%d/%f" % [icon, disc]
	if not _cache.has(key):
		_cache[key] = _render(icon, disc)
	return _cache[key]


## `icon` white on transparent for an ordinary Button, `px` pixels square. Drawn at three times
## that size and scaled down smoothly (icon_max_width), so it stays sharp on dense screens.
static func button_icon(icon: Icon, px: int) -> ImageTexture:
	var key := "button/%d/%d" % [icon, px]
	if _cache.has(key):
		return _cache[key]
	var side := px * 3
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	# The square spans -0.5..0.5; symbols reach about 0.45 from the centre.
	var pixel := 1.0 / side
	for y in side:
		for x in side:
			var p := Vector2(x + 0.5, y + 0.5) / side - Vector2(0.5, 0.5)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(0.5 - distance(icon, p) / pixel, 0.0, 1.0)))
	image.generate_mipmaps()
	_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## The needle for the "stitch this colour" button, lying flat with the point to the right, `width`
## pixels long. Its outline follows the user's drawing (Input des Users/Needel.svg, coordinates
## below in its units): a round head with a long eye, a shaft tapering towards a blunt
## elliptical point, in the drawing's ratio of about 18 : 1. Shaded as polished steel under the
## default test light, the eye see-through; `flat` makes it plain white instead (StepSymbols).
static func needle_icon(width: int, flat := false) -> ImageTexture:
	var key := "needle/%d/%s" % [width, flat]
	if _cache.has(key):
		return _cache[key]
	const LEFT := NEEDLE_LEFT
	const RIGHT := NEEDLE_RIGHT
	const TOP := 202.9
	const BOTTOM := 228.2
	var scale := width / (RIGHT - LEFT)
	var height := ceili((BOTTOM - TOP) * scale) + 2
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var light := Vector3(-0.54, -0.54, 0.64).normalized()
	var steel := Color("#a9a9a9")
	for y in height:
		for x in width:
			var p := Vector2(LEFT + (x + 0.5) / scale, TOP + (y - 0.5) / scale)
			var coverage := clampf(0.5 - _needle_distance(p) * scale, 0.0, 1.0)
			if coverage <= 0.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			if flat:
				image.set_pixel(x, y, Color(1, 1, 1, coverage))
				continue
			# Round across: the normal tilts up or down with the height inside the outline.
			var v := clampf((p.y - NEEDLE_AXIS) / _needle_half_height(p.x), -1.0, 1.0)
			var normal := Vector3(0.0, v, sqrt(1.0 - v * v))
			var diffuse := maxf(normal.dot(light), 0.0)
			var specular := pow(maxf(normal.dot((light + Vector3(0, 0, 1)).normalized()), 0.0), 30.0) * 0.6
			var shade := steel * (0.45 + 0.75 * diffuse) + Color(specular, specular, specular)
			image.set_pixel(x, y, Color(shade, coverage))
	image.generate_mipmaps()
	_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## The needle's ends along its length, its middle line and its parts, in the drawing's units.
const NEEDLE_LEFT := 70.0
const NEEDLE_RIGHT := 523.4
const NEEDLE_AXIS := 215.5
const NEEDLE_HEAD := Vector2(82.63, 215.54)
const NEEDLE_HEAD_RADIUS := 12.59
const NEEDLE_POINT := Vector2(501.8, 215.5)
const NEEDLE_POINT_RADII := Vector2(21.6, 6.75)
const NEEDLE_EYE_FROM := Vector2(84.69, 215.34)
const NEEDLE_EYE_TO := Vector2(123.85, 215.34)
const NEEDLE_EYE_RADIUS := 5.4


static func _needle_distance(p: Vector2) -> float:
	var shaft := _tapered(p, NEEDLE_HEAD, NEEDLE_POINT, NEEDLE_HEAD_RADIUS, NEEDLE_POINT_RADII.y)
	var q := (p - NEEDLE_POINT) / NEEDLE_POINT_RADII
	var point := (q.length() - 1.0) * NEEDLE_POINT_RADII.y
	var eye := _capsule(p, NEEDLE_EYE_FROM, NEEDLE_EYE_TO, NEEDLE_EYE_RADIUS)
	return maxf(minf(shaft, point), -eye)


## Half the needle's thickness at `x`: round head, straight taper, elliptical point.
static func _needle_half_height(x: float) -> float:
	if x < NEEDLE_HEAD.x:
		return sqrt(maxf(NEEDLE_HEAD_RADIUS ** 2 - (x - NEEDLE_HEAD.x) ** 2, 0.25))
	if x < NEEDLE_POINT.x:
		return lerpf(NEEDLE_HEAD_RADIUS, NEEDLE_POINT_RADII.y,
				(x - NEEDLE_HEAD.x) / (NEEDLE_POINT.x - NEEDLE_HEAD.x))
	var t := (x - NEEDLE_POINT.x) / NEEDLE_POINT_RADII.x
	return maxf(NEEDLE_POINT_RADII.y * sqrt(maxf(1.0 - t * t, 0.0)), 0.5)


static func _render(icon: Icon, disc: float) -> ImageTexture:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_L8)
	var pixel := 2.0 / (SIZE * disc)
	for y in SIZE:
		for x in SIZE:
			var p := (Vector2(x + 0.5, y + 0.5) / SIZE * 2.0 - Vector2.ONE) / disc
			# Shapes stay well inside the rim; skip the rest.
			var coverage := 0.0
			if p.length_squared() < 0.6:
				coverage = clampf(0.5 - distance(icon, p) / pixel, 0.0, 1.0)
			image.set_pixel(x, y, Color(coverage, coverage, coverage))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Signed distance from `p` to the symbol (negative inside).
static func distance(icon: Icon, p: Vector2) -> float:
	match icon:
		Icon.MENU:
			# Three bars.
			var d := INF
			for y in [-0.27, 0.0, 0.27]:
				d = minf(d, _capsule(p, Vector2(-0.36, y), Vector2(0.36, y), 0.07))
			return d
		Icon.TEXT:
			# A page with lines of text.
			var d := absf(_box(p, Vector2.ZERO, Vector2(0.31, 0.41), 0.08)) - 0.035
			for line: Array in [[-0.2, 0.15], [-0.04, 0.15], [0.12, 0.15], [0.28, 0.04]]:
				d = minf(d, _capsule(p, Vector2(-0.15, line[0]), Vector2(line[1], line[0]), 0.035))
			return d
		Icon.NEEDLE:
			# A needle leaning right, its eye at the top, with the thread looping out of it.
			var tip := Vector2(-0.4, 0.4)
			var top := Vector2(0.33, -0.33)
			var d := _tapered(p, tip, top, 0.012, 0.065)
			var eye := maxf(d, -_capsule(p, tip.lerp(top, 0.8), tip.lerp(top, 0.92), 0.022))
			return minf(eye, _bezier(p, tip.lerp(top, 0.86), Vector2(0.55, 0.05), Vector2(0.05, 0.42), 0.03))
		Icon.SPOOL:
			# A reel of thread: two flanges with wound thread between.
			var d := minf(_box(p, Vector2(0.0, -0.36), Vector2(0.32, 0.06), 0.04),
					_box(p, Vector2(0.0, 0.36), Vector2(0.32, 0.06), 0.04))
			for y in [-0.19, -0.065, 0.065, 0.19]:
				d = minf(d, _capsule(p, Vector2(-0.2, y), Vector2(0.2, y), 0.05))
			return d
		Icon.PIN:
			# A push pin leaning left: cap, body, collar and needle, turned by 40°.
			var q := p.rotated(deg_to_rad(-40.0)) + Vector2(0.0, 0.06)
			var d := _capsule(q, Vector2(-0.19, -0.36), Vector2(0.19, -0.36), 0.065)
			d = minf(d, _box(q, Vector2(0.0, -0.14), Vector2(0.1, 0.2), 0.03))
			d = minf(d, _capsule(q, Vector2(-0.24, 0.07), Vector2(0.24, 0.07), 0.06))
			return minf(d, _tapered(q, Vector2(0.0, 0.5), Vector2(0.0, 0.07), 0.01, 0.035))
		Icon.IMAGE:
			# A framed picture: two hills under a sun.
			var frame := absf(_box(p, Vector2.ZERO, Vector2(0.44, 0.36), 0.07)) - 0.04
			var hills := minf(_triangle(p, Vector2(-0.32, 0.26), Vector2(-0.08, -0.06), Vector2(0.16, 0.26)),
					_triangle(p, Vector2(0.0, 0.26), Vector2(0.17, 0.04), Vector2(0.34, 0.26)))
			var sun := (p - Vector2(0.17, -0.14)).length() - 0.07
			return minf(frame, minf(hills, sun))
		Icon.FOLDER:
			# A folder with a tab on the left.
			return minf(_box(p, Vector2(0.0, 0.07), Vector2(0.42, 0.27), 0.06),
					_box(p, Vector2(-0.2, -0.2), Vector2(0.2, 0.08), 0.05))
		Icon.PROJECTS:
			# Four tiles, like a collection of pictures.
			var d := INF
			for center in [Vector2(-0.2, -0.2), Vector2(0.2, -0.2), Vector2(-0.2, 0.2), Vector2(0.2, 0.2)]:
				d = minf(d, _box(p, center, Vector2(0.15, 0.15), 0.05))
			return d
		Icon.GEAR:
			# A cog with eight teeth and a hole.
			var d := p.length() - 0.29
			for i in 8:
				var q := p.rotated(-i * TAU / 8.0)
				d = minf(d, _box(q, Vector2(0.0, -0.34), Vector2(0.075, 0.09), 0.02))
			return maxf(d, 0.11 - p.length())
		Icon.PENCIL:
			# A pencil leaning right, its point at the bottom left, the eraser set off by a gap.
			var q := p.rotated(deg_to_rad(-45.0))
			var body := _box(q, Vector2(0.0, -0.08), Vector2(0.1, 0.3), 0.03)
			body = maxf(body, 0.025 - absf(q.y + 0.2))
			return minf(body, _triangle(q, Vector2(-0.1, 0.25), Vector2(0.1, 0.25), Vector2(0.0, 0.44)))
		Icon.TRASH:
			# A bin with a lid and handle, three slots in it.
			var d := _box(p, Vector2(0.0, 0.12), Vector2(0.26, 0.28), 0.06)
			for x in [-0.11, 0.0, 0.11]:
				d = maxf(d, -_capsule(p, Vector2(x, -0.02), Vector2(x, 0.26), 0.032))
			d = minf(d, _capsule(p, Vector2(-0.34, -0.25), Vector2(0.34, -0.25), 0.045))
			return minf(d, _capsule(p, Vector2(-0.08, -0.34), Vector2(0.08, -0.34), 0.045))
		Icon.CLOSE:
			return minf(_capsule(p, Vector2(-0.28, -0.28), Vector2(0.28, 0.28), 0.06),
					_capsule(p, Vector2(-0.28, 0.28), Vector2(0.28, -0.28), 0.06))
		Icon.CHECK:
			return minf(_capsule(p, Vector2(-0.32, 0.02), Vector2(-0.1, 0.24), 0.065),
					_capsule(p, Vector2(-0.1, 0.24), Vector2(0.34, -0.26), 0.065))
		Icon.OVERVIEW:
			# The whole pattern: a frame with four little crosses in it.
			var d := absf(_box(p, Vector2.ZERO, Vector2(0.42, 0.42), 0.08)) - 0.04
			for center in [Vector2(-0.14, -0.14), Vector2(0.14, -0.14), Vector2(-0.14, 0.14), Vector2(0.14, 0.14)]:
				d = minf(d, _capsule(p, center - Vector2(0.08, 0.08), center + Vector2(0.08, 0.08), 0.035))
				d = minf(d, _capsule(p, center + Vector2(-0.08, 0.08), center + Vector2(0.08, -0.08), 0.035))
			return d
		Icon.FLIP:
			# Turning the fabric over: two half-round arrows going round clockwise.
			return minf(_arc_arrow(p, deg_to_rad(-160.0), deg_to_rad(-25.0)),
					_arc_arrow(p, deg_to_rad(20.0), deg_to_rad(155.0)))
		Icon.BACK:
			# An arrow to the left.
			var d := _capsule(p, Vector2(-0.3, 0.0), Vector2(0.32, 0.0), 0.06)
			d = minf(d, _capsule(p, Vector2(-0.3, 0.0), Vector2(-0.08, -0.22), 0.06))
			return minf(d, _capsule(p, Vector2(-0.3, 0.0), Vector2(-0.08, 0.22), 0.06))
		Icon.NEW_THREAD:
			# The needle with its thread, a little smaller, up left and drawn bolder (it is fine for
			# the small size), and a plus beside it.
			var plus := minf(_capsule(p, Vector2(0.12, 0.29), Vector2(0.42, 0.29), 0.06),
					_capsule(p, Vector2(0.27, 0.14), Vector2(0.27, 0.44), 0.06))
			const SHRINK := 1.15
			var needle := distance(Icon.NEEDLE, (p + Vector2(0.06, 0.06)) * SHRINK) / SHRINK - 0.025
			return minf(maxf(needle, 0.07 - plus), plus)
		Icon.LIST:
			# Three lines, each with a dot in front.
			var d := INF
			for y in [-0.25, 0.0, 0.25]:
				d = minf(d, (p - Vector2(-0.3, y)).length() - 0.065)
				d = minf(d, _capsule(p, Vector2(-0.12, y), Vector2(0.36, y), 0.05))
			return d
		Icon.FILTER:
			# A funnel: only some go through.
			var funnel := _triangle(p, Vector2(-0.36, -0.3), Vector2(0.36, -0.3), Vector2(0.0, 0.12)) - 0.04
			return minf(funnel, _box(p, Vector2(0.0, 0.16), Vector2(0.07, 0.2), 0.03))
		Icon.WRENCH:
			# A spanner leaning right: a handle and a round head with its jaw open to the top right.
			var head := (p - Vector2(0.16, -0.16)).length() - 0.19
			head = maxf(head, 0.11 - (p - Vector2(0.27, -0.27)).length())
			return minf(head, _capsule(p, Vector2(-0.32, 0.32), Vector2(0.1, -0.1), 0.075))
	return INF


## An arc of radius 0.3 from angle `from` to `to` (radians, clockwise on screen), with an arrow
## head at `to`.
static func _arc_arrow(p: Vector2, from: float, to: float) -> float:
	const RADIUS := 0.3
	const SEGMENTS := 12
	var d := INF
	var previous := Vector2.from_angle(from) * RADIUS
	for i in range(1, SEGMENTS + 1):
		var point := Vector2.from_angle(lerpf(from, to, float(i) / SEGMENTS)) * RADIUS
		d = minf(d, _capsule(p, previous, point, 0.055))
		previous = point
	var out := Vector2.from_angle(to)
	var along := Vector2(-out.y, out.x)
	return minf(d, _triangle(p, previous + out * 0.13, previous - out * 0.13, previous + along * 0.17))


static func _capsule(p: Vector2, a: Vector2, b: Vector2, radius: float) -> float:
	return _tapered(p, a, b, radius, radius)


## A capsule from `a` to `b` whose radius goes from `radius_a` to `radius_b`.
static func _tapered(p: Vector2, a: Vector2, b: Vector2, radius_a: float, radius_b: float) -> float:
	var ab := b - a
	var h := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - a - ab * h).length() - lerpf(radius_a, radius_b, h)


static func _box(p: Vector2, center: Vector2, half: Vector2, radius: float) -> float:
	var q := (p - center).abs() - half + Vector2.ONE * radius
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - radius


## A filled triangle with corners `a`, `b` and `c`.
static func _triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	var e0 := b - a
	var e1 := c - b
	var e2 := a - c
	var v0 := p - a
	var v1 := p - b
	var v2 := p - c
	var q0 := v0 - e0 * clampf(v0.dot(e0) / e0.dot(e0), 0.0, 1.0)
	var q1 := v1 - e1 * clampf(v1.dot(e1) / e1.dot(e1), 0.0, 1.0)
	var q2 := v2 - e2 * clampf(v2.dot(e2) / e2.dot(e2), 0.0, 1.0)
	var s := signf(e0.cross(e2))
	var d := Vector2(q0.dot(q0), s * v0.cross(e0)).min(Vector2(q1.dot(q1), s * v1.cross(e1))).min(
			Vector2(q2.dot(q2), s * v2.cross(e2)))
	return -sqrt(d.x) * signf(d.y)


## A quadratic Bézier curve from `a` over `control` to `b`, `radius` thick.
static func _bezier(p: Vector2, a: Vector2, control: Vector2, b: Vector2, radius: float) -> float:
	const SEGMENTS := 12
	var d := INF
	var previous := a
	for i in range(1, SEGMENTS + 1):
		var t := float(i) / SEGMENTS
		var point := a.lerp(control, t).lerp(control.lerp(b, t), t)
		d = minf(d, _capsule(p, previous, point, radius))
		previous = point
	return d

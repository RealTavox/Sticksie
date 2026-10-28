class_name ButtonIcons
## Symbols for RoundButton, drawn procedurally from distance functions into a greyscale mask
## (white = symbol), which the button's shader also uses as a height map. Coordinates are in
## units of the button's disc: (0, 0) is its centre, 1 its rim, y points down. Each mask is
## made once and cached.

enum Icon { MENU, TEXT, NEEDLE, SPOOL, PIN, STITCH }

const SIZE := 128

static var _cache := {}


## The mask of `icon` for a button whose disc fills `disc` of its rect (RoundButton.DISC).
static func texture(icon: Icon, disc: float) -> ImageTexture:
	var key := "%d/%f" % [icon, disc]
	if not _cache.has(key):
		_cache[key] = _render(icon, disc)
	return _cache[key]


## `icon` as a white symbol on transparent ground, `size` pixels square, for an ordinary Button.
static func button_icon(icon: Icon, size: int) -> ImageTexture:
	var key := "button/%d/%d" % [icon, size]
	if not _cache.has(key):
		var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		var pixel := 2.0 / size
		for y in size:
			for x in size:
				var p := Vector2(x + 0.5, y + 0.5) / size * 2.0 - Vector2.ONE
				image.set_pixel(x, y, Color(1, 1, 1, clampf(0.5 - distance(icon, p) / pixel, 0.0, 1.0)))
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


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
		Icon.STITCH:
			# A needle lying flat, pointing right, the thread trailing from its eye: "stitch this".
			var tip := Vector2(0.9, 0.0)
			var top := Vector2(-0.55, 0.0)
			var d := _tapered(p, tip, top, 0.03, 0.17)
			var eye := maxf(d, -_capsule(p, top.lerp(tip, 0.06), top.lerp(tip, 0.2), 0.06))
			return minf(eye, _bezier(p, top.lerp(tip, 0.13), Vector2(-1.0, -0.15), Vector2(-0.85, 0.75), 0.08))
	return INF


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

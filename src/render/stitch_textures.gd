class_name StitchTextures
extends RefCounted
## Procedural textures for the 3D view, made once on first use: Aida fabric and stranded cotton
## floss, each as a height field turned into a normal map plus a brightness map (cavities darker).
##
## Normal maps use their own convention, not Godot's NORMAL_MAP: RGB = (n.x, n.y, n.z) * 0.5 + 0.5
## with x along the image's x and y along the image's y (downwards), so the shaders build the
## normal from the mesh's own axes.

## Fabric tile: 2 × 2 cells (the weave alternates from cell to cell), this many pixels per cell.
const FABRIC_CELL_PX := 128
## Width of a thread bundle as a part of the cell; the rest is the gap, holes where gaps cross.
const FABRIC_BUNDLE := 0.8
## Relief height in cells; decides how strongly the light picks out the weave.
const FABRIC_RELIEF := 0.07
## Floss tile: one twist period along the thread (x) by the thread's width (y).
const THREAD_LENGTH_PX := 128
const THREAD_WIDTH_PX := 64
## Twist period and thread width in cells; must match StitchScene, which scales the tile to them.
const TWIST_PERIOD := 0.4
const THREAD_WIDTH := 0.46
## How many strands lie side by side (2 is the usual for 14 ct Aida), and plies per strand.
const STRANDS := 2
const PLY_TWISTS := 1.0
const THREAD_RELIEF := 0.06

static var _fabric: Array[ImageTexture] = []
static var _thread: Array[ImageTexture] = []


## [normal, brightness] of the fabric tile.
static func fabric() -> Array[ImageTexture]:
	if _fabric.is_empty():
		_fabric = _make_fabric()
	return _fabric


## [normal, brightness] of the floss tile.
static func thread() -> Array[ImageTexture]:
	if _thread.is_empty():
		_thread = _make_thread()
	return _thread


static func _make_fabric() -> Array[ImageTexture]:
	var size := FABRIC_CELL_PX * 2
	var fibres := _noise(size, size, 7, 0.06)
	var mottle := _noise(size, size, 11, 0.012)
	var height := PackedFloat32Array()
	height.resize(size * size)
	var shade := PackedFloat32Array()
	shade.resize(size * size)
	var half := FABRIC_BUNDLE / 2.0
	for py in size:
		var y := (py + 0.5) / FABRIC_CELL_PX
		var row := floori(y)
		var dy := (y - row - 0.5) / half
		for px in size:
			var x := (px + 0.5) / FABRIC_CELL_PX
			var column := floori(x)
			var dx := (x - column - 0.5) / half
			# Each bundle is a few threads side by side, so it has ridges along its direction.
			var vertical := _bundle(dx) * (0.62 + 0.28 * _parity(column) * cos(PI * (y - 0.5)))
			var horizontal := _bundle(dy) * (0.62 - 0.28 * _parity(row) * cos(PI * (x - 0.5)))
			var on_top := vertical >= horizontal
			# Fibres run along the bundle on top: sample the noise stretched across it.
			var fibre := _sample(fibres, size, px * (1 if on_top else 4), py * (4 if on_top else 1))
			var h := maxf(vertical, horizontal)
			height[py * size + px] = h + (fibre - 0.5) * 0.12 * h
			# Cavities (the gaps between bundles and the holes) catch less light.
			var cavity := smoothstep(0.0, 0.55, h)
			shade[py * size + px] = (0.42 + 0.58 * cavity) * (0.96 + 0.08 * _sample(mottle, size, px, py))
	return [_normal_texture(height, size, size, FABRIC_RELIEF, 1.0 / FABRIC_CELL_PX, 1.0 / FABRIC_CELL_PX, true),
			_gray_texture(shade, size, size)]


## Cross section of a fabric bundle at `d` (-1..1 across it): a flat-topped bump with three
## thread ridges.
static func _bundle(d: float) -> float:
	if absf(d) >= 1.0:
		return 0.0
	var dome := pow(1.0 - d * d, 0.35)
	return dome * (0.86 + 0.14 * cos(d * PI * 3.0))


static func _parity(i: int) -> float:
	return 1.0 if posmod(i, 2) == 0 else -1.0


static func _make_thread() -> Array[ImageTexture]:
	var w := THREAD_LENGTH_PX
	var h := THREAD_WIDTH_PX
	var fibres := _noise(w, h, 3, 0.09)
	var height := PackedFloat32Array()
	height.resize(w * h)
	var shade := PackedFloat32Array()
	shade.resize(w * h)
	for py in h:
		var v := (py + 0.5) / h  # 0..1 across the thread
		var strand := mini(int(v * STRANDS), STRANDS - 1)
		var s := (v * STRANDS - strand) * 2.0 - 1.0  # -1..1 across this strand
		var profile := sqrt(maxf(0.0, 1.0 - s * s))
		for px in w:
			var u := (px + 0.5) / w  # one twist period
			# The plies wind round each other: diagonal ridges with grooves between them. Each
			# strand is twisted with its own phase, so their grooves don't line up.
			var phase := TAU * (u * PLY_TWISTS - s * 0.3 + strand * 0.37)
			var ply := 0.5 + 0.5 * cos(phase)
			var fibre := _sample(fibres, w, px, py) - 0.5
			var hh := profile * (0.78 + 0.22 * pow(ply, 0.6)) + fibre * 0.08 * profile
			height[py * w + px] = hh
			shade[py * w + px] = clampf(0.7 + 0.3 * smoothstep(0.1, 0.9, ply) * smoothstep(0.0, 0.6, profile)
					+ fibre * 0.08, 0.0, 1.0)
	var period := TWIST_PERIOD
	return [_normal_texture(height, w, h, THREAD_RELIEF, period / w, THREAD_WIDTH / h, false),
			_gray_texture(shade, w, h)]


## Seamless noise in 0..1, `w` × `h` pixels.
static func _noise(w: int, h: int, seed: int, frequency: float) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var image := noise.get_seamless_image(w, h)
	var values := PackedFloat32Array()
	values.resize(w * h)
	for y in h:
		for x in w:
			values[y * w + x] = image.get_pixel(x, y).r
	return values


## `values` at (x, y), wrapping round; the width is `w`, the height follows from the size.
static func _sample(values: PackedFloat32Array, w: int, x: int, y: int) -> float:
	var h := values.size() / w
	return values[posmod(y, h) * w + posmod(x, w)]


## Normal map from a height field (0..1, scaled to `relief` cells), with pixel spacing `step_x`
## and `step_y` in cells. `wrap_y` repeats the field vertically too (the floss is clamped across).
static func _normal_texture(height: PackedFloat32Array, w: int, h: int, relief: float,
		step_x: float, step_y: float, wrap_y: bool) -> ImageTexture:
	var data := PackedByteArray()
	data.resize(w * h * 3)
	for y in h:
		var up := posmod(y - 1, h) if wrap_y else maxi(y - 1, 0)
		var down := posmod(y + 1, h) if wrap_y else mini(y + 1, h - 1)
		for x in w:
			var left := height[y * w + posmod(x - 1, w)]
			var right := height[y * w + posmod(x + 1, w)]
			var dx := (right - left) * relief / (2.0 * step_x)
			var dy := (height[down * w + x] - height[up * w + x]) * relief / ((down - up) * step_y)
			var n := Vector3(-dx, -dy, 1.0).normalized()
			var i := (y * w + x) * 3
			data[i] = int(round((n.x * 0.5 + 0.5) * 255.0))
			data[i + 1] = int(round((n.y * 0.5 + 0.5) * 255.0))
			data[i + 2] = int(round((n.z * 0.5 + 0.5) * 255.0))
	var image := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)
	image.generate_mipmaps(true)
	return ImageTexture.create_from_image(image)


static func _gray_texture(values: PackedFloat32Array, w: int, h: int) -> ImageTexture:
	var data := PackedByteArray()
	data.resize(w * h)
	for i in values.size():
		data[i] = int(round(clampf(values[i], 0.0, 1.0) * 255.0))
	var image := Image.create_from_data(w, h, false, Image.FORMAT_L8, data)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

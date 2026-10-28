class_name SkeinSwatch
extends Control
## A thread colour: a square of the pure colour on the left, shaded like a paper band wrapped
## round the thread, with the thread coming straight out of it to the right as a single loop,
## shaded like a round strand. Drawn from one colourless template image (template()) tinted by
## skein.gdshader, so square and loop are one picture and fade together. With `clickable` a
## click or tap emits `pressed`.

signal pressed

const SIZE := Vector2(76, 40)
## Template geometry in canvas pixels: the thread where it leaves the square, the square's side
## (a little bigger, about as tall as the loop), and the loop tube's half thickness.
const BUNDLE := 24.0
const SQUARE := 30.0
const TUBE := 6.0
## Loop length beyond the square: in the colour list, and in the colour picker's stairs.
const LIST_LOOP := 47.0
const PICKER_LOOP := 22.0
## Template pixels per canvas pixel, so it stays sharp on dense screens.
const DETAIL := 3
const SHADER := preload("res://src/ui/skein.gdshader")
## Must match SHADE_RANGE in the shader.
const SHADE_RANGE := 1.6

static var _templates := {}
static var _material: ShaderMaterial

var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()
var clickable := false:
	set(value):
		clickable = value
		mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW

var _press_position := Vector2.ZERO


func _init(p_color := Color.WHITE, scale_factor := 1.0) -> void:
	color = p_color
	custom_minimum_size = SIZE * scale_factor
	clickable = false
	material = shared_material()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
	draw_texture_rect(template(LIST_LOOP, 0.0, SIZE.y, false), Rect2(Vector2.ZERO, size), false, color)


func _gui_input(event: InputEvent) -> void:
	if not clickable or not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_press_position = event.position
	elif event.position.distance_to(_press_position) < 12.0 and Rect2(Vector2.ZERO, size).has_point(event.position):
		pressed.emit()
	accept_event()


## The material that tints templates; shared by every swatch.
static func shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


## Size in canvas pixels of a template from template().
static func template_size(loop: float, extension: float, across: float, vertical: bool) -> Vector2:
	var length := extension + SQUARE - 2.0 + loop + 1.0
	return Vector2(across, length) if vertical else Vector2(length, across)


## The colourless picture of a skein for skein.gdshader: the square, lengthened by `extension`
## away from the loop, and the loop `loop` long; `across` is the size across the thread. The
## loop points right, or up if `vertical`. Made once per shape.
static func template(loop: float, extension: float, across: float, vertical: bool) -> ImageTexture:
	var key := "%s/%s/%s/%s" % [loop, extension, across, vertical]
	if _templates.has(key):
		return _templates[key]
	var size := template_size(loop, extension, across, vertical)
	var width := int(size.x * DETAIL)
	var height := int(size.y * DETAIL)
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	# The loop: an ellipse whose left ends sit on the two halves of the thread at the joint,
	# only a little taller than the thread so the fold leaves a narrow slit.
	var joint := SQUARE - 2.0
	var loop_right := joint + loop - TUBE
	var loop_height := minf(BUNDLE * 0.42, across / 2.0 - 1.0 - TUBE)
	var start := PI - asin(clampf(TUBE / loop_height, 0.0, 1.0))
	var radii := Vector2((loop_right - joint) / (1.0 - cos(start)), loop_height)
	var loop_center := loop_right - radii.x
	var length := extension + SQUARE - 2.0 + loop + 1.0
	for y in height:
		for x in width:
			# Along the thread (u, from the square's far end at -extension) and across it (w).
			var u: float
			var w: float
			if vertical:
				u = length - extension - (y + 0.5) / DETAIL
				w = (x + 0.5) / DETAIL - across / 2.0
			else:
				u = (x + 0.5) / DETAIL - extension
				w = (y + 0.5) / DETAIL - across / 2.0
			image.set_pixel(x, y, _shade(u, w, extension, loop_center, radii))
	image.generate_mipmaps()
	_templates[key] = ImageTexture.create_from_image(image)
	return _templates[key]


## One template pixel at (u, w): shading in red, added light in green, coverage in alpha.
static func _shade(u: float, w: float, extension: float, loop_center: float, radii: Vector2) -> Color:
	# Loop: a round tube along the ellipse, dark at its rims, a light ridge on the inner side.
	var q := Vector2(u - loop_center, w)
	var k0 := (q / radii).length()
	var k1 := (q / (radii * radii)).length()
	var d := k0 * (k0 - 1.0) / k1 if k1 > 0.0 else -radii.y
	var loop_cover := clampf((TUBE - absf(d)) * DETAIL + 0.5, 0.0, 1.0)
	var v := clampf(d / TUBE, -1.0, 1.0)
	var loop_shade := lerpf(1.0, 0.65, smoothstep(0.62, 0.78, absf(v)))
	var loop_light := 0.0
	if absf(v + 0.3) < 0.15:
		loop_shade *= 0.73
		loop_light = 0.27
	# The square casts a thin shadow on the loop where it comes out.
	if u > SQUARE and u < SQUARE + 3.0 and absf(w) < BUNDLE / 2.0:
		loop_shade *= 0.7

	# Square: plain colour, darker where the band bends away at its edges across the thread, a
	# light crease after the first bend and a lit edge towards the loop.
	var half := SQUARE / 2.0
	var inside := minf(minf(u + extension, SQUARE - u), half - absf(w))
	var square_cover := clampf(inside * DETAIL + 0.5, 0.0, 1.0)
	var square_shade := 1.0
	var square_light := 0.0
	var band := w + half
	var edge := SQUARE * 0.12
	if band < edge:
		square_shade = 0.82
	elif band > SQUARE - edge:
		square_shade = 0.75
	elif band < edge + 1.5:
		square_shade = 0.75
		square_light = 0.25
	if u > SQUARE - 1.0:
		square_shade = 0.65
		square_light = 0.35

	var alpha := square_cover + loop_cover * (1.0 - square_cover)
	if alpha <= 0.0:
		return Color(0, 0, 0, 0)
	var loop_part := loop_cover * (1.0 - square_cover)
	var shade := (square_shade * square_cover + loop_shade * loop_part) / alpha
	var light := (square_light * square_cover + loop_light * loop_part) / alpha
	return Color(shade / SHADE_RANGE, light, 0.0, alpha)

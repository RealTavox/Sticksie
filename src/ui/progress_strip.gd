class_name ProgressStrip
extends Control
## The progress bar at the bottom of the screen: a grey capsule track, filled from the left with
## a capsule of `color` (progress_strip.gdshader). Filling up is a show, like a boss's life bar
## in a game: the new part flashes white first, the bar pops, then the colour runs in after it
## while bands of light sweep along the bar. Going down just slides back. The control is bigger
## than the bar by `margin` on every side, room for the glow (`glow`); place it with place_bar().

## The fill animation has caught up with the value.
signal fill_finished

const SHADER := preload("res://src/ui/progress_strip.gdshader")
const DEFAULT_COLOR := RoundButton.DEFAULT_TINT
## How long the new part takes to flash up, how long it stays white before the colour comes,
## and how long the colour takes to fill it.
const FLASH_SECONDS := 0.1
const HOLD_SECONDS := 0.18
const FILL_SECONDS := 0.8
const DOWN_SECONDS := 0.25
## The bands of light fade out over this time once the fill has caught up.
const SHIMMER_FADE_SECONDS := 0.6
const POP_SCALE := 1.12
const COLOR_SECONDS := 0.3

var color := DEFAULT_COLOR:
	set(v):
		color = v
		_param("fill_color", v)
## 0: none, 1: around the bar, up to 2: bright.
var glow := 0.0:
	set(v):
		glow = v
		_param("glow", v)
## Keeps the bands of light running (0..1) even without a fill animation.
var shimmer := 0.0:
	set(v):
		shimmer = v
		_update_shimmer()
var margin := 10.0:
	set(v):
		margin = v
		_param("margin", v)

## The value the bar shows or is heading to, 0..1.
var value := 0.0

var _material := ShaderMaterial.new()
var _fill := 0.0:
	set(v):
		_fill = v
		_param("fill", v)
var _ghost := 0.0:
	set(v):
		_ghost = v
		_param("ghost", v)
var _flash := 0.0:
	set(v):
		_flash = v
		_param("flash", v)
## The bands of light of the fill animation.
var _sweep := 0.0:
	set(v):
		_sweep = v
		_update_shimmer()
var _phase := 0.0
var _tween: Tween
var _color_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material.shader = SHADER
	material = _material
	color = DEFAULT_COLOR
	margin = margin
	resized.connect(func() -> void:
		_param("rect_size", size)
		pivot_offset = size / 2.0)
	set_process(false)


## Puts the bar itself on `rect` (in the parent's coordinates); the control grows by `margin`.
func place_bar(rect: Rect2) -> void:
	position = rect.position - Vector2.ONE * margin
	size = rect.size + Vector2.ONE * margin * 2.0


## The bar itself in global coordinates, without the margin, at the scale it has now.
func bar_rect() -> Rect2:
	var rect := get_global_rect()
	return Rect2(rect.position + Vector2.ONE * margin, rect.size - Vector2.ONE * margin * 2.0)


## Shows `new_value` (0..1); with `animate` going up plays the fill show, going down slides.
func set_value(new_value: float, animate := false) -> void:
	new_value = clampf(new_value, 0.0, 1.0)
	value = new_value
	if _tween != null:
		_tween.kill()
		_tween = null
		scale = Vector2.ONE
	if not animate or not is_visible_in_tree() or is_equal_approx(new_value, _fill):
		_fill = new_value
		_ghost = new_value
		_flash = 0.0
		_sweep = 0.0
		return
	_tween = create_tween()
	if new_value < _fill:
		_ghost = new_value
		_tween.tween_property(self, "_fill", new_value, DOWN_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_callback(fill_finished.emit)
		return
	_ghost = new_value
	_flash = 0.0
	_tween.tween_property(self, "_flash", 1.0, FLASH_SECONDS)
	_tween.parallel().tween_property(self, "scale", Vector2(1.0 + (POP_SCALE - 1.0) * 0.4, POP_SCALE), FLASH_SECONDS).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "_sweep", 1.0, FLASH_SECONDS)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "_fill", new_value, FILL_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, FILL_SECONDS * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	_tween.parallel().tween_property(self, "_flash", 0.0, FILL_SECONDS).set_ease(Tween.EASE_IN)
	_tween.tween_callback(fill_finished.emit)
	_tween.tween_property(self, "_sweep", 0.0, SHIMMER_FADE_SECONDS)


## Blends to `new_color`, or jumps there without `animate`.
func set_color(new_color: Color, animate := false) -> void:
	if _color_tween != null:
		_color_tween.kill()
	if not animate or not is_visible_in_tree():
		color = new_color
		return
	_color_tween = create_tween()
	_color_tween.tween_property(self, "color", new_color, COLOR_SECONDS)


## Whether the fill show is still running (until the colour has caught up).
func is_filling() -> bool:
	return _tween != null and _tween.is_running() and not is_equal_approx(_fill, value)


func _update_shimmer() -> void:
	var amount := maxf(shimmer, _sweep)
	_param("shimmer", amount)
	set_process(amount > 0.0)


func _param(name: String, param_value: Variant) -> void:
	_material.set_shader_parameter(name, param_value)
	queue_redraw()


func _process(delta: float) -> void:
	_phase += delta
	_param("phase", _phase)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)

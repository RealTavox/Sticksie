class_name Celebration
extends Control
## The show when a colour is finished: the screen greys out, the progress bar flies up into the
## middle, grows and glows, confetti bursts out of it and from the lower corners, sparkles drift
## over the screen, and a big congratulation pops in. A tap (after a short moment, so the tap
## that finished the colour can't skip it) fades it all out and emits `dismissed`; the
## celebration then frees itself.

signal dismissed

const DIM := Color(0.0, 0.0, 0.0, 0.66)
const INTRO_SECONDS := 0.7
const OUTRO_SECONDS := 0.3
## Taps before this are ignored.
const TAP_DELAY_SECONDS := 0.8
const BAR_HEIGHT := 34.0
const BAR_MAX_WIDTH := 620.0
const GLOW_LOW := 1.1
const GLOW_HIGH := 1.9
const GLOW_SECONDS := 0.8
const TITLE_SIZE := 64
const TEXT_SIZE := 22
const CONFETTI_COLORS: Array[Color] = [Color(1.0, 0.82, 0.2), Color(1.0, 0.5, 0.05),
		Color(0.17, 0.47, 0.88), Color(0.0, 0.75, 0.75), Color(0.9, 0.25, 0.6), Color.WHITE]

var _dim := ColorRect.new()
var _bar := ProgressStrip.new()
var _title := Label.new()
var _text := Label.new()
var _tap_label := Label.new()
var _started_msec := 0
var _leaving := false
var _intro: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(DIM, 0.0)
	add_child(_dim)
	_bar.margin = 40.0
	add_child(_bar)
	for label: Label in [_title, _text, _tap_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.modulate.a = 0.0
		add_child(label)
	_title.text = "Geschafft!"
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.add_theme_constant_override("outline_size", 14)
	_text.add_theme_font_size_override("font_size", TEXT_SIZE)
	_tap_label.text = "Tippen, um zur Übersicht zu gehen"
	_tap_label.add_theme_font_size_override("font_size", 16)


## Starts the show for `floss` (`crosses` of them stitched): the bar comes from `from_rect` (the
## progress bar on screen, global) in `color`.
func play(floss: FlossColor, crosses: int, color: Color, from_rect: Rect2) -> void:
	_started_msec = Time.get_ticks_msec()
	var screen := get_viewport_rect().size
	_title.add_theme_color_override("font_outline_color", color.darkened(0.2))
	_text.text = "DMC %s · %s ist fertig: alle %d Kreuze gestickt!" % [floss.code, floss.name, crosses]
	var width := minf(BAR_MAX_WIDTH, screen.x * 0.8)
	var bar_rect := Rect2((screen.x - width) / 2.0, screen.y * 0.5 - BAR_HEIGHT / 2.0, width, BAR_HEIGHT)
	_bar.color = color
	_bar.set_value(1.0)
	_bar.place_bar(from_rect)
	_bar.shimmer = 0.8
	var column := Rect2(16.0, 0.0, screen.x - 32.0, 0.0)
	_title.position = Vector2(column.position.x, bar_rect.position.y - 150.0)
	_title.size = Vector2(column.size.x, 90.0)
	_title.pivot_offset = _title.size / 2.0
	_title.scale = Vector2.ONE * 0.3
	_text.position = Vector2(column.position.x, bar_rect.end.y + 40.0)
	_text.size = Vector2(column.size.x, 0.0)
	_tap_label.position = Vector2(column.position.x, minf(screen.y - 60.0, bar_rect.end.y + 150.0))
	_tap_label.size = Vector2(column.size.x, 0.0)

	_intro = create_tween().set_parallel()
	_intro.tween_property(_dim, "color", DIM, INTRO_SECONDS * 0.7)
	var grown := Rect2(bar_rect.position - Vector2.ONE * _bar.margin, bar_rect.size + Vector2.ONE * _bar.margin * 2.0)
	_intro.tween_property(_bar, "position", grown.position, INTRO_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_bar, "size", grown.size, INTRO_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_bar, "glow", GLOW_HIGH, INTRO_SECONDS)
	_intro.tween_property(_title, "modulate:a", 1.0, 0.25).set_delay(INTRO_SECONDS * 0.6)
	_intro.tween_property(_title, "scale", Vector2.ONE, 0.5).set_delay(INTRO_SECONDS * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_text, "modulate:a", 1.0, 0.4).set_delay(INTRO_SECONDS)
	_intro.tween_property(_tap_label, "modulate:a", 0.75, 0.4).set_delay(INTRO_SECONDS + TAP_DELAY_SECONDS * 0.5)
	_intro.chain().tween_callback(_pulse)
	get_tree().create_timer(INTRO_SECONDS * 0.6).timeout.connect(func() -> void:
		if not _leaving:
			_burst(bar_rect, color))
	add_child(_sparkles(screen))
	Input.vibrate_handheld(80)


## Whether the show is still coming in (for screenshots).
func is_arriving() -> bool:
	return _intro != null and _intro.is_running()


## Confetti out of the bar and from both lower corners.
func _burst(bar_rect: Rect2, color: Color) -> void:
	var screen := get_viewport_rect().size
	var colors: Array[Color] = CONFETTI_COLORS.duplicate()
	colors.append(color)
	colors.append(color.lightened(0.4))
	var from_bar := _confetti(colors, 220)
	from_bar.position = bar_rect.get_center()
	from_bar.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	from_bar.emission_rect_extents = bar_rect.size / 2.0
	from_bar.direction = Vector2.UP
	from_bar.spread = 75.0
	add_child(from_bar)
	for corner in [Vector2(0.0, screen.y), Vector2(screen.x, screen.y)]:
		var cannon := _confetti(colors, 120)
		cannon.position = corner
		cannon.direction = Vector2(0.55 if corner.x == 0.0 else -0.55, -1.0).normalized()
		cannon.spread = 18.0
		cannon.initial_velocity_min = 700.0
		cannon.initial_velocity_max = 1300.0
		add_child(cannon)


func _confetti(colors: Array[Color], amount: int) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = amount
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 2.8
	particles.initial_velocity_min = 380.0
	particles.initial_velocity_max = 900.0
	particles.gravity = Vector2(0.0, 900.0)
	particles.damping_min = 40.0
	particles.damping_max = 120.0
	particles.angle_min = -180.0
	particles.angle_max = 180.0
	particles.angular_velocity_min = -540.0
	particles.angular_velocity_max = 540.0
	particles.scale_amount_min = 6.0
	particles.scale_amount_max = 13.0
	particles.color_initial_ramp = _ramp(colors)
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.75, Color.WHITE)
	particles.color_ramp = fade
	particles.emitting = true
	return particles


## Each particle picks one of `colors` (no blends between them).
static func _ramp(colors: Array[Color]) -> Gradient:
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array()
	ramp.colors = PackedColorArray()
	for i in colors.size():
		ramp.add_point(float(i) / colors.size(), colors[i])
	return ramp


## Small lights rising slowly all over the screen, for as long as the show lasts.
func _sparkles(screen: Vector2) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = 60
	particles.lifetime = 2.2
	particles.preprocess = 1.0
	particles.position = screen / 2.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = screen / 2.0
	particles.direction = Vector2.UP
	particles.spread = 30.0
	particles.gravity = Vector2(0.0, -30.0)
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 50.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	var twinkle := Gradient.new()
	twinkle.set_color(0, Color(1.0, 0.95, 0.7, 0.0))
	twinkle.set_color(1, Color(1.0, 0.95, 0.7, 0.0))
	twinkle.add_point(0.3, Color(1.0, 0.95, 0.7, 1.0))
	particles.color_ramp = twinkle
	particles.emitting = true
	return particles


## The bar's glow breathes and the tap hint with it.
func _pulse() -> void:
	if _leaving:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(_bar, "glow", GLOW_LOW, GLOW_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_tap_label, "modulate:a", 0.4, GLOW_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_bar, "glow", GLOW_HIGH, GLOW_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_tap_label, "modulate:a", 0.85, GLOW_SECONDS).set_trans(Tween.TRANS_SINE)


func _gui_input(event: InputEvent) -> void:
	var press: bool = ((event is InputEventMouseButton and event.pressed)
			or (event is InputEventScreenTouch and event.pressed))
	accept_event()
	if not press or _leaving or Time.get_ticks_msec() - _started_msec < TAP_DELAY_SECONDS * 1000.0:
		return
	leave()


## Fades everything out, emits `dismissed` and frees the celebration.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, OUTRO_SECONDS)
	tween.tween_callback(func() -> void:
		dismissed.emit()
		queue_free())

class_name Finale
extends Control
## The big show when the whole project is stitched: a white flash and a jolt, the screen goes
## dark around the finished pattern while golden rays turn behind it, "MEISTERWERK!" pops in
## letter by letter in rainbow colours and keeps dancing, fireworks go off all over the screen,
## confetti rains, the stitch count runs up and a full bar glows through every colour. Then three
## buttons ask what next; choosing one fades the show out, emits `chosen` and frees it.

enum Choice {
	OVERVIEW,
	NEW_PROJECT,
	OPEN_PROJECT,
}

signal chosen(choice: Choice)

const SHADER := preload("res://src/ui/finale.gdshader")
const TITLE := "MEISTERWERK!"
const TITLE_MAX_SIZE := 96
const LETTER_DELAY := 0.08
const LETTER_SECONDS := 0.45
const FLASH_SECONDS := 0.7
const DARK_SECONDS := 0.9
## When the title is complete: after the 12 letters of TITLE, LETTER_DELAY apart.
const TEXT_AT := 0.5 + 12 * LETTER_DELAY
const COUNT_SECONDS := 1.6
const BUTTONS_AT := 3.4
const OUTRO_SECONDS := 0.4
## Fireworks: one every this often at first, slower after FIREWORKS_CALM_AFTER.
const FIREWORK_EVERY := 0.28
const FIREWORK_CALM_EVERY := 0.9
const FIREWORKS_CALM_AFTER := 7.0
const BAR_HEIGHT := 30.0
const BAR_MAX_WIDTH := 560.0
const BUTTON_HEIGHT := 56.0
const GOLD := Color(1.0, 0.82, 0.3)
## Where the title starts (share of the screen height), and how far below it the texts and the
## bar reach.
const TOP_SHARE := 0.06
const TEXT_BOTTOM := 300.0

var _background := ColorRect.new()
var _material := ShaderMaterial.new()
var _flash := ColorRect.new()
## Everything that shakes.
var _content := Control.new()
var _letters: Array[Label] = []
var _letter_home: Array[Vector2] = []
var _subtitle := Label.new()
var _stats := Label.new()
var _bar := ProgressStrip.new()
var _buttons := VBoxContainer.new()
var _time := 0.0
var _shake := 0.0
var _next_firework := 0.5
var _crosses := 0
var _colors := 0
var _leaving := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_material.shader = SHADER
	_background.material = _material
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	for label: Label in [_subtitle, _stats]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.modulate.a = 0.0
		label.add_theme_constant_override("outline_size", 8)
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.8))
		_content.add_child(label)
	_subtitle.add_theme_font_size_override("font_size", 26)
	_stats.add_theme_font_size_override("font_size", 40)
	_stats.add_theme_color_override("font_color", GOLD)
	_bar.margin = 36.0
	_bar.modulate.a = 0.0
	_bar.shimmer = 1.0
	_bar.set_value(1.0)
	_content.add_child(_bar)
	_buttons.modulate.a = 0.0
	_buttons.add_theme_constant_override("separation", 12)
	_content.add_child(_buttons)
	for entry in [["Zur Übersicht", Choice.OVERVIEW], ["Neues Projekt starten", Choice.NEW_PROJECT],
			["Projekt öffnen", Choice.OPEN_PROJECT]]:
		_buttons.add_child(_make_button(entry[0], entry[1]))
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_flash)
	set_process(false)


## Starts the show for the project `project_name` (`crosses` stitches in `colors` colours);
## `pattern_rect` is where the finished pattern is on screen (global), kept lighter. The title
## and texts take the top TOP_SHARE of the screen down to TEXT_BOTTOM below it, the buttons the
## bottom (see covered_bottom()), so the pattern can be fitted between.
func play(project_name: String, crosses: int, colors: int, pattern_rect: Rect2) -> void:
	_crosses = crosses
	_colors = colors
	var screen := get_viewport_rect().size
	_material.set_shader_parameter("rect_size", screen)
	_material.set_shader_parameter("spot", Vector4(pattern_rect.position.x / screen.x,
			pattern_rect.position.y / screen.y, pattern_rect.size.x / screen.x, pattern_rect.size.y / screen.y))
	var title_y := screen.y * TOP_SHARE
	_material.set_shader_parameter("center", Vector2(0.5, (title_y + 50.0) / screen.y))
	_build_title(screen, title_y)
	var column := Rect2(24.0, 0.0, screen.x - 48.0, 0.0)
	_subtitle.text = "„%s“ ist fertig gestickt!" % project_name
	_subtitle.position = Vector2(column.position.x, title_y + 120.0)
	_subtitle.size = Vector2(column.size.x, 0.0)
	_stats.position = Vector2(column.position.x, title_y + 170.0)
	_stats.size = Vector2(column.size.x, 0.0)
	_set_count(0.0)
	var width := minf(BAR_MAX_WIDTH, screen.x * 0.8)
	_bar.place_bar(Rect2((screen.x - width) / 2.0, title_y + 245.0, width, BAR_HEIGHT))
	_bar.pivot_offset = _bar.size / 2.0
	var buttons_width := minf(420.0, screen.x - 48.0)
	_buttons.position = Vector2((screen.x - buttons_width) / 2.0, screen.y - covered_bottom() + 16.0)
	_buttons.size = Vector2(buttons_width, 0.0)

	var tween := create_tween().set_parallel()
	_flash.color.a = 0.95
	tween.tween_property(_flash, "color:a", 0.0, FLASH_SECONDS).set_ease(Tween.EASE_OUT)
	tween.tween_method(_shader_float.bind("amount"), 0.0, 1.0, DARK_SECONDS)
	tween.tween_method(_shader_float.bind("rays"), 0.0, 1.0, DARK_SECONDS * 1.5).set_delay(0.3)
	for i in _letters.size():
		var letter := _letters[i]
		var at := 0.4 + i * LETTER_DELAY
		tween.tween_property(letter, "modulate:a", 1.0, 0.1).set_delay(at)
		tween.tween_property(letter, "scale", Vector2.ONE, LETTER_SECONDS).set_delay(at).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(letter, "rotation", 0.0, LETTER_SECONDS).set_delay(at).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_jolt.bind(4.0)).set_delay(at)
	tween.tween_callback(_jolt.bind(18.0)).set_delay(TEXT_AT)
	tween.tween_callback(_big_burst.bind(screen)).set_delay(TEXT_AT)
	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.5).set_delay(TEXT_AT)
	tween.tween_property(_stats, "modulate:a", 1.0, 0.4).set_delay(TEXT_AT + 0.2)
	tween.tween_method(_set_count, 0.0, 1.0, COUNT_SECONDS).set_delay(TEXT_AT + 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_bar.scale = Vector2(0.2, 1.0)
	tween.tween_property(_bar, "modulate:a", 1.0, 0.3).set_delay(TEXT_AT + 0.6)
	tween.tween_property(_bar, "scale", Vector2.ONE, 0.6).set_delay(TEXT_AT + 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bar, "glow", 1.8, 0.6).set_delay(TEXT_AT + 0.6)
	tween.tween_callback(_jolt.bind(10.0)).set_delay(TEXT_AT + 0.6 + COUNT_SECONDS * 0.6)
	var buttons_home := _buttons.position
	_buttons.position.y += 60.0
	tween.tween_property(_buttons, "modulate:a", 1.0, 0.5).set_delay(BUTTONS_AT)
	tween.tween_property(_buttons, "position", buttons_home, 0.6).set_delay(BUTTONS_AT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	add_child(_rain(screen))
	add_child(_sparkles(screen))
	_jolt(24.0)
	Input.vibrate_handheld(200)
	set_process(true)


## The title, one label per letter, each popping in from small and turned.
func _build_title(screen: Vector2, y: float) -> void:
	var font := get_theme_default_font()
	var font_size := mini(TITLE_MAX_SIZE, int((screen.x - 32.0) / (TITLE.length() * 0.68)))
	var widths: Array[float] = []
	var total := 0.0
	for letter in TITLE:
		var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widths.append(width)
		total += width
	var x := (screen.x - total) / 2.0
	for i in TITLE.length():
		var label := Label.new()
		label.text = TITLE[i]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_constant_override("outline_size", maxi(6, font_size / 7))
		label.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.0))
		label.position = Vector2(x, y)
		label.size = Vector2(widths[i], font.get_height(font_size))
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2.ONE * 0.05
		label.rotation = deg_to_rad(randf_range(-90.0, 90.0))
		label.modulate.a = 0.0
		_content.add_child(label)
		_letters.append(label)
		_letter_home.append(label.position)
		x += widths[i]


func _process(delta: float) -> void:
	_time += delta
	_material.set_shader_parameter("phase", _time)
	# The letters dance in a wave, each in a rainbow colour running along the word.
	for i in _letters.size():
		_letters[i].position = _letter_home[i] + Vector2(0.0, sin(_time * 5.0 - i * 0.55) * 7.0)
		_letters[i].add_theme_color_override("font_color",
				Color.from_hsv(fposmod(_time * 0.25 + i * 0.07, 1.0), 0.55, 1.0))
	_bar.color = Color.from_hsv(fposmod(_time * 0.2, 1.0), 0.75, 1.0)
	_shake = maxf(0.0, _shake - delta * 60.0)
	_content.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	if _time >= _next_firework and not _leaving:
		var screen := get_viewport_rect().size
		_firework(Vector2(randf_range(0.1, 0.9) * screen.x, randf_range(0.08, 0.6) * screen.y))
		_next_firework = _time + (FIREWORK_EVERY if _time < FIREWORKS_CALM_AFTER else FIREWORK_CALM_EVERY) * randf_range(0.7, 1.3)


## A jolt of the screen, `pixels` far at first.
func _jolt(pixels: float) -> void:
	_shake = maxf(_shake, pixels)


func _shader_float(value: float, name: String) -> void:
	_material.set_shader_parameter(name, value)


func _set_count(progress: float) -> void:
	_stats.text = "%d Kreuze · %d Farben" % [roundi(_crosses * progress), _colors]


## A firework at `at`: a ball of sparks in one colour and a few in white.
func _firework(at: Vector2) -> void:
	var hue := randf()
	for ring in 2:
		var particles := CPUParticles2D.new()
		particles.position = at
		particles.amount = 90 if ring == 0 else 30
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.lifetime = 1.5
		particles.spread = 180.0
		particles.initial_velocity_min = 160.0 if ring == 0 else 320.0
		particles.initial_velocity_max = 380.0 if ring == 0 else 420.0
		particles.gravity = Vector2(0.0, 160.0)
		particles.damping_min = 60.0
		particles.damping_max = 120.0
		particles.scale_amount_min = 3.0 if ring == 0 else 2.0
		particles.scale_amount_max = 6.0 if ring == 0 else 3.0
		var color := Color.from_hsv(hue, 0.7, 1.0) if ring == 0 else Color(1.0, 1.0, 0.9)
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
		fade.colors = PackedColorArray([Color.WHITE, color, color, Color(color, 0.0)])
		particles.color_ramp = fade
		particles.emitting = true
		particles.finished.connect(particles.queue_free)
		add_child(particles)


## Fireworks all at once across the top, when the title is complete.
func _big_burst(screen: Vector2) -> void:
	for i in 6:
		_firework(Vector2(screen.x * (i + 0.5) / 6.0, screen.y * randf_range(0.1, 0.4)))
	Input.vibrate_handheld(120)


## Confetti falling from the top all the time.
func _rain(screen: Vector2) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = 160
	particles.lifetime = 4.0
	particles.position = Vector2(screen.x / 2.0, -20.0)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(screen.x / 2.0, 10.0)
	particles.direction = Vector2.DOWN
	particles.spread = 25.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 220.0
	particles.gravity = Vector2(0.0, 120.0)
	particles.angle_min = -180.0
	particles.angle_max = 180.0
	particles.angular_velocity_min = -400.0
	particles.angular_velocity_max = 400.0
	particles.scale_amount_min = 6.0
	particles.scale_amount_max = 11.0
	particles.color_initial_ramp = Celebration._ramp(Celebration.CONFETTI_COLORS)
	particles.emitting = true
	return particles


## Golden lights rising over the screen.
func _sparkles(screen: Vector2) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = 90
	particles.lifetime = 2.4
	particles.preprocess = 1.0
	particles.position = screen / 2.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = screen / 2.0
	particles.direction = Vector2.UP
	particles.gravity = Vector2(0.0, -40.0)
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 60.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	var twinkle := Gradient.new()
	twinkle.set_color(0, Color(GOLD, 0.0))
	twinkle.set_color(1, Color(GOLD, 0.0))
	twinkle.add_point(0.3, Color(1.0, 0.95, 0.7))
	particles.color_ramp = twinkle
	particles.emitting = true
	return particles


func _make_button(text: String, choice: Choice) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.11, 0.9) if choice != Choice.OVERVIEW else Color(GOLD, 0.95)
	style.set_corner_radius_all(int(BUTTON_HEIGHT / 2.0))
	style.border_color = GOLD
	style.set_border_width_all(2)
	for state in ["normal", "hover", "pressed", "focus"]:
		var state_style := style.duplicate() as StyleBoxFlat
		if state == "pressed":
			state_style.bg_color = state_style.bg_color.lightened(0.2)
		button.add_theme_stylebox_override(state, state_style)
	var text_color := Color(0.15, 0.08, 0.0) if choice == Choice.OVERVIEW else Color(1.0, 0.95, 0.85)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, text_color)
	button.pressed.connect(_choose.bind(choice))
	return button


## How much of the top of `screen` the title and texts cover.
static func covered_top(screen: Vector2) -> float:
	return screen.y * TOP_SHARE + TEXT_BOTTOM


## How much of the bottom the buttons cover.
static func covered_bottom() -> float:
	return BUTTON_HEIGHT * 3.0 + 24.0 + 56.0


## Whether the buttons are up (for screenshots).
func is_arriving() -> bool:
	return _time < BUTTONS_AT + 0.6


func _choose(choice: Choice) -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, OUTRO_SECONDS)
	tween.tween_callback(func() -> void:
		chosen.emit(choice)
		queue_free())


func _gui_input(event: InputEvent) -> void:
	accept_event()

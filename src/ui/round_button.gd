class_name RoundButton
extends Control
## A round, see-through button lit like the fabric: a disc with a rounded rim and a raised
## symbol (ButtonIcons), shaded by round_button.gdshader from the same light as the 3D view
## (set_light()). Holding it down shows `tooltip` instead of pressing it. Reacts to the left
## mouse button only; touches arrive as mouse clicks too (emulate_mouse_from_touch).

signal pressed
signal toggled(on: bool)

## Share of the rect the disc fills; the rest holds the shadow.
const DISC := 0.84
const LONG_PRESS_SECONDS := 0.5
const TOOLTIP_GAP := 8.0
## Switching on or off blends the colour over this time.
const TINT_SECONDS := 0.15
const SHADER := preload("res://src/ui/round_button.gdshader")
const DEFAULT_TINT := Color(0.17, 0.47, 0.88)

## Shown while the button is held down.
var tooltip := ""
var toggle_mode := false
var button_pressed := false:
	set(value):
		button_pressed = value
		if _tint_tween != null:
			_tint_tween.kill()
		if is_inside_tree() and is_visible_in_tree():
			_tint_tween = create_tween()
			_tint_tween.tween_property(self, "_tint", 1.0 if value else 0.0, TINT_SECONDS)
		else:
			_tint = 1.0 if value else 0.0
var disabled := false:
	set(value):
		disabled = value
		_update_material()
## Colour of the face while switched on (the blue of the app by default).
var tint_color := DEFAULT_TINT:
	set(value):
		tint_color = value
		_material.set_shader_parameter("tint_color", value)
		queue_redraw()
var icon := ButtonIcons.Icon.MENU:
	set(value):
		icon = value
		_texture = ButtonIcons.texture(icon, DISC)
		queue_redraw()

var _texture: ImageTexture
var _material := ShaderMaterial.new()
## How far the "on" colour shows, 0..1.
var _tint := 0.0:
	set(value):
		_tint = value
		_material.set_shader_parameter("tint", value)
		queue_redraw()
var _tint_tween: Tween
var _down := false
## The tooltip was shown during this press, so letting go doesn't press the button.
var _held := false
## Counts presses, so a timer from an earlier press can't show the tooltip.
var _press_count := 0
var _tooltip_panel: PanelContainer
var _tooltip_label: Label


func _init(p_icon := ButtonIcons.Icon.MENU, p_tooltip := "", diameter := 72.0) -> void:
	icon = p_icon
	tooltip = p_tooltip
	custom_minimum_size = Vector2.ONE * diameter
	focus_mode = Control.FOCUS_NONE
	_material.shader = SHADER
	_material.set_shader_parameter("disc", DISC)
	_material.set_shader_parameter("icon", _texture)
	material = _material
	_build_tooltip()


## Light from `azimuth` (degrees clockwise from the top of the screen) at `elevation` degrees
## above the screen, as StitchScene.set_light().
func set_light(azimuth: float, elevation: float) -> void:
	var a := deg_to_rad(azimuth)
	var e := deg_to_rad(elevation)
	_material.set_shader_parameter("light", Vector3(sin(a) * cos(e), -cos(a) * cos(e), sin(e)))
	queue_redraw()


func set_pressed_no_signal(value: bool) -> void:
	button_pressed = value


func _draw() -> void:
	_material.set_shader_parameter("icon", _texture)
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size / 2.0) <= size.x / 2.0 * DISC


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if event.pressed:
		_down = true
		_held = false
		_press_count += 1
		var press := _press_count
		get_tree().create_timer(LONG_PRESS_SECONDS).timeout.connect(func() -> void:
			if _down and press == _press_count:
				show_tooltip())
	elif _down:
		_down = false
		_tooltip_panel.hide()
		if not _held and not disabled and _has_point(event.position):
			if toggle_mode:
				button_pressed = not button_pressed
				toggled.emit(button_pressed)
			pressed.emit()
	_update_material()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _down and not _held:
		_down = false
		_update_material()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_down = false
		_tooltip_panel.hide()


func _update_material() -> void:
	_material.set_shader_parameter("pressed", 1.0 if _down else 0.0)
	_material.set_shader_parameter("disabled", 1.0 if disabled else 0.0)
	queue_redraw()


func _build_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.top_level = true
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.1, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	_tooltip_panel.add_child(_tooltip_label)
	add_child(_tooltip_panel)


## Next to the button, towards the middle of the screen, kept on screen.
func show_tooltip() -> void:
	if tooltip.is_empty():
		return
	_held = true
	_tooltip_label.text = tooltip
	_tooltip_panel.reset_size()
	var screen := get_viewport_rect().size
	var tip_size := _tooltip_panel.get_combined_minimum_size()
	var rect := get_global_rect()
	var position_y := rect.end.y + TOOLTIP_GAP
	if rect.get_center().y > screen.y / 2.0:
		position_y = rect.position.y - TOOLTIP_GAP - tip_size.y
	var position_x := rect.get_center().x - tip_size.x / 2.0
	_tooltip_panel.global_position = Vector2(
			clampf(position_x, TOOLTIP_GAP, maxf(TOOLTIP_GAP, screen.x - tip_size.x - TOOLTIP_GAP)), position_y)
	_tooltip_panel.show()
	Input.vibrate_handheld(20)
	_update_material()

class_name OverlayWindow
extends Control
## A window inside the app in the look of the touch overlays: a dark, rounded, see-through panel
## with a title, a close button, `content` (it scrolls when taller than the screen allows) and
## `buttons` at the bottom, centred over a dimmed screen that takes every touch and key. Opening
## it slides it up a little while it fades in, closing slides it back down while it fades out.

## The window starts closing (its close button, Escape, a tap outside with
## `close_on_outside_tap`, or close()).
signal closed

const PANEL_COLOR := Color(0.13, 0.12, 0.11, 0.84)
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.5)
const SLIDE_PX := 24.0
const OPEN_SECONDS := 0.2
const CLOSE_SECONDS := 0.12
## Distance from the screen edge, inside the safe area.
const MARGIN := 12.0
const BUTTON_HEIGHT := 48.0
const ICON_PX := 24
const TITLE_FONT_SIZE := 18
## Background of a window's or row's main button (make_primary()): the round buttons' blue.
const PRIMARY_COLOR := RoundButton.DEFAULT_TINT

var content := VBoxContainer.new()
var buttons := HBoxContainer.new()
## Widest the panel gets; with `fill_height` it takes the screen's whole height, otherwise only
## what the content needs.
var max_width := 640.0
var fill_height := false
## Screen parts kept free for a notch or home bar: left, top, right, bottom.
var safe_area := Vector4.ZERO
## A tap beside the panel closes the window (as its close button does).
var close_on_outside_tap := false

var _panel := PanelContainer.new()
var _title := Label.new()
var _scroll := ScrollContainer.new()
var _tween: Tween
var _open := false
## Opened, waiting a frame for the layout before sliding in.
var _waiting := false
## How far the screen behind is dimmed, 0..1.
var _dim := 0.0:
	set(value):
		_dim = value
		queue_redraw()


func _init(title_text := "") -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel.add_theme_stylebox_override("panel", panel_style())
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title.text = title_text
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_title)
	var close_button := make_button("", ButtonIcons.Icon.CLOSE, close)
	close_button.flat = true
	close_button.tooltip_text = "Schließen"
	header.add_child(close_button)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.minimum_size_changed.connect(func() -> void: fit.call_deferred())
	_scroll.add_child(content)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	resized.connect(fit)


## The look of the touch overlays, shared with the start screen's panels.
static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(16)
	style.set_content_margin_all(12)
	return style


## A button for windows and menus: `text` with a white symbol from ButtonIcons in front (none
## for -1), big enough to tap.
static func make_button(text: String, icon: int, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	if icon >= 0:
		set_icon(button, icon)
	button.custom_minimum_size = Vector2(BUTTON_HEIGHT, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


## Puts the white symbol `icon` (ButtonIcons.Icon) in front of the button's text.
static func set_icon(button: Button, icon: int) -> void:
	button.icon = ButtonIcons.button_icon(icon, ICON_PX)
	button.add_theme_constant_override("icon_max_width", ICON_PX)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Gives `button` the blue background of a main action, lighter under the mouse, darker while
## pressed, faded while disabled; the theme's shape and margins stay.
static func make_primary(button: Button) -> Button:
	var colors := {"normal": PRIMARY_COLOR, "hover": PRIMARY_COLOR.lightened(0.12),
			"pressed": PRIMARY_COLOR.darkened(0.15), "hover_pressed": PRIMARY_COLOR.darkened(0.1),
			"disabled": Color(PRIMARY_COLOR, 0.35)}
	for state: String in colors:
		var style := button.get_theme_stylebox(state, "Button").duplicate() as StyleBoxFlat
		if style == null:
			style = StyleBoxFlat.new()
			style.set_corner_radius_all(4)
		style.bg_color = colors[state]
		button.add_theme_stylebox_override(state, style)
	return button


func is_open() -> bool:
	return _open


func is_animating() -> bool:
	return _waiting or (_tween != null and _tween.is_running())


func open() -> void:
	if _tween != null:
		_tween.kill()
	_open = true
	buttons.visible = buttons.get_child_count() > 0
	_panel.modulate.a = 0.0
	_dim = 0.0
	visible = true
	fit()
	_waiting = true
	await get_tree().process_frame  # Wrapped labels know their width now, and so their height.
	_waiting = false
	if not _open:
		return
	fit()
	var home := _panel.position
	_panel.position = home + Vector2(0.0, SLIDE_PX)
	_tween = create_tween().set_parallel()
	_tween.tween_property(_panel, "position", home, OPEN_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(_panel, "modulate:a", 1.0, OPEN_SECONDS)
	_tween.tween_property(self, "_dim", 1.0, OPEN_SECONDS)
	_tween.chain().tween_callback(fit)


func close() -> void:
	if not _open:
		return
	_open = false
	if _tween != null:
		_tween.kill()
	closed.emit()
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_panel, "position", _panel.position + Vector2(0.0, SLIDE_PX), CLOSE_SECONDS)
	_tween.tween_property(_panel, "modulate:a", 0.0, CLOSE_SECONDS)
	_tween.tween_property(self, "_dim", 0.0, CLOSE_SECONDS)
	_tween.chain().tween_callback(hide)


## Sizes the panel to its content (or the screen's height) and centres it in the safe area.
func fit() -> void:
	if not visible or (_tween != null and _tween.is_running()):
		return
	var room := Rect2(safe_area.x + MARGIN, safe_area.y + MARGIN,
			size.x - safe_area.x - safe_area.z - MARGIN * 2.0, size.y - safe_area.y - safe_area.w - MARGIN * 2.0)
	var height := room.size.y
	if not fill_height:
		# The scroll adds no height of its own, so the panel's minimum is everything but the content.
		height = minf(_panel.get_combined_minimum_size().y + content.get_combined_minimum_size().y, height)
	_panel.size = Vector2(minf(max_width, room.size.x), height)
	_panel.position = (room.position + (room.size - _panel.size) / 2.0).round()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(DIM_COLOR, DIM_COLOR.a * _dim))


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if (close_on_outside_tap and mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
			and not _panel.get_rect().has_point(mouse.position)):
		close()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	# Keys meant for the screen behind (next step, back) stay there.
	get_viewport().set_input_as_handled()

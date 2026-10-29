class_name ChoiceCards
extends HBoxContainer
## A choice in the settings as big buttons side by side, in the symbol window's look: a white
## SettingPicture over the label on a see-through card; the chosen one in the buttons' blue.

## The user chose another card.
signal selected_changed(index: int)

const HEIGHT := 136.0
const PICTURE_HEIGHT := 96.0
const CARD_COLOR := Color(1.0, 1.0, 1.0, 0.07)

## Index of the chosen card.
var selected := 0:
	set(value):
		selected = value
		for i in _buttons.size():
			_buttons[i].set_pressed_no_signal(i == selected)

var _buttons: Array[Button] = []


## `choices`: per card its label and SettingPicture.Kind.
func _init(choices: Array) -> void:
	add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for i in choices.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.text = choices[i][0]
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, HEIGHT)
		_style(button)
		var picture := SettingPicture.new(choices[i][1])
		picture.set_anchors_preset(Control.PRESET_TOP_WIDE)
		picture.offset_bottom = PICTURE_HEIGHT
		button.add_child(picture)
		button.pressed.connect(func() -> void:
			selected = i
			selected_changed.emit(i))
		add_child(button)
		_buttons.append(button)
	selected = 0


## Rounded cards, the label under the picture: see-through grey, a little lighter under the
## mouse, blue when chosen.
static func _style(button: Button) -> void:
	var colors := {"normal": CARD_COLOR, "hover": Color(1, 1, 1, 0.12), "pressed": OverlayWindow.PRIMARY_COLOR,
			"hover_pressed": OverlayWindow.PRIMARY_COLOR.lightened(0.08), "disabled": Color(1, 1, 1, 0.04)}
	for state: String in colors:
		var style := StyleBoxFlat.new()
		style.bg_color = colors[state]
		style.set_corner_radius_all(12)
		style.content_margin_top = PICTURE_HEIGHT
		style.content_margin_bottom = 8.0
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color, Color.WHITE)

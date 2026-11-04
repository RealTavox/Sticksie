class_name OverviewSwitch
extends PanelContainer
## What the overview shows, as two buttons side by side on a panel in the overlays' look: the whole
## motif, or how far the stitching has come; the chosen one in the buttons' blue.

## The user chose the other view.
signal progress_changed(on: bool)

const MARGIN := 4.0

## Whether the current progress is chosen instead of the whole motif.
var progress := false:
	set(value):
		progress = value
		_motif_button.set_pressed_no_signal(not value)
		_progress_button.set_pressed_no_signal(value)

var _motif_button := Button.new()
var _progress_button := Button.new()


func _init() -> void:
	var style := OverlayWindow.panel_style()
	style.set_content_margin_all(MARGIN)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(MARGIN))
	add_child(row)
	var group := ButtonGroup.new()
	for entry: Array in [[_motif_button, "Gesamtmotiv", false], [_progress_button, "Aktueller Stand", true]]:
		var button: Button = entry[0]
		button.text = entry[1]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = OverlayWindow.BUTTON_HEIGHT
		_style(button)
		button.pressed.connect(_choose.bind(entry[2]))
		row.add_child(button)
	progress = false


## The buttons' own click, only when it changes the view.
func _choose(on: bool) -> void:
	if on != progress:
		progress = on
		progress_changed.emit(on)


## See-through grey like ChoiceCards, blue when chosen.
static func _style(button: Button) -> void:
	var colors := {"normal": ChoiceCards.CARD_COLOR, "hover": Color(1, 1, 1, 0.12), "pressed": OverlayWindow.PRIMARY_COLOR,
			"hover_pressed": OverlayWindow.PRIMARY_COLOR.lightened(0.08)}
	for state: String in colors:
		var style := StyleBoxFlat.new()
		style.bg_color = colors[state]
		style.set_corner_radius_all(12)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color, Color.WHITE)

class_name ThreadPicker
extends VBoxContainer
## Swapping one thread colour for another: the colour being replaced on top (`header_swatch`
## and `header_name`, which the screen flies in from the colour list), every other thread colour
## below as a ThreadGrid (as a grid or a list, all colours or only the project's), and buttons to
## cancel or confirm once a colour is chosen.

signal confirmed(old_code: String, new_code: String)
signal cancelled

const HEADER_SCALE := 1.3
const BUTTON_HEIGHT := 48.0
const TITLE_FONT_SIZE := 18

var header_swatch := SkeinSwatch.new(Color.WHITE, HEADER_SCALE)
var header_name := Label.new()

var _old: FlossColor
var _title := Label.new()
var _scroll := ScrollContainer.new()
var _grid := ThreadGrid.new()
var _hint := Label.new()
var _replace_button := Button.new()
var _list_button := Button.new()
var _project_button := Button.new()


func _init() -> void:
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	add_child(_title)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", roundi(4 * HEADER_SCALE))
	add_child(header)
	header.add_child(header_swatch)
	header_name.add_theme_font_size_override("font_size", roundi(16 * HEADER_SCALE))
	header_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(header_name)

	var view_row := HBoxContainer.new()
	add_child(view_row)
	for button: Button in [_list_button, _project_button]:
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggled.connect(func(_on: bool) -> void:
			_grid.set_view(_list_button.button_pressed, _project_button.button_pressed))
		view_row.add_child(button)
	_list_button.text = "Als Liste"
	OverlayWindow.set_icon(_list_button, ButtonIcons.Icon.LIST)
	_project_button.text = "Nur Farben aus diesem Projekt"
	OverlayWindow.set_icon(_project_button, ButtonIcons.Icon.FILTER)

	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_scroll.add_child(_grid)
	_grid.chosen.connect(_on_chosen)

	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.modulate.a = 0.7
	add_child(_hint)
	var buttons := HBoxContainer.new()
	add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Abbrechen"
	OverlayWindow.set_icon(cancel, ButtonIcons.Icon.CLOSE)
	cancel.custom_minimum_size.y = BUTTON_HEIGHT
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(cancelled.emit)
	buttons.add_child(cancel)
	_replace_button.text = "Ersetzen"
	OverlayWindow.set_icon(_replace_button, ButtonIcons.Icon.CHECK)
	OverlayWindow.make_primary(_replace_button)
	_replace_button.custom_minimum_size.y = BUTTON_HEIGHT
	_replace_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replace_button.focus_mode = Control.FOCUS_NONE
	_replace_button.pressed.connect(func() -> void:
		var chosen := _grid.selected_color()
		if chosen != null:
			confirmed.emit(_old.code, chosen.code))
	buttons.add_child(_replace_button)


## Shows every colour of `palette` except `old`, nothing chosen yet; `project_codes` are the
## colours of the open project, for the filter.
func open(old: FlossColor, palette: FlossPalette, project_codes: PackedStringArray) -> void:
	_old = old
	_title.text = "Farbe %s ersetzen" % old.code
	header_swatch.color = old.color
	header_name.text = old.name
	var others: Array[FlossColor] = []
	for floss in palette.colors:
		if floss.code != old.code:
			others.append(floss)
	_grid.set_colors(others, project_codes)
	_grid.set_view(_list_button.button_pressed, _project_button.button_pressed)
	_scroll.scroll_vertical = 0
	_on_chosen(null)


## Chooses the colour with `code` as if tapped (for screenshots).
func choose(code: String) -> void:
	_grid.choose(code)


## Switches to the list and/or the project's colours as if the buttons were pressed.
func set_view(list: bool, project_only: bool) -> void:
	_list_button.button_pressed = list
	_project_button.button_pressed = project_only


func is_animating() -> bool:
	return _grid.is_animating()


func _on_chosen(floss: FlossColor) -> void:
	_replace_button.disabled = floss == null
	if floss == null:
		_hint.text = "Tippe die neue Farbe an."
		return
	_hint.text = "DMC %s statt %s. Nochmal tippen: andere Farbe." % [floss.code, _old.code]
	# Keep the chosen colour in view while the others shrink away.
	var rect := _grid.selected_rect()
	var target := int(clampf(rect.get_center().y - _scroll.size.y / 2.0, 0.0,
			maxf(0.0, _grid.size.y - _scroll.size.y)))
	create_tween().tween_property(_scroll, "scroll_vertical", target, ThreadGrid.VANISH_SECONDS).set_trans(
			Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

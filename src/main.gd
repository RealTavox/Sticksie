extends Control
## Start screen: open a pixel-art image and show it as a cross-stitch pattern with its threads.
##
## Command line (after `--`): `--open=<path>` opens an image, `--screenshot=<png path>` saves
## a screenshot after a few frames and quits.

const SAMPLE_PATH := "res://samples/hypsi_anhaenger.png"
## Images bigger than this on either side are refused (most likely a photo, not pixel art).
const MAX_SIDE := 500
const BUTTON_HEIGHT := 48.0
const SWATCH_SIZE := Vector2(28, 28)
const CREDIT := "Garnfarben: craft-color-codes von MakeBead (makebead.com), CC BY 4.0"

var _palette: FlossPalette
var _image: Image
## Pattern with every colour of the image, for the colour list.
var _full_pattern: Pattern
## Thread codes the user marked as fabric (not stitched).
var _fabric_codes := PackedStringArray()

var _info_label: Label
var _body: BoxContainer
var _view: PatternView
var _side: VBoxContainer
var _color_list: VBoxContainer
var _file_dialog: FileDialog


func _ready() -> void:
	_palette = FlossPalette.dmc()
	_build_ui()
	resized.connect(_update_layout)
	_update_layout()
	_handle_cmdline()


func _build_ui() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.png ; PNG-Bilder"])
	_file_dialog.use_native_dialog = true
	_file_dialog.file_selected.connect(_open_image)
	add_child(_file_dialog)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)

	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	var open_button := Button.new()
	open_button.text = "Bild öffnen…"
	open_button.custom_minimum_size.y = BUTTON_HEIGHT
	open_button.pressed.connect(_file_dialog.popup_centered_ratio.bind(0.8))
	toolbar.add_child(open_button)
	var sample_button := Button.new()
	sample_button.text = "Beispiel"
	sample_button.custom_minimum_size.y = BUTTON_HEIGHT
	sample_button.pressed.connect(_open_image.bind(SAMPLE_PATH))
	toolbar.add_child(sample_button)
	_info_label = Label.new()
	_info_label.text = "Öffne ein Pixelart-Bild (PNG). Ein Pixel wird ein Kreuzstich."
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar.add_child(_info_label)

	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	_view = PatternView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_view)

	_side = VBoxContainer.new()
	_body.add_child(_side)
	var heading := Label.new()
	heading.text = "Garnfarben (DMC) · Stiche"
	_side.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(scroll)
	_color_list = VBoxContainer.new()
	_color_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_color_list)
	var credit := Label.new()
	credit.text = CREDIT
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit.add_theme_font_size_override("font_size", 12)
	credit.modulate.a = 0.6
	_side.add_child(credit)


## Portrait: pattern above the colour list; landscape: colour list on the right.
func _update_layout() -> void:
	var portrait := size.y > size.x
	_body.vertical = portrait
	if portrait:
		_side.custom_minimum_size = Vector2(0.0, size.y * 0.38)
	else:
		_side.custom_minimum_size = Vector2(minf(380.0, size.x * 0.4), 0.0)


func _open_image(path: String) -> void:
	var image: Image
	if path.begins_with("res://"):
		image = load(path) as Image
	else:
		image = Image.load_from_file(path)
	if image == null or image.is_empty():
		_info_label.text = "Bild konnte nicht geladen werden."
		return
	if image.get_width() > MAX_SIDE or image.get_height() > MAX_SIDE:
		_info_label.text = "Bild ist zu groß (%d × %d), höchstens %d Pixel pro Seite." % [
				image.get_width(), image.get_height(), MAX_SIDE]
		return
	if image.is_compressed():
		image.decompress()
	_image = image
	_full_pattern = PatternImporter.from_image(image, _palette)
	_fabric_codes = PackedStringArray()
	_show_pattern(false)
	_fill_color_list()


func _show_pattern(keep_view: bool) -> void:
	var pattern := PatternImporter.from_image(_image, _palette, _fabric_codes)
	_view.show_pattern(pattern, _palette, keep_view)
	_info_label.text = "%d × %d Felder · %d Farben · %d Stiche" % [
			pattern.width, pattern.height, pattern.thread_codes.size(), pattern.total_stitches()]


## One row per thread of the image, most stitches first.
func _fill_color_list() -> void:
	for child in _color_list.get_children():
		child.queue_free()
	var counts := _full_pattern.stitch_counts()
	var order := range(counts.size())
	order.sort_custom(func(a: int, b: int) -> bool: return counts[a] > counts[b])
	for i: int in order:
		var floss := _palette.find_code(_full_pattern.thread_codes[i])
		_color_list.add_child(_make_color_row(floss, counts[i]))


func _make_color_row(floss: FlossColor, count: int) -> Control:
	var row := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = floss.color
	swatch.custom_minimum_size = SWATCH_SIZE
	row.add_child(swatch)
	var code_label := Label.new()
	code_label.text = floss.code
	code_label.custom_minimum_size.x = 56.0
	row.add_child(code_label)
	var name_label := Label.new()
	name_label.text = floss.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	var count_label := Label.new()
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.custom_minimum_size.x = 56.0
	row.add_child(count_label)
	var fabric_box := CheckBox.new()
	fabric_box.text = "Stoff"
	fabric_box.tooltip_text = "Diese Farbe nicht sticken, hier bleibt der Stoff frei."
	fabric_box.button_pressed = _fabric_codes.has(floss.code)
	fabric_box.toggled.connect(_on_fabric_toggled.bind(floss.code))
	row.add_child(fabric_box)
	return row


func _on_fabric_toggled(pressed: bool, code: String) -> void:
	if pressed and not _fabric_codes.has(code):
		_fabric_codes.append(code)
	elif not pressed and _fabric_codes.has(code):
		_fabric_codes.remove_at(_fabric_codes.find(code))
	_show_pattern(true)


func _handle_cmdline() -> void:
	var screenshot_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--open="):
			_open_image(arg.trim_prefix("--open="))
		elif arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
	if screenshot_path.is_empty():
		return
	for i in 3:
		await get_tree().process_frame
	# Low processor mode draws only when something changed, so ask for one more frame.
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	get_tree().quit()

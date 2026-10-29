class_name ProjectBrowser
extends OverlayWindow
## Lists the saved projects with a preview picture each, to open, rename, export or delete them,
## and imports exported ones. Deleting asks first, since it can't be undone. Renaming and deleting happen here; the signals
## let the start screen follow when it concerns the open project. The questions come up as
## smaller windows of the same look on top.

signal open_requested(path: String)
signal project_renamed(path: String, new_name: String)
signal project_deleted(path: String)
## The user wants the project saved at `path` as a file of their own.
signal export_requested(path: String, project_name: String)
## The user wants to pick an exported project file and add it.
signal import_requested

const PREVIEW_SIZE := Vector2(96, 96)

## Path of the project open on the start screen, marked in the list.
var current_path := ""

var _storage_label: Label
var _list: VBoxContainer
var _empty_label: Label
var _status_label: Label
var _rename_window: OverlayWindow
var _rename_edit: LineEdit
var _rename_button: Button
var _delete_window: OverlayWindow
var _delete_label: Label
## Project the rename or delete window is about.
var _target := {}


func _init() -> void:
	super("Projekte")
	fill_height = true
	close_on_outside_tap = true
	# Where the browser may lose the projects, a warning on top (BrowserStorage).
	_storage_label = Label.new()
	_storage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_storage_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	content.add_child(_storage_label)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	content.add_child(_list)
	_empty_label = Label.new()
	_empty_label.text = ("Noch keine Projekte. Öffne ein Bild, dann wird es hier gespeichert, "
			+ "oder importiere ein exportiertes Projekt.")
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_empty_label)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)
	buttons.add_child(make_button("Projekt importieren", ButtonIcons.Icon.IMPORT, import_requested.emit))

	_rename_window = OverlayWindow.new("Umbenennen")
	_rename_window.max_width = 420.0
	_rename_edit = LineEdit.new()
	_rename_edit.custom_minimum_size.y = BUTTON_HEIGHT
	_rename_edit.text_changed.connect(
			func(text: String) -> void: _rename_button.disabled = text.strip_edges().is_empty())
	_rename_edit.text_submitted.connect(func(_text: String) -> void: _rename())
	_rename_window.content.add_child(_rename_edit)
	_rename_window.buttons.add_child(make_button("Abbrechen", ButtonIcons.Icon.CLOSE, _rename_window.close))
	_rename_button = make_button("Umbenennen", ButtonIcons.Icon.PENCIL, _rename)
	_rename_window.buttons.add_child(_rename_button)
	add_child(_rename_window)

	_delete_window = OverlayWindow.new("Endgültig löschen?")
	_delete_window.max_width = 420.0
	_delete_label = Label.new()
	_delete_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_delete_window.content.add_child(_delete_label)
	_delete_window.buttons.add_child(make_button("Abbrechen", ButtonIcons.Icon.CLOSE, _delete_window.close))
	_delete_window.buttons.add_child(make_button("Endgültig löschen", ButtonIcons.Icon.TRASH, _delete))
	add_child(_delete_window)


## Fills the list from the saved files and opens the window.
func open() -> void:
	_status_label.text = ""
	_storage_label.text = BrowserStorage.warning()
	_storage_label.visible = not _storage_label.text.is_empty()
	_fill()
	super()


func _fill() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var entries := ProjectStore.list()
	_empty_label.visible = entries.is_empty()
	for entry in entries:
		_list.add_child(_make_row(entry))


## A project's row; the open project's is blue like a pressed button.
func _make_row(entry: Dictionary) -> Control:
	var frame := PanelContainer.new()
	var background := StyleBoxFlat.new()
	background.set_corner_radius_all(8)
	background.set_content_margin_all(8)
	background.bg_color = PRIMARY_COLOR if entry.path == current_path else Color.TRANSPARENT
	frame.add_theme_stylebox_override("panel", background)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	frame.add_child(row)
	var picture := TextureRect.new()
	picture.custom_minimum_size = PREVIEW_SIZE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if entry.preview != null:
		picture.texture = ImageTexture.create_from_image(entry.preview)
	row.add_child(picture)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var name_label := Label.new()
	name_label.text = entry.name + ("  (geöffnet)" if entry.path == current_path else "")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 20)
	column.add_child(name_label)
	var info_label := Label.new()
	info_label.text = "%d × %d Felder · gespeichert %s" % [entry.width, entry.height,
			str(entry.saved_at).replace("T", " ").left(16)]
	info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_label.modulate.a = 0.7
	column.add_child(info_label)
	var row_buttons := HFlowContainer.new()
	column.add_child(row_buttons)
	row_buttons.add_child(make_button("Öffnen", ButtonIcons.Icon.FOLDER, func() -> void:
		close()
		open_requested.emit(entry.path)))
	row_buttons.add_child(make_button("Umbenennen", ButtonIcons.Icon.PENCIL, _ask_rename.bind(entry)))
	row_buttons.add_child(make_button("Exportieren", ButtonIcons.Icon.EXPORT, func() -> void:
		export_requested.emit(entry.path, entry.name)))
	row_buttons.add_child(make_button("Löschen", ButtonIcons.Icon.TRASH, _ask_delete.bind(entry)))
	return frame


## Shows `text` under the list, e.g. why an import or export failed.
func show_status(text: String) -> void:
	_status_label.text = text


func _ask_rename(entry: Dictionary) -> void:
	_target = entry
	_rename_edit.text = entry.name
	_rename_button.disabled = false
	_rename_window.safe_area = safe_area
	_rename_window.open()
	_rename_edit.grab_focus()
	_rename_edit.select_all()


func _rename() -> void:
	var new_name := _rename_edit.text.strip_edges()
	if new_name.is_empty():
		return
	_rename_window.close()
	var error := ProjectStore.rename(_target.path, new_name)
	if error != OK:
		_status_label.text = "Umbenennen fehlgeschlagen: %s" % error_string(error)
		return
	project_renamed.emit(_target.path, new_name)
	_fill()


func _ask_delete(entry: Dictionary) -> void:
	_target = entry
	_delete_label.text = ("„%s“ wird mit dem ganzen Stickfortschritt gelöscht. "
			+ "Das lässt sich nicht rückgängig machen.") % entry.name
	_delete_window.safe_area = safe_area
	_delete_window.open()


func _delete() -> void:
	_delete_window.close()
	var error := ProjectStore.delete(_target.path)
	if error != OK:
		_status_label.text = "Löschen fehlgeschlagen: %s" % error_string(error)
		return
	project_deleted.emit(_target.path)
	_fill()

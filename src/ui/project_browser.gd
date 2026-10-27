class_name ProjectBrowser
extends AcceptDialog
## Lists the saved projects with a preview picture each, to open, rename or delete them.
## Deleting asks first, since it can't be undone. Renaming and deleting happen here; the signals
## let the start screen follow when it concerns the open project.

signal open_requested(path: String)
signal project_renamed(path: String, new_name: String)
signal project_deleted(path: String)

const BUTTON_HEIGHT := 48.0
const PREVIEW_SIZE := Vector2(96, 96)

## Path of the project open on the start screen, marked in the list.
var current_path := ""

var _list: VBoxContainer
var _empty_label: Label
var _status_label: Label
var _rename_dialog: ConfirmationDialog
var _rename_edit: LineEdit
var _delete_dialog: ConfirmationDialog
## Project the rename or delete dialog is about.
var _target := {}


func _init() -> void:
	title = "Projekte"
	ok_button_text = "Schließen"
	var content := VBoxContainer.new()
	add_child(content)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_empty_label = Label.new()
	_empty_label.text = "Noch keine Projekte. Öffne ein Bild, dann wird es hier gespeichert."
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_empty_label)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)

	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Umbenennen"
	_rename_dialog.ok_button_text = "Umbenennen"
	_rename_dialog.cancel_button_text = "Abbrechen"
	_rename_edit = LineEdit.new()
	_rename_edit.custom_minimum_size = Vector2(320, BUTTON_HEIGHT)
	_rename_edit.text_changed.connect(
			func(text: String) -> void: _rename_dialog.get_ok_button().disabled = text.strip_edges().is_empty())
	_rename_dialog.add_child(_rename_edit)
	_rename_dialog.register_text_enter(_rename_edit)
	_rename_dialog.confirmed.connect(_rename)
	add_child(_rename_dialog)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Endgültig löschen?"
	_delete_dialog.ok_button_text = "Endgültig löschen"
	_delete_dialog.cancel_button_text = "Abbrechen"
	_delete_dialog.dialog_autowrap = true
	_delete_dialog.confirmed.connect(_delete)
	add_child(_delete_dialog)


## Fills the list from the saved files and shows the dialog.
func open() -> void:
	_status_label.text = ""
	_fill()
	popup_centered_ratio(0.9)


func _fill() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var entries := ProjectStore.list()
	_empty_label.visible = entries.is_empty()
	for entry in entries:
		_list.add_child(_make_row(entry))


func _make_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
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
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	buttons.add_child(_make_button("Öffnen", func() -> void:
		hide()
		open_requested.emit(entry.path)))
	buttons.add_child(_make_button("Umbenennen", _ask_rename.bind(entry)))
	buttons.add_child(_make_button("Löschen", _ask_delete.bind(entry)))
	return row


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


func _ask_rename(entry: Dictionary) -> void:
	_target = entry
	_rename_edit.text = entry.name
	_rename_dialog.get_ok_button().disabled = false
	_rename_dialog.popup_centered()
	_rename_edit.grab_focus()
	_rename_edit.select_all()


func _rename() -> void:
	var new_name := _rename_edit.text.strip_edges()
	var error := ProjectStore.rename(_target.path, new_name)
	if error != OK:
		_status_label.text = "Umbenennen fehlgeschlagen: %s" % error_string(error)
		return
	project_renamed.emit(_target.path, new_name)
	_fill()


func _ask_delete(entry: Dictionary) -> void:
	_target = entry
	_delete_dialog.dialog_text = ("„%s“ wird mit dem ganzen Stickfortschritt gelöscht.\n"
			+ "Das lässt sich nicht rückgängig machen.") % entry.name
	_delete_dialog.popup_centered(Vector2(400, 0))


func _delete() -> void:
	var error := ProjectStore.delete(_target.path)
	if error != OK:
		_status_label.text = "Löschen fehlgeschlagen: %s" % error_string(error)
		return
	project_deleted.emit(_target.path)
	_fill()

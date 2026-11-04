class_name FileExchange
extends Node
## Brings files into the app and hands them out: the system's file dialogs in the app; in the
## browser, where the app only sees its own storage, the browser's file picker and a download.

## The app's own dialog closed, with or without a file. Not in the browser, whose picker covers
## nothing of the app.
signal closed
## Reading or writing a file went wrong; `message` is for the user.
signal failed(message: String)

## What the user picks: a pixel-art image or a project file someone exported.
enum Kind { IMAGE, PROJECT }

## Per kind: the filter of the app's dialog and the browser picker's accept list.
const FILTERS := {
	Kind.IMAGE: ["*.png ; PNG-Bilder", ".png,image/png"],
	Kind.PROJECT: ["*.json ; Sticksie-Projekte", ".json,application/json"],
}

## The browser side, set up once: a file picker and a download, called through JavaScriptBridge.
const BROWSER_HELPER := """
window.sticksieFiles = {
	// Opens the browser's file picker; calls `done` with the chosen file's name and contents (an
	// ArrayBuffer). Browsers open it only shortly after a tap, which the app's button press is.
	pick(accept, done) {
		const input = document.createElement("input");
		input.type = "file";
		input.accept = accept;
		input.style.display = "none";
		document.body.appendChild(input);
		input.addEventListener("cancel", () => input.remove());
		input.addEventListener("change", () => {
			const file = input.files[0];
			input.remove();
			if (file) {
				file.arrayBuffer().then((buffer) => done(file.name, buffer));
			}
		});
		try {
			input.showPicker();
		} catch (error) {
			input.click();
		}
	},
	// Downloads `text` as a file named `name`. The link is revoked only after a while, as some
	// browsers fetch the file after the click has returned.
	save(text, name, type) {
		const url = URL.createObjectURL(new Blob([text], { type: type }));
		const link = document.createElement("a");
		link.href = url;
		link.download = name;
		link.style.display = "none";
		document.body.appendChild(link);
		link.click();
		link.remove();
		setTimeout(() => URL.revokeObjectURL(url), 60000);
	},
};
"""

var _open_dialog: FileDialog
var _save_dialog: FileDialog
## Called with the picked file's name and bytes.
var _on_picked := Callable()
## What the save dialog writes once the user chose where.
var _save_text := ""
## Kept so the browser can call back after the picker closes.
var _browser_picked: JavaScriptObject


## Whether the app runs in a browser, where only the picker and downloads reach the device's files.
static func in_browser() -> bool:
	return OS.has_feature("web")


func _ready() -> void:
	if in_browser():
		JavaScriptBridge.eval(BROWSER_HELPER, true)
		_browser_picked = JavaScriptBridge.create_callback(func(args: Array) -> void:
			_on_picked.call(str(args[0]), JavaScriptBridge.js_buffer_to_packed_byte_array(args[1])))
		return
	_open_dialog = _make_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	_open_dialog.file_selected.connect(func(path: String) -> void:
		closed.emit()
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty() and FileAccess.get_open_error() != OK:
			failed.emit("„%s“ ließ sich nicht lesen: %s" % [path.get_file(),
					error_string(FileAccess.get_open_error())])
			return
		_on_picked.call(path.get_file(), bytes))
	_save_dialog = _make_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	_save_dialog.file_selected.connect(func(path: String) -> void:
		closed.emit()
		write_text(path, _save_text))


## Lets the user pick a file of `kind`; `on_picked` gets its name and bytes.
func pick(kind: Kind, on_picked: Callable) -> void:
	_on_picked = on_picked
	if in_browser():
		JavaScriptBridge.get_interface("sticksieFiles").pick(FILTERS[kind][1], _browser_picked)
		return
	_open_dialog.filters = PackedStringArray([FILTERS[kind][0]])
	_open_dialog.popup_centered_ratio(0.8)


## Hands `text` out as a project file named `file_name`: a download in the browser, else where the
## user chooses.
func save_text(file_name: String, text: String) -> void:
	if in_browser():
		JavaScriptBridge.get_interface("sticksieFiles").save(text, file_name, "application/json")
		return
	_save_text = text
	_save_dialog.filters = PackedStringArray([FILTERS[Kind.PROJECT][0]])
	_save_dialog.current_file = file_name
	_save_dialog.popup_centered_ratio(0.8)


## Writes `text` to `path` outside the app's storage, as the save dialog does.
func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failed.emit("Speichern von „%s“ fehlgeschlagen: %s" % [path.get_file(),
				error_string(FileAccess.get_open_error())])
		return
	file.store_string(text)
	var error := file.get_error()
	file.close()
	if error != OK:
		failed.emit("Speichern von „%s“ fehlgeschlagen: %s" % [path.get_file(), error_string(error)])


func _make_dialog(mode: FileDialog.FileMode) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.canceled.connect(closed.emit)
	add_child(dialog)
	return dialog

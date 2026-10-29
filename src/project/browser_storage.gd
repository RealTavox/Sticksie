class_name BrowserStorage
## In the browser the projects live in its storage (IndexedDB, via user://), which the browser may
## clear: Safari after 7 days without a visit (not for a web app on the Home Screen), any browser
## when space runs short, a private window when it closes. This asks the browser to keep it and
## says how safe the projects are, for the warnings.

enum Safety {
	## Outside the browser, or the browser promised to keep the storage.
	SAFE,
	## Saved, but the browser may clear it.
	MAY_BE_CLEARED,
	## The browser keeps nothing (no IndexedDB, e.g. a private window): gone when the page closes.
	NOT_KEPT,
}

static var safety := Safety.SAFE
## Takes the browser's answers; kept, so it is still there when they come.
static var _answer: JavaScriptObject


## Finds out how safe the storage is, without asking the user (navigator.storage.persisted()).
static func check() -> void:
	_ask(false)


## Asks the browser to keep the storage (navigator.storage.persist()). Some browsers decide by
## themselves (Safari: yes for a Home Screen web app), Firefox asks the user; so this is done
## once there is a project to keep.
static func request() -> void:
	_ask(true)


## What the user should know about the storage, or "" while it is safe.
static func warning() -> String:
	match safety:
		Safety.MAY_BE_CLEARED:
			return ("Der Browser darf deine Projekte löschen, Safari etwa nach 7 Tagen ohne Besuch. "
					+ "Sichere wichtige Projekte mit „Exportieren“. Als App auf dem Home-Bildschirm "
					+ "sind sie besser geschützt, haben dort aber einen eigenen Speicher: Projekte "
					+ "mit Exportieren und Importieren mitnehmen.")
		Safety.NOT_KEPT:
			return ("Achtung: Der Browser speichert hier nichts dauerhaft, etwa in einem privaten "
					+ "Fenster. Schließt du die Seite, sind deine Projekte weg. Sichere sie vorher "
					+ "mit „Exportieren“ in der Projektliste.")
	return ""


static func _ask(persist: bool) -> void:
	if not OS.has_feature("web"):
		return
	if not OS.is_userfs_persistent():
		safety = Safety.NOT_KEPT
		return
	var storage: Variant = JavaScriptBridge.get_interface("navigator").storage
	if storage == null:
		safety = Safety.MAY_BE_CLEARED
		return
	if not persist:
		safety = Safety.MAY_BE_CLEARED  # until the browser says otherwise
	if _answer == null:
		_answer = JavaScriptBridge.create_callback(func(args: Array) -> void:
			safety = Safety.SAFE if args[0] == true else Safety.MAY_BE_CLEARED)
	var promise: JavaScriptObject = storage.persist() if persist else storage.persisted()
	promise.then(_answer)

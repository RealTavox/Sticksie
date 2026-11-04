class_name ColorQuestion
extends OverlayWindow
## Asks whether to stitch the colour of the area tapped in the overview: which colour it is and how
## far it has come, with Abbrechen and a blue OK with the needle.

## The user pressed OK; the window closes right after.
signal confirmed(thread: int)

const NEEDLE_ICON_PX := 96

var ok_button: Button

var _thread := -1
var _swatch := SkeinSwatch.new(Color.WHITE)
var _name_label := Label.new()
var _status_label := Label.new()


func _init() -> void:
	super("Diese Farbe sticken?")
	max_width = 480.0
	close_on_outside_tap = true
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_swatch)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	for label: Label in [_name_label, _status_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(label)
	buttons.add_child(make_button("Abbrechen", ButtonIcons.Icon.CLOSE, close))
	ok_button = make_button("OK", -1, _confirm)
	set_needle_icon(ok_button, NEEDLE_ICON_PX)
	make_primary(ok_button)
	buttons.add_child(ok_button)


## Fills the window in for `floss`, thread `thread` of the pattern; open() shows it.
func ask(floss: FlossColor, thread: int, done: int, total: int) -> void:
	_thread = thread
	_swatch.color = floss.color
	_name_label.text = "DMC %s · %s" % [floss.code, floss.name]
	_status_label.text = status_text(done, total)


## How far a colour has come, from its finished crosses and all its stitches.
static func status_text(done: int, total: int) -> String:
	if done >= total:
		return "Schon fertig gestickt."
	if done > 0:
		return "%d von %d Stichen gestickt." % [done, total]
	return "1 Stich" if total == 1 else "%d Stiche" % total


func _confirm() -> void:
	confirmed.emit(_thread)
	close()

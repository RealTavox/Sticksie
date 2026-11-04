extends SceneTree
## Writes every logo file from one description of the mark, so they can't drift apart.
## `Godot --headless --path . --script res://tools/make_logo.gd`
##
## assets/logo/ (ignored by Godot, not exported): the SVG sources and the favicon.
## assets/icon.png, assets/splash.png: what project.godot uses.

const BLUE := "#2B78E0" # RoundButton.DEFAULT_TINT
const CREAM := "#F5F1E6" # StitchScene.FABRIC_COLOR
const ORANGE := "#FF800D" # PatternView.HIGHLIGHT_COLOR
const SIZE := 512.0
const CORNER := 112.0
const STROKE_SHARE := 23.0 / 60.0 # of a cell
const INSET_SHARE := 0.14 # of a cell, where a leg ends

## X a whole cross, / the half stitch still being worked (the step the app is guiding).
const S_MARK: Array[String] = [
	".XXXX",
	"X....",
	"X....",
	".XXX.",
	"....X",
	"....X",
	"/XXX.",
]
## "Sticksie", a letter each, seven rows high.
const LETTERS: Array[Array] = [
	S_MARK,
	[".X.", ".X.", "XXX", ".X.", ".X.", ".X.", "..X"], # t
	["X", ".", "X", "X", "X", "X", "X"], # i
	["....", "....", ".XXX", "X...", "X...", "X...", ".XXX"], # c
	["X...", "X...", "X..X", "X.X.", "XX..", "X.X.", "X..X"], # k
	["....", "....", ".XXX", "X...", ".XX.", "...X", "XXX."], # s
	["X", ".", "X", "X", "X", "X", "X"], # i
	["....", "....", ".XX.", "X..X", "XXXX", "X...", ".XXX"], # e
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(_path("res://assets/logo"))
	_write("res://assets/logo/.gdignore", "")
	var icon := _rounded(_crosses(S_MARK, 60.0, 256.0, 256.0, CREAM, ORANGE))
	_write("res://assets/logo/logo.svg", icon)
	_write("res://assets/logo/logo-square.svg", _canvas(SIZE, SIZE,
			_background(false) + _crosses(S_MARK, 60.0, 256.0, 256.0, CREAM, ORANGE)))
	var small := _rounded(_pixels())
	_write("res://assets/logo/logo-small.svg", small)
	# Android's launcher crops an adaptive icon to at most the middle 66/108 of its width.
	_write("res://assets/logo/android-foreground.svg", _canvas(SIZE, SIZE,
			_crosses(S_MARK, 36.0, 256.0, 256.0, CREAM, ORANGE)))
	_write("res://assets/logo/android-monochrome.svg", _canvas(SIZE, SIZE,
			_crosses(S_MARK, 36.0, 256.0, 256.0, "#FFFFFF", "#FFFFFF")))
	_write("res://assets/logo/wordmark.svg", _wordmark(BLUE))
	_write("res://assets/logo/wordmark-light.svg", _wordmark(CREAM))
	_render(icon, 512, "res://assets/icon.png")
	_render(small, 32, "res://assets/logo/favicon-32.png")
	_render(_splash(), 1024, "res://assets/splash.png")
	quit()


func _canvas(width: float, height: float, body: String) -> String:
	return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">%s</svg>\n'
			% [width, height, width, height, body])


func _background(rounded: bool) -> String:
	return '<rect width="%d" height="%d" rx="%d" fill="%s"/>' % [SIZE, SIZE, CORNER if rounded else 0, BLUE]


func _rounded(body: String) -> String:
	return _canvas(SIZE, SIZE, _background(true) + body)


func _leg(from: Vector2, to: Vector2, color: String, width: float) -> String:
	return ('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f" stroke-linecap="round"/>'
			% [from.x, from.y, to.x, to.y, color, width])


## The rows as stitches, centred on (center_x, center_y).
func _crosses(rows: Array[String], cell: float, center_x: float, center_y: float,
		color: String, half_color: String) -> String:
	var origin := Vector2(center_x - rows[0].length() * cell / 2.0, center_y - rows.size() * cell / 2.0)
	var inset := cell * INSET_SHARE
	var width := cell * STROKE_SHARE
	var body := ""
	for y in rows.size():
		for x in rows[y].length():
			var mark := rows[y][x]
			if mark == ".":
				continue
			var low := origin + Vector2(x, y) * cell + Vector2(inset, inset)
			var high := low + Vector2(cell - 2.0 * inset, cell - 2.0 * inset)
			if mark == "X":
				body += _leg(low, high, color, width)
			body += _leg(Vector2(low.x, high.y), Vector2(high.x, low.y),
					color if mark == "X" else half_color, width)
	return body


## The S for 16 to 48 px, where crosses blur: filled cells on whole pixels at 32 px (16 units).
func _pixels() -> String:
	const CELL := 48
	const LEFT := 128
	const TOP := 80
	var body := ""
	for y in S_MARK.size():
		for x in S_MARK[y].length():
			if S_MARK[y][x] != ".":
				body += '<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [LEFT + x * CELL, TOP + y * CELL,
						CELL, CELL, ORANGE if S_MARK[y][x] == "/" else CREAM]
	return body


func _wordmark(color: String) -> String:
	const CELL := 40.0
	var rows: Array[String] = []
	for y in S_MARK.size():
		var row := ""
		for letter: Array in LETTERS:
			row += ("." if row else "") + letter[y]
		rows.append(row)
	var width: float = rows[0].length() * CELL + CELL
	var height: float = rows.size() * CELL + CELL
	return _canvas(width, height, _crosses(rows, CELL, width / 2.0, height / 2.0, color, ORANGE))


## Transparent, on the splash's plain background; square and padded, so it fits either orientation.
func _splash() -> String:
	return _canvas(SIZE, SIZE, _crosses(S_MARK, 30.0, 256.0, 256.0, CREAM, ORANGE))


func _render(svg: String, size: int, target: String) -> void:
	var image := Image.new()
	var error := image.load_svg_from_string(svg, size / SIZE)
	if error == OK:
		error = image.save_png(_path(target))
	if error != OK:
		push_error("Could not render %s: %s" % [target, error_string(error)])


func _write(target: String, text: String) -> void:
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % target)
		return
	file.store_string(text)


func _path(res_path: String) -> String:
	return ProjectSettings.globalize_path(res_path)

class_name FlossPalette
extends RefCounted
## A set of thread colours loaded from a CSV file with the columns
## code,name,hex,r,g,b,discontinued (see data/threads/SOURCE.md).

const DMC_PATH := "res://data/threads/dmc-floss.csv"

static var _dmc: FlossPalette

var colors: Array[FlossColor] = []
var _by_code: Dictionary = {}  # String -> FlossColor


## The DMC palette, loaded once and shared.
static func dmc() -> FlossPalette:
	if _dmc == null:
		_dmc = load_csv(DMC_PATH)
	return _dmc


## Loads a palette; discontinued colours are left out. Returns an empty palette on error.
static func load_csv(path: String) -> FlossPalette:
	var palette := FlossPalette.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open thread palette %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return palette
	var header := file.get_csv_line()
	var i_code := header.find("code")
	var i_name := header.find("name")
	var i_r := header.find("r")
	var i_g := header.find("g")
	var i_b := header.find("b")
	var i_discontinued := header.find("discontinued")
	if mini(mini(i_code, i_name), mini(mini(i_r, i_g), i_b)) < 0:
		push_error("Thread palette %s lacks a column: %s" % [path, ",".join(header)])
		return palette
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < header.size():
			continue
		if i_discontinued >= 0 and row[i_discontinued] == "true":
			continue
		var color := Color8(row[i_r].to_int(), row[i_g].to_int(), row[i_b].to_int())
		var floss := FlossColor.new(row[i_code], row[i_name], color)
		palette.colors.append(floss)
		palette._by_code[floss.code] = floss
	return palette


## The thread with this code, or null.
func find_code(code: String) -> FlossColor:
	return _by_code.get(code)


## The thread closest to `color` by CIEDE2000, or null for an empty palette.
func nearest(color: Color) -> FlossColor:
	var lab := ColorLab.from_color(color)
	var best: FlossColor = null
	var best_distance := INF
	for floss in colors:
		var distance := ColorLab.delta_e(lab, floss.lab)
		if distance < best_distance:
			best_distance = distance
			best = floss
	return best

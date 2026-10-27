extends SceneTree
## Plain checks of the pattern logic, no framework:
## `Godot --headless --path . --script res://tests/run_tests.gd`. Exits with 1 on any failure.

var _failures := 0


func _initialize() -> void:
	_test_lab()
	_test_delta_e()
	_test_palette()
	_test_import_sample()
	_test_import_transparent()
	_test_split_blocks()
	_test_planner_rows()
	_test_planner_order()
	_test_planner_covers_sample()
	if _failures == 0:
		print("All tests passed.")
	else:
		printerr("%d check(s) failed." % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)


func _test_lab() -> void:
	var white := ColorLab.from_color(Color.WHITE)
	_check(white.distance_to(Vector3(100, 0, 0)) < 0.01, "white is Lab(100, 0, 0), got %s" % white)
	var black := ColorLab.from_color(Color.BLACK)
	_check(black.length() < 0.01, "black is Lab(0, 0, 0), got %s" % black)


## Reference pairs from Sharma, Wu & Dalal (2005), "The CIEDE2000 color-difference formula".
func _test_delta_e() -> void:
	var pairs := [
		[Vector3(50, 2.6772, -79.7751), Vector3(50, 0, -82.7485), 2.0425],
		[Vector3(50, 0, 0), Vector3(50, -1, 2), 2.3669],
		[Vector3(50, 2.5, 0), Vector3(73, 25, -18), 27.1492],
		[Vector3(60.2574, -34.0099, 36.2677), Vector3(60.4626, -34.1751, 39.4387), 1.2644],
		[Vector3(2.0776, 0.0795, -1.135), Vector3(0.9033, -0.0636, -0.5514), 0.9082],
	]
	for pair in pairs:
		var got := ColorLab.delta_e(pair[0], pair[1])
		_check(absf(got - pair[2]) < 0.0001, "delta_e%s = %.4f, expected %.4f" % [pair.slice(0, 2), got, pair[2]])
		var back := ColorLab.delta_e(pair[1], pair[0])
		_check(absf(back - got) < 0.0001, "delta_e is symmetric for %s" % [pair.slice(0, 2)])


func _test_palette() -> void:
	var palette := FlossPalette.dmc()
	_check(palette.colors.size() == 489, "DMC palette has 489 colours, got %d" % palette.colors.size())
	var black := palette.find_code("310")
	_check(black != null and black.name == "Black", "DMC 310 is Black")
	for code in ["309", "Blanc", "B5200", "3865"]:
		var floss := palette.find_code(code)
		_check(floss != null and palette.nearest(floss.color).code == code,
				"exact colour of DMC %s matches itself" % code)


func _test_import_sample() -> void:
	var palette := FlossPalette.dmc()
	var image := load("res://samples/hypsi_anhaenger.png") as Image
	_check(image != null, "sample loads as Image")
	if image == null:
		return
	var full := PatternImporter.from_image(image, palette)
	_check(full.width == 60 and full.height == 41, "sample is 60 × 41")
	_check(full.total_stitches() == 60 * 41, "opaque sample stitches every cell")
	_check(full.thread_codes.size() >= 1 and full.thread_codes.size() <= 10,
			"sample has 1–10 threads, got %d" % full.thread_codes.size())
	var counts := full.stitch_counts()
	var sum := 0
	for c in counts:
		sum += c
	_check(sum == full.total_stitches(), "stitch counts add up")

	var background := palette.nearest(Color8(192, 203, 220)).code
	_check(background == "800", "sample background is DMC 800, got %s" % background)
	var without := PatternImporter.from_image(image, palette, PackedStringArray([background]))
	var background_count := counts[full.thread_codes.find(background)]
	_check(without.total_stitches() == full.total_stitches() - background_count,
			"fabric thread is left out")
	_check(not without.thread_codes.has(background), "fabric thread is not in the thread list")
	_check(without.get_cell(1, 1) == Pattern.EMPTY, "background cell inside the frame is empty")
	_check(without.get_cell(0, 0) != Pattern.EMPTY, "frame cell is still stitched")


func _test_import_transparent() -> void:
	var image := Image.create_empty(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(1, 0, 0, 0))
	image.set_pixel(1, 0, Color(1, 0, 0, 1))
	var pattern := PatternImporter.from_image(image, FlossPalette.dmc())
	_check(pattern.get_cell(0, 0) == Pattern.EMPTY, "transparent pixel stays empty")
	_check(pattern.get_cell(1, 0) == 0, "opaque pixel gets a thread")


## Pattern from text rows: a digit is that thread index, "." is fabric.
func _pattern(rows: Array[String]) -> Pattern:
	var pattern := Pattern.new()
	pattern.width = rows[0].length()
	pattern.height = rows.size()
	var highest := -1
	for row in rows:
		for ch in row:
			var index := Pattern.EMPTY if ch == "." else ch.to_int()
			pattern.cells.append(index)
			highest = maxi(highest, index)
	for i in highest + 1:
		pattern.thread_codes.append(str(i))
	return pattern


func _describe(steps: Array[StitchStep]) -> Array[String]:
	var result: Array[String] = []
	for step in steps:
		result.append(str(step))
	return result


func _test_split_blocks() -> void:
	var cases := {10: [5, 5], 7: [4, 3], 6: [3, 3], 11: [4, 4, 3], 5: [5], 2: [2], 1: [1]}
	for n: int in cases:
		var cells := PackedInt32Array(range(n))
		var sizes := []
		var joined := PackedInt32Array()
		for block in StitchPlanner.split_blocks(cells):
			sizes.append(block.size())
			joined.append_array(block)
		_check(sizes == cases[n], "split %d into %s, got %s" % [n, cases[n], sizes])
		_check(joined == cells, "split %d keeps order" % n)


func _test_planner_rows() -> void:
	# DESIGN.md example: 10 cells → 5 right, 5 right, 5 back, 5 back.
	var got := _describe(StitchPlanner.plan(_pattern(["0000000000"]), 0))
	var expected := ["HALF row 0 [0, 1, 2, 3, 4]", "HALF row 0 [5, 6, 7, 8, 9]",
			"BACK row 0 [9, 8, 7, 6, 5]", "BACK row 0 [4, 3, 2, 1, 0]"]
	_check(got == expected, "10 in a row: %s" % [got])

	# A gap of 3 is skipped on the back, a gap of 4 splits the row.
	got = _describe(StitchPlanner.plan(_pattern(["00...00....0"]), 0))
	expected = ["HALF row 0 [0, 1, 5, 6]", "BACK row 0 [6, 5, 1, 0]", "CROSS row 0 [11]"]
	_check(got == expected, "gaps: %s" % [got])

	# Other threads are left alone.
	got = _describe(StitchPlanner.plan(_pattern(["0110"]), 1))
	_check(got == ["HALF row 0 [1, 2]", "BACK row 0 [2, 1]"], "other thread: %s" % [got])


func _test_planner_order() -> void:
	var pattern := _pattern(["00.", "000"])
	var got := _describe(StitchPlanner.plan(pattern, 0, false, false))
	var expected := ["HALF row 1 [2, 1, 0]", "BACK row 1 [0, 1, 2]",
			"HALF row 0 [1, 0]", "BACK row 0 [0, 1]"]
	_check(got == expected, "bottom up, from the right: %s" % [got])
	var steps := StitchPlanner.plan(pattern, 0, true, false)
	_check(steps[0].direction == -1 and steps[1].direction == 1, "directions from the right")


## Every cell of a thread is stitched exactly once as a whole cross, in blocks of at most 5.
func _test_planner_covers_sample() -> void:
	var image := load("res://samples/hypsi_anhaenger.png") as Image
	var pattern := PatternImporter.from_image(image, FlossPalette.dmc())
	for thread in pattern.thread_codes.size():
		var halves := {}
		var backs := {}
		var ok := true
		for step in StitchPlanner.plan(pattern, thread):
			ok = ok and step.cells.size() <= StitchPlanner.MAX_BLOCK and step.thread == thread
			for x in step.cells:
				var key := Vector2i(x, step.row)
				ok = ok and pattern.get_cell(x, step.row) == thread
				if step.kind != StitchStep.Kind.BACK:
					ok = ok and not halves.has(key)
					halves[key] = true
				if step.kind != StitchStep.Kind.HALF:
					ok = ok and not backs.has(key)
					backs[key] = true
		var count := pattern.stitch_counts()[thread]
		_check(ok and halves.size() == count and backs.size() == count,
				"thread %s: every cell crossed once (%d cells, %d bottom legs, %d top legs)" % [
					pattern.thread_codes[thread], count, halves.size(), backs.size()])

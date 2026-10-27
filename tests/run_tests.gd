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
	_test_session()
	_test_position_hint()
	_test_describe_offset()
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

	# A gap of 3 is skipped on the back between blocks, a gap of 4 splits the row.
	got = _describe(StitchPlanner.plan(_pattern(["00...00....0"]), 0))
	expected = ["HALF row 0 [0, 1]", "HALF row 0 [5, 6] skip 3", "BACK row 0 [6, 5]",
			"BACK row 0 [1, 0] skip 3", "CROSS row 0 [11]"]
	_check(got == expected, "gaps: %s" % [got])

	# Blocks never span a gap; each run of adjacent cells is split on its own.
	got = _describe(StitchPlanner.plan(_pattern(["0000000..00"]), 0))
	expected = ["HALF row 0 [0, 1, 2, 3]", "HALF row 0 [4, 5, 6]", "HALF row 0 [9, 10] skip 2",
			"BACK row 0 [10, 9]", "BACK row 0 [6, 5, 4, 3] skip 2", "BACK row 0 [2, 1, 0]"]
	_check(got == expected, "runs split separately: %s" % [got])

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
			for i in range(1, step.cells.size()):
				ok = ok and absi(step.cells[i] - step.cells[i - 1]) == 1
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
				"thread %s: every cell crossed once, no gap inside a block (%d cells, %d bottom legs, %d top legs)" % [
					pattern.thread_codes[thread], count, halves.size(), backs.size()])


func _test_session() -> void:
	var pattern := _pattern(["000000.1", "......11"])
	var session := StitchSession.new(pattern)
	var width := pattern.width
	_check(not session.has_progress(), "new session has no progress")
	_check(str(session.current_step(0)) == "HALF row 0 [0, 1, 2]", "first step of thread 0")
	session.go_back(0)
	_check(session.done_count(0) == 0, "going back at the start stays at 0")

	session.advance(0)
	var states := session.cell_states()
	_check(states[0] == StitchSession.Cell.HALF and states[3] == StitchSession.Cell.NONE,
			"after one step the first block has bottom legs only")
	_check(session.finished_crosses(0) == 0, "half stitches are no finished crosses")
	session.advance(0)
	session.advance(0)
	states = session.cell_states()
	_check(states[5] == StitchSession.Cell.FULL and states[2] == StitchSession.Cell.HALF,
			"first return block completes cells 5..3")
	_check(session.finished_crosses(0) == 3, "3 crosses finished, got %d" % session.finished_crosses(0))
	session.advance(0)
	_check(session.current_step(0) == null, "thread 0 is finished after 4 steps")
	session.advance(0)
	_check(session.done_count(0) == 4, "advancing past the end stays at the end")
	_check(session.finished_crosses(0) == 6, "all 6 crosses of thread 0 finished")

	states = session.cell_states()
	_check(states[7] == StitchSession.Cell.NONE and states[width + 6] == StitchSession.Cell.NONE,
			"thread 1 is untouched")
	session.advance(1)
	states = session.cell_states()
	_check(states[7] == StitchSession.Cell.FULL, "single stitch of thread 1 is a full cross")
	_check(session.has_progress(), "session has progress")


func _test_position_hint() -> void:
	# Row 0: thread 0 with a gap of 1; row 2: thread 1 under it; thread 0 again in row 3.
	var pattern := _pattern(["000.0", ".....", "..1..", "0...."])
	var session := StitchSession.new(pattern)
	var first := session.current_step(0)
	_check(PositionHint.find(pattern, session.cell_states(), first) == null,
			"no hint for the very first stitch")

	session.advance(0)
	var after_gap := session.current_step(0)
	var hint := PositionHint.find(pattern, session.cell_states(), after_gap)
	_check(hint != null and hint.reference == Vector2i(2, 0) and hint.target == Vector2i(4, 0),
			"after a gap, count from the end of the last block")
	_check(hint != null and hint.path == [Vector2i(3, 0), Vector2i(4, 0)], "path counts 2 cells")

	session.advance(0)
	_check(PositionHint.find(pattern, session.cell_states(), session.current_step(0)) == null,
			"no hint for a return pass")
	while session.current_step(0) != null and session.current_step(0).row == 0:
		session.advance(0)

	# Row 3 (0, 3): nearest stitch is (0, 0) at 3 straight down, not (2, 0) with a bend.
	var down := session.current_step(0)
	hint = PositionHint.find(pattern, session.cell_states(), down)
	_check(hint != null and hint.reference == Vector2i(0, 0), "straight line wins: %s" % [
			hint.reference if hint else null])
	_check(hint != null and hint.path == [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
			"path goes straight down")

	# Thread 1 at (2, 2): two below (2, 0), any colour counts as reference.
	hint = PositionHint.find(pattern, session.cell_states(), session.current_step(1))
	_check(hint != null and hint.reference == Vector2i(2, 0), "other thread as reference")
	_check(hint != null and hint.corner() == hint.target, "a straight path has its corner at the target")

	# The stitch just made is a reference even inside a run; the cross above it is not.
	var tie := _pattern(["1111111111", "0000000000"])
	var tie_session := StitchSession.new(tie)
	while tie_session.current_step(1) != null:
		tie_session.advance(1)
	tie_session.advance(0)
	hint = PositionHint.find(tie, tie_session.cell_states(), tie_session.current_step(0),
			tie_session.last_cell(0))
	_check(hint != null and hint.reference == Vector2i(4, 1)
			and hint.landmark == PositionHint.Landmark.LAST, "last stitch is the reference: %s" % [
			hint.reference if hint else null])

	# A stitch in the middle of a run is never the reference, even when it is closest.
	var run := _pattern(["1111111111", "....0000.."])
	var run_session := StitchSession.new(run)
	while run_session.current_step(1) != null:
		run_session.advance(1)
	hint = PositionHint.find(run, run_session.cell_states(), run_session.current_step(0))
	_check(hint != null and hint.reference == Vector2i(0, 0)
			and hint.landmark == PositionHint.Landmark.LEFT_END,
			"count from the end of the row above: %s" % [hint.reference if hint else null])

	# Bent path: longer leg first.
	var bent := PositionHint.new()
	bent.reference = Vector2i(0, 0)
	bent.target = Vector2i(3, 1)
	_check(bent.corner() == Vector2i(3, 0), "corner after the longer horizontal leg")
	_check(PositionHint._counting_path(bent.reference, bent.target)
			== [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1)], "bent path")


func _test_describe_offset() -> void:
	var ref := "dem markierten Kreuz (DMC 310) am linken Ende"
	var cases := {
		Vector2i(1, 0): "Direkt rechts neben dem markierten Kreuz (DMC 310) am linken Ende.",
		Vector2i(0, 1): "Direkt unter dem markierten Kreuz (DMC 310) am linken Ende.",
		Vector2i(-1, -1): "Schräg links über dem markierten Kreuz (DMC 310) am linken Ende.",
		Vector2i(3, 0): "Ab dem markierten Kreuz (DMC 310) am linken Ende zählen: 3 nach rechts.",
		Vector2i(-1, 4): "Ab dem markierten Kreuz (DMC 310) am linken Ende zählen: 4 nach unten, dann 1 nach links.",
	}
	for offset: Vector2i in cases:
		var got := StitchPanel.describe_offset(offset, ref)
		_check(got == cases[offset], "describe %s: %s" % [offset, got])

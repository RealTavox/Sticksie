class_name StitchPlanner
## Plans the stitching order of one thread with the Danish method (DESIGN.md, section 2):
## per row segment, first the bottom legs outward, then the top legs back, in blocks of at most
## MAX_BLOCK stitches. A block never has a gap inside: the thread skips cells on the back only
## between blocks. A segment of a single stitch becomes one full cross.
##
## Thread changes: with a skip limit (user preference), a step whose way from the previous one
## skips more cells on the back starts a new thread. Without a limit only the first step does.

## Most stitches in one step.
const MAX_BLOCK := 5
## Most cells a Danish pass skips inside a row; a bigger gap splits the row into segments.
## A lower skip limit lowers it further.
const MAX_GAP := 3
## Skip limit meaning "no limit": the thread is never changed automatically.
const UNLIMITED := -1


## Steps for `thread` (index into pattern.thread_codes), row by row. Each segment starts on the
## start side; the Danish return pass brings the needle back there for the next one.
## `max_skip` is the most cells the thread may skip on the back before a new thread is needed.
static func plan(pattern: Pattern, thread: int, top_to_bottom := true,
		start_left := true, max_skip := UNLIMITED) -> Array[StitchStep]:
	var steps: Array[StitchStep] = []
	var rows := range(pattern.height)
	if not top_to_bottom:
		rows.reverse()
	var max_gap := MAX_GAP if max_skip == UNLIMITED else mini(MAX_GAP, max_skip)
	for y: int in rows:
		for segment in row_segments(pattern, thread, y, start_left, max_gap):
			steps.append_array(_segment_steps(segment, thread, y, 1 if start_left else -1))
	for i in steps.size():
		if i == 0:
			steps[i].starts_thread = true
			continue
		steps[i].travel_before = travel(steps[i - 1], steps[i])
		steps[i].starts_thread = max_skip != UNLIMITED and steps[i].travel_before > max_skip
	return steps


## Cells skipped on the back between the last stitch of `from` and the first of `to`. Moving to
## a neighbouring cell, also diagonally or to the next row, skips none.
static func travel(from: StitchStep, to: StitchStep) -> int:
	var offset := (Vector2i(to.cells[0], to.row) - Vector2i(from.cells[-1], from.row)).abs()
	return maxi(maxi(offset.x, offset.y) - 1, 0)


## The cells of `thread` in row `y`, ordered from the start side and split at gaps wider than
## `max_gap`.
static func row_segments(pattern: Pattern, thread: int, y: int,
		start_left := true, max_gap := MAX_GAP) -> Array[PackedInt32Array]:
	var segments: Array[PackedInt32Array] = []
	var segment := PackedInt32Array()
	var xs := range(pattern.width)
	if not start_left:
		xs.reverse()
	for x: int in xs:
		if pattern.get_cell(x, y) != thread:
			continue
		if not segment.is_empty() and absi(x - segment[-1]) - 1 > max_gap:
			segments.append(segment)
			segment = PackedInt32Array()
		segment.append(x)
	if not segment.is_empty():
		segments.append(segment)
	return segments


## Splits `cells` into ceil(n / max_size) blocks of nearly equal size, larger blocks first
## (7 → 4 + 3), so no block is a lone leftover stitch when it can be avoided.
static func split_blocks(cells: PackedInt32Array, max_size := MAX_BLOCK) -> Array[PackedInt32Array]:
	var blocks: Array[PackedInt32Array] = []
	var count := ceili(float(cells.size()) / max_size)
	var start := 0
	for i in count:
		var size := floori(float(cells.size()) / count) + (1 if i < cells.size() % count else 0)
		blocks.append(cells.slice(start, start + size))
		start += size
	return blocks


static func _segment_steps(segment: PackedInt32Array, thread: int, y: int,
		direction: int) -> Array[StitchStep]:
	var steps: Array[StitchStep] = []
	if segment.size() == 1:
		steps.append(StitchStep.new(StitchStep.Kind.CROSS, thread, y, segment, 0))
		return steps
	steps.append_array(_pass_steps(segment, StitchStep.Kind.HALF, thread, y, direction))
	var back := segment.duplicate()
	back.reverse()
	steps.append_array(_pass_steps(back, StitchStep.Kind.BACK, thread, y, -direction))
	return steps


## One pass over `cells` (in stitching order): each run of adjacent cells is split into blocks
## on its own, so gaps fall between blocks.
static func _pass_steps(cells: PackedInt32Array, kind: StitchStep.Kind, thread: int, y: int,
		direction: int) -> Array[StitchStep]:
	var steps: Array[StitchStep] = []
	for run in adjacent_runs(cells):
		for block in split_blocks(run):
			steps.append(StitchStep.new(kind, thread, y, block, direction))
	return steps


## Splits `cells` (in stitching order) wherever two neighbours aren't adjacent.
static func adjacent_runs(cells: PackedInt32Array) -> Array[PackedInt32Array]:
	var runs: Array[PackedInt32Array] = []
	var start := 0
	for i in range(1, cells.size() + 1):
		if i == cells.size() or absi(cells[i] - cells[i - 1]) != 1:
			runs.append(cells.slice(start, i))
			start = i
	return runs

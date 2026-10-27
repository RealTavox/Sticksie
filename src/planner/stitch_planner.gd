class_name StitchPlanner
## Plans the stitching order of one thread with the Danish method (DESIGN.md, section 2):
## per row segment, first the bottom legs outward, then the top legs back, in blocks of at most
## `max_block` stitches (a user preference, DEFAULT_MAX_BLOCK by default). A block never has a
## gap inside: the thread skips cells on the back only between blocks. A segment of a single
## stitch becomes one full cross. A segment starts at whichever end is nearer to the needle (on a
## tie, the start side); the Danish return pass brings the needle back there. Keeping the thread is worth more than keeping every row in one direction.
## With the English method (a user preference) each block is a step of whole crosses instead,
## one after the other, and the needle ends at the segment's far end. With `whole_back` (a user
## preference, the app's default) the Danish return pass isn't split into blocks: it runs over
## each run of adjacent cells in one step, still never across a gap.
##
## Order: one connected area of the thread is finished before the next begins. Inside an area the
## stitched part grows without holes: the next segment must touch a finished one, preferably the
## one just finished, so no open row is jumped over and filled in later. Among those, and when
## moving on to the next area, the nearest to the needle wins (on a tie, the first in row order).
##
## Thread changes: with a skip limit (user preference), a step whose way from the previous one
## skips more cells on the back starts a new thread. Without a limit only the first step does.

## Most stitches in one block unless the user sets another limit.
const DEFAULT_MAX_BLOCK := 5
## Most cells a Danish pass skips inside a row; a bigger gap splits the row into segments.
## A lower skip limit lowers it further.
const MAX_GAP := 3
## Skip limit meaning "no limit": the thread is never changed automatically.
const UNLIMITED := -1


## Steps for `thread` (index into pattern.thread_codes), area by area. Each segment starts at its
## end nearer to the needle; the Danish return pass brings the needle back there. `top_to_bottom`
## and `start_left` set the row order and the start side used on ties. `max_skip` is the most cells the thread may skip
## on the back before a new thread is needed. `english` plans whole crosses instead of Danish passes.
## `whole_back` makes each return pass one step per run of adjacent cells. `max_block` is the most
## stitches in one block.
static func plan(pattern: Pattern, thread: int, top_to_bottom := true,
		start_left := true, max_skip := UNLIMITED, english := false,
		whole_back := false, max_block := DEFAULT_MAX_BLOCK) -> Array[StitchStep]:
	var steps: Array[StitchStep] = []
	var rows := range(pattern.height)
	if not top_to_bottom:
		rows.reverse()
	var max_gap := MAX_GAP if max_skip == UNLIMITED else mini(MAX_GAP, max_skip)
	# Segments in row order: the first one found wins a tie.
	var segment_rows := PackedInt32Array()
	var segments: Array[PackedInt32Array] = []
	for y: int in rows:
		for segment in row_segments(pattern, thread, y, start_left, max_gap):
			segment_rows.append(y)
			segments.append(segment)
	var areas := connected_areas(segment_rows, segments)
	var done := PackedByteArray()
	done.resize(segments.size())
	done.fill(0)
	var last := -1
	var needle := Vector2i(-1, -1)
	for n in segments.size():
		var next := _next_segment(segment_rows, segments, areas, done, last, needle)
		done[next] = 1
		last = next
		var segment := segments[next]
		var direction := 1 if start_left else -1
		if not steps.is_empty() and _entry_end(segment, segment_rows[next], needle) != 0:
			segment = segment.duplicate()
			segment.reverse()
			direction = -direction
		steps.append_array(_segment_steps(segment, thread, segment_rows[next], direction, english,
				whole_back, max_block))
		# The Danish return pass (or a single cross) ends where the segment began, English
		# crosses at its far end.
		needle = Vector2i(segment[-1] if english else segment[0], segment_rows[next])
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
	return _skipped(Vector2i(from.cells[-1], from.row), Vector2i(to.cells[0], to.row))


## The segment to stitch after `last` (-1 at the start). Tried in turn: open segments touching
## `last`; open segments of the same area touching any finished one; open segments of other areas.
## In the first tier that has any, the one whose nearer end is nearest to the needle wins, on a tie
## the lowest index (row order).
static func _next_segment(segment_rows: PackedInt32Array, segments: Array[PackedInt32Array],
		areas: PackedInt32Array, done: PackedByteArray, last: int, needle: Vector2i) -> int:
	if last < 0:
		return 0
	for tier in 3:
		var best := -1
		var best_cost := 0
		for i in segments.size():
			if done[i]:
				continue
			var fits := false
			match tier:
				0:
					fits = _touch(segment_rows, segments, i, last)
				1:
					if areas[i] == areas[last]:
						for j in segments.size():
							if done[j] and _touch(segment_rows, segments, i, j):
								fits = true
								break
				_:
					fits = true
			if not fits:
				continue
			var cost := _entry_cost(segments[i], segment_rows[i], needle)
			if best < 0 or cost < best_cost:
				best = i
				best_cost = cost
		if best >= 0:
			return best
	return -1


## Cells skipped from `needle` to the nearer end of `segment`.
static func _entry_cost(segment: PackedInt32Array, y: int, needle: Vector2i) -> int:
	return _skipped(needle, Vector2i(segment[_entry_end(segment, y, needle)], y))


## Index of the end of `segment` (in row `y`) to start from: 0 (the start side) unless the other
## end is nearer to `needle`.
static func _entry_end(segment: PackedInt32Array, y: int, needle: Vector2i) -> int:
	var far := _skipped(needle, Vector2i(segment[-1], y))
	return segment.size() - 1 if far < _skipped(needle, Vector2i(segment[0], y)) else 0


## Whether segments `a` and `b` lie in neighbouring rows and overlap or touch diagonally.
static func _touch(segment_rows: PackedInt32Array, segments: Array[PackedInt32Array], a: int, b: int) -> bool:
	if absi(segment_rows[a] - segment_rows[b]) != 1:
		return false
	var a_min := mini(segments[a][0], segments[a][-1])
	var a_max := maxi(segments[a][0], segments[a][-1])
	var b_min := mini(segments[b][0], segments[b][-1])
	var b_max := maxi(segments[b][0], segments[b][-1])
	return a_min <= b_max + 1 and b_min <= a_max + 1


## Area index per segment: segments in neighbouring rows belong together when they overlap or
## touch diagonally. Gaps inside a row are already bridged by the segments themselves.
static func connected_areas(segment_rows: PackedInt32Array,
		segments: Array[PackedInt32Array]) -> PackedInt32Array:
	var parent := PackedInt32Array(range(segments.size()))
	for a in segments.size():
		for b in range(a + 1, segments.size()):
			if _touch(segment_rows, segments, a, b):
				parent[_root(parent, a)] = _root(parent, b)
	var areas := PackedInt32Array()
	for i in segments.size():
		areas.append(_root(parent, i))
	return areas


static func _root(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		i = parent[i]
	return i


## Cells skipped between two cells: none for neighbours, also diagonal ones.
static func _skipped(from: Vector2i, to: Vector2i) -> int:
	var offset := (to - from).abs()
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
static func split_blocks(cells: PackedInt32Array, max_size := DEFAULT_MAX_BLOCK) -> Array[PackedInt32Array]:
	var blocks: Array[PackedInt32Array] = []
	var count := ceili(float(cells.size()) / max_size)
	var start := 0
	for i in count:
		var size := floori(float(cells.size()) / count) + (1 if i < cells.size() % count else 0)
		blocks.append(cells.slice(start, start + size))
		start += size
	return blocks


static func _segment_steps(segment: PackedInt32Array, thread: int, y: int,
		direction: int, english := false, whole_back := false,
		max_block := DEFAULT_MAX_BLOCK) -> Array[StitchStep]:
	var steps: Array[StitchStep] = []
	if segment.size() == 1:
		steps.append(StitchStep.new(StitchStep.Kind.CROSS, thread, y, segment, 0))
		return steps
	if english:
		return _pass_steps(segment, StitchStep.Kind.CROSS, thread, y, direction, max_block)
	steps.append_array(_pass_steps(segment, StitchStep.Kind.HALF, thread, y, direction, max_block))
	var back := segment.duplicate()
	back.reverse()
	steps.append_array(_pass_steps(back, StitchStep.Kind.BACK, thread, y, -direction,
			0 if whole_back else max_block))
	return steps


## One pass over `cells` (in stitching order): each run of adjacent cells is split into blocks of
## at most `max_block` on its own (or, with 0, stays one step), so gaps fall between steps.
static func _pass_steps(cells: PackedInt32Array, kind: StitchStep.Kind, thread: int, y: int,
		direction: int, max_block: int) -> Array[StitchStep]:
	var steps: Array[StitchStep] = []
	for run in adjacent_runs(cells):
		var blocks: Array[PackedInt32Array] = [run]
		if max_block > 0:
			blocks = split_blocks(run, max_block)
		for block in blocks:
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

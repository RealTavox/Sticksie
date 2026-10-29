class_name StitchPlanner
## Plans the stitching order of one thread with the Danish method (DESIGN.md, section 2):
## per row segment, first the bottom legs outward, then the top legs back, in blocks of at most
## `max_block` stitches (a user preference, DEFAULT_MAX_BLOCK by default). A block never has a
## gap inside: the thread skips cells on the back only between blocks. A segment of a single
## stitch becomes one full cross. The Danish return pass brings the needle back to the end the
## segment began at. With the English method (a user preference) each block is a step of whole
## crosses instead, one after the other, and the needle ends at the segment's far end. With
## `whole_back` (a user preference, the app's default) the Danish return pass isn't split into
## blocks: it runs over each run of adjacent cells in one step, still never across a gap.
##
## Order: the one with the least thread on the back (PathOptimizer), measured from hole to hole as
## the needle really goes (StitchStyle): which segment comes next, which end it begins at, through
## which hole the needle first comes up and through which it goes down last (StitchStep.first_hole,
## last_hole). The rules of DESIGN.md
## hold: one connected area of the thread is finished before the next begins, and inside an area
## the stitched part grows without holes: every segment after the first touches one stitched before
## it, so no open row is jumped over and filled in later.
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
## Thread a new thread costs in thread_cost(), in cells: the tails secured at both ends.
const THREAD_START_COST := 8
## Start corners as (top_to_bottom, start_left).
const CORNERS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 0)]


## Like plan(), but starts wherever that leaves the least thread on the back (thread_cost()).
static func plan_shortest(pattern: Pattern, thread: int, max_skip := UNLIMITED, english := false,
		whole_back := false, max_block := DEFAULT_MAX_BLOCK, style: StitchStyle = null) -> Array[StitchStep]:
	return _plan(pattern, thread, true, true, false, max_skip, english, whole_back, max_block, style)


## Thread on the back, in cells, with the holes `style` uses (the automatic style when null): inside
## the steps, from each step to the next, and THREAD_START_COST for every new thread after the
## first. The stitches on the front cost the same in every order.
static func thread_cost(steps: Array[StitchStep], style: StitchStyle = null) -> float:
	if style == null:
		style = StitchStyle.new()
	var cost := 0.0
	var down := Vector2(NAN, NAN)
	for i in steps.size():
		var holes := style.needle_holes(steps[i])
		if i > 0:
			cost += THREAD_START_COST if steps[i].starts_thread else down.distance_to(holes[0])
		for j in range(1, holes.size() - 1, 2):
			cost += holes[j].distance_to(holes[j + 1])
		down = holes[-1]
	return cost


## Steps for `thread` (index into pattern.thread_codes), area by area, beginning in the corner given
## by `top_to_bottom` and `start_left` and keeping that direction: every segment from that side,
## the rows in that order wherever an area growing without holes allows (it costs more thread
## than plan_shortest()).
## `max_skip` is the most cells the thread may skip on the back before a new thread is needed.
## `english` plans whole crosses instead of Danish passes. `whole_back` makes each return pass one
## step per run of adjacent cells. `max_block` is the most stitches in one block. `style` decides
## the holes (the automatic style when null).
static func plan(pattern: Pattern, thread: int, top_to_bottom := true,
		start_left := true, max_skip := UNLIMITED, english := false,
		whole_back := false, max_block := DEFAULT_MAX_BLOCK, style: StitchStyle = null) -> Array[StitchStep]:
	return _plan(pattern, thread, top_to_bottom, start_left, true, max_skip, english, whole_back,
			max_block, style)


static func _plan(pattern: Pattern, thread: int, top_to_bottom: bool, start_left: bool,
		fixed_start: bool, max_skip: int, english: bool, whole_back: bool, max_block: int,
		style: StitchStyle) -> Array[StitchStep]:
	if style == null:
		style = StitchStyle.new()
	var steps: Array[StitchStep] = []
	var rows := range(pattern.height)
	if not top_to_bottom:
		rows.reverse()
	var max_gap := MAX_GAP if max_skip == UNLIMITED else mini(MAX_GAP, max_skip)
	# Segments in row order from the start corner.
	var segment_rows := PackedInt32Array()
	var segments: Array[PackedInt32Array] = []
	for y: int in rows:
		for segment in row_segments(pattern, thread, y, start_left, max_gap):
			segment_rows.append(y)
			segments.append(segment)
	if segments.is_empty():
		return steps
	var pairs := touching(segment_rows, segments)
	var areas := _areas(segments.size(), pairs)
	var optimizer := PathOptimizer.new(max_skip, THREAD_START_COST)
	var worked: Array = []  # per segment, per end (0: from the start side): its steps
	# Per entry of the optimizer: its hole, segment, end, and the hole its way ends in.
	var entry_holes := PackedVector2Array()
	var entry_segments := PackedInt32Array()
	var entry_ends := PackedInt32Array()
	var entry_exits := PackedVector2Array()
	var fixed_ways := PackedInt32Array()
	var way_count := 0
	for i in segments.size():
		var segment := segments[i]
		var y := segment_rows[i]
		optimizer.add_segment(areas[i], y, mini(segment[0], segment[-1]), maxi(segment[0], segment[-1]))
		var ends: Array = []
		for end in (1 if segment.size() == 1 or fixed_start else 2):
			var cells := segment
			if end == 1:
				cells = segment.duplicate()
				cells.reverse()
			var direction := 0 if cells.size() == 1 else signi(cells[-1] - cells[0])
			var work := _segment_steps(cells, thread, y, direction, english, whole_back, max_block)
			ends.append(work)
			# One way per hole the needle ends in, with the entries that lead there. The steps after
			# the first go the same way wherever the first ended, so they are worked once per end.
			# The last leg may end in either of its holes (see StitchStyle.last_hole_choices()).
			var exits := PackedVector2Array()
			var entries: Array = []  # per exit: [hole, inner, hole, inner, …]
			var rests := {}  # where the first step ended -> [exit, inner, holes of the last step]
			for hole in style.first_hole_choices(work[0]):
				var first := _work(work.slice(0, 1), hole, style)
				if work.size() > 1 and not rests.has(first[0]):
					rests[first[0]] = _work(work.slice(1), first[0], style, true)
				var rest: Array = rests[first[0]] if work.size() > 1 else [first[0], 0.0, first[2]]
				var last: PackedVector2Array = rest[2]
				for exit in style.last_hole_choices(last):
					var inner: float = first[1] + rest[1]
					if exit != last[-1]:
						inner += last[-3].distance_to(last[-1]) - last[-3].distance_to(last[-2])
					var index := exits.find(exit)
					if index < 0:
						index = exits.size()
						exits.append(exit)
						entries.append([])
					entries[index].append_array([hole, inner])
			for index in exits.size():
				if fixed_start and i == 0 and end == 0:
					fixed_ways.append(way_count)
				way_count += 1
				optimizer.add_way(Vector2i(work[0].cells[0], y), Vector2i(work[-1].cells[-1], y), exits[index])
				for k in range(0, entries[index].size(), 2):
					optimizer.add_entry(entries[index][k], entries[index][k + 1])
					entry_holes.append(entries[index][k])
					entry_segments.append(i)
					entry_ends.append(end)
					entry_exits.append(exits[index])
		worked.append(ends)
	for k in range(0, pairs.size(), 2):
		optimizer.add_touch(pairs[k], pairs[k + 1])
	if fixed_start:
		optimizer.set_direction(1 if top_to_bottom else -1, 1 if start_left else -1)
	var down := Vector2(NAN, NAN)
	for entry in optimizer.solve(0 if fixed_start else -1, fixed_ways):
		var work: Array[StitchStep] = worked[entry_segments[entry]][entry_ends[entry]]
		for k in work.size():
			work[k].first_hole = entry_holes[entry] if k == 0 else style.hole_after(work[k], down)
			work[k].last_hole = entry_exits[entry] if k == work.size() - 1 else Vector2(NAN, NAN)
			down = style.needle_holes(work[k])[-1]
		steps.append_array(work)
	for i in steps.size():
		if i == 0:
			steps[i].starts_thread = true
			continue
		steps[i].travel_before = travel(steps[i - 1], steps[i])
		steps[i].starts_thread = max_skip != UNLIMITED and steps[i].travel_before > max_skip
	return steps


## Works `steps` (of one segment) with the needle first coming up through `hole`, or, with `after`,
## coming up wherever is nearest after going down through `hole` (setting first_hole on every
## step, last_hole on none): the hole it goes down through last, the thread on the back inside the
## steps and the holes of the last step, as [exit, inner, holes].
static func _work(steps: Array[StitchStep], hole: Vector2, style: StitchStyle, after := false) -> Array:
	var inner := 0.0
	var down := hole
	var holes := PackedVector2Array()
	for k in steps.size():
		var step := steps[k]
		step.first_hole = hole if k == 0 and not after else style.hole_after(step, down)
		step.last_hole = Vector2(NAN, NAN)
		holes = style.needle_holes(step)
		if k > 0 or after:
			inner += down.distance_to(holes[0])
		for j in range(1, holes.size() - 1, 2):
			inner += holes[j].distance_to(holes[j + 1])
		down = holes[-1]
	return [down, inner, holes]


## Cells skipped on the back between the last stitch of `from` and the first of `to`. Moving to
## a neighbouring cell, also diagonally or to the next row, skips none.
static func travel(from: StitchStep, to: StitchStep) -> int:
	return _skipped(Vector2i(from.cells[-1], from.row), Vector2i(to.cells[0], to.row))


## Whether segments `a` and `b` lie in neighbouring rows and overlap or touch diagonally.
static func _touch(segment_rows: PackedInt32Array, segments: Array[PackedInt32Array], a: int, b: int) -> bool:
	if absi(segment_rows[a] - segment_rows[b]) != 1:
		return false
	var a_min := mini(segments[a][0], segments[a][-1])
	var a_max := maxi(segments[a][0], segments[a][-1])
	var b_min := mini(segments[b][0], segments[b][-1])
	var b_max := maxi(segments[b][0], segments[b][-1])
	return a_min <= b_max + 1 and b_min <= a_max + 1


## Area number per segment (0, 1, … in the order of their first segments): segments in
## neighbouring rows belong together when they overlap or touch diagonally. Gaps inside a row are
## already bridged by the segments themselves.
static func connected_areas(segment_rows: PackedInt32Array,
		segments: Array[PackedInt32Array]) -> PackedInt32Array:
	return _areas(segments.size(), touching(segment_rows, segments))


## Pairs of segments that lie in neighbouring rows and overlap or touch diagonally, flattened
## (a, b, a, b, …). One sweep over the rows, so it stays fast for big patterns.
static func touching(segment_rows: PackedInt32Array, segments: Array[PackedInt32Array]) -> PackedInt32Array:
	var count := segments.size()
	var pairs := PackedInt32Array()
	if count == 0:
		return pairs
	var lows := PackedInt32Array()
	var highs := PackedInt32Array()
	var top := segment_rows[0]
	var span := 1
	for i in count:
		lows.append(mini(segments[i][0], segments[i][-1]))
		highs.append(maxi(segments[i][0], segments[i][-1]))
		top = mini(top, segment_rows[i])
		span = maxi(span, highs[i] + 1)
	# Segments sorted by row, then by leftmost cell.
	var keys := PackedInt64Array()
	for i in count:
		keys.append((int(segment_rows[i] - top) * span + lows[i]) * count + i)
	keys.sort()
	var sorted := PackedInt32Array()
	for key in keys:
		sorted.append(key % count)
	# For each row, the segments of the row below that it reaches.
	var row_start := 0
	var below_start := 0
	while row_start < count:
		var row := segment_rows[sorted[row_start]]
		var row_end := row_start
		while row_end < count and segment_rows[sorted[row_end]] == row:
			row_end += 1
		below_start = row_end
		var below_end := below_start
		while below_end < count and segment_rows[sorted[below_end]] == row + 1:
			below_end += 1
		var first := below_start
		for i in range(row_start, row_end):
			var a := sorted[i]
			while first < below_end and highs[sorted[first]] < lows[a] - 1:
				first += 1
			var j := first
			while j < below_end and lows[sorted[j]] <= highs[a] + 1:
				pairs.append(a)
				pairs.append(sorted[j])
				j += 1
		row_start = row_end
	return pairs


## Area number per segment from the touching `pairs` (see touching()).
static func _areas(count: int, pairs: PackedInt32Array) -> PackedInt32Array:
	var parent := PackedInt32Array(range(count))
	for k in range(0, pairs.size(), 2):
		var a := pairs[k]
		while parent[a] != a:
			parent[a] = parent[parent[a]]
			a = parent[a]
		var b := pairs[k + 1]
		while parent[b] != b:
			parent[b] = parent[parent[b]]
			b = parent[b]
		if a != b:
			parent[maxi(a, b)] = mini(a, b)
	var areas := PackedInt32Array()
	var numbers := {}
	for i in count:
		var root := i
		while parent[root] != root:
			root = parent[root]
		if not numbers.has(root):
			numbers[root] = numbers.size()
		areas.append(numbers[root])
	return areas


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

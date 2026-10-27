class_name StitchPlanner
## Plans the stitching order of one thread with the Danish method (DESIGN.md, section 2):
## per row segment, first the bottom legs outward, then the top legs back, in blocks of at most
## MAX_BLOCK stitches. A segment of a single stitch becomes one full cross.

## Most stitches in one step.
const MAX_BLOCK := 5
## Most cells the thread may skip on the back inside one segment; a bigger gap splits the row.
const MAX_GAP := 3


## Steps for `thread` (index into pattern.thread_codes), row by row. Each segment starts on the
## start side; the Danish return pass brings the needle back there for the next one.
static func plan(pattern: Pattern, thread: int, top_to_bottom := true,
		start_left := true) -> Array[StitchStep]:
	var steps: Array[StitchStep] = []
	var rows := range(pattern.height)
	if not top_to_bottom:
		rows.reverse()
	for y: int in rows:
		for segment in row_segments(pattern, thread, y, start_left):
			steps.append_array(_segment_steps(segment, thread, y, 1 if start_left else -1))
	return steps


## The cells of `thread` in row `y`, ordered from the start side and split at gaps wider than
## MAX_GAP.
static func row_segments(pattern: Pattern, thread: int, y: int,
		start_left := true) -> Array[PackedInt32Array]:
	var segments: Array[PackedInt32Array] = []
	var segment := PackedInt32Array()
	var xs := range(pattern.width)
	if not start_left:
		xs.reverse()
	for x: int in xs:
		if pattern.get_cell(x, y) != thread:
			continue
		if not segment.is_empty() and absi(x - segment[-1]) - 1 > MAX_GAP:
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
	for block in split_blocks(segment):
		steps.append(StitchStep.new(StitchStep.Kind.HALF, thread, y, block, direction))
	var back := segment.duplicate()
	back.reverse()
	for block in split_blocks(back):
		steps.append(StitchStep.new(StitchStep.Kind.BACK, thread, y, block, -direction))
	return steps

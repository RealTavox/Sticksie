class_name PositionHint
extends RefCounted
## Where a step starts, relative to a stitch that is already on the fabric (DESIGN.md "Smarte
## Positionshinweise"). The fabric has no marks of its own, and a stitch in the middle of a row
## of equal stitches can't be found again, so the reference is either the last stitch made or
## the end of a run: a stitch whose left or right neighbour is empty or looks different (other
## thread, or half stitch next to cross). Of those, the closest wins, preferring a straight line
## to count along, and on a tie one in the same row. Before the very first stitch, counting
## starts at the nearest corner of the pattern, which the user places on the fabric.
##
## Counting goes from hole to hole (the needle holes at the cells' corners): from the reference
## stitch's hole nearest to where the needle comes up, or from the pattern's corner hole itself
## before the first stitch, to the needle's hole.

enum Landmark {
	## The stitch just made; the needle is there.
	LAST,
	LEFT_END,
	RIGHT_END,
	## A stitch on its own: both neighbours differ.
	SINGLE,
	## Nothing is stitched yet: a corner cell of the pattern, wherever the user puts it.
	CORNER,
}

## The stitched cell to count from.
var reference: Vector2i
## What makes the reference findable.
var landmark: Landmark
## The first cell of the step.
var target: Vector2i
## The hole counting starts at, and the hole where the needle comes up first (grid points).
var start: Vector2i
var needle: Vector2i
## Holes to count, from the one after `start` to `needle`: first along the longer direction,
## then along the shorter one.
var holes: Array[Vector2i] = []


## The hint for `step`, given the cell states (StitchSession.Cell per cell) before it and the
## last stitched cell of its thread ((-1, -1) if none), and the hole where the needle comes up
## first (StitchStyle.needle_holes(); by default the first cell's top left). Null for a return
## pass (it runs back over its own half stitches). When nothing is stitched yet, the reference
## is the corner of the pattern nearest to the step (on a tie: top before bottom, left before
## right).
static func find(pattern: Pattern, states: PackedByteArray, step: StitchStep,
		last_cell := Vector2i(-1, -1), needle_hole := Vector2i(-1, -1)) -> PositionHint:
	if step.kind == StitchStep.Kind.BACK:
		return null
	var target := Vector2i(step.cells[0], step.row)
	var best := Vector2i(-1, -1)
	var best_landmark := Landmark.LAST
	var best_cost := INF
	for y in pattern.height:
		for x in pattern.width:
			var cell := Vector2i(x, y)
			if states[y * pattern.width + x] == StitchSession.Cell.NONE:
				continue
			var landmark := Landmark.LAST
			if cell != last_cell:
				var look := _look(pattern, states, cell)
				var left_differs := _look(pattern, states, cell + Vector2i.LEFT) != look
				var right_differs := _look(pattern, states, cell + Vector2i.RIGHT) != look
				if left_differs and right_differs:
					landmark = Landmark.SINGLE
				elif left_differs:
					landmark = Landmark.LEFT_END
				elif right_differs:
					landmark = Landmark.RIGHT_END
				else:
					continue  # Inside a run of equal stitches: not findable.
			var offset := (target - cell).abs()
			# Half a cell extra for a bend and a quarter for another row, so on equal distance a
			# straight line in the same row wins.
			var cost := offset.x + offset.y + (0.5 if offset.x > 0 and offset.y > 0 else 0.0)
			if offset.y > 0:
				cost += 0.25
			if cost < best_cost:
				best_cost = cost
				best = cell
				best_landmark = landmark
	var hint := PositionHint.new()
	hint.target = target
	hint.needle = needle_hole if needle_hole.x >= 0 else target
	if best.x < 0:
		var left := target.x * 2 <= pattern.width - 1
		var top := target.y * 2 <= pattern.height - 1
		best = Vector2i(0 if left else pattern.width - 1, 0 if top else pattern.height - 1)
		best_landmark = Landmark.CORNER
		hint.start = Vector2i(0 if left else pattern.width, 0 if top else pattern.height)
	else:
		hint.start = _nearest_hole(best, hint.needle - target, hint.needle)
	hint.reference = best
	hint.landmark = best_landmark
	hint.holes = _counting_path(hint.start, hint.needle)
	return hint


## The corner hole of `cell` closest to `needle`; on a tie the one at the same corner of its cell
## as the needle's (`needle_corner`).
static func _nearest_hole(cell: Vector2i, needle_corner: Vector2i, needle: Vector2i) -> Vector2i:
	var best := cell + needle_corner
	var best_distance := _hops(best, needle)
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var distance := _hops(cell + corner, needle)
		if distance < best_distance:
			best = cell + corner
			best_distance = distance
	return best


static func _hops(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## What a cell looks like on the fabric: -1 for empty (or outside the pattern), otherwise
## thread and state combined.
static func _look(pattern: Pattern, states: PackedByteArray, cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= pattern.width or cell.y >= pattern.height:
		return -1
	var state := states[cell.y * pattern.width + cell.x]
	if state == StitchSession.Cell.NONE:
		return -1
	return pattern.get_cell(cell.x, cell.y) * 3 + state

## The offset from the reference to the target, in cells.
func offset() -> Vector2i:
	return target - reference


## The holes to count, from `start` to `needle`.
func count() -> Vector2i:
	return needle - start


## Where the counting path turns: the end of its first, longer leg.
func bend() -> Vector2i:
	var delta := count()
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(needle.x, start.y)
	return Vector2i(start.x, needle.y)


static func _counting_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var bend := Vector2i(to.x, from.y) if absi(to.x - from.x) >= absi(to.y - from.y) else Vector2i(from.x, to.y)
	for leg in [[from, bend], [bend, to]]:
		var cell: Vector2i = leg[0]
		var step := Vector2i((leg[1] - leg[0]).sign())
		while cell != leg[1]:
			cell += step
			path.append(cell)
	return path

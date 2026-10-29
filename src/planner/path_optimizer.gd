class_name PathOptimizer
extends RefCounted
## Finds the order of the row segments of one thread, and the way into each, that leaves the
## least thread on the back. StitchPlanner describes the segments and turns the result into steps.
##
## A segment can be worked in a few ways (which end it starts at, and so where it ends), and each
## way has one or two entries (the hole the needle first comes up through). A way fixes the cell it
## starts and ends at and the hole the needle goes down through last; an entry fixes the thread on
## the back inside the segment. From one segment to the next the thread runs straight from that
## hole to the next entry, never up through the hole it just went down; where the way skips more
## cells than the skip limit, a new thread is started instead, which costs a fixed length.
##
## Rules kept from DESIGN.md: an area of the thread is finished before the next one begins, and
## inside an area every segment after the first touches one stitched before it (add_touch()).
##
## The search (checked against exact solutions: on the sample image it finds the optimum for nine
## colours of ten, 0.02 % more thread over all). Threads of few segments get the exact optimum
## (_solve_exactly()); the others:
## 1. a greedy plan (always the cheapest next segment the rules allow) from several starts: the
##    pattern's corners, both ends of the longest way through the largest area, and the end of the
##    first plan found, each improved by 2 to 4 while the work budget lasts; the best is kept;
## 2. local search on the order of the areas: moving one to three of them elsewhere, also turned
##    round, and reversing runs of them; then random swaps of neighbouring runs of areas, kept
##    where they lead to less thread (iterated local search);
## 3. local search inside each area: small areas get their best order outright; in larger ones runs
##    of segments are moved and reversed around jumps, and windows of WINDOW segments are put in
##    their best order;
## 4. the best way and entry for every segment for the order found, exactly (dynamic programming);
## 5. last, the first and last ENDS segments of each area are put in their best order.
## All of it is deterministic: the work is counted, not timed, and the random swaps use a fixed
## seed, so the same pattern and settings always give the same plan on every device.

## Cost of coming up through the hole the needle just went down through: never chosen.
const SAME_HOLE := 1.0e6
## Threads with at most this many segments are first planned exactly (see _solve_exactly()), unless
## that takes more than EXACT_WORK thread costs worked out.
const EXACT_SEGMENTS := 24
const EXACT_WORK := 150000
## Areas with at most this many segments are put in their best order as a whole.
const EXACT_AREA := 6
## Larger areas are reordered this many consecutive segments at a time, and their first and last
## ENDS segments at the very end.
const WINDOW := 5
const ENDS := 8
## Longest run of areas or segments moved at once, also turned round.
const CHAIN := 3
## Longest run of segments moved in one piece; only runs that start and end with a jump are moved
## further than CHAIN segments. A transition is a jump when it costs at least JUMP more than the
## cheapest one into the same segment from a touching segment.
const LONG_CHAIN := 64
const JUMP := 0.75
## Windows are only reordered where a transition costs at least SLACK more than it could.
const SLACK := 1.0e-3
## Nearest areas tried as new neighbours when moving areas in the order.
const NEIGHBOURS := 10
## Rounds of steps 2 to 4 at most.
const MAX_ROUNDS := 10
## Work allowed for one thread, counted in thread costs worked out: BUDGET plus
## BUDGET_PER_SEGMENT per segment for the starts (a further start is only tried while the budget
## is likely to last for it), and KICK_BUDGET_PER_AREA per area, at most KICK_BUDGET, for the
## random swaps. Keeps big patterns quick.
const BUDGET := 30000
const BUDGET_PER_SEGMENT := 500
const KICK_BUDGET_PER_AREA := 2000
const KICK_BUDGET := 1000000
## Random swaps of the area order tried per area, the longest run they swap, and their seed.
const KICKS_PER_AREA := 20
const KICK_RUN := 6
const SEED := 20261029
## Smallest gain worth a change, so rounding never makes the search go round in circles.
const EPSILON := 1.0e-6

var _max_skip: int
var _start_cost: float

# The problem, in flat arrays. Segments, ways and entries are numbered in the order they are added.
var _seg_area := PackedInt32Array()
var _seg_row := PackedInt32Array()
## Leftmost and rightmost cell of each segment.
var _seg_low := PackedInt32Array()
var _seg_high := PackedInt32Array()
## First way of each segment; one more at the end, so segment s has ways _seg_ways[s] to
## _seg_ways[s + 1] - 1. Likewise _way_entries for the entries of a way.
var _seg_ways := PackedInt32Array([0])
var _way_seg := PackedInt32Array()
var _way_first := PackedVector2Array()
var _way_last := PackedVector2Array()
var _way_exit := PackedVector2Array()
var _way_entries := PackedInt32Array([0])
## Thread inside the segment with its cheapest entry: the cost of a way after a new thread.
var _way_alone := PackedFloat64Array()
var _entry_hole := PackedVector2Array()
var _entry_inner := PackedFloat64Array()
var _touches := PackedInt32Array()  # pairs
## Touching segments, as one list: segment s has _adjacent[_adjacent_start[s]] up to
## _adjacent_start[s + 1] - 1.
var _adjacent_start := PackedInt32Array()
var _adjacent := PackedInt32Array()
var _area_count := 0
## Cheapest thread into each segment from any segment touching it, any ways.
var _best_in := PackedFloat64Array()
## Per segment: whether all its ways have the same entries (a single cross), so that its way only
## decides where it ends; per area: whether it is one such segment.
var _free_exit := PackedByteArray()
var _area_free := PackedByteArray()
## Segments of each row, as (first, end): segments are added row by row. The rows have segments
## from _row_low to _row_high.
var _rows := {}
var _row_low := 0
var _row_high := 0
## The segment that must come first and the ways allowed for it, or -1 for a free start.
var _fixed := -1
var _fixed_ways := PackedInt32Array()

# The solution: the order of the areas, the order of the segments in each area, and the way of
# each segment, plus positions for looking them up.
var _order := PackedInt32Array()
var _area_pos := PackedInt32Array()
var _paths: Array[PackedInt32Array] = []
var _seg_pos := PackedInt32Array()
var _way := PackedInt32Array()
## Per area: the ways before and after it when its order was last improved, and whether anything in
## it changed since; an area is only searched again when one of them did.
var _settled := PackedInt64Array()
var _area_dirty := PackedByteArray()
## Per area: its first and last way when the area order was last searched (see
## _improve_area_order()).
var _area_ends := PackedInt64Array()
## Thread costs worked out so far, and the count at which the search stops (see solve()).
var _calls := 0
var _limit := 0
## Areas next to the last change of the area order (see _move_areas()).
var _touched_areas := PackedInt32Array()
## Thread along the area order up to each position, and against it, for reversing runs of areas at
## once; rebuilt after a change when needed.
var _area_forward := PackedFloat64Array()
var _area_backward := PackedFloat64Array()
var _area_sums_dirty := true
# Nearest areas, rebuilt for each search of the area order: areas whose entry is near an area's
# exit, and areas whose exit is near its entry.
var _near_after: Array[PackedInt32Array] = []
var _near_before: Array[PackedInt32Array] = []

## For the area being improved: per position of its path (and one more for its end), whether the
## transition into it is a jump (see _mark_jumps()).
var _jumps := PackedByteArray()
## For the same area: thread along its path up to each position, and the same against the path
## (from each segment back into the one before it), for evaluating reversals at once.
var _forward := PackedFloat64Array()
var _backward := PackedFloat64Array()
## For the same area, per segment: the thread from the segment before it on the path into it (from
## the way before the area for the first), and back from it into the one before it; and from the
## last one into the way after the area. Kept up to date as the path changes (_update_edges()).
var _edge_in := PackedFloat64Array()
var _edge_back := PackedFloat64Array()
var _edge_end := 0.0


## `max_skip` is the most cells the thread may skip on the back (StitchPlanner.UNLIMITED for no
## limit); `thread_start_cost` the thread a new thread costs.
func _init(max_skip: int, thread_start_cost: float) -> void:
	_max_skip = max_skip
	_start_cost = thread_start_cost


## Adds the next segment: `area` is its area number (0, 1, …), `low` and `high` its leftmost and
## rightmost cell in `row`. Segments must come row by row. Its ways follow with add_way().
func add_segment(area: int, row: int, low: int, high: int) -> void:
	_seg_area.append(area)
	_seg_row.append(row)
	_seg_low.append(low)
	_seg_high.append(high)
	_seg_ways.append(_seg_ways[-1])
	_area_count = maxi(_area_count, area + 1)


## Adds a way to work the segment added last: from `first_cell` to `last_cell`, the needle going
## down through `exit` at the end. Its entries follow with add_entry().
func add_way(first_cell: Vector2i, last_cell: Vector2i, exit: Vector2) -> void:
	_way_seg.append(_seg_area.size() - 1)
	_way_first.append(Vector2(first_cell))
	_way_last.append(Vector2(last_cell))
	_way_exit.append(exit)
	_way_entries.append(_way_entries[-1])
	_way_alone.append(INF)
	_seg_ways[-1] += 1


## Adds an entry to the way added last: the needle first comes up through `hole`, and the thread
## on the back inside the segment is then `inner` long.
func add_entry(hole: Vector2, inner: float) -> void:
	_entry_hole.append(hole)
	_entry_inner.append(inner)
	_way_entries[-1] += 1
	_way_alone[-1] = minf(_way_alone[-1], inner)


## Segments `a` and `b` touch: in an area, either may be the one that lets the other follow.
func add_touch(a: int, b: int) -> void:
	_touches.append(a)
	_touches.append(b)


## Plans the order and returns the entry chosen for each segment, in stitching order. `fixed` is a
## segment that must come first, in one of `fixed_ways`, or -1 for a free start.
func solve(fixed := -1, fixed_ways := PackedInt32Array()) -> PackedInt32Array:
	_fixed = fixed
	_fixed_ways = fixed_ways
	_build_adjacency()
	if _solve_exactly():
		return _entries()
	var best := INF
	var best_order := PackedInt32Array()
	var best_paths: Array[PackedInt32Array] = []
	var best_way := PackedInt32Array()
	var starts := _starts()
	var budget := BUDGET + BUDGET_PER_SEGMENT * _seg_area.size()
	_calls = 0
	var most := 0  # the most work one start took so far
	var i := 0
	while i < starts.size():
		if i > 0 and _calls + most > budget:
			break
		var used := _calls
		_limit = budget
		_greedy(starts[i], starts[i + 1])
		_refresh_positions()
		_improve()
		most = maxi(most, _calls - used)
		var cost := total_cost()
		if cost < best - EPSILON:
			best = cost
			best_order = _order
			best_paths = _paths.duplicate(true)
			best_way = _way
		if i == 0 and _fixed < 0:
			# Next, from the end of this plan: the same plan backwards often starts better.
			var last: int = best_paths[best_order[-1]][-1]
			var way := best_way[last]
			for k in range(starts.size() - 2, 1, -2):
				if _way_first[starts[k + 1]] == _way_first[way]:
					starts = starts.slice(0, k) + starts.slice(k + 2)
			starts.insert(2, last)
			starts.insert(3, way)
		i += 2
	_order = best_order
	_paths = best_paths
	_way = best_way
	_refresh_positions()
	_reorder_ends()
	return _entries()


## The best plan of all, by dynamic programming over the sets of segments stitched so far and the
## way of the last one, keeping only the sets the rules allow (whole areas, each grown without
## holes, plus the one being stitched); sets the solution and returns true. Returns false for more
## than EXACT_SEGMENTS segments or when it would take more than EXACT_WORK steps.
func _solve_exactly() -> bool:
	var n := _seg_area.size()
	if n > EXACT_SEGMENTS:
		return false
	var ways := _way_seg.size()
	var bits := 1
	while (1 << bits) <= ways:
		bits += 1
	var way_mask := (1 << bits) - 1
	var area_masks := PackedInt64Array()
	area_masks.resize(_area_count)
	area_masks.fill(0)
	var touch_masks := PackedInt64Array()
	touch_masks.resize(n)
	for segment in n:
		area_masks[_seg_area[segment]] |= 1 << segment
		touch_masks[segment] = 0
		for a in range(_adjacent_start[segment], _adjacent_start[segment + 1]):
			touch_masks[segment] |= 1 << _adjacent[a]
	var costs := PackedFloat64Array()  # from way * ways + to way
	costs.resize(ways * ways)
	for from in ways:
		for to in ways:
			costs[from * ways + to] = _cost(from, to)
	# One layer per number of segments stitched: its states (set << bits | last way), their costs,
	# and the state of the layer before that each came from.
	var states := PackedInt64Array()
	var totals := PackedFloat64Array()
	var layers: Array[PackedInt64Array] = []
	var parents: Array[PackedInt64Array] = []
	for segment in n:
		if _fixed >= 0 and segment != _fixed:
			continue
		for way in range(_seg_ways[segment], _seg_ways[segment + 1]):
			if _way_allowed(segment, way):
				states.append(((1 << segment) << bits) | way)
				totals.append(_way_alone[way])
	layers.append(states)
	parents.append(PackedInt64Array())
	var work := 0
	for count in range(1, n):
		var index := {}  # state -> its place in the next layer
		var next := PackedInt64Array()
		var next_totals := PackedFloat64Array()
		var came_from := PackedInt64Array()
		for i in states.size():
			var state := states[i]
			var done := state >> bits
			var last := state & way_mask
			var open := area_masks[_seg_area[_way_seg[last]]] & ~done
			var total := totals[i]
			for segment in n:
				var bit := 1 << segment
				if done & bit:
					continue
				# Inside an unfinished area: a segment touching it; else any of an untouched area.
				if open != 0:
					if not (open & bit) or not (touch_masks[segment] & done):
						continue
				elif area_masks[_seg_area[segment]] & done:
					continue
				for way in range(_seg_ways[segment], _seg_ways[segment + 1]):
					var cost := total + costs[last * ways + way]
					var key := ((done | bit) << bits) | way
					var at: int = index.get(key, -1)
					if at < 0:
						index[key] = next.size()
						next.append(key)
						next_totals.append(cost)
						came_from.append(state)
					elif cost < next_totals[at]:
						next_totals[at] = cost
						came_from[at] = state
				work += _seg_ways[segment + 1] - _seg_ways[segment]
			if work > EXACT_WORK:
				return false
		states = next
		totals = next_totals
		layers.append(states)
		parents.append(came_from)
	var best := 0
	for i in totals.size():
		if totals[i] < totals[best]:
			best = i
	# Back through the layers.
	var sequence := PackedInt32Array()
	_way.resize(n)
	var state := states[best]
	for count in range(n - 1, -1, -1):
		var way := state & way_mask
		sequence.append(_way_seg[way])
		_way[_way_seg[way]] = way
		if count > 0:
			state = parents[count][layers[count].find(state)]
	sequence.reverse()
	_order = PackedInt32Array()
	_paths = []
	for area in _area_count:
		_paths.append(PackedInt32Array())
	for segment in sequence:
		var area := _seg_area[segment]
		if _paths[area].is_empty():
			_order.append(area)
		var path := _paths[area]
		path.append(segment)
		_paths[area] = path
	_refresh_positions()
	return true


## Local search from the current solution until nothing gets shorter or the budget is used up,
## then the random swaps of the area order.
func _improve() -> void:
	_settled.resize(_area_count)
	_settled.fill(-1)
	_area_dirty.resize(_area_count)
	_area_dirty.fill(1)
	_area_ends.resize(_area_count)
	_area_ends.fill(-1)
	_optimize_ways()
	for round in MAX_ROUNDS:
		if _calls > _limit:
			break
		var before := total_cost()
		_improve_area_order()
		_optimize_ways()
		_improve_areas()
		_optimize_ways()
		if total_cost() > before - EPSILON:
			break
	var before := total_cost()
	var limit := _limit
	_limit = _calls + mini(KICK_BUDGET_PER_AREA * _order.size(), KICK_BUDGET)
	_shake_area_order()
	_limit = limit
	_optimize_ways()
	if total_cost() < before - EPSILON:
		_improve_areas()
		_optimize_ways()


## Puts the first and the last ENDS segments of every larger area in their best order, where
## greedy plans leave what they skipped.
func _reorder_ends() -> void:
	for p in _order.size():
		var area := _order[p]
		var size := _paths[area].size()
		if size <= EXACT_AREA:
			continue
		var before := _last_way(_order[p - 1]) if p > 0 else -1
		var after := _first_way(_order[p + 1]) if p + 1 < _order.size() else -1
		var count := mini(ENDS, size)
		_update_edges(area, before, after, _paths[area])
		_reorder(area, size - count, count, before, after)
		_update_edges(area, before, after, _paths[area])
		_reorder(area, 0, count, before, after)
	_optimize_ways()


## Thread on the back of the current solution, as StitchPlanner.thread_cost() counts it.
func total_cost() -> float:
	var total := 0.0
	var previous := -1
	for area in _order:
		for segment in _paths[area]:
			total += _cost(previous, _way[segment])
			previous = _way[segment]
	return total


# --- Costs -----------------------------------------------------------------------------------

## Thread from the end of way `from` (-1: nothing before, or a new thread) into way `to`, with the
## thread inside it, for its cheapest entry.
func _cost(from: int, to: int) -> float:
	_calls += 1
	if from < 0:
		return _way_alone[to]
	if _max_skip >= 0:
		var gap := (_way_first[to] - _way_last[from]).abs()
		if maxf(gap.x, gap.y) - 1.0 > _max_skip:
			return _start_cost + _way_alone[to]
	var down := _way_exit[from]
	var best := INF
	for entry in range(_way_entries[to], _way_entries[to + 1]):
		var hole := _entry_hole[entry]
		var cost := (SAME_HOLE if hole == down else down.distance_to(hole)) + _entry_inner[entry]
		if cost < best:
			best = cost
	return best


## Like _cost(), but nothing to go to (-1) costs nothing.
func _link(from: int, to: int) -> float:
	return 0.0 if to < 0 else _cost(from, to)


## The cheapest entry of way `to` after way `from` (see _cost()); on a tie the first added.
func _entry(from: int, to: int) -> int:
	var skips := from >= 0 and _max_skip >= 0 and maxf(absf(_way_first[to].x - _way_last[from].x),
			absf(_way_first[to].y - _way_last[from].y)) - 1.0 > _max_skip
	var best := INF
	var best_entry := _way_entries[to]
	for entry in range(_way_entries[to], _way_entries[to + 1]):
		var cost := _entry_inner[entry]
		if from >= 0 and not skips:
			var hole := _entry_hole[entry]
			cost += SAME_HOLE if hole == _way_exit[from] else _way_exit[from].distance_to(hole)
		if cost < best:
			best = cost
			best_entry = entry
	return best_entry


## The entry of every segment, in stitching order.
func _entries() -> PackedInt32Array:
	var entries := PackedInt32Array()
	var previous := -1
	for area in _order:
		for segment in _paths[area]:
			entries.append(_entry(previous, _way[segment]))
			previous = _way[segment]
	return entries


## The way the first segment of `area` is worked in, and the last one's.
func _first_way(area: int) -> int:
	return _way[_paths[area][0]]


func _last_way(area: int) -> int:
	return _way[_paths[area][-1]]


## Whether `segment` may be worked in `way`: any way, except for the fixed start.
func _way_allowed(segment: int, way: int) -> bool:
	return segment != _fixed or _fixed_ways.has(way)


# --- Start -----------------------------------------------------------------------------------

## The row index and the touching segments of each segment.
func _build_adjacency() -> void:
	var n := _seg_area.size()
	var row_start := 0
	while row_start < n:
		var end := row_start
		while end < n and _seg_row[end] == _seg_row[row_start]:
			end += 1
		_rows[_seg_row[row_start]] = Vector2i(row_start, end)
		row_start = end
	_row_low = _rows.keys().min()
	_row_high = _rows.keys().max()
	var counts := PackedInt32Array()
	counts.resize(n + 1)
	counts.fill(0)
	for t in _touches:
		counts[t + 1] += 1
	for s in n:
		counts[s + 1] += counts[s]
	_adjacent_start = counts.duplicate()
	_adjacent.resize(_touches.size())
	for i in range(0, _touches.size(), 2):
		for side in 2:
			var a := _touches[i + side]
			_adjacent[counts[a]] = _touches[i + 1 - side]
			counts[a] += 1
	_free_exit.resize(n)
	_area_free.resize(_area_count)
	_area_free.fill(0)
	var area_sizes := PackedInt32Array()
	area_sizes.resize(_area_count)
	area_sizes.fill(0)
	for segment in n:
		area_sizes[_seg_area[segment]] += 1
		_free_exit[segment] = 1
		var first := _seg_ways[segment]
		for way in range(first + 1, _seg_ways[segment + 1]):
			var count := _way_entries[way + 1] - _way_entries[way]
			if count != _way_entries[first + 1] - _way_entries[first]:
				_free_exit[segment] = 0
				continue
			for k in count:
				if (_entry_hole[_way_entries[way] + k] != _entry_hole[_way_entries[first] + k]
						or _entry_inner[_way_entries[way] + k] != _entry_inner[_way_entries[first] + k]):
					_free_exit[segment] = 0
	for segment in n:
		if area_sizes[_seg_area[segment]] == 1 and _free_exit[segment]:
			_area_free[_seg_area[segment]] = 1
	_edge_in.resize(n)
	_edge_back.resize(n)
	_best_in.resize(n)
	for segment in n:
		var best := INF
		for a in range(_adjacent_start[segment], _adjacent_start[segment + 1]):
			var other := _adjacent[a]
			for from in range(_seg_ways[other], _seg_ways[other + 1]):
				for to in range(_seg_ways[segment], _seg_ways[segment + 1]):
					best = minf(best, _cost(from, to))
		_best_in[segment] = best


## Where the greedy plans begin, as pairs (segment, way): the fixed start, or the corners (the outer
## ends of the first and last segment of the top and the bottom row) and both ends of the longest way
## through the largest area, each end of a segment once.
func _starts() -> PackedInt32Array:
	var n := _seg_area.size()
	var starts := PackedInt32Array()
	if _fixed >= 0:
		starts.append_array([_fixed, _fixed_ways[0]])
		return starts
	# Segments come row by row from the top left: the corners are the first and last segment of the
	# top and the bottom row, each from its outer end.
	var top: Vector2i = _rows[_seg_row[0]]
	var bottom: Vector2i = _rows[_seg_row[n - 1]]
	# Both ends of the longest way through the largest area: where a spiral or a long branch is
	# best begun.
	var largest := 0
	var sizes := PackedInt32Array()
	sizes.resize(_area_count)
	sizes.fill(0)
	for segment in n:
		sizes[_seg_area[segment]] += 1
		if sizes[_seg_area[segment]] > sizes[_seg_area[largest]]:
			largest = segment
	var end := _farthest(_farthest(largest))
	var other_end := _farthest(end)
	var candidates := [Vector2i(top.x, 0), Vector2i(bottom.x, 0), Vector2i(other_end, 0),
			Vector2i(end, 0), Vector2i(top.y - 1, 1), Vector2i(n - 1, 1)]
	var seen := {}  # where the starts begin: the two holes of a cross are the same start
	for candidate: Vector2i in candidates:
		var way := _seg_ways[candidate.x] if candidate.y == 0 else _seg_ways[candidate.x + 1] - 1
		if not seen.has(_way_first[way]):
			seen[_way_first[way]] = true
			starts.append_array([candidate.x, way])
	return starts


## The segment of `start`'s area farthest from it in touching steps (breadth first); on a tie
## the one reached first.
func _farthest(start: int) -> int:
	var seen := {start: true}
	var queue := PackedInt32Array([start])
	var i := 0
	while i < queue.size():
		var segment := queue[i]
		for a in range(_adjacent_start[segment], _adjacent_start[segment + 1]):
			if not seen.has(_adjacent[a]):
				seen[_adjacent[a]] = true
				queue.append(_adjacent[a])
		i += 1
	return queue[-1]


## Stitches area by area, each segment the cheapest the rules allow after the one before; the next
## area begins at the segment nearest to where the needle is.
func _greedy(start: int, start_way: int) -> void:
	var n := _seg_area.size()
	_order = PackedInt32Array()
	_paths = []
	for area in _area_count:
		_paths.append(PackedInt32Array())
	_way = PackedInt32Array()
	_way.resize(n)
	_way.fill(-1)
	var started := PackedByteArray()
	started.resize(_area_count)
	started.fill(0)
	var queued := PackedByteArray()
	queued.resize(n)
	queued.fill(0)
	var frontier := PackedInt32Array()  # open segments of the current area touching a done one
	var segment := start
	var way := start_way
	for count in n:
		if count > 0:
			if frontier.is_empty():
				var next := _nearest_open(way, started)
				segment = next.x
				way = next.y
			else:
				var best := INF
				var best_index := -1
				var best_way := -1
				for index in frontier.size():
					var candidate := frontier[index]
					for option in range(_seg_ways[candidate], _seg_ways[candidate + 1]):
						var cost := _cost(way, option)
						if best_index < 0 or cost < best or (cost == best and candidate < frontier[best_index]):
							best = cost
							best_index = index
							best_way = option
				segment = frontier[best_index]
				way = best_way
				frontier[best_index] = frontier[-1]
				frontier.resize(frontier.size() - 1)
		var area := _seg_area[segment]
		if not started[area]:
			started[area] = 1
			_order.append(area)
		var path := _paths[area]
		path.append(segment)
		_paths[area] = path
		_way[segment] = way
		queued[segment] = 1
		for i in range(_adjacent_start[segment], _adjacent_start[segment + 1]):
			var other := _adjacent[i]
			if not queued[other]:
				queued[other] = 1
				frontier.append(other)


## The segment of an area not started yet whose entry is nearest to the end of way `from`, and its
## way, as (segment, way). Searches the rows outwards from the needle; on a tie the lower segment
## number.
func _nearest_open(from: int, started: PackedByteArray) -> Vector2i:
	var down := _way_exit[from]
	var hole_row := int(down.y)
	var best := INF
	var best_segment := -1
	var best_way := -1
	# Rows hole_row - 1 - reach and hole_row + reach have holes `reach` rows from the needle.
	var farthest := maxi(hole_row - _row_low, _row_high - hole_row) + 1
	for reach in farthest + 1:
		if float(reach) >= best:
			break
		for row: int in [hole_row - 1 - reach, hole_row + reach]:
			var segments: Vector2i = _rows.get(row, Vector2i.ZERO)
			for s in range(segments.x, segments.y):
				if started[_seg_area[s]]:
					continue
				var across := maxf(0.0, maxf(float(_seg_low[s]) - down.x, down.x - float(_seg_high[s] + 1)))
				if across >= best:
					continue
				for option in range(_seg_ways[s], _seg_ways[s + 1]):
					for entry in range(_way_entries[option], _way_entries[option + 1]):
						var hole := _entry_hole[entry]
						if hole == down:
							continue
						var distance := down.distance_to(hole)
						if distance < best or (distance == best and s < best_segment):
							best = distance
							best_segment = s
							best_way = option
	if best_segment < 0:
		# Only the hole the needle is in is left: take any open segment.
		for s in _seg_area.size():
			if not started[_seg_area[s]]:
				return Vector2i(s, _seg_ways[s])
	return Vector2i(best_segment, best_way)


## Positions of the areas in the order and of the segments in their areas' paths.
func _refresh_positions() -> void:
	_area_pos.resize(_area_count)
	for i in _order.size():
		_area_pos[_order[i]] = i
	_seg_pos.resize(_seg_area.size())
	for area in _area_count:
		var path := _paths[area]
		for i in path.size():
			_seg_pos[path[i]] = i


# --- Ways ------------------------------------------------------------------------------------

## The best way for every segment in the current order (dynamic programming over the sequence).
func _optimize_ways() -> void:
	var sequence := PackedInt32Array()
	for area in _order:
		sequence.append_array(_paths[area])
	var cost := PackedFloat64Array()  # per way: cheapest thread up to and including it
	cost.resize(_way_seg.size())
	var back := PackedInt32Array()  # per way: the way before it on that cheapest path
	back.resize(_way_seg.size())
	var previous := -1
	for segment in sequence:
		for way in range(_seg_ways[segment], _seg_ways[segment + 1]):
			if not _way_allowed(segment, way):
				cost[way] = INF
				continue
			if previous < 0:
				cost[way] = _cost(-1, way)
				back[way] = -1
				continue
			var best := INF
			var best_way := -1
			for before in range(_seg_ways[previous], _seg_ways[previous + 1]):
				var total := cost[before] + _cost(before, way)
				if total < best:
					best = total
					best_way = before
			cost[way] = best
			back[way] = best_way
		previous = segment
	var last := sequence[-1]
	var way := -1
	for option in range(_seg_ways[last], _seg_ways[last + 1]):
		if way < 0 or cost[option] < cost[way]:
			way = option
	for i in range(sequence.size() - 1, -1, -1):
		if _way[sequence[i]] != way:
			_way[sequence[i]] = way
			_area_dirty[_seg_area[sequence[i]]] = 1
		way = back[way]


# --- Area order ------------------------------------------------------------------------------

## Thread from the end of `from_area` (-1: nothing before) into way `to`. An area of one single
## cross ends in whichever of its ways suits `to` best: its way doesn't change what leads into it.
func _area_link_to(from_area: int, to: int) -> float:
	if from_area < 0:
		return _cost(-1, to)
	if not _area_free[from_area]:
		return _cost(_last_way(from_area), to)
	var segment := _paths[from_area][0]
	var best := INF
	for way in range(_seg_ways[segment], _seg_ways[segment + 1]):
		if _way_allowed(segment, way):
			best = minf(best, _cost(way, to))
	return best


## Like _area_link_to(), into the first way of `to_area`; nothing (-1) costs nothing.
func _area_link(from_area: int, to_area: int) -> float:
	return 0.0 if to_area < 0 else _area_link_to(from_area, _first_way(to_area))


## Moves runs of areas elsewhere and reverses runs of them while that saves thread.
func _improve_area_order() -> void:
	if _order.size() < 2:
		return
	# Only from areas that begin or end differently since last time, and their neighbours.
	var queue := PackedInt32Array()
	var count := _order.size()
	for p in count:
		var area := _order[p]
		var ends := _first_way(area) * (_way_seg.size() + 1) + _last_way(area)
		if _area_ends[area] != ends:
			_area_ends[area] = ends
			for q in [p - 1, p, p + 1]:
				if q >= 0 and q < count and not queue.has(_order[q]):
					queue.append(_order[q])
	if queue.is_empty():
		return
	_build_near_areas()
	_search_area_order(queue)


## Local search on the area order: looks at the areas in `queue` and again at those next to every
## change, moving runs of up to CHAIN areas from or to each and reversing runs of areas so that it
## leads into a near one. Returns the thread saved.
func _search_area_order(queue: PackedInt32Array) -> float:
	var saved := 0.0
	var queued := {}
	for area in queue:
		queued[area] = true
	queue.reverse()
	_area_sums_dirty = true
	while not queue.is_empty() and _calls <= _limit:
		var area := queue[-1]
		queue.resize(queue.size() - 1)
		queued.erase(area)
		var gain := 0.0
		var p := _area_pos[area]
		for length in range(1, CHAIN + 1):
			for start in ([p, p - length + 1] if length > 1 else [p]):
				if gain <= 0.0 and start >= 0:
					gain = _move_areas(start, length)
		if gain <= 0.0:
			gain = _reverse_areas_at(area)
		if gain <= 0.0:
			continue
		saved += gain
		_area_sums_dirty = true
		for other in _touched_areas:
			if not queued.has(other):
				queued[other] = true
				queue.append(other)
	return saved


## Iterated local search on the area order: swaps two neighbouring runs of up to KICK_RUN areas at
## random (with a fixed seed, so always the same way), improves the order around them and keeps
## the result only if the thread got shorter. KICKS_PER_AREA tries per area, while the budget lasts.
func _shake_area_order() -> void:
	var count := _order.size()
	var low := 1 if _fixed >= 0 else 0
	if count - low < 4:
		return
	var random := RandomNumberGenerator.new()
	random.seed = SEED
	_build_near_areas()
	for kick in KICKS_PER_AREA * count:
		if _calls > _limit:
			break
		var first := random.randi_range(1, mini(KICK_RUN, floori((count - low) / 2.0)))
		var second := random.randi_range(1, mini(KICK_RUN, count - low - first))
		var start := random.randi_range(low, count - first - second)
		var kept_order := _order.duplicate()
		var kept_way := _way.duplicate()
		var change := _swap_runs(start, first, second)
		var touched := PackedInt32Array()
		for p in [start - 1, start, start + second - 1, start + second, start + first + second - 1,
				start + first + second]:
			if p >= 0 and p < count:
				touched.append(_order[p])
		change -= _search_area_order(touched)
		if change < -EPSILON:
			continue
		_order = kept_order
		_way = kept_way
		for i in count:
			_area_pos[_order[i]] = i
	_area_sums_dirty = true


## Swaps the run of `first` areas at position `start` with the run of `second` areas after it;
## returns how much more thread that costs.
func _swap_runs(start: int, first: int, second: int) -> float:
	var count := _order.size()
	var a_first := _order[start]
	var a_last := _order[start + first - 1]
	var b_first := _order[start + first]
	var b_last := _order[start + first + second - 1]
	var before := _order[start - 1] if start > 0 else -1
	var after := _order[start + first + second] if start + first + second < count else -1
	var old := _area_link(before, a_first) + _area_link(a_last, b_first) + _area_link(b_last, after)
	var new := _area_link(before, b_first) + _area_link(b_last, a_first) + _area_link(a_last, after)
	var swapped := _order.slice(start + first, start + first + second)
	swapped.append_array(_order.slice(start, start + first))
	for i in swapped.size():
		_order[start + i] = swapped[i]
		_area_pos[swapped[i]] = start + i
	return new - old


## For each area, the NEIGHBOURS areas whose entry is nearest to its exit, and those whose exit is
## nearest to its entry.
func _build_near_areas() -> void:
	var entries := PackedVector2Array()
	var exits := PackedVector2Array()
	for area in _area_count:
		entries.append(_entry_hole[_way_entries[_first_way(area)]])
		exits.append(_way_exit[_last_way(area)])
	_near_after = _nearest_points(exits, entries, NEIGHBOURS)
	_near_before = _nearest_points(entries, exits, NEIGHBOURS)


## For each point of `from`, the indices of the `count` nearest points of `to` (never its own).
static func _nearest_points(from: PackedVector2Array, to: PackedVector2Array, count: int) -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	var low := to[0]
	var high := to[0]
	for point in to + from:
		low = low.min(point)
		high = high.max(point)
	var cell := maxf(2.0, sqrt(maxf(1.0, (high.x - low.x + 1.0) * (high.y - low.y + 1.0) / to.size())) * 1.5)
	var columns := int((high.x - low.x) / cell) + 1
	var rows := int((high.y - low.y) / cell) + 1
	var buckets: Array[PackedInt32Array] = []
	buckets.resize(columns * rows)
	for i in to.size():
		var at := Vector2i(((to[i] - low) / cell).floor())
		var bucket := buckets[at.y * columns + at.x]
		bucket.append(i)
		buckets[at.y * columns + at.x] = bucket
	for i in from.size():
		var point := from[i]
		var center := Vector2i(((point - low) / cell).floor())
		var found := PackedInt32Array()
		var distances := PackedFloat64Array()
		var ring := 0
		while true:
			for y in range(center.y - ring, center.y + ring + 1):
				if y < 0 or y >= rows:
					continue
				var step := 1 if y == center.y - ring or y == center.y + ring else 2 * ring
				for x in range(center.x - ring, center.x + ring + 1, maxi(step, 1)):
					if x < 0 or x >= columns:
						continue
					for j in buckets[y * columns + x]:
						if j == i:
							continue
						var distance := point.distance_to(to[j])
						if found.size() == count and distance >= distances[-1]:
							continue
						var at := found.size()
						while at > 0 and distances[at - 1] > distance:
							at -= 1
						found.insert(at, j)
						distances.insert(at, distance)
						if found.size() > count:
							found.resize(count)
							distances.resize(count)
			# Every point not seen yet is at least `ring` cells away.
			var reach := ring * cell
			if (found.size() == count and distances[-1] <= reach) or ring > maxi(columns, rows):
				break
			ring += 1
		result.append(found)
	return result


## Tries to move the `length` areas from position `start` to a better place, as they are or
## turned round; returns the thread saved (0 if it didn't), with the areas next to the change in
## _touched_areas.
func _move_areas(start: int, length: int) -> float:
	var count := _order.size()
	if start + length > count or (_fixed >= 0 and start == 0) or length >= count:
		return 0.0
	var head := _order[start]
	var tail := _order[start + length - 1]
	var before := _order[start - 1] if start > 0 else -1
	var after := _order[start + length] if start + length < count else -1
	var removed := _area_link(before, head) + _area_link(tail, after) - _area_link(before, after)
	var inside := 0.0
	var inside_turned := 0.0
	for i in range(start, start + length - 1):
		inside += _area_link(_order[i], _order[i + 1])
		inside_turned += _area_link(_order[i + 1], _order[i])
	# An area of one segment whose ways begin differently may change its way where it goes.
	var lone := length == 1 and _paths[head].size() == 1 and not _area_free[head]
	var best := -EPSILON
	var best_gap := -2
	var best_turned := false
	var best_way := -1
	for turned in ([false, true] if length > 1 else [false]):
		var first := tail if turned else head
		var last := head if turned else tail
		var change := (inside_turned - inside) if turned else 0.0
		# Gaps as the area after which the run goes (-1: the very front).
		var gaps := PackedInt32Array()
		for other in _near_before[first]:
			gaps.append(other)
		for other in _near_after[last]:
			gaps.append(_order[_area_pos[other] - 1] if _area_pos[other] > 0 else -1)
		gaps.append(_order[-1])
		if _fixed < 0:
			gaps.append(-1)
		for gap in gaps:
			var gap_pos := _area_pos[gap] if gap >= 0 else -1
			if (gap_pos >= start - 1 and gap_pos < start + length) or (gap < 0 and _fixed >= 0):
				continue  # next to the run or inside it, or before the fixed start
			var b := _order[gap_pos + 1] if gap_pos + 1 < count else -1
			if lone:
				var segment := _paths[head][0]
				for way in range(_seg_ways[segment], _seg_ways[segment + 1]):
					var gain := (_area_link_to(gap, way) + (_cost(way, _first_way(b)) if b >= 0 else 0.0)
							- _area_link(gap, b) - removed)
					if gain < best:
						best = gain
						best_gap = gap
						best_way = way
			else:
				var gain := (_area_link(gap, first) + _area_link(last, b) - _area_link(gap, b)
						- removed + change)
				if gain < best:
					best = gain
					best_gap = gap
					best_turned = turned
	if best_gap == -2:
		return 0.0
	_touched_areas = _order.slice(start, start + length)
	for p in [start - 1, start + length]:
		if p >= 0 and p < count:
			_touched_areas.append(_order[p])
	# The areas the run goes between.
	var after_gap := 0
	if best_gap >= 0:
		_touched_areas.append(best_gap)
		after_gap = _area_pos[best_gap] + 1
	if after_gap < count:
		_touched_areas.append(_order[after_gap])
	var run := _order.slice(start, start + length)
	if best_turned:
		run.reverse()
	var rest := _order.slice(0, start)
	rest.append_array(_order.slice(start + length))
	var at := rest.find(best_gap) + 1 if best_gap >= 0 else 0
	_order = rest.slice(0, at)
	_order.append_array(run)
	_order.append_array(rest.slice(at))
	if lone:
		_way[_paths[head][0]] = best_way
	for i in _order.size():
		_area_pos[_order[i]] = i
	return -best


## Tries to reverse a run of areas (each keeping its own order) that starts or ends next to `area`,
## so that `area` then leads into a near area or a near area into it; returns the thread saved (0 if
## it didn't), with the areas next to the change in _touched_areas.
func _reverse_areas_at(area: int) -> float:
	var count := _order.size()
	if _area_sums_dirty:
		_area_forward.resize(count)
		_area_backward.resize(count)
		_area_forward[0] = 0.0
		_area_backward[0] = 0.0
		for i in range(1, count):
			_area_forward[i] = _area_forward[i - 1] + _area_link(_order[i - 1], _order[i])
			_area_backward[i] = _area_backward[i - 1] + _area_link(_order[i], _order[i - 1])
		_area_sums_dirty = false
	var p := _area_pos[area]
	var runs := PackedInt32Array()  # pairs: first and last position
	for other in _near_after[area]:
		# area's exit leads into other's entry: p stays and p + 1 .. q turn round, or p .. q - 1.
		var q := _area_pos[other]
		if q > p + 1:
			runs.append_array([p + 1, q, p, q - 1])
	for other in _near_before[area]:
		# other's exit leads into area's entry.
		var q := _area_pos[other]
		if q < p - 1:
			runs.append_array([q + 1, p, q, p - 1])
	for r in range(0, runs.size(), 2):
		var low := runs[r]
		var high := runs[r + 1]
		if low >= high or (_fixed >= 0 and low == 0):
			continue
		var before := _order[low - 1] if low > 0 else -1
		var after := _order[high + 1] if high + 1 < count else -1
		var old := (_area_link(before, _order[low]) + _area_forward[high] - _area_forward[low]
				+ _area_link(_order[high], after))
		var new := (_area_link(before, _order[high]) + _area_backward[high] - _area_backward[low]
				+ _area_link(_order[low], after))
		if new < old - EPSILON:
			_touched_areas = PackedInt32Array()
			for at in [low - 1, low, high, high + 1]:
				if at >= 0 and at < count:
					_touched_areas.append(_order[at])
			var middle := _order.slice(low, high + 1)
			middle.reverse()
			for i in middle.size():
				_order[low + i] = middle[i]
				_area_pos[middle[i]] = low + i
			return old - new
	return 0.0


# --- Inside areas ----------------------------------------------------------------------------

## Improves the order inside every area, given where the needle comes from and goes to next.
func _improve_areas() -> void:
	for p in _order.size():
		var area := _order[p]
		if _paths[area].size() < 2:
			continue
		var before := _last_way(_order[p - 1]) if p > 0 else -1
		var after := _first_way(_order[p + 1]) if p + 1 < _order.size() else -1
		var context := (before + 1) * (_way_seg.size() + 1) + after + 1
		if _settled[area] == context and not _area_dirty[area]:
			continue
		_improve_area(area, before, after)
		_settled[area] = context
		_area_dirty[area] = 0


## Local search inside `area` between ways `before` and `after`. Small areas get their best order
## outright. In larger ones each segment is looked at, and again whenever something changed next
## to it (see _improve_at()); then windows of WINDOW segments around jumps are put in their best
## order, and that again until nothing gets shorter.
func _improve_area(area: int, before: int, after: int) -> void:
	_update_edges(area, before, after, _paths[area])
	if _paths[area].size() <= EXACT_AREA:
		_reorder(area, 0, _paths[area].size(), before, after)
		return
	if _turn_area(area, before, after):
		_update_edges(area, before, after, _paths[area])
	_mark_jumps(area)
	var queue := _paths[area].duplicate()
	queue.reverse()
	var queued := {}
	for segment in queue:
		queued[segment] = true
	for pass_number in MAX_ROUNDS:
		while not queue.is_empty() and _calls <= _limit:
			var segment := queue[-1]
			queue.resize(queue.size() - 1)
			queued.erase(segment)
			var touched := _improve_at(area, segment, before, after)
			if touched.is_empty():
				continue
			_update_edges(area, before, after, touched)
			_mark_jumps(area)
			for other in touched:
				if not queued.has(other):
					queued[other] = true
					queue.append(other)
		var reordered := _reorder_windows(area, before, after)
		if reordered.is_empty() or _calls > _limit:
			break
		_update_edges(area, before, after, reordered)
		_mark_jumps(area)
		for other in reordered:
			if not queued.has(other):
				queued[other] = true
				queue.append(other)


## Tries the moves around `segment` of `area`'s path; returns the segments next to the change, or
## nothing if none saved thread. Moved are runs starting or ending at it that have a jump at one
## end (up to CHAIN segments, also turned round) or at both ends (up to LONG_CHAIN), next to a
## segment they touch; reversed are runs from or to it with a jump at one end.
func _improve_at(area: int, segment: int, before: int, after: int) -> PackedInt32Array:
	var size := _paths[area].size()
	var i := _seg_pos[segment]
	for length in range(1, mini(CHAIN, size - 1) + 1):
		for start in ([i, i - length + 1] if length > 1 else [i]):
			if start >= 0 and start + length <= size and (_jumps[start] or _jumps[start + length]):
				var touched := _move_run(area, start, length, before, after, true)
				if not touched.is_empty():
					return touched
	# Long runs from here to a jump, and from a jump to here.
	if _jumps[i]:
		for end in range(i + CHAIN + 1, mini(i + LONG_CHAIN, size) + 1):
			if _jumps[end] and end - i < size:
				var touched := _move_run(area, i, end - i, before, after, false)
				if not touched.is_empty():
					return touched
	if _jumps[i + 1]:
		for start in range(i - CHAIN, maxi(i + 1 - LONG_CHAIN, 0) - 1, -1):
			if _jumps[start] and i + 1 - start < size:
				var touched := _move_run(area, start, i + 1 - start, before, after, false)
				if not touched.is_empty():
					return touched
	return _reverse_at(area, i, before, after)


## Fills _jumps for `area`: a transition is a jump when it costs clearly more (JUMP) than the
## cheapest one into the same segment from a touching segment. The area's start and end count as
## jumps, since what comes before and after can be anywhere.
func _mark_jumps(area: int) -> void:
	var path := _paths[area]
	_jumps.resize(path.size() + 1)
	_forward.resize(path.size())
	_backward.resize(path.size())
	_jumps[0] = 1
	_forward[0] = 0.0
	_backward[0] = 0.0
	for i in range(1, path.size()):
		var segment := path[i]
		_jumps[i] = 1 if _edge_in[segment] - _best_in[segment] > JUMP else 0
		_forward[i] = _forward[i - 1] + _edge_in[segment]
		_backward[i] = _backward[i - 1] + _edge_back[segment]
	_jumps[path.size()] = 1


## Works out the edges (see _edge_in) of `segments` of `area`'s path, which lies between ways
## `before` and `after`, and the one out of its end.
func _update_edges(area: int, before: int, after: int, segments: PackedInt32Array) -> void:
	var path := _paths[area]
	for segment in segments:
		var p := _seg_pos[segment]
		if p == 0:
			_edge_in[segment] = _cost(before, _way[segment])
			_edge_back[segment] = 0.0
		else:
			_edge_in[segment] = _cost(_way[path[p - 1]], _way[segment])
			_edge_back[segment] = _cost(_way[segment], _way[path[p - 1]])
	_edge_end = _link(_way[path[-1]], after)


## The edge into position `p` of `area`'s path: into the segment there, or out of the end.
func _edge_at(area: int, p: int) -> float:
	var path := _paths[area]
	return _edge_in[path[p]] if p < path.size() else _edge_end


## Puts windows of WINDOW segments of `area`'s path in their best order where a transition in or
## into them costs more than it could; returns the segments of the windows that changed.
func _reorder_windows(area: int, before: int, after: int) -> PackedInt32Array:
	var changed := PackedInt32Array()
	var excess := _excess(area, before, after)
	var i := 0
	while i + WINDOW <= _paths[area].size():
		var window := 0.0
		for k in range(i, i + WINDOW + 1):
			window += excess[k]
		if window > SLACK and _reorder(area, i, WINDOW, before, after):
			changed.append_array(_paths[area].slice(i, i + WINDOW + 1))
			_update_edges(area, before, after, _paths[area].slice(i, i + WINDOW + 1))
			excess = _excess(area, before, after)
		i += 1
	return changed


## Per position of `area`'s path (and one more for what follows it), how much more thread the
## transition into it costs than the cheapest one from a touching segment. The ends always count
## as worth trying when something comes before or after.
func _excess(area: int, before: int, after: int) -> PackedFloat64Array:
	var path := _paths[area]
	var excess := PackedFloat64Array()
	excess.resize(path.size() + 1)
	excess[0] = INF if before >= 0 else 0.0
	for i in range(1, path.size()):
		excess[i] = maxf(0.0, _edge_in[path[i]] - _best_in[path[i]])
	excess[path.size()] = INF if after >= 0 else 0.0
	return excess


## The way before position `i` of `area`'s path: the segment before it, or `before` at the start.
func _way_before(area: int, i: int, before: int) -> int:
	return _way[_paths[area][i - 1]] if i > 0 else before


## The way after position `i - 1` of `area`'s path: the segment at `i`, or `after` past the end.
func _way_after(area: int, i: int, after: int) -> int:
	return _way[_paths[area][i]] if i < _paths[area].size() else after


## Puts the `count` segments from position `start` of `area`'s path in their best order (and best
## ways) between what comes before and after them, keeping the area growing without holes; true if
## that saved thread. Exact: dynamic programming over the subsets.
func _reorder(area: int, start: int, count: int, before_area: int, after_area: int) -> bool:
	var path := _paths[area]
	var before := _way_before(area, start, before_area)
	var after := _way_after(area, start + count, after_area)
	var nodes := path.slice(start, start + count)
	var width := 1  # slots per node: the most ways any node has
	for segment in nodes:
		width = maxi(width, _seg_ways[segment + 1] - _seg_ways[segment])
	var slots := count * width
	var ways := PackedInt32Array()  # way per slot, -1 for none
	ways.resize(slots)
	ways.fill(-1)
	var touch := PackedInt32Array()  # per node: bit mask of the nodes it touches
	var anchored := PackedByteArray()  # per node: touches a segment before the window
	touch.resize(count)
	anchored.resize(count)
	var fixed_first := _fixed >= 0 and start == 0 and _seg_area[_fixed] == area
	for i in count:
		var segment := nodes[i]
		var slot := i * width
		for way in range(_seg_ways[segment], _seg_ways[segment + 1]):
			if _way_allowed(segment, way):
				ways[slot] = way
				slot += 1
		touch[i] = 0
		anchored[i] = 0
		for a in range(_adjacent_start[segment], _adjacent_start[segment + 1]):
			var p := _seg_pos[_adjacent[a]]
			if p < start:
				anchored[i] = 1
			elif p < start + count:
				touch[i] |= 1 << (p - start)
	# Costs between the slots, from `before` and to `after`.
	var between := PackedFloat64Array()
	between.resize(slots * slots)
	var from_before := PackedFloat64Array()
	from_before.resize(slots)
	var to_after := PackedFloat64Array()
	to_after.resize(slots)
	for i in slots:
		if ways[i] < 0:
			continue
		from_before[i] = _cost(before, ways[i])
		to_after[i] = _link(ways[i], after)
		for j in slots:
			if ways[j] >= 0 and _way_seg[ways[i]] != _way_seg[ways[j]]:
				between[i * slots + j] = _cost(ways[i], ways[j])
	var current := 0.0
	for i in count + 1:
		current += _edge_at(area, start + i)
	# best[mask * slots + slot]: cheapest way to stitch the nodes in mask, ending in slot.
	var full := (1 << count) - 1
	var best := PackedFloat64Array()
	best.resize((full + 1) * slots)
	best.fill(INF)
	var from := PackedInt32Array()
	from.resize((full + 1) * slots)
	for i in count:
		# The first of the window: the fixed start, any segment when the window begins the area,
		# else one touching a segment before the window.
		var may_start := nodes[i] == _fixed if fixed_first else (start == 0 or anchored[i] == 1)
		if not may_start:
			continue
		for s in range(i * width, i * width + width):
			if ways[s] >= 0:
				best[(1 << i) * slots + s] = from_before[s]
				from[(1 << i) * slots + s] = -1
	for mask in range(1, full + 1):
		for s in slots:
			var cost := best[mask * slots + s]
			if cost == INF:
				continue
			for j in count:
				var bit := 1 << j
				if mask & bit or not (anchored[j] or touch[j] & mask):
					continue
				var next := (mask | bit) * slots
				for t in range(j * width, j * width + width):
					if ways[t] < 0:
						continue
					var total := cost + between[s * slots + t]
					if total < best[next + t]:
						best[next + t] = total
						from[next + t] = mask * slots + s
	var best_total := INF
	var best_state := -1
	for s in slots:
		var total := best[full * slots + s] + to_after[s]
		if total < best_total:
			best_total = total
			best_state = full * slots + s
	if best_state < 0 or best_total >= current - EPSILON:
		return false
	var chosen := PackedInt32Array()
	var state := best_state
	while state >= 0:
		chosen.append(state % slots)
		state = from[state]
	chosen.reverse()
	for i in count:
		var way := ways[chosen[i]]
		var segment := _way_seg[way]
		path[start + i] = segment
		_way[segment] = way
		_seg_pos[segment] = start + i
	_paths[area] = path
	return true


## Tries to move the `length` segments from position `start` of `area`'s path elsewhere in it, next
## to a segment its first or last one touches or to an end (turned round too if `may_turn`), keeping
## the area growing without holes. Returns the segments next to the change, or nothing.
func _move_run(area: int, start: int, length: int, before_area: int, after_area: int,
		may_turn: bool) -> PackedInt32Array:
	var path := _paths[area]
	var size := path.size()
	var fixed_here := _fixed >= 0 and _seg_area[_fixed] == area
	if fixed_here and start == 0:
		return PackedInt32Array()
	var before := _way_before(area, start, before_area)
	var after := _way_after(area, start + length, after_area)
	var head := path[start]
	var tail := path[start + length - 1]
	var removed := _edge_in[head] + _edge_at(area, start + length) - _link(before, after)
	var inside := 0.0
	var inside_turned := 0.0
	if may_turn:
		for i in range(start + 1, start + length):
			inside += _edge_in[path[i]]
			inside_turned += _edge_back[path[i]]
	var best := -EPSILON
	var best_gap := -1
	var best_turned := false
	for turned in ([false, true] if may_turn and length > 1 else [false]):
		var first := tail if turned else head
		var last := head if turned else tail
		var change := (inside_turned - inside) if turned else 0.0
		# Gaps (insert before path[gap]): after a segment touching the first, before one touching
		# the last, and both ends.
		var gaps := PackedInt32Array([0, size])
		for a in range(_adjacent_start[first], _adjacent_start[first + 1]):
			gaps.append(_seg_pos[_adjacent[a]] + 1)
		for a in range(_adjacent_start[last], _adjacent_start[last + 1]):
			gaps.append(_seg_pos[_adjacent[a]])
		for gap in gaps:
			if (gap >= start and gap <= start + length) or (gap == 0 and fixed_here):
				continue
			var a := _way_before(area, gap, before_area)
			var b := _way_after(area, gap, after_area)
			var gain := _link(a, _way[first]) + _link(_way[last], b) - _edge_at(area, gap) - removed + change
			if gain < best and _keeps_growing(area, start, length, gap, turned):
				best = gain
				best_gap = gap
				best_turned = turned
	if best_gap < 0:
		return PackedInt32Array()
	var touched := PackedInt32Array()
	for p in [start - 1, start + length, best_gap - 1, best_gap]:
		if p >= 0 and p < size:
			touched.append(path[p])
	var run := path.slice(start, start + length)
	touched.append_array(run)
	if best_turned:
		run.reverse()
	var rest := path.slice(0, start)
	rest.append_array(path.slice(start + length))
	var at := best_gap if best_gap < start else best_gap - length
	path = rest.slice(0, at)
	path.append_array(run)
	path.append_array(rest.slice(at))
	_paths[area] = path
	for i in path.size():
		_seg_pos[path[i]] = i
	return touched


## Position of path position `p` after moving the run of `length` from `start` to before `gap`.
static func _moved(p: int, start: int, length: int, gap: int, turned: bool) -> int:
	if gap > start + length:
		if p < start or p >= gap:
			return p
		if p < start + length:
			return gap - 1 - (p - start) if turned else gap - length + (p - start)
		return p - length
	if p < gap or p >= start + length:
		return p
	if p >= start:
		return gap + length - 1 - (p - start) if turned else gap + (p - start)
	return p + length


## Whether every segment of `area` still touches one before it after that move (the first needs
## none). Only the run, the segments touching it and the old first can change.
func _keeps_growing(area: int, start: int, length: int, gap: int, turned: bool) -> bool:
	var path := _paths[area]
	var check := PackedInt32Array([path[0]])
	for i in range(start, start + length):
		check.append(path[i])
		for a in range(_adjacent_start[path[i]], _adjacent_start[path[i] + 1]):
			check.append(_adjacent[a])
	for segment in check:
		var p := _moved(_seg_pos[segment], start, length, gap, turned)
		if p == 0:
			continue
		var found := false
		for a in range(_adjacent_start[segment], _adjacent_start[segment + 1]):
			if _moved(_seg_pos[_adjacent[a]], start, length, gap, turned) < p:
				found = true
				break
		if not found:
			return false
	return true


## Tries to reverse a run of `area`'s path that starts or ends at position `i`, so that a segment
## then follows one it touches, where one of the two transitions it breaks is a jump. Returns the
## segments next to the change, or nothing.
func _reverse_at(area: int, i: int, before_area: int, after_area: int) -> PackedInt32Array:
	var path := _paths[area]
	var size := path.size()
	var fixed_here := _fixed >= 0 and _seg_area[_fixed] == area
	var runs := PackedInt32Array()  # pairs: first, last position
	# Runs i .. j: the segment before i then leads into j, or i into the one after j.
	if i > 0:
		for a in range(_adjacent_start[path[i - 1]], _adjacent_start[path[i - 1] + 1]):
			runs.append_array([i, _seg_pos[_adjacent[a]]])
	for a in range(_adjacent_start[path[i]], _adjacent_start[path[i] + 1]):
		runs.append_array([i, _seg_pos[_adjacent[a]] - 1])
	runs.append_array([i, size - 1])
	# Runs h .. i: the segment before h then leads into i, or h into the one after i.
	for a in range(_adjacent_start[path[i]], _adjacent_start[path[i] + 1]):
		runs.append_array([_seg_pos[_adjacent[a]] + 1, i])
	if i + 1 < size:
		for a in range(_adjacent_start[path[i + 1]], _adjacent_start[path[i + 1] + 1]):
			runs.append_array([_seg_pos[_adjacent[a]], i])
	runs.append_array([0, i])
	for r in range(0, runs.size(), 2):
		var low := runs[r]
		var high := runs[r + 1]
		if high <= low or low < 0 or high >= size or (fixed_here and low == 0):
			continue
		if not (_jumps[low] or _jumps[high + 1]):
			continue
		var from := _way_before(area, low, before_area)
		var to := _way_after(area, high + 1, after_area)
		var old := (_edge_in[path[low]] + _edge_at(area, high + 1)
				+ _forward[high] - _forward[low])
		var new := (_cost(from, _way[path[high]]) + _link(_way[path[low]], to)
				+ _backward[high] - _backward[low])
		if new < old - EPSILON and _reversal_keeps_growing(area, low, high):
			var touched := PackedInt32Array()
			for p in [low - 1, high + 1]:
				if p >= 0 and p < size:
					touched.append(path[p])
			var middle := path.slice(low, high + 1)
			touched.append_array(middle)
			middle.reverse()
			for k in middle.size():
				path[low + k] = middle[k]
				_seg_pos[middle[k]] = low + k
			_paths[area] = path
			return touched
	return PackedInt32Array()


## Whether `area` still grows without holes with positions i .. j of its path reversed.
func _reversal_keeps_growing(area: int, i: int, j: int) -> bool:
	var path := _paths[area]
	for p in range(i, j + 1):
		var segment := path[p]
		var new := i + j - p
		if new == 0:
			continue
		var found := false
		for a in range(_adjacent_start[segment], _adjacent_start[segment + 1]):
			var q := _seg_pos[_adjacent[a]]
			if (q < i) or (q >= i and q <= j and i + j - q < new):
				found = true
				break
		if not found:
			return false
	return true


## Turns `area`'s whole path round (with the best ways for it) if it still grows without holes
## that way and that saves thread.
func _turn_area(area: int, before: int, after: int) -> bool:
	var path := _paths[area]
	if _fixed >= 0 and _seg_area[_fixed] == area:
		return false
	var turned := path.duplicate()
	turned.reverse()
	for i in range(1, turned.size()):
		var segment := turned[i]
		var found := false
		for a in range(_adjacent_start[segment], _adjacent_start[segment + 1]):
			if _seg_pos[_adjacent[a]] > _seg_pos[segment]:
				found = true
				break
		if not found:
			return false
	var current := _path_cost(path, before, after, false)
	var new := _path_cost(turned, before, after, true)
	if new >= current - EPSILON:
		return false
	_paths[area] = turned
	for i in turned.size():
		_seg_pos[turned[i]] = i
	_path_cost(turned, before, after, true, true)
	return true


## Thread along `path` from way `before` to way `after`: with the current ways, or with the best
## ways for it (`best_ways`), which `apply` then keeps.
func _path_cost(path: PackedInt32Array, before: int, after: int, best_ways: bool, apply := false) -> float:
	if not best_ways:
		var total := _cost(before, _way[path[0]])
		for i in range(1, path.size()):
			total += _cost(_way[path[i - 1]], _way[path[i]])
		return total + _link(_way[path[-1]], after)
	var cost := {}  # way -> cheapest thread up to it
	var back := {}
	var previous := -1
	for segment in path:
		for way in range(_seg_ways[segment], _seg_ways[segment + 1]):
			if previous < 0:
				cost[way] = _cost(before, way)
				back[way] = -1
				continue
			var best := INF
			var best_way := -1
			for option in range(_seg_ways[previous], _seg_ways[previous + 1]):
				var total: float = cost[option] + _cost(option, way)
				if total < best:
					best = total
					best_way = option
			cost[way] = best
			back[way] = best_way
		previous = segment
	var last := path[-1]
	var end := -1
	var end_cost := INF
	for way in range(_seg_ways[last], _seg_ways[last + 1]):
		var total: float = cost[way] + _link(way, after)
		if total < end_cost:
			end_cost = total
			end = way
	if apply:
		for i in range(path.size() - 1, -1, -1):
			_way[path[i]] = end
			end = back[end]
	return end_cost

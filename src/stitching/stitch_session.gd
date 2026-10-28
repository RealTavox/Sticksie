class_name StitchSession
extends RefCounted
## Progress of stitching one pattern: how many planned steps of each thread are done, and where
## the user started a new thread by hand.

enum Cell {
	NONE,
	## Only the bottom leg is stitched.
	HALF,
	## The whole cross is stitched.
	FULL,
}

## Why a step begins with a new thread.
enum ThreadStart {
	NONE,
	## The first step of the colour.
	FIRST,
	## The way from the previous step is longer than the skip limit.
	AUTO,
	## The user asked for a new thread here.
	MANUAL,
}

var pattern: Pattern
## Row order and start side (the start corner). Change them with set_direction(), which replans.
var top_to_bottom := true
var start_left := true
## Whether each thread starts in whichever corner leaves the least thread on the back
## (StitchPlanner.plan_shortest()) instead of top_to_bottom and start_left. Changed with
## set_direction() too. Not saved with the project; it comes from the preferences.
var auto_start := false
## Most cells the thread may skip on the back (StitchPlanner.UNLIMITED: no automatic changes).
## Change it with set_max_skip(), which replans.
var max_skip := StitchPlanner.UNLIMITED
## English method: whole crosses one by one instead of Danish passes. Change it with
## set_english(), which replans. Not saved with the project; it comes from the preferences.
var english := false
## Danish return pass in one step per run of adjacent cells instead of blocks of 5. Change it
## with set_whole_back(), which replans. Not saved with the project either.
var whole_back := false
## Most stitches in one block. Change it with set_max_block(), which replans. Not saved with the
## project either.
var max_block := StitchPlanner.DEFAULT_MAX_BLOCK

var _plans := {}  # thread index -> Array[StitchStep]
## Per thread index, one flag per planned step: 1 when done. Not just "the first n steps", since
## after replanning finished stitches can lie anywhere in the new order.
var _done := {}  # thread index -> PackedByteArray
## Manual thread changes per thread index, each as the step's key (see step_key()). Keys instead
## of step numbers, so they stay at the same stitch when the plan changes.
var _manual_starts := {}  # thread index -> Array[Vector3i]


func _init(p_pattern: Pattern) -> void:
	pattern = p_pattern


func steps(thread: int) -> Array[StitchStep]:
	if not _plans.has(thread):
		if auto_start:
			_plans[thread] = StitchPlanner.plan_shortest(pattern, thread, max_skip, english, whole_back,
					max_block)
		else:
			_plans[thread] = StitchPlanner.plan(pattern, thread, top_to_bottom, start_left, max_skip,
					english, whole_back, max_block)
	return _plans[thread]


## Number of finished steps of `thread`.
func done_count(thread: int) -> int:
	return _flags(thread).count(1)


func is_done(thread: int, index: int) -> bool:
	return _flags(thread)[index] == 1


## Index of the next step of `thread`: the first one not done, or the step count when finished.
func current_index(thread: int) -> int:
	var index := _flags(thread).find(0)
	return steps(thread).size() if index < 0 else index


## The next step of `thread`, or null when the thread is finished.
func current_step(thread: int) -> StitchStep:
	var index := current_index(thread)
	return steps(thread)[index] if index < steps(thread).size() else null


func advance(thread: int) -> void:
	var index := current_index(thread)
	if index < steps(thread).size():
		_set_flag(thread, index, 1)


## Takes back the last finished step before the current one.
func go_back(thread: int) -> void:
	var previous := _previous_done(thread)
	if previous >= 0:
		_set_flag(thread, previous, 0)


## The cell of the last stitch made in `thread` (the needle is there), or (-1, -1) before the
## first.
func last_cell(thread: int) -> Vector2i:
	var previous := _previous_done(thread)
	if previous < 0:
		return Vector2i(-1, -1)
	var step := steps(thread)[previous]
	return Vector2i(step.cells[-1], step.row)


## Changes the skip limit and replans every thread. Finished stitches stay finished: progress
## is taken over from the stitched cells.
func set_max_skip(value: int) -> void:
	if value == max_skip:
		return
	var states := cell_states()
	max_skip = value
	_replan(states)


## Changes the start corner (or `auto` for the shortest thread) and replans every thread,
## keeping progress like set_max_skip().
func set_direction(p_top_to_bottom: bool, p_start_left: bool, auto := false) -> void:
	if p_top_to_bottom == top_to_bottom and p_start_left == start_left and auto == auto_start:
		return
	var states := cell_states()
	top_to_bottom = p_top_to_bottom
	start_left = p_start_left
	auto_start = auto
	_replan(states)


## Switches between the English and the Danish method and replans, keeping progress like
## set_max_skip(). Half stitches from Danish passes count as not done for English crosses.
func set_english(value: bool) -> void:
	if value == english:
		return
	var states := cell_states()
	english = value
	_replan(states)


## Switches the Danish return pass between blocks and whole runs and replans, keeping progress
## like set_max_skip().
func set_whole_back(value: bool) -> void:
	if value == whole_back:
		return
	var states := cell_states()
	whole_back = value
	_replan(states)


## Changes the most stitches per block and replans, keeping progress like set_max_skip().
func set_max_block(value: int) -> void:
	if value == max_block:
		return
	var states := cell_states()
	max_block = value
	_replan(states)


## Drops every plan and takes progress over from `states` (cell_states() taken before the change).
func _replan(states: PackedByteArray) -> void:
	_plans.clear()
	restore(states)


## Identifies a step by its first cell and kind: (x, y, kind).
static func step_key(step: StitchStep) -> Vector3i:
	return Vector3i(step.cells[0], step.row, step.kind)


## Whether step `index` of `thread` begins with a new thread, and why.
func thread_start(thread: int, index: int) -> ThreadStart:
	var step: StitchStep = steps(thread)[index]
	if index == 0:
		return ThreadStart.FIRST
	if step.starts_thread:
		return ThreadStart.AUTO
	if _manual_starts.get(thread, []).has(step_key(step)):
		return ThreadStart.MANUAL
	return ThreadStart.NONE


## Starts a new thread at the current step of `thread`, or takes that back. Does nothing where a
## new thread starts anyway (first step, skip limit).
func toggle_manual_start(thread: int) -> void:
	var step := current_step(thread)
	if step == null or thread_start(thread, current_index(thread)) in [ThreadStart.FIRST, ThreadStart.AUTO]:
		return
	var starts: Array = _manual_starts.get_or_add(thread, [])
	var key := step_key(step)
	if starts.has(key):
		starts.erase(key)
	else:
		starts.append(key)


## Manual thread changes per thread code, for saving: {code: [[x, y, kind], …]}.
func manual_starts_by_code() -> Dictionary:
	var result := {}
	for thread: int in _manual_starts:
		var keys := []
		for key: Vector3i in _manual_starts[thread]:
			keys.append([key.x, key.y, key.z])
		if not keys.is_empty():
			result[pattern.thread_codes[thread]] = keys
	return result


## Restores manual thread changes saved by manual_starts_by_code().
func restore_manual_starts(by_code: Dictionary) -> void:
	_manual_starts.clear()
	for code: String in by_code:
		var thread := pattern.thread_codes.find(code)
		if thread < 0:
			continue
		var keys: Array[Vector3i] = []
		for key in by_code[code]:
			if key is Array and key.size() == 3:
				keys.append(Vector3i(int(key[0]), int(key[1]), int(key[2])))
		_manual_starts[thread] = keys


func has_progress() -> bool:
	for thread: int in _done:
		if _done[thread].has(1):
			return true
	return false


## Number of whole crosses of `thread` already stitched.
func finished_crosses(thread: int) -> int:
	var count := 0
	var all := steps(thread)
	var flags := _flags(thread)
	for i in all.size():
		if flags[i] and all[i].kind != StitchStep.Kind.HALF:
			count += all[i].cells.size()
	return count


## Cell value per cell (row by row), from the finished steps of every thread.
func cell_states() -> PackedByteArray:
	var states := PackedByteArray()
	states.resize(pattern.width * pattern.height)
	states.fill(Cell.NONE)
	for thread in pattern.thread_codes.size():
		var all := steps(thread)
		var flags := _flags(thread)
		for i in all.size():
			if not flags[i]:
				continue
			var value := Cell.HALF if all[i].kind == StitchStep.Kind.HALF else Cell.FULL
			for x in all[i].cells:
				var cell := all[i].row * pattern.width + x
				states[cell] = maxi(states[cell], value)
	return states


## Restores progress from saved cell states: a step is done when the fabric already shows it
## (its cells have at least a bottom leg for half stitches, a whole cross otherwise). This works
## whatever order the plan has now, so changed settings or planner rules keep the progress.
##
## A step with stitched and unstitched cells (a longer step in the new plan, e.g. a whole return
## pass after blocks of 5, or two colours merged into one) is split where they meet, so those
## stitches aren't lost.
func restore(saved_states: PackedByteArray) -> void:
	_done.clear()
	for thread in pattern.thread_codes.size():
		var all := steps(thread)
		var flags := PackedByteArray()
		var i := 0
		while i < all.size():
			var step := all[i]
			var needed := Cell.HALF if step.kind == StitchStep.Kind.HALF else Cell.FULL
			var done := saved_states[step.row * pattern.width + step.cells[0]] >= needed
			var same := 1
			while (same < step.cells.size()
					and (saved_states[step.row * pattern.width + step.cells[same]] >= needed) == done):
				same += 1
			if same < step.cells.size():
				var rest := StitchStep.new(step.kind, thread, step.row, step.cells.slice(same), step.direction)
				step.cells = step.cells.slice(0, same)
				all.insert(i + 1, rest)
			flags.append(1 if done else 0)
			i += 1
		_done[thread] = flags


## The done flags of `thread`, created on first use. PackedByteArray is a value type: writing to
## the returned array doesn't change the stored one, use _set_flag() for that.
func _flags(thread: int) -> PackedByteArray:
	if not _done.has(thread):
		var flags := PackedByteArray()
		flags.resize(steps(thread).size())
		flags.fill(0)
		_done[thread] = flags
	return _done[thread]


func _set_flag(thread: int, index: int, value: int) -> void:
	var flags := _flags(thread)
	flags[index] = value
	_done[thread] = flags


func _previous_done(thread: int) -> int:
	var flags := _flags(thread)
	for i in range(current_index(thread) - 1, -1, -1):
		if flags[i]:
			return i
	return -1

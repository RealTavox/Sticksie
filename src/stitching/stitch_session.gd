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
var top_to_bottom := true
var start_left := true
## Most cells the thread may skip on the back (StitchPlanner.UNLIMITED: no automatic changes).
## Change it with set_max_skip(), which replans.
var max_skip := StitchPlanner.UNLIMITED

var _plans := {}  # thread index -> Array[StitchStep]
var _done := PackedInt32Array()  # finished steps per thread
## Manual thread changes per thread index, each as the step's key (see step_key()). Keys instead
## of step numbers, so they stay at the same stitch when the plan changes.
var _manual_starts := {}  # thread index -> Array[Vector3i]


func _init(p_pattern: Pattern) -> void:
	pattern = p_pattern
	_done.resize(pattern.thread_codes.size())
	_done.fill(0)


func steps(thread: int) -> Array[StitchStep]:
	if not _plans.has(thread):
		_plans[thread] = StitchPlanner.plan(pattern, thread, top_to_bottom, start_left, max_skip)
	return _plans[thread]


func done_count(thread: int) -> int:
	return _done[thread]


## The next step of `thread`, or null when the thread is finished.
func current_step(thread: int) -> StitchStep:
	var all := steps(thread)
	return all[_done[thread]] if _done[thread] < all.size() else null


func advance(thread: int) -> void:
	_done[thread] = mini(_done[thread] + 1, steps(thread).size())


func go_back(thread: int) -> void:
	_done[thread] = maxi(_done[thread] - 1, 0)


## The cell of the last stitch made in `thread`, or (-1, -1) before the first.
func last_cell(thread: int) -> Vector2i:
	if _done[thread] == 0:
		return Vector2i(-1, -1)
	var step := steps(thread)[_done[thread] - 1]
	return Vector2i(step.cells[-1], step.row)


## Changes the skip limit and replans every thread. Finished stitches stay finished: progress
## is recounted from the stitched cells.
func set_max_skip(value: int) -> void:
	if value == max_skip:
		return
	var states := cell_states()
	max_skip = value
	_plans.clear()
	restore(_done, states)


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
	if step == null or thread_start(thread, _done[thread]) in [ThreadStart.FIRST, ThreadStart.AUTO]:
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
	for count in _done:
		if count > 0:
			return true
	return false


## Number of whole crosses of `thread` already stitched.
func finished_crosses(thread: int) -> int:
	var count := 0
	var all := steps(thread)
	for i in _done[thread]:
		if all[i].kind != StitchStep.Kind.HALF:
			count += all[i].cells.size()
	return count


## Cell value per cell (row by row), from the finished steps of every thread.
func cell_states() -> PackedByteArray:
	var states := PackedByteArray()
	states.resize(pattern.width * pattern.height)
	states.fill(Cell.NONE)
	for thread in _done.size():
		_apply_steps(thread, _done[thread], states)
	return states


## Restores saved progress: finished steps per thread (indexed like pattern.thread_codes) and
## the saved cell states. A thread whose steps don't reproduce the saved states (the planner rules
## changed since saving) is recounted from the states: its steps are done as far as the fabric
## already shows them.
func restore(done_steps: PackedInt32Array, saved_states: PackedByteArray) -> void:
	for thread in _done.size():
		var count := clampi(done_steps[thread] if thread < done_steps.size() else 0, 0, steps(thread).size())
		if not _reproduces(thread, count, saved_states):
			count = _count_from_states(thread, saved_states)
		_done[thread] = count


func _apply_steps(thread: int, count: int, states: PackedByteArray) -> void:
	var all := steps(thread)
	for i in count:
		var step := all[i]
		var value := Cell.HALF if step.kind == StitchStep.Kind.HALF else Cell.FULL
		for x in step.cells:
			states[step.row * pattern.width + x] = value


## Whether the first `count` steps of `thread` give exactly the saved states of its cells.
func _reproduces(thread: int, count: int, saved_states: PackedByteArray) -> bool:
	var states := PackedByteArray()
	states.resize(saved_states.size())
	states.fill(Cell.NONE)
	_apply_steps(thread, count, states)
	for i in pattern.cells.size():
		if pattern.cells[i] == thread and states[i] != saved_states[i]:
			return false
	return true


func _count_from_states(thread: int, saved_states: PackedByteArray) -> int:
	var count := 0
	for step in steps(thread):
		var needed := Cell.HALF if step.kind == StitchStep.Kind.HALF else Cell.FULL
		for x in step.cells:
			if saved_states[step.row * pattern.width + x] < needed:
				return count
		count += 1
	return count

class_name StitchSession
extends RefCounted
## Progress of stitching one pattern: how many planned steps of each thread are done.

enum Cell {
	NONE,
	## Only the bottom leg is stitched.
	HALF,
	## The whole cross is stitched.
	FULL,
}

var pattern: Pattern
var top_to_bottom := true
var start_left := true

var _plans := {}  # thread index -> Array[StitchStep]
var _done := PackedInt32Array()  # finished steps per thread


func _init(p_pattern: Pattern) -> void:
	pattern = p_pattern
	_done.resize(pattern.thread_codes.size())
	_done.fill(0)


func steps(thread: int) -> Array[StitchStep]:
	if not _plans.has(thread):
		_plans[thread] = StitchPlanner.plan(pattern, thread, top_to_bottom, start_left)
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

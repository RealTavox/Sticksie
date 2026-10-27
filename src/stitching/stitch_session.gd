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
		var all := steps(thread)
		for i in _done[thread]:
			var step := all[i]
			var value := Cell.HALF if step.kind == StitchStep.Kind.HALF else Cell.FULL
			for x in step.cells:
				states[step.row * pattern.width + x] = value
	return states

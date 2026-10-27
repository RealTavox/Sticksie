class_name BackSide
extends RefCounted
## What the thread does on the back of the fabric, worked out from the planned steps. Each leg
## comes up through one hole and goes down through another; on the back the thread runs from
## where it went down to where it comes up next.
##
## Holes are in grid units as seen from the front: (x, y) is the top left corner of cell (x, y).
## Segments are packed in pairs (from, to), ready for draw_multiline().


## Holes of `step` in stitching order: up, down, up, down, … one pair per leg, as the guide says
## (StitchPanel.describe_position()): "/" comes up bottom left and goes down top right, "\" comes
## up bottom right and goes down top left.
static func needle_holes(step: StitchStep) -> PackedVector2Array:
	var holes := PackedVector2Array()
	var y := float(step.row)
	for cell in step.cells:
		var x := float(cell)
		if step.kind != StitchStep.Kind.BACK:
			holes.append_array([Vector2(x, y + 1.0), Vector2(x + 1.0, y)])
		if step.kind != StitchStep.Kind.HALF:
			holes.append_array([Vector2(x + 1.0, y + 1.0), Vector2(x, y)])
	return holes


## The back of `step`: from each down hole to the next up hole, and, unless `from` is NAN (a new
## thread), from `from` (where the previous step went down) to its first up hole.
static func step_segments(step: StitchStep, from := Vector2(NAN, NAN)) -> PackedVector2Array:
	var holes := needle_holes(step)
	var segments := PackedVector2Array()
	if not is_nan(from.x):
		segments.append_array([from, holes[0]])
	for i in range(1, holes.size() - 1, 2):
		segments.append_array([holes[i], holes[i + 1]])
	return segments


## Where the thread is after `step`: its last down hole.
static func last_hole(step: StitchStep) -> Vector2:
	var holes := needle_holes(step)
	return holes[-1]


## The back of the finished steps of `thread`. Two steps are joined when both are done, one
## follows the other in the plan and the later one doesn't start a new thread.
static func thread_segments(session: StitchSession, thread: int) -> PackedVector2Array:
	var segments := PackedVector2Array()
	var steps := session.steps(thread)
	for i in steps.size():
		if not session.is_done(thread, i):
			continue
		var from := Vector2(NAN, NAN)
		if i > 0 and session.is_done(thread, i - 1) and session.thread_start(thread, i) == StitchSession.ThreadStart.NONE:
			from = last_hole(steps[i - 1])
		segments.append_array(step_segments(steps[i], from))
	return segments


## Thread starts and ends among the finished steps of `thread`, as holes:
## {"starts": PackedVector2Array, "ends": PackedVector2Array}. A start is the first hole of a
## finished step that begins a new thread; an end is the last hole of a finished step after which
## a new thread begins or the colour is finished.
static func thread_ends(session: StitchSession, thread: int) -> Dictionary:
	var starts := PackedVector2Array()
	var ends := PackedVector2Array()
	var steps := session.steps(thread)
	for i in steps.size():
		if not session.is_done(thread, i):
			continue
		if session.thread_start(thread, i) != StitchSession.ThreadStart.NONE:
			starts.append(needle_holes(steps[i])[0])
		if i == steps.size() - 1 or session.thread_start(thread, i + 1) != StitchSession.ThreadStart.NONE:
			ends.append(last_hole(steps[i]))
	return {"starts": starts, "ends": ends}

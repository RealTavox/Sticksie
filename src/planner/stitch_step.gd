class_name StitchStep
extends RefCounted
## One guided step: up to StitchPlanner.MAX_BLOCK stitches of one thread in one row, in one
## direction (a whole return pass may be longer, see StitchPlanner).

enum Kind {
	## Danish outward pass: the bottom legs of the crosses.
	HALF,
	## Danish return pass: the top legs, completing the crosses.
	BACK,
	## Whole crosses, each finished before the next: a single scattered stitch (Danish doesn't
	## pay off), or a block of the English method.
	CROSS,
}

var kind: Kind
## Index into Pattern.thread_codes.
var thread: int
var row: int
## Cell x positions in the order they are stitched.
var cells: PackedInt32Array
## +1 to the right, -1 to the left (0 for a single cross).
var direction: int
## Cells the thread skips on the back on its way from the previous step (0 for the first).
var travel_before := 0
## Whether a new thread begins with this step: the first step, or the way here skips more cells
## than the user's limit. Manual thread changes are kept by StitchSession, not here.
var starts_thread := false


func _init(p_kind: Kind, p_thread: int, p_row: int, p_cells: PackedInt32Array, p_direction: int) -> void:
	kind = p_kind
	thread = p_thread
	row = p_row
	cells = p_cells
	direction = p_direction


func _to_string() -> String:
	var text := "%s row %d %s" % [Kind.keys()[kind], row, cells]
	return text + (" skip %d" % travel_before if travel_before > 0 else "")

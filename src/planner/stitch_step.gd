class_name StitchStep
extends RefCounted
## One guided step: up to StitchPlanner.MAX_BLOCK stitches of one thread in one row, in one
## direction.

enum Kind {
	## Danish outward pass: the bottom legs of the crosses.
	HALF,
	## Danish return pass: the top legs, completing the crosses.
	BACK,
	## A single full cross (scattered stitch, Danish doesn't pay off).
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
## Cells the thread skips on the back between the previous block of this pass and this one.
var skip_before := 0


func _init(p_kind: Kind, p_thread: int, p_row: int, p_cells: PackedInt32Array, p_direction: int) -> void:
	kind = p_kind
	thread = p_thread
	row = p_row
	cells = p_cells
	direction = p_direction


func _to_string() -> String:
	var text := "%s row %d %s" % [Kind.keys()[kind], row, cells]
	return text + (" skip %d" % skip_before if skip_before > 0 else "")

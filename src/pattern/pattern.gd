class_name Pattern
extends Resource
## A cross-stitch pattern: a grid of cells, each empty fabric or one thread colour.

const EMPTY := -1

@export var width := 0
@export var height := 0
## Thread index per cell, row by row from the top left; EMPTY for fabric.
@export var cells := PackedInt32Array()
## Codes of the palette threads used, indexed by the values in `cells`.
@export var thread_codes := PackedStringArray()


func get_cell(x: int, y: int) -> int:
	return cells[y * width + x]


## Number of stitches per thread, indexed like `thread_codes`.
func stitch_counts() -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(thread_codes.size())
	counts.fill(0)
	for index in cells:
		if index != EMPTY:
			counts[index] += 1
	return counts


## Number of stitches of `thread`.
func stitch_count(thread: int) -> int:
	return cells.count(thread)


func total_stitches() -> int:
	return cells.size() - cells.count(EMPTY)

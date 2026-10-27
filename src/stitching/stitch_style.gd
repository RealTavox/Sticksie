class_name StitchStyle
extends RefCounted
## How each cross is worked: which leg comes first and through which hole the needle comes up.
## Automatic (the default) keeps "/" first and brings the needle up wherever the thread on the
## back stays shortest, which for the Danish method means short vertical stitches in both
## directions. Fixed uses the user's leg order and always comes up at the bottom or always at the
## top. Set in the advanced settings (Preferences).
##
## Holes are in grid units as seen from the front: (x, y) is the top left corner of cell (x, y).

enum Needle {
	## Up wherever the thread on the back is shortest.
	AUTO,
	## Every leg from its bottom hole up.
	FROM_BOTTOM,
	## Every leg from its top hole down.
	FROM_TOP,
}

var needle := Needle.AUTO
## Whether "/" is the first leg (the half stitch of the Danish method) and "\" the second, or the
## other way round.
var slash_first := true


static func create(p_needle: Needle, p_slash_first: bool) -> StitchStyle:
	var style := StitchStyle.new()
	style.needle = p_needle
	style.slash_first = p_slash_first
	return style


## The style chosen in the settings.
static func from_preferences() -> StitchStyle:
	if not Preferences.needle_fixed():
		return StitchStyle.new()
	return create(Needle.FROM_TOP if Preferences.needle_from_top() else Needle.FROM_BOTTOM,
			Preferences.slash_first())


## "/" or "\", for the first leg (`first`) or the second.
func leg_symbol(first: bool) -> String:
	return "/" if first == slash_first else "\\"


## The two holes of a leg of cell (x, y): "/" joins bottom left and top right, "\" top left and
## bottom right. Bottom hole first.
func leg_holes(x: int, y: int, first: bool) -> PackedVector2Array:
	if first == slash_first:
		return PackedVector2Array([Vector2(x, y + 1), Vector2(x + 1, y)])
	return PackedVector2Array([Vector2(x + 1, y + 1), Vector2(x, y)])


## Holes of `step` in stitching order: up, down, up, down, … one pair per leg. A half stitch
## step has the first leg of each cell, a return pass the second, a cross step both.
func needle_holes(step: StitchStep) -> PackedVector2Array:
	var holes := PackedVector2Array()
	for x in step.cells:
		if step.kind != StitchStep.Kind.BACK:
			holes.append_array(_ordered(leg_holes(x, step.row, true), step.direction, holes))
		if step.kind != StitchStep.Kind.HALF:
			holes.append_array(_ordered(leg_holes(x, step.row, false), step.direction, holes))
	return holes


## The leg's two holes as (up, down). Automatic: the first leg of a step comes up on the side the
## step comes from (the bottom for a single cross); every later leg comes up at the hole nearest
## to where the needle went down, preferring the one straight above or below, never the same.
func _ordered(leg: PackedVector2Array, direction: int, before: PackedVector2Array) -> PackedVector2Array:
	var bottom_first := true
	match needle:
		Needle.FROM_TOP:
			bottom_first = false
		Needle.AUTO:
			if before.is_empty():
				if direction != 0:
					# leg[0] is the bottom hole; come up at the one on the trailing side.
					bottom_first = (leg[0].x < leg[1].x) == (direction > 0)
			else:
				bottom_first = _cost(before[-1], leg[0]) <= _cost(before[-1], leg[1])
	return leg if bottom_first else PackedVector2Array([leg[1], leg[0]])


## Thread length on the back from `down` to `up`, a vertical step a little cheaper than an equally
## long other one; the same hole is ruled out.
static func _cost(down: Vector2, up: Vector2) -> float:
	if down == up:
		return INF
	return down.distance_to(up) - (0.01 if down.x == up.x else 0.0)

class_name StitchStyle
extends RefCounted
## How each cross is worked: which leg comes first and through which hole the needle comes up.
## Automatic (the default) keeps "/" first and brings the needle up wherever the thread on the
## back stays shortest, which for the Danish method means short vertical stitches in both
## directions; where a step begins and ends, the planner picks the holes (StitchStep.first_hole,
## last_hole). Fixed uses the user's leg order and always comes up at the bottom or always at the
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


## Whether `other` works every cross the same way.
func equals(other: StitchStyle) -> bool:
	return other != null and other.needle == needle and other.slash_first == slash_first


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
			holes.append_array(_ordered(leg_holes(x, step.row, true), step.direction, holes,
					step.first_hole))
		if step.kind != StitchStep.Kind.HALF:
			holes.append_array(_ordered(leg_holes(x, step.row, false), step.direction, holes))
	# The last leg goes down through last_hole where the planner chose its other hole.
	if step.last_hole == holes[-2] and last_hole_choices(holes).size() > 1:
		holes[-2] = holes[-1]
		holes[-1] = step.last_hole
	return holes


## The holes the last leg of a step with `holes` (needle_holes() without last_hole) can go down
## through, for the planner to choose from: the one the rule gives first, and when automatic also
## the leg's other hole, as long as the needle then doesn't come up through the hole it just went
## down through. A step of one leg ends where it begins (see first_hole_choices()).
func last_hole_choices(holes: PackedVector2Array) -> PackedVector2Array:
	if needle != Needle.AUTO or holes.size() < 4 or holes[-1] == holes[-3]:
		return holes.slice(-1)
	return PackedVector2Array([holes[-1], holes[-2]])


## The holes the first leg of `step` can come up through, for the planner to choose from: both of
## the leg's holes when automatic (the one on the side the step comes from first), else the one
## the fixed style uses.
func first_hole_choices(step: StitchStep) -> PackedVector2Array:
	var holes := _ordered(_first_leg(step), step.direction, PackedVector2Array())
	return holes if needle == Needle.AUTO else holes.slice(0, 1)


## Where the first leg of `step` comes up when the needle went down at `down` just before: the
## hole nearest to it when automatic, as for every later leg.
func hole_after(step: StitchStep, down: Vector2) -> Vector2:
	return _ordered(_first_leg(step), step.direction, PackedVector2Array([down]))[0]


func _first_leg(step: StitchStep) -> PackedVector2Array:
	return leg_holes(step.cells[0], step.row, step.kind != StitchStep.Kind.BACK)


## The leg's two holes as (up, down). Automatic: the first leg of a step comes up at `first_hole`
## when it is one of its holes, else on the side the step comes from (the bottom for a single
## cross); every later leg comes up at the hole nearest to where the needle went down, preferring
## the one straight above or below, never the same.
func _ordered(leg: PackedVector2Array, direction: int, before: PackedVector2Array,
		first_hole := Vector2(NAN, NAN)) -> PackedVector2Array:
	var bottom_first := true
	match needle:
		Needle.FROM_TOP:
			bottom_first = false
		Needle.AUTO:
			if not before.is_empty():
				bottom_first = _cost(before[-1], leg[0]) <= _cost(before[-1], leg[1])
			elif leg.has(first_hole):
				bottom_first = first_hole == leg[0]
			elif direction != 0:
				# leg[0] is the bottom hole; come up at the one on the trailing side.
				bottom_first = (leg[0].x < leg[1].x) == (direction > 0)
	return leg if bottom_first else PackedVector2Array([leg[1], leg[0]])


## Thread length on the back from `down` to `up`, a vertical step a little cheaper than an equally
## long other one; the same hole is ruled out.
static func _cost(down: Vector2, up: Vector2) -> float:
	if down == up:
		return INF
	return down.distance_to(up) - (0.01 if down.x == up.x else 0.0)

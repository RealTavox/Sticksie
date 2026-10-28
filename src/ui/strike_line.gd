class_name StrikeLine
extends Control
## A line through a finished colour in the colour list, from the left of its parent (the code
## label) to the right end of `to` (the name label). strike() draws it from left to right.

const SECONDS := 0.55
const WIDTH := 2.5
const COLOR := Color(0.97, 0.95, 0.9, 0.9)

var to: Control
## How much of the line is drawn, 0..1.
var amount := 1.0:
	set(value):
		amount = value
		queue_redraw()


func _init(p_to: Control, drawn := true) -> void:
	to = p_to
	amount = 1.0 if drawn else 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	to.resized.connect(queue_redraw)


## Draws the line through, then lets the struck text fade a little.
func strike() -> Tween:
	amount = 0.0
	var tween := create_tween()
	tween.tween_property(self, "amount", 1.0, SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return tween


func _draw() -> void:
	if amount <= 0.0:
		return
	var end_x := to.global_position.x + to.size.x - global_position.x
	var y := size.y / 2.0 + 1.0
	draw_line(Vector2(-2.0, y), Vector2(lerpf(-2.0, end_x, amount), y), COLOR, WIDTH, true)

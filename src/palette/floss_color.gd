class_name FlossColor
extends RefCounted
## One embroidery thread colour of a thread palette (e.g. DMC 310 Black).

var code: String
var name: String
var color: Color
## The colour in CIE Lab, cached for matching.
var lab: Vector3


func _init(p_code: String, p_name: String, p_color: Color) -> void:
	code = p_code
	name = p_name
	color = p_color
	lab = ColorLab.from_color(p_color)

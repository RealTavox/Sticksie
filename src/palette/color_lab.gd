class_name ColorLab
## Conversion of sRGB colours to CIE Lab (D65) and the CIEDE2000 colour difference.


## Returns the colour as Vector3(L, a, b). Alpha is ignored.
static func from_color(color: Color) -> Vector3:
	var r := _srgb_to_linear(color.r)
	var g := _srgb_to_linear(color.g)
	var b := _srgb_to_linear(color.b)
	var x := (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
	var y := 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
	var z := (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883
	var fx := _lab_f(x)
	var fy := _lab_f(y)
	var fz := _lab_f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## CIEDE2000 difference between two Lab colours; about 1.0 is the smallest visible difference.
static func delta_e(lab1: Vector3, lab2: Vector3) -> float:
	var c1 := Vector2(lab1.y, lab1.z).length()
	var c2 := Vector2(lab2.y, lab2.z).length()
	var c_bar7 := pow((c1 + c2) / 2.0, 7.0)
	var g := 0.5 * (1.0 - sqrt(c_bar7 / (c_bar7 + pow(25.0, 7.0))))
	var a1p := (1.0 + g) * lab1.y
	var a2p := (1.0 + g) * lab2.y
	var c1p := Vector2(a1p, lab1.z).length()
	var c2p := Vector2(a2p, lab2.z).length()
	var h1p := _hue_degrees(lab1.z, a1p)
	var h2p := _hue_degrees(lab2.z, a2p)

	var dlp := lab2.x - lab1.x
	var dcp := c2p - c1p
	var dhp := 0.0
	if c1p * c2p != 0.0:
		dhp = h2p - h1p
		if dhp > 180.0:
			dhp -= 360.0
		elif dhp < -180.0:
			dhp += 360.0
	var big_dhp := 2.0 * sqrt(c1p * c2p) * sin(deg_to_rad(dhp / 2.0))

	var l_bar := (lab1.x + lab2.x) / 2.0
	var c_bar_p := (c1p + c2p) / 2.0
	var h_bar_p := h1p + h2p
	if c1p * c2p != 0.0:
		if absf(h1p - h2p) <= 180.0:
			h_bar_p /= 2.0
		elif h1p + h2p < 360.0:
			h_bar_p = (h1p + h2p + 360.0) / 2.0
		else:
			h_bar_p = (h1p + h2p - 360.0) / 2.0

	var t := (1.0 - 0.17 * cos(deg_to_rad(h_bar_p - 30.0))
			+ 0.24 * cos(deg_to_rad(2.0 * h_bar_p))
			+ 0.32 * cos(deg_to_rad(3.0 * h_bar_p + 6.0))
			- 0.20 * cos(deg_to_rad(4.0 * h_bar_p - 63.0)))
	var d_theta := 30.0 * exp(-pow((h_bar_p - 275.0) / 25.0, 2.0))
	var c_bar_p7 := pow(c_bar_p, 7.0)
	var r_c := 2.0 * sqrt(c_bar_p7 / (c_bar_p7 + pow(25.0, 7.0)))
	var l50 := pow(l_bar - 50.0, 2.0)
	var s_l := 1.0 + 0.015 * l50 / sqrt(20.0 + l50)
	var s_c := 1.0 + 0.045 * c_bar_p
	var s_h := 1.0 + 0.015 * c_bar_p * t
	var r_t := -sin(deg_to_rad(2.0 * d_theta)) * r_c

	var dl := dlp / s_l
	var dc := dcp / s_c
	var dh := big_dhp / s_h
	return sqrt(dl * dl + dc * dc + dh * dh + r_t * dc * dh)


static func _srgb_to_linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func _lab_f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


static func _hue_degrees(b: float, a: float) -> float:
	if a == 0.0 and b == 0.0:
		return 0.0
	var h := rad_to_deg(atan2(b, a))
	return h + 360.0 if h < 0.0 else h

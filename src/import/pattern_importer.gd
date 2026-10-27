class_name PatternImporter
## Turns pixel art into a Pattern: one pixel is one cross stitch, each colour the nearest thread.

## Pixels less opaque than this stay empty fabric.
const MIN_ALPHA := 0.5


## Threads whose code is in `fabric_codes` are left out; their cells stay empty fabric.
## Image colours that map to the same thread become one thread.
static func from_image(image: Image, palette: FlossPalette,
		fabric_codes := PackedStringArray()) -> Pattern:
	if image.is_compressed():
		image = image.duplicate()
		image.decompress()
	var pattern := Pattern.new()
	pattern.width = image.get_width()
	pattern.height = image.get_height()
	pattern.cells.resize(pattern.width * pattern.height)
	var floss_by_color := {}  # Color -> FlossColor
	var index_by_code := {}  # String -> int
	for y in pattern.height:
		for x in pattern.width:
			var index := Pattern.EMPTY
			var color := image.get_pixel(x, y)
			if color.a >= MIN_ALPHA:
				color.a = 1.0
				var floss: FlossColor = floss_by_color.get(color)
				if floss == null:
					floss = palette.nearest(color)
					floss_by_color[color] = floss
				if not fabric_codes.has(floss.code):
					index = index_by_code.get(floss.code, Pattern.EMPTY)
					if index == Pattern.EMPTY:
						index = pattern.thread_codes.size()
						pattern.thread_codes.append(floss.code)
						index_by_code[floss.code] = index
			pattern.cells[y * pattern.width + x] = index
	return pattern


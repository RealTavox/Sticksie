class_name PatternImporter
## Turns pixel art into a Pattern: one pixel is one cross stitch, each colour the nearest thread.

## Alpha (0..255) from which a pixel is stitched; less opaque ones stay empty fabric.
const MIN_ALPHA := 128
## An image with more colours (a photo, a JPEG's artefacts) is matched in coarser steps, as finding
## the nearest thread takes long enough to freeze the app for minutes on hundreds of thousands.
const MAX_EXACT_COLORS := 2048
## Coarse matching: the top 4 bits per channel, taken at the middle of their range. That is at most
## 4096 colours to match, and about as fine as the distance between neighbouring threads.
const COARSE_MASK := 0xF0F0F0
const COARSE_MIDDLE := 0x080808
const EXACT_MASK := 0xFFFFFF


## Threads whose code is in `fabric_codes` are left out; their cells stay empty fabric.
## `replacements` maps a matched thread code to the one the user chose instead.
## Image colours that map to the same thread become one thread.
static func from_image(image: Image, palette: FlossPalette,
		fabric_codes := PackedStringArray(), replacements := {}) -> Pattern:
	var job := Job.new(image, palette, fabric_codes, replacements)
	job.run(Job.NO_LIMIT)
	return job.pattern


## An import that can be worked off in parts, so the app keeps drawing during a big one.
class Job:
	extends RefCounted

	const NO_LIMIT := 9223372036854775807

	## Complete once run() returned true.
	var pattern := Pattern.new()

	var _palette: FlossPalette
	var _fabric_codes: PackedStringArray
	var _replacements: Dictionary
	var _data: PackedByteArray
	var _cells := PackedInt32Array()
	var _row := 0
	var _counted_rows := 0
	var _seen := {}
	var _mask := EXACT_MASK
	var _middle := 0
	var _index_by_key := {}  # masked colour -> thread index or EMPTY
	var _index_by_code := {}  # String -> int
	var _last_key := -1
	var _last_index := Pattern.EMPTY

	func _init(image: Image, palette: FlossPalette, fabric_codes: PackedStringArray, replacements: Dictionary) -> void:
		var rgba := image
		if image.is_compressed() or image.get_format() != Image.FORMAT_RGBA8:
			rgba = image.duplicate()
			if rgba.is_compressed():
				rgba.decompress()
			rgba.convert(Image.FORMAT_RGBA8)
		_data = rgba.get_data()
		_palette = palette
		_fabric_codes = fabric_codes
		_replacements = replacements
		pattern.width = image.get_width()
		pattern.height = image.get_height()
		_cells.resize(pattern.width * pattern.height)

	## Works until the time `until_usec` (Time.get_ticks_usec()) has passed. Returns whether it is
	## done.
	func run(until_usec: int) -> bool:
		while _counted_rows < pattern.height:
			if not _count_row(_counted_rows):
				_mask = COARSE_MASK
				_middle = COARSE_MIDDLE
				_counted_rows = pattern.height
				_seen.clear()
				break
			_counted_rows += 1
			if Time.get_ticks_usec() >= until_usec:
				return false
		while _row < pattern.height:
			_match_row(_row)
			_row += 1
			if Time.get_ticks_usec() >= until_usec and _row < pattern.height:
				return false
		pattern.cells = _cells
		return true

	## Notes the row's colours; false once they are more than MAX_EXACT_COLORS.
	func _count_row(row: int) -> bool:
		var offset := row * pattern.width * 4
		var last_key := -1
		for x in pattern.width:
			if _data[offset + 3] >= MIN_ALPHA:
				var key := (_data[offset] << 16) | (_data[offset + 1] << 8) | _data[offset + 2]
				if key != last_key:
					last_key = key
					_seen[key] = true
			offset += 4
		return _seen.size() <= MAX_EXACT_COLORS

	func _match_row(row: int) -> void:
		var cell := row * pattern.width
		var offset := cell * 4
		for x in pattern.width:
			var index := Pattern.EMPTY
			if _data[offset + 3] >= MIN_ALPHA:
				var key := ((_data[offset] << 16) | (_data[offset + 1] << 8) | _data[offset + 2]) & _mask
				if key != _last_key:
					_last_key = key
					_last_index = _thread_index(key)
				index = _last_index
			_cells[cell] = index
			cell += 1
			offset += 4

	func _thread_index(key: int) -> int:
		var index: int = _index_by_key.get(key, -2)
		if index != -2:
			return index
		var rgb := key | _middle
		var floss := _palette.nearest(Color8(rgb >> 16, (rgb >> 8) & 255, rgb & 255))
		if _replacements.has(floss.code):
			floss = _palette.find_code(_replacements[floss.code])
		index = Pattern.EMPTY
		if not _fabric_codes.has(floss.code):
			index = _index_by_code.get(floss.code, Pattern.EMPTY)
			if index == Pattern.EMPTY:
				index = pattern.thread_codes.size()
				pattern.thread_codes.append(floss.code)
				_index_by_code[floss.code] = index
		_index_by_key[key] = index
		return index

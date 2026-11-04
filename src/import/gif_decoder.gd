class_name GifDecoder
## Reads GIF files, which Godot has no loader for. A pattern is one picture, so only the first
## frame counts, placed on the file's canvas.

const _SIGNATURE_SIZE := 6
const _HEADER_SIZE := 13
const _DESCRIPTOR_SIZE := 9
const _EXTENSION := 0x21
const _GRAPHIC_CONTROL := 0xF9
const _IMAGE := 0x2C
const _HAS_COLOR_TABLE := 0x80
const _INTERLACED := 0x40
const _MAX_CODES := 4096
## Interlaced rows arrive in four passes: where each starts and how far apart its rows are.
const _INTERLACE_STARTS: Array[int] = [0, 4, 2, 1]
const _INTERLACE_STEPS: Array[int] = [8, 8, 4, 2]


## Width and height of the canvas, known before anything is decoded; zero if `bytes` is no GIF.
static func canvas_size(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() < _HEADER_SIZE or bytes.slice(0, 4).get_string_from_ascii() != "GIF8":
		return Vector2i.ZERO
	return Vector2i(bytes.decode_u16(_SIGNATURE_SIZE), bytes.decode_u16(_SIGNATURE_SIZE + 2))


## The first frame as an RGBA8 image, transparent where it doesn't cover the canvas; null if the
## file is broken.
static func first_frame(bytes: PackedByteArray) -> Image:
	var canvas := canvas_size(bytes)
	if canvas.x <= 0 or canvas.y <= 0:
		return null
	var pos := _HEADER_SIZE
	var colors := PackedByteArray()
	var flags := bytes[_HEADER_SIZE - 3]
	if flags & _HAS_COLOR_TABLE:
		var table_size := _table_bytes(flags)
		colors = bytes.slice(pos, pos + table_size)
		pos += table_size
	var transparent := -1
	while pos + 1 < bytes.size():
		var block := bytes[pos]
		pos += 1
		if block == _EXTENSION:
			var label := bytes[pos]
			pos += 1
			if label == _GRAPHIC_CONTROL and pos + 4 < bytes.size() and bytes[pos + 1] & 1:
				transparent = bytes[pos + 4]
			pos = _skip_sub_blocks(bytes, pos)
		elif block == _IMAGE:
			return _read_frame(bytes, pos, canvas, colors, transparent)
		else:
			return null
	return null


static func _read_frame(bytes: PackedByteArray, start: int, canvas: Vector2i,
		global_colors: PackedByteArray, transparent: int) -> Image:
	if start + _DESCRIPTOR_SIZE >= bytes.size():
		return null
	var left := bytes.decode_u16(start)
	var top := bytes.decode_u16(start + 2)
	var width := bytes.decode_u16(start + 4)
	var height := bytes.decode_u16(start + 6)
	var flags := bytes[start + 8]
	var pos := start + _DESCRIPTOR_SIZE
	var colors := global_colors
	if flags & _HAS_COLOR_TABLE:
		var table_size := _table_bytes(flags)
		colors = bytes.slice(pos, pos + table_size)
		pos += table_size
	if pos >= bytes.size() or width == 0 or height == 0 or left + width > canvas.x or top + height > canvas.y:
		return null
	var min_code_size := bytes[pos]
	var indices := _decompress(_sub_block_data(bytes, pos + 1), min_code_size, width * height)
	if indices.is_empty():
		return null
	var rows := _row_order(height, flags & _INTERLACED != 0)
	var rgba := PackedByteArray()
	rgba.resize(canvas.x * canvas.y * 4)
	rgba.fill(0)
	var color_count := colors.size() / 3
	var from := 0
	for row in rows:
		var to := ((top + row) * canvas.x + left) * 4
		for x in width:
			var index := indices[from]
			from += 1
			if index != transparent and index < color_count:
				rgba[to] = colors[index * 3]
				rgba[to + 1] = colors[index * 3 + 1]
				rgba[to + 2] = colors[index * 3 + 2]
				rgba[to + 3] = 255
			to += 4
	return Image.create_from_data(canvas.x, canvas.y, false, Image.FORMAT_RGBA8, rgba)


## Size in bytes of the colour table that `flags` announce.
static func _table_bytes(flags: int) -> int:
	return 3 * (2 << (flags & 7))


## Which row each decoded row of the frame is.
static func _row_order(height: int, interlaced: bool) -> PackedInt32Array:
	var rows := PackedInt32Array()
	if not interlaced:
		rows.resize(height)
		for y in height:
			rows[y] = y
		return rows
	for i in _INTERLACE_STARTS.size():
		for y in range(_INTERLACE_STARTS[i], height, _INTERLACE_STEPS[i]):
			rows.append(y)
	return rows


## The position after the sub-blocks at `pos`, each a size byte and that much data, up to an empty
## one.
static func _skip_sub_blocks(bytes: PackedByteArray, pos: int) -> int:
	while pos < bytes.size() and bytes[pos] != 0:
		pos += bytes[pos] + 1
	return pos + 1


## The data of the sub-blocks at `pos`, joined.
static func _sub_block_data(bytes: PackedByteArray, pos: int) -> PackedByteArray:
	var data := PackedByteArray()
	while pos < bytes.size() and bytes[pos] != 0:
		data.append_array(bytes.slice(pos + 1, pos + 1 + bytes[pos]))
		pos += bytes[pos] + 1
	return data


## The colour index of each pixel from GIF's LZW compressed `data`; empty if the stream is invalid.
## A stream that ends early leaves the remaining pixels at index 0.
static func _decompress(data: PackedByteArray, min_code_size: int, pixel_count: int) -> PackedByteArray:
	if min_code_size < 1 or min_code_size > 8:
		return PackedByteArray()
	var out := PackedByteArray()
	out.resize(pixel_count)
	out.fill(0)
	var clear := 1 << min_code_size
	var prefix := PackedInt32Array()
	prefix.resize(_MAX_CODES)
	var suffix := PackedByteArray()
	suffix.resize(_MAX_CODES)
	var lengths := PackedInt32Array()
	lengths.resize(_MAX_CODES)
	for i in clear:
		suffix[i] = i
		lengths[i] = 1
	var next_code := clear + 2
	var code_size := min_code_size + 1
	var previous := -1
	var first := 0
	var bits := 0
	var bit_count := 0
	var written := 0
	for byte in data:
		bits |= byte << bit_count
		bit_count += 8
		while bit_count >= code_size:
			var code := bits & ((1 << code_size) - 1)
			bits >>= code_size
			bit_count -= code_size
			if code == clear:
				next_code = clear + 2
				code_size = min_code_size + 1
				previous = -1
				continue
			if code == clear + 1:
				return out
			if previous < 0:
				if code >= clear or written >= pixel_count:
					return out
				out[written] = code
				written += 1
				first = code
				previous = code
				continue
			if code > next_code:
				return PackedByteArray()
			# A code not in the table yet is the previous string plus its own first byte.
			var known := code < next_code
			var length: int = lengths[code] if known else lengths[previous] + 1
			if written + length > pixel_count:
				return out
			var at := written + length - 1
			var current := code
			if not known:
				out[at] = first
				at -= 1
				current = previous
			while current >= clear:
				out[at] = suffix[current]
				at -= 1
				current = prefix[current]
			out[at] = current
			first = current
			written += length
			if next_code < _MAX_CODES:
				prefix[next_code] = previous
				suffix[next_code] = first
				lengths[next_code] = lengths[previous] + 1
				next_code += 1
				if next_code == 1 << code_size and code_size < 12:
					code_size += 1
			previous = code
	return out

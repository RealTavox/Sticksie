class_name ImageReader
## Reads an image file of any supported format from its bytes. The format comes from the file's
## first bytes, not its name, as on the web the bytes are all there is and names can lie. Only TGA,
## which has no signature, goes by the name.

## For messages to the user.
const FORMAT_NAMES := "PNG, JPEG, WebP, GIF, BMP, TGA oder SVG"
## How far into a file its <svg> tag is looked for, past an XML declaration and comments.
const SVG_SEARCH_BYTES := 4096


## The image in `bytes`, or null if it isn't one that can be read.
static func read(file_name: String, bytes: PackedByteArray) -> Image:
	if _starts_with(bytes, 0, "GIF8"):
		return GifDecoder.first_frame(bytes)
	var image := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	if bytes.slice(0, 4) == PackedByteArray([0x89, 0x50, 0x4E, 0x47]):
		error = image.load_png_from_buffer(bytes)
	elif bytes.slice(0, 3) == PackedByteArray([0xFF, 0xD8, 0xFF]):
		error = image.load_jpg_from_buffer(bytes)
	elif _starts_with(bytes, 0, "RIFF") and _starts_with(bytes, 8, "WEBP"):
		error = image.load_webp_from_buffer(bytes)
	elif _starts_with(bytes, 0, "BM"):
		error = image.load_bmp_from_buffer(bytes)
	elif bytes.slice(0, SVG_SEARCH_BYTES).get_string_from_utf8().contains("<svg"):
		error = image.load_svg_from_buffer(bytes)
	elif file_name.get_extension().to_lower() == "tga":
		error = image.load_tga_from_buffer(bytes)
	return image if error == OK else null


static func _starts_with(bytes: PackedByteArray, offset: int, text: String) -> bool:
	return bytes.slice(offset, offset + text.length()).get_string_from_ascii() == text

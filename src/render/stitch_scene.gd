class_name StitchScene
extends Node3D
## The fabric and its threads in 3D, rendered by PatternView into a SubViewport behind its 2D
## marks. One world unit is one cell: x to the right, y up, the pattern's top left corner at the
## origin, so grid point (x, y) is at (x, -y). The front faces +z, where the orthographic camera
## looks from; the back faces -z. Turning the fabric over is a rotation about a vertical axis,
## which mirrors it left to right just like the 2D back view.
##
## Threads are flat quads (MultiMesh, one instance per leg or back stitch) shaded by
## thread.gdshader; their soft shadows reuse the same MultiMeshes with thread_shadow.gdshader.
## Blending follows instance order, so every first leg comes before every second leg.

## The reward orbit of the light (orbit()), seen from above in units of the light's own distance
## from overhead: the oval's centre lies this far towards the light, and it is this wide across.
const ORBIT_CENTER := 0.55
const ORBIT_WIDTH := 0.6
const THREAD_WIDTH := StitchTextures.THREAD_WIDTH
## Height of the legs and back stitches above the fabric, in cells.
const FIRST_LIFT := 0.03
const SECOND_LIFT := 0.06
const BACK_LIFT := 0.035
## How high the thread is for its shadow: decides how far the shadow falls from it.
const SHADOW_HEIGHT := 0.07
const SHADOW_STRENGTH := 0.5
const GHOST_OPACITY := 0.4
## Bare fabric round the pattern, in cells.
const FABRIC_MARGIN := 1.0
const FABRIC_COLOR := Color8(245, 241, 230)
## Perspective at the middle of the flip, as a part of the fabric's size.
const FLIP_PERSPECTIVE := 0.35
const AMBIENT_ENERGY := 0.45
const LIGHT_ENERGY := 0.8
## Floats per MultiMesh instance: transform 12, colour 4, custom 4.
const STRIDE := 20

var _camera := Camera3D.new()
var _light := DirectionalLight3D.new()
## The fabric with everything on it; turned for the flip.
var _turn := Node3D.new()
var _fabric := MeshInstance3D.new()
var _fabric_material := ShaderMaterial.new()
var _thread_material := ShaderMaterial.new()
var _ghost_material := ShaderMaterial.new()
var _front_shadow_material := ShaderMaterial.new()
var _back_shadow_material := ShaderMaterial.new()
var _front := _make_multimesh()
var _back := _make_multimesh()
var _ghost := _make_multimesh()
var _back_ghost := _make_multimesh()
var _pattern: Pattern
## Floss colours per thread index.
var _colors: Array[Color] = []
var _slash_first := true
## Grid index (y * width + x) of each non-empty cell; cell k has legs k and k + count.
var _cells := PackedInt32Array()
## StitchSession.Cell shown per entry of _cells; 255 before anything is shown.
var _shown := PackedByteArray()
var _light_direction := Vector3(0.0, 0.0, 1.0)
var _side_normal := Vector3(0.0, 0.0, 1.0)


func _init() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.98, 0.95)
	environment.ambient_light_energy = AMBIENT_ENERGY
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.05
	add_child(_camera)
	_light.light_color = Color(1.0, 0.98, 0.94)
	_light.light_energy = LIGHT_ENERGY
	add_child(_light)
	add_child(_turn)

	var fabric_textures := StitchTextures.fabric()
	_fabric_material.shader = preload("res://src/render/fabric.gdshader")
	_fabric_material.set_shader_parameter("normal_map", fabric_textures[0])
	_fabric_material.set_shader_parameter("shade_map", fabric_textures[1])
	_fabric_material.set_shader_parameter("fabric_color", FABRIC_COLOR)
	_fabric.mesh = QuadMesh.new()
	_fabric.material_override = _fabric_material
	_turn.add_child(_fabric)

	var thread_textures := StitchTextures.thread()
	for material in [_thread_material, _ghost_material]:
		material.shader = preload("res://src/render/thread.gdshader")
		material.set_shader_parameter("normal_map", thread_textures[0])
		material.set_shader_parameter("shade_map", thread_textures[1])
		material.set_shader_parameter("twist_period", StitchTextures.TWIST_PERIOD)
	_ghost_material.set_shader_parameter("opacity", GHOST_OPACITY)
	# Transparent passes: shadows first, then the threads, the ghosts last.
	_ghost_material.render_priority = 1
	for material in [_front_shadow_material, _back_shadow_material]:
		material.shader = preload("res://src/render/thread_shadow.gdshader")
		material.render_priority = -1
	_add_threads(_front, _front_shadow_material)
	_add_threads(_back, _back_shadow_material)
	_add_threads(_back, _thread_material)
	_add_threads(_front, _thread_material)
	_add_threads(_ghost, _ghost_material)
	_add_threads(_back_ghost, _ghost_material)
	set_light(315.0, 40.0)


## Shows `pattern` with nothing stitched; `colors` are the floss colours per thread (sRGB).
func set_pattern(pattern: Pattern, colors: Array[Color], slash_first: bool) -> void:
	_pattern = pattern
	_slash_first = slash_first
	# Instance colours are sRGB: the Compatibility renderer converts them itself.
	_colors = colors.duplicate()
	_cells.clear()
	for index in pattern.width * pattern.height:
		if pattern.get_cell(index % pattern.width, index / pattern.width) != Pattern.EMPTY:
			_cells.append(index)
	_shown = PackedByteArray()
	_shown.resize(_cells.size())
	_shown.fill(255)
	var size := Vector2(pattern.width, pattern.height)
	(_fabric.mesh as QuadMesh).size = size + Vector2.ONE * FABRIC_MARGIN * 2.0
	_fabric.position = Vector3(size.x / 2.0, -size.y / 2.0, 0.0)
	_fabric_material.set_shader_parameter("pattern_size", size)
	var distance := maxf(size.x, size.y) + 10.0
	_camera.far = distance * 2.0
	_camera.position.z = distance
	for material in _materials():
		material.set_shader_parameter("plane_distance", distance)
	_front.instance_count = 0
	_back.instance_count = 0
	_ghost.instance_count = 0
	_back_ghost.instance_count = 0


## Shows the legs of `states` (a StitchSession.Cell per cell); empty shows every cell as a
## finished cross, as in the overview.
func set_states(states: PackedByteArray) -> void:
	if _pattern == null:
		return
	var count := _cells.size()
	if _front.instance_count != count * 2:
		_build_front(states)
		return
	for k in count:
		var state := StitchSession.Cell.FULL if states.is_empty() else states[_cells[k]]
		if state == _shown[k]:
			continue
		_shown[k] = state
		var x := _cells[k] % _pattern.width
		var y := _cells[k] / _pattern.width
		_front.set_instance_transform(k, _leg_transform(x, y, true) if state != StitchSession.Cell.NONE else _hidden())
		_front.set_instance_custom_data(k, _leg_custom(x, y, state == StitchSession.Cell.FULL))
		_front.set_instance_transform(k + count, _leg_transform(x, y, false) if state == StitchSession.Cell.FULL else _hidden())


## The legs of `step` still to stitch, see-through; null shows none.
func set_ghost(step: StitchStep) -> void:
	var buffer := PackedFloat32Array()
	if step != null and _pattern != null:
		var color := _colors[step.thread]
		for x in step.cells:
			if step.kind != StitchStep.Kind.BACK:
				_append(buffer, _leg_ends(x, step.row, true), FIRST_LIFT, 1.0, color, _seed(x, step.row), false)
			if step.kind != StitchStep.Kind.HALF:
				_append(buffer, _leg_ends(x, step.row, false), SECOND_LIFT, 1.0, color, _seed(x, step.row) + 0.5, false)
	_set_buffer(_ghost, buffer)


## The back: `lines` holds the finished stitches per thread index as pairs of holes (BackSide),
## `ghost` the current step's still to stitch, in thread `ghost_thread`.
func set_back(lines: Array[PackedVector2Array], ghost: PackedVector2Array, ghost_thread: int) -> void:
	var buffer := PackedFloat32Array()
	for thread in mini(lines.size(), _colors.size()):
		var segments := lines[thread]
		for i in range(0, segments.size() - 1, 2):
			_append(buffer, [segments[i], segments[i + 1]], BACK_LIFT + 0.0005 * (i % 8), -1.0,
					_colors[thread], _seed(segments[i].x, segments[i].y + 0.3 * thread), false)
	_set_buffer(_back, buffer)
	var ghost_buffer := PackedFloat32Array()
	if ghost_thread >= 0 and ghost_thread < _colors.size():
		for i in range(0, ghost.size() - 1, 2):
			_append(ghost_buffer, [ghost[i], ghost[i + 1]], BACK_LIFT + 0.004, -1.0,
					_colors[ghost_thread], _seed(ghost[i].x, ghost[i].y), false)
	_set_buffer(_back_ghost, ghost_buffer)


## Points the camera at `center` (world x, grid y) showing `height` cells from top to bottom.
func set_view(center: Vector2, height: float) -> void:
	_camera.position.x = center.x
	_camera.position.y = -center.y
	_camera.size = maxf(height, 0.01)


## Lies the fabric front up (or back up with `back`), then turns it by `angle` about the
## vertical line at world x `pivot`.
func set_turn(back: bool, angle: float, pivot: float, view_width: float) -> void:
	var rest := Transform3D.IDENTITY
	if back and _pattern != null:
		rest = _turn_about(PI, _pattern.width / 2.0)
	_turn.transform = _turn_about(angle, pivot) * rest
	_side_normal = _turn.transform.basis.z.normalized()
	var extent := maxf(view_width, 1.0)
	if _pattern != null:
		extent = maxf(extent, maxf(_pattern.width, _pattern.height))
	for material in _materials():
		material.set_shader_parameter("flip_perspective", FLIP_PERSPECTIVE * absf(sin(angle)) / extent)
	_update_shadows()


## Light from `azimuth` degrees (clockwise from the top of the screen) at `elevation` degrees
## above the fabric.
## The light `turn` degrees along its reward orbit from (`azimuth`, `elevation`), as
## Vector2(azimuth, elevation). Seen from above, the light's direction runs round an oval that
## starts at the given light and is shifted towards it: on the far side the light stands almost
## overhead instead of coming from the opposite corner, and on the way round it rises and sinks
## again. A turn of 0 or 360 is the given light.
static func orbit(azimuth: float, elevation: float, turn: float) -> Vector2:
	var a := deg_to_rad(azimuth)
	var flat := cos(deg_to_rad(elevation))
	var toward := Vector2(sin(a), -cos(a))
	var t := deg_to_rad(turn)
	var p := toward * flat * (ORBIT_CENTER + (1.0 - ORBIT_CENTER) * cos(t)) \
			+ toward.orthogonal() * flat * ORBIT_WIDTH * sin(t)
	var new_azimuth := fposmod(rad_to_deg(atan2(p.x, -p.y)), 360.0) if p.length() > 0.0001 else azimuth
	return Vector2(new_azimuth, rad_to_deg(acos(clampf(p.length(), 0.0, 1.0))))


func set_light(azimuth: float, elevation: float) -> void:
	var a := deg_to_rad(azimuth)
	var e := deg_to_rad(clampf(elevation, 1.0, 90.0))
	_light_direction = Vector3(sin(a) * cos(e), cos(a) * cos(e), sin(e)).normalized()
	var up := Vector3.UP if absf(_light_direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	_light.transform = Transform3D(Basis.looking_at(-_light_direction, up), Vector3.ZERO)
	_update_shadows()


## Moves each side's shadows away from the light, and fades them on the side facing away.
func _update_shadows() -> void:
	for side in [1.0, -1.0]:
		var normal: Vector3 = _side_normal * side
		var facing := _light_direction.dot(normal)
		var material := _front_shadow_material if side > 0.0 else _back_shadow_material
		var tangent := _light_direction - normal * facing
		material.set_shader_parameter("offset", -tangent / maxf(facing, 0.2) * SHADOW_HEIGHT)
		material.set_shader_parameter("strength", SHADOW_STRENGTH * clampf(facing * 4.0, 0.0, 1.0))


func _materials() -> Array[ShaderMaterial]:
	return [_fabric_material, _thread_material, _ghost_material, _front_shadow_material, _back_shadow_material]


## Every leg of the pattern in one go: all first legs, then all second legs.
func _build_front(states: PackedByteArray) -> void:
	var count := _cells.size()
	var buffer := PackedFloat32Array()
	buffer.resize(count * 2 * STRIDE)
	for k in count:
		var x := _cells[k] % _pattern.width
		var y := _cells[k] / _pattern.width
		var state := StitchSession.Cell.FULL if states.is_empty() else states[_cells[k]]
		_shown[k] = state
		var color := _colors[_pattern.get_cell(x, y)]
		var seed := _seed(x, y)
		_write(buffer, k, _leg_ends(x, y, true), FIRST_LIFT, 1.0, color, seed,
				state == StitchSession.Cell.FULL, state != StitchSession.Cell.NONE)
		_write(buffer, k + count, _leg_ends(x, y, false), SECOND_LIFT, 1.0, color, seed + 0.5,
				false, state == StitchSession.Cell.FULL)
	_set_buffer(_front, buffer)


## The holes a leg of cell (x, y) goes between: "/" from the bottom left to the top right, "\"
## from the top left to the bottom right.
func _leg_ends(x: int, y: int, first: bool) -> Array[Vector2]:
	if first == _slash_first:
		return [Vector2(x, y + 1), Vector2(x + 1, y)]
	return [Vector2(x, y), Vector2(x + 1, y + 1)]


func _leg_transform(x: int, y: int, first: bool) -> Transform3D:
	var buffer := PackedFloat32Array()
	buffer.resize(STRIDE)
	_write(buffer, 0, _leg_ends(x, y, first), FIRST_LIFT if first else SECOND_LIFT, 1.0, Color.WHITE, 0.0, false, true)
	return Transform3D(Vector3(buffer[0], buffer[4], buffer[8]), Vector3(buffer[1], buffer[5], buffer[9]),
			Vector3(buffer[2], buffer[6], buffer[10]), Vector3(buffer[3], buffer[7], buffer[11]))


func _leg_custom(x: int, y: int, covered: bool) -> Color:
	return Color(_seed(x, y), 1.0 if covered else 0.0, sqrt(2.0), THREAD_WIDTH)


func _hidden() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)


## Writes instance `i` of `buffer`: a thread between the holes `ends` (grid units), `lift` above
## the side whose normal is z * `side`. A hidden instance gets a zero transform.
func _write(buffer: PackedFloat32Array, i: int, ends: Array, lift: float, side: float, color: Color,
		seed: float, covered: bool, visible := true) -> void:
	var a := Vector2(ends[0].x, -ends[0].y)
	var b := Vector2(ends[1].x, -ends[1].y)
	var length := a.distance_to(b)
	var along := (b - a) / maxf(length, 1e-6)
	var center := (a + b) / 2.0
	var scale := (length + THREAD_WIDTH) if visible else 0.0
	var width := THREAD_WIDTH if visible else 0.0
	# Columns: along the thread, across it (normal × along), the normal.
	var o := i * STRIDE
	buffer[o] = along.x * scale
	buffer[o + 1] = -side * along.y * width
	buffer[o + 2] = 0.0
	buffer[o + 3] = center.x
	buffer[o + 4] = along.y * scale
	buffer[o + 5] = side * along.x * width
	buffer[o + 6] = 0.0
	buffer[o + 7] = center.y
	buffer[o + 8] = 0.0
	buffer[o + 9] = 0.0
	buffer[o + 10] = side if visible else 0.0
	buffer[o + 11] = side * lift
	buffer[o + 12] = color.r
	buffer[o + 13] = color.g
	buffer[o + 14] = color.b
	buffer[o + 15] = color.a
	buffer[o + 16] = seed
	buffer[o + 17] = 1.0 if covered else 0.0
	buffer[o + 18] = length
	buffer[o + 19] = THREAD_WIDTH


func _append(buffer: PackedFloat32Array, ends: Array, lift: float, side: float, color: Color,
		seed: float, covered: bool) -> void:
	if (ends[0] as Vector2).distance_to(ends[1]) < 0.01:
		return
	var i := buffer.size() / STRIDE
	buffer.resize(buffer.size() + STRIDE)
	_write(buffer, i, ends, lift, side, color, seed, covered)


func _set_buffer(multimesh: MultiMesh, buffer: PackedFloat32Array) -> void:
	multimesh.instance_count = buffer.size() / STRIDE
	if multimesh.instance_count > 0:
		multimesh.buffer = buffer


## A stable pseudo-random 0..1 per position, so neighbouring stitches twist differently.
func _seed(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


func _turn_about(angle: float, pivot: float) -> Transform3D:
	var shift := Transform3D(Basis.IDENTITY, Vector3(pivot, 0.0, 0.0))
	return shift * Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO) * shift.affine_inverse()


func _add_threads(multimesh: MultiMesh, material: ShaderMaterial) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	# The fabric can be turned and zoomed anywhere; don't let a stale AABB cull the threads.
	instance.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e3), Vector3(2e5, 2e5, 2e3))
	_turn.add_child(instance)


static func _make_multimesh() -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = QuadMesh.new()
	return multimesh

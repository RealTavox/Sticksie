shader_type spatial;
// Aida fabric, both faces: the woven relief from StitchTextures, and the chart's grid as a line
// every 10 cells and round the pattern.
render_mode cull_disabled, diffuse_lambert, specular_disabled;

#include "res://src/render/flip.gdshaderinc"

uniform vec3 fabric_color : source_color = vec3(0.96, 0.945, 0.9);
uniform vec2 pattern_size = vec2(10.0);
uniform vec4 grid_color : source_color = vec4(0.32, 0.4, 0.55, 0.45);
uniform sampler2D normal_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shade_map : filter_linear_mipmap_anisotropic, repeat_enable;

// Grid units: x to the right, y down, (0, 0) the pattern's top left corner.
varying vec2 v_grid;
varying vec3 v_right;
varying vec3 v_down;
varying vec3 v_out;

void vertex() {
	v_grid = vec2(VERTEX.x, -VERTEX.y) + pattern_size * 0.5;
	v_right = normalize((MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	v_down = normalize((MODELVIEW_MATRIX * vec4(0.0, -1.0, 0.0, 0.0)).xyz);
	v_out = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	POSITION = flip_position(PROJECTION_MATRIX, (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	// The tile holds 2 × 2 cells.
	vec2 uv = v_grid * 0.5;
	vec3 n = texture(normal_map, uv).rgb * 2.0 - 1.0;
	float shade = texture(shade_map, uv).r;
	float side = FRONT_FACING ? 1.0 : -1.0;
	NORMAL = normalize(v_right * n.x + v_down * n.y + v_out * n.z * side);

	vec2 to_line = abs(v_grid - round(v_grid / 10.0) * 10.0);
	vec2 to_border = min(abs(v_grid), abs(v_grid - pattern_size));
	vec2 distance_to = min(to_line, to_border);
	vec2 pixel = fwidth(v_grid);
	vec2 half_width = max(pixel * 0.7, vec2(0.03));
	vec2 line = 1.0 - smoothstep(half_width, half_width + pixel, distance_to);
	vec2 inside = step(vec2(-0.03), v_grid) * step(v_grid, pattern_size + 0.03);
	float grid = max(line.x * inside.y, line.y * inside.x) * grid_color.a;

	ALBEDO = mix(fabric_color * shade, grid_color.rgb * mix(0.6, 1.0, shade), grid);
	ROUGHNESS = 1.0;
}

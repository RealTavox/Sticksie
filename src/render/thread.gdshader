shader_type spatial;
// One length of stranded cotton between two holes (a leg on the front, a stitch on the back),
// drawn on a flat quad: the shape is a capsule that narrows where the thread dives into its
// holes, the strands and their twist come from StitchTextures, and the sheen runs along the
// fibres. Instance data: COLOR the floss colour (sRGB), CUSTOM (seed, covered, length, width).
render_mode blend_mix, depth_draw_never, cull_back;

#include "res://src/render/flip.gdshaderinc"

uniform float opacity = 1.0;
uniform float twist_period = 0.42;
uniform float sheen = 0.35;
uniform sampler2D normal_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shade_map : filter_linear_mipmap_anisotropic, repeat_enable;

// Position on the thread in cells: x along it from its middle, y across.
varying vec2 v_pq;
varying flat vec4 v_custom;
varying vec3 v_along;
varying vec3 v_across;
varying vec3 v_out;
varying vec3 v_fibre;
varying float v_gloss;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_pq = VERTEX.xy * vec2(v_custom.b + v_custom.a, v_custom.a);
	v_along = normalize((MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	v_across = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	v_out = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	POSITION = flip_position(PROJECTION_MATRIX, (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float half_length = v_custom.b * 0.5;
	float width = v_custom.a;
	float along = abs(v_pq.x);
	// 0 along the thread, 1 in the hole.
	float end = smoothstep(half_length - width * 0.9, half_length, along);
	float radius = width * 0.5 * mix(1.0, 0.62, end);
	float distance_to = length(vec2(max(along - half_length, 0.0), v_pq.y));
	float alpha = clamp((radius - distance_to) / max(fwidth(distance_to), 1e-4) + 0.5, 0.0, 1.0);
	if (alpha <= 0.0) {
		discard;
	}
	float across = clamp(v_pq.y / radius, -1.0, 1.0);
	vec2 uv = vec2(v_pq.x / twist_period + v_custom.r * 7.0, clamp(across * 0.5 + 0.5, 0.02, 0.98));
	vec3 n = texture(normal_map, uv).rgb * 2.0 - 1.0;
	// The thread as a whole is rounded, and it bends down into the holes.
	n.y += across * 0.6;
	n.x += sign(v_pq.x) * end * 0.9;
	n = normalize(n);
	NORMAL = normalize(v_along * n.x + v_across * n.y + v_out * n.z);

	float shade = texture(shade_map, uv).r;
	float occlusion = mix(1.0, 0.55, end) * mix(1.0, 0.8, pow(abs(across), 3.0));
	// A first leg is pressed down where the second one crosses it.
	occlusion *= mix(1.0, mix(0.68, 1.0, smoothstep(width * 0.25, width * 0.85, along)), v_custom.g);
	ALBEDO = COLOR.rgb * shade * occlusion;
	ALPHA = alpha * opacity;
	ROUGHNESS = 0.7;
	v_fibre = normalize(v_along * cos(0.5) + v_across * sin(0.5));
	v_gloss = shade * occlusion;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += clamp((n_dot_l + 0.3) / 1.3, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR;
	// Mercerised cotton: a soft sheen on the plies' ridges (from the normal map), stretched
	// along the fibres (Kajiya-Kay, kept narrow so flat-lying fibres don't all light up).
	vec3 halfway = normalize(LIGHT + VIEW);
	float ridge = pow(clamp(dot(NORMAL, halfway), 0.0, 1.0), 28.0);
	float t_dot_h = dot(v_fibre, halfway);
	float fibre = pow(sqrt(max(0.0, 1.0 - t_dot_h * t_dot_h)), 300.0);
	float highlight = ridge * (0.5 + 0.5 * fibre);
	SPECULAR_LIGHT += highlight * sheen * v_gloss * clamp(n_dot_l * 2.0 + 0.3, 0.0, 1.0)
			* ATTENUATION * LIGHT_COLOR;
}

shader_type spatial;
// The soft shadow of a thread on the fabric: the thread's capsule, widened and blurred, moved
// away from the light by `offset` (world space, set by StitchScene) and multiplied onto what is
// below. Uses the threads' own MultiMesh.
render_mode blend_mul, depth_draw_never, cull_back, unshaded;

#include "res://src/render/flip.gdshaderinc"

uniform vec3 offset = vec3(0.0);
uniform float blur = 0.07;
uniform float strength = 0.5;
uniform vec3 tint : source_color = vec3(0.3, 0.26, 0.22);

varying vec2 v_pq;
varying flat vec2 v_size;

void vertex() {
	v_size = vec2(INSTANCE_CUSTOM.b, INSTANCE_CUSTOM.a);
	vec2 quad = vec2(v_size.x + v_size.y, v_size.y);
	vec2 grown = quad + vec2(4.0 * blur);
	v_pq = VERTEX.xy * grown;
	VERTEX.xy *= grown / quad;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + offset;
	POSITION = flip_position(PROJECTION_MATRIX, (VIEW_MATRIX * vec4(world, 1.0)).xyz);
}

void fragment() {
	float distance_to = length(vec2(max(abs(v_pq.x) - v_size.x * 0.5, 0.0), v_pq.y));
	float radius = v_size.y * 0.5;
	float shadow = 1.0 - smoothstep(radius - blur, radius + blur * 1.5, distance_to);
	ALBEDO = mix(vec3(1.0), tint, shadow * strength);
}

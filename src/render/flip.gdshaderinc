// Shared by the 3D view's shaders: a touch of perspective while the fabric turns over, so the
// flip reads as a turn and not as a squeeze. The camera is orthographic; `flip_perspective` is 0
// when the fabric lies flat, so the picture then matches the 2D overlays exactly.

uniform float flip_perspective = 0.0;
// Distance from the camera to the fabric's plane at rest.
uniform float plane_distance = 100.0;

// Through w, so the GPU interpolates perspective-correctly; depth stays as it was.
vec4 flip_position(mat4 projection, vec3 view_position) {
	vec4 clip = projection * vec4(view_position, 1.0);
	float w = max(0.25, 1.0 - (view_position.z + plane_distance) * flip_perspective);
	return vec4(clip.xy, clip.z * w, w);
}

shader_type canvas_item;
// Background of the finale (Finale): the screen darkened towards the edges, with the finished
// pattern (`spot`, a rect in UV) left brighter, and golden rays turning around `center`.

uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec2 center = vec2(0.5, 0.4);
uniform vec4 spot = vec4(0.1, 0.2, 0.8, 0.5);
uniform float phase = 0.0;
// 0..1: how far the darkness and the rays have come in.
uniform float amount = 0.0;
uniform float rays = 0.0;
uniform vec4 ray_color : source_color = vec4(1.0, 0.82, 0.3, 1.0);

void fragment() {
	vec2 p = UV * rect_size;
	vec2 c = center * rect_size;
	vec2 d = p - c;
	float radius = length(d) / length(rect_size);
	// Darker towards the edges; the pattern stays lighter.
	vec2 inside = smoothstep(spot.xy - 0.03, spot.xy, UV) * (1.0 - smoothstep(spot.xy + spot.zw, spot.xy + spot.zw + 0.03, UV));
	float lit = inside.x * inside.y;
	float dark = mix(0.55 + radius * 0.6, 0.12, lit) * amount;
	// Two sets of rays turning against each other.
	float angle = atan(d.y, d.x);
	float a = pow(max(sin(angle * 12.0 + phase * 0.7), 0.0), 3.0);
	float b = pow(max(sin(angle * 7.0 - phase * 0.45), 0.0), 4.0) * 0.6;
	float fade = exp(-radius * 3.2) * (1.0 - lit * 0.9);
	float ray = (a + b) * fade * rays;
	vec3 rgb = ray_color.rgb * ray;
	float alpha = clamp(dark + ray * 0.8, 0.0, 1.0);
	COLOR = vec4(alpha > 0.0 ? rgb / alpha : rgb, alpha);
}

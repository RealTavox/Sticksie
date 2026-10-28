shader_type canvas_item;
// The progress bar (ProgressStrip): a grey capsule track with the filled part as a capsule of
// `fill_color` from the left end. `ghost` is where the fill is heading: the part between `fill`
// and `ghost` shows white with `flash`. `shimmer` sends bands of light along the fill, `glow`
// lights up the space around the bar. The rect is bigger than the bar by `margin` on every side
// to leave room for the glow.

uniform vec2 rect_size = vec2(200.0, 24.0);
uniform float margin = 0.0;
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float ghost : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform float glow : hint_range(0.0, 2.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.17, 0.47, 0.88, 1.0);
uniform vec4 track_color : source_color = vec4(0.42, 0.42, 0.42, 0.8);

// Distance to a capsule from x = a to x = b (centres of its round ends) of radius r, at height 0.
float capsule(vec2 p, float a, float b, float r) {
	float x = clamp(p.x, a, max(a, b));
	return length(p - vec2(x, 0.0)) - r;
}

void fragment() {
	vec2 p = UV * rect_size - vec2(margin);
	vec2 bar = rect_size - vec2(margin * 2.0);
	float r = bar.y * 0.5;
	vec2 q = vec2(p.x, p.y - r);
	float aa = max(fwidth(p.x), 0.5);
	float left = r;
	float right = bar.x - r;
	float track_d = capsule(q, left, right, r);
	float track = 1.0 - smoothstep(-aa, aa, track_d);
	// A capsule as long as the fill; it grows from a dot at the left end.
	float fill_end = mix(left, right, fill);
	float fill_d = capsule(q, left, fill_end, r);
	float filled = fill > 0.0 ? 1.0 - smoothstep(-aa, aa, fill_d) : 0.0;
	float ghost_d = capsule(q, left, mix(left, right, ghost), r);
	float ghosted = ghost > fill ? (1.0 - smoothstep(-aa, aa, ghost_d)) * flash : 0.0;

	// Rounded like a tube: lighter on top, darker at the bottom.
	float height = clamp(q.y / r, -1.0, 1.0);
	vec3 tube = fill_color.rgb * (1.05 - 0.3 * height) + vec3(0.18) * pow(max(-height, 0.0), 3.0);
	// Bands of light running to the right, slanted a little.
	float band = sin((p.x - p.y * 0.6) / bar.y * 1.7 - phase * 9.0);
	float wave = pow(max(band, 0.0), 6.0) * shimmer;
	tube += vec3(wave * 0.9);
	vec3 rgb = mix(mix(track_color.rgb, vec3(1.0), ghosted), tube, filled);
	float alpha = max(track * track_color.a, max(filled, ghosted));

	// Glow around the bar.
	float outside = max(track_d, 0.0);
	float halo = glow * exp(-outside / (r * 0.9)) * (1.0 - track) * (1.0 - smoothstep(margin * 0.4, margin, outside));
	vec3 halo_rgb = mix(fill_color.rgb, vec3(1.0), 0.35);
	float out_alpha = alpha + halo * (1.0 - alpha);
	rgb = out_alpha > 0.0 ? (rgb * alpha + halo_rgb * halo * (1.0 - alpha)) / out_alpha : rgb;
	// The whole bar brightens while glowing.
	rgb += vec3(0.25) * clamp(glow - 1.0, 0.0, 1.0) * filled;
	COLOR = vec4(rgb, out_alpha);
}

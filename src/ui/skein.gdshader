shader_type canvas_item;
// Colours a skein template (SkeinSwatch.template()): red is the shading the thread colour is
// multiplied by (scaled by 1/SHADE_RANGE so it can go above 1), green is light added on top,
// alpha the coverage. The thread colour comes in as the vertex colour (draw_texture_rect's
// modulate), which also carries the node's fading, so the whole skein fades as one.

const float SHADE_RANGE = 1.6;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(tint.rgb * t.r * SHADE_RANGE + t.g, t.a * tint.a);
}

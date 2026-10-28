shader_type canvas_item;
// A round, see-through button lit like the fabric (RoundButton): a disc with a rounded rim, a
// raised symbol from the `icon` mask, and a soft shadow cast away from the light. The rect is
// bigger than the disc (`disc` of it) to leave room for the shadow.

uniform sampler2D icon : filter_linear_mipmap, hint_default_black;
uniform float disc = 0.84;
// Towards the light in screen space: x right, y down, z out of the screen.
uniform vec3 light = vec3(-0.54, -0.54, 0.64);
uniform vec4 base_color : source_color = vec4(0.2, 0.2, 0.21, 0.62);
uniform vec4 icon_color : source_color = vec4(0.88, 0.88, 0.87, 1.0);
uniform vec4 tint_color : source_color = vec4(0.17, 0.47, 0.88, 1.0);
// 0..1 each: held down (the rim turns concave), toggled on (tinted), disabled (faded).
uniform float pressed = 0.0;
uniform float tint = 0.0;
uniform float disabled = 0.0;

const float RIM_START = 0.76;
const float RIM_STRENGTH = 0.4;
const float EMBOSS = 1.6;

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) / disc;
	float r = length(p);
	float aa = max(fwidth(r) * 1.5, 0.001);
	float inside = 1.0 - smoothstep(1.0 - aa, 1.0, r);
	vec3 to_light = normalize(light);

	// Rounded rim: flat in the middle, a quarter circle towards the edge.
	float t = clamp((r - RIM_START) / (1.0 - RIM_START), 0.0, 0.97);
	float slope = t / sqrt(1.0 - t * t) * RIM_STRENGTH * mix(1.0, -0.6, pressed);
	vec2 outward = r > 0.0001 ? p / r : vec2(0.0);
	vec3 normal = vec3(outward * slope, 1.0);

	// The symbol stands out of the face: its mask is a height map.
	vec2 texel = 1.5 / vec2(textureSize(icon, 0));
	float m = texture(icon, UV).r;
	float dx = texture(icon, UV + vec2(texel.x, 0.0)).r - texture(icon, UV - vec2(texel.x, 0.0)).r;
	float dy = texture(icon, UV + vec2(0.0, texel.y)).r - texture(icon, UV - vec2(0.0, texel.y)).r;
	normal.xy -= vec2(dx, dy) * EMBOSS * mix(1.0, 0.5, pressed);
	normal = normalize(normal);

	float diffuse = max(dot(normal, to_light), 0.0);
	vec3 half_vector = normalize(to_light + vec3(0.0, 0.0, 1.0));
	float specular = pow(max(dot(normal, half_vector), 0.0), 40.0) * 0.45;
	vec3 face = mix(base_color.rgb, tint_color.rgb, tint * 0.85);
	vec3 surface = face * (0.6 + 0.6 * diffuse) + specular * 0.7;
	vec3 symbol = mix(icon_color.rgb, vec3(1.0), tint) * (0.65 + 0.45 * diffuse) + specular * 0.4;
	vec3 rgb = mix(surface, symbol, m);
	// The rim is a little more solid than the face, so the button reads on any background.
	float alpha = inside * mix(base_color.a + 0.15 * t + 0.2 * tint, icon_color.a, m);
	rgb = mix(rgb, vec3(dot(rgb, vec3(0.333))), disabled * 0.7);
	alpha *= 1.0 - disabled * 0.45;

	// Shadow below, pushed away from the light.
	float shadow_r = length(p + to_light.xy * 0.16 * (1.0 - pressed * 0.6));
	float shadow = (1.0 - smoothstep(0.75, 1.17, shadow_r)) * 0.32 * (1.0 - disabled * 0.6);
	float out_alpha = alpha + shadow * (1.0 - alpha);
	COLOR = vec4(out_alpha > 0.0 ? rgb * alpha / out_alpha : rgb, out_alpha);
}

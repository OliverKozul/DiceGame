// Warm, flickering light pools added on top of the scene.
shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.62, 0.28, 1.0);
uniform vec2 glow_a = vec2(0.06, 0.04);
uniform vec2 glow_b = vec2(0.94, 0.04);
uniform float radius = 0.5;
uniform float strength = 0.16;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float flicker = 0.86 + 0.08 * sin(TIME * 7.3) + 0.05 * sin(TIME * 13.1 + 1.7) + 0.03 * sin(TIME * 23.0);
	float a = 1.0 - smoothstep(0.0, radius, length((UV - glow_a) * vec2(aspect, 1.0)));
	float b = 1.0 - smoothstep(0.0, radius, length((UV - glow_b) * vec2(aspect, 1.0)));
	COLOR = vec4(glow_color.rgb * (a * a + b * b) * strength * flicker, 1.0);
}

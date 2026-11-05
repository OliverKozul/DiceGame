// A coloured glow that creeps in from the screen edges (ambushes, knockouts). Animate `strength`.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.75, 0.1, 0.05, 1.0);
uniform float strength = 0.0;
uniform float inner = 0.46;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (UV - 0.5) * vec2(aspect, 1.0);
	float edge = smoothstep(inner, 1.0, length(d));
	COLOR = vec4(tint.rgb, edge * strength);
}

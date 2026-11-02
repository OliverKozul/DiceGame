// Darkens the edges of the screen.
shader_type canvas_item;

uniform float strength = 0.85;
uniform float inner = 0.38;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (UV - 0.5) * vec2(aspect, 1.0);
	COLOR = vec4(0.03, 0.015, 0.005, smoothstep(inner, 1.05, length(d)) * strength);
}

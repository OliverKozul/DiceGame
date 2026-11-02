// Scene transition: darkness creeps in from the edges like a candle being snuffed.
shader_type canvas_item;
#include "res://Assets/Shaders/noise.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.04, 0.02, 0.01, 1.0);

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float d = length((UV - 0.5) * vec2(aspect, 1.0)) * 1.1 + dg_fbm(FRAGCOORD.xy * 0.006) * 0.3;
	float t = 1.35 - progress * 1.9;
	float dark = smoothstep(t - 0.03, t + 0.03, d);
	float ember = (smoothstep(t - 0.09, t - 0.01, d) - smoothstep(t - 0.01, t + 0.03, d)) * (1.0 - progress);
	COLOR = vec4(mix(color.rgb, vec3(1.0, 0.48, 0.12), ember), max(dark, ember * 0.85));
}

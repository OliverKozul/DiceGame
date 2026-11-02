// Aged parchment: blotches, fine grain and darkened edges.
shader_type canvas_item;
#include "res://Assets/Shaders/noise.gdshaderinc"

uniform vec4 paper : source_color = vec4(0.91, 0.85, 0.71, 1.0);
uniform vec4 stain : source_color = vec4(0.60, 0.44, 0.24, 1.0);
uniform float edge_burn = 0.45;

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float n = dg_fbm(p * 0.007);
	float fine = dg_noise(p * 0.7) * 0.05;
	vec3 color = mix(paper.rgb, stain.rgb, smoothstep(0.45, 0.95, n) * 0.4) - fine;
	vec2 e = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, 0.07, min(e.x, e.y) + (n - 0.5) * 0.04);
	color = mix(color, stain.rgb * 0.65, edge * edge_burn);
	COLOR = vec4(color, 1.0);
}

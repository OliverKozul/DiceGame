// Aged parchment: soft blotches from a simplex noise texture, fine grain and darkened edges.
shader_type canvas_item;

uniform vec4 paper : source_color = vec4(0.91, 0.85, 0.71, 1.0);
uniform vec4 stain : source_color = vec4(0.60, 0.44, 0.24, 1.0);
uniform float edge_burn = 0.45;
uniform sampler2D noise_texture : repeat_enable, filter_linear;

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float blotch = texture(noise_texture, p / 700.0).r;
	float grain = texture(noise_texture, p / 37.0).r;
	vec3 color = mix(paper.rgb, stain.rgb, smoothstep(0.55, 0.95, blotch) * 0.32);
	color -= (grain - 0.5) * 0.05;
	vec2 e = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, 0.07, min(e.x, e.y) + (blotch - 0.5) * 0.05);
	color = mix(color, stain.rgb * 0.65, edge * edge_burn);
	COLOR = vec4(color, 1.0);
}

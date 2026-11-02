// Procedural wooden planks: grain, knots, seams and per-plank tint.
shader_type canvas_item;
#include "res://Assets/Shaders/noise.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.23, 0.14, 0.08, 1.0);
uniform vec4 light_color : source_color = vec4(0.36, 0.22, 0.12, 1.0);
uniform vec4 dark_color : source_color = vec4(0.10, 0.06, 0.03, 1.0);
uniform float plank_width = 170.0;
uniform bool horizontal = false;

void fragment() {
	vec2 p = FRAGCOORD.xy;
	if (horizontal) {
		p = p.yx;
	}
	float id = floor(p.x / plank_width);
	float local = fract(p.x / plank_width);
	float n = dg_fbm(vec2(p.x * 0.018, p.y * 0.0022 + id * 7.3));
	float grain = pow(sin(p.x * 0.11 + n * 10.0 + id * 3.1) * 0.5 + 0.5, 3.0);
	float knots = smoothstep(0.72, 0.9, dg_fbm(p * 0.012 + id * 5.0));
	vec3 color = mix(base_color.rgb, light_color.rgb, n * 0.7);
	color = mix(color, dark_color.rgb, grain * 0.32 + knots * 0.45);
	float seam = smoothstep(0.0, 0.014, local) * smoothstep(1.0, 0.986, local);
	float joint = abs(fract((p.y + dg_hash(vec2(id, 1.0)) * 900.0) / 1100.0) - 0.5) * 1100.0;
	seam *= smoothstep(0.0, 2.5, joint);
	color *= mix(0.42, 1.0, seam) * (0.88 + 0.14 * dg_hash(vec2(id, 3.0)));
	COLOR = vec4(color, 1.0);
}

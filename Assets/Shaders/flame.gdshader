// A candle flame that sways and flickers. Draw on a tall ColorRect.
shader_type canvas_item;
render_mode blend_add;

uniform float seed = 0.0;

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME + seed * 10.0;
	float sway = (sin(t * 5.0 + uv.y * 3.0) * 0.05 + sin(t * 11.0) * 0.02) * uv.y;
	vec2 d = uv - vec2(0.5 + sway, 0.28);
	d.x *= 2.3;
	d.y *= d.y > 0.0 ? 0.72 : 1.7;
	float r = length(d);
	float flicker = 0.9 + 0.1 * sin(t * 17.0) + 0.05 * sin(t * 29.0);
	float core = 1.0 - smoothstep(0.03, 0.17 * flicker, r);
	float outer = 1.0 - smoothstep(0.08, 0.40 * flicker, r);
	COLOR = vec4(vec3(1.0, 0.5, 0.14) * outer * 0.9 + vec3(1.0, 0.94, 0.72) * core, 1.0);
}

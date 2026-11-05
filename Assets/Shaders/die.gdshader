// An ivory die, slightly darker and worn along its rounded edges, with an emissive glow for
// selection and landing. The rounding is real geometry (DiceTray builds the mesh).
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.95, 0.91, 0.82, 1.0);
uniform vec4 edge_tint : source_color = vec4(0.70, 0.60, 0.46, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.28, 1.0);
// 0..1: selection glow along the edges.
uniform float glow = 0.0;
// 0..1: a flash over the whole die (landing, a new face).
uniform float flash = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 p = abs(local_pos) / 0.49;
	// On a face one coordinate is 1; towards an edge a second one approaches it too.
	float second = max(min(p.x, p.y), min(max(p.x, p.y), p.z));
	float worn = 1.0 - smoothstep(0.68, 0.97, second);
	ALBEDO = mix(edge_tint.rgb, albedo.rgb, mix(0.4, 1.0, worn));
	ROUGHNESS = 0.34;
	SPECULAR = 0.5;
	EMISSION = glow_color.rgb * (glow * (1.15 - worn * 0.8) + flash * 0.9);
}

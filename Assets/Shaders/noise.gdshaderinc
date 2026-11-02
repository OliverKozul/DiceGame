// Shared value noise helpers for the procedural tavern materials.
float dg_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float dg_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dg_hash(i), dg_hash(i + vec2(1.0, 0.0)), u.x),
		mix(dg_hash(i + vec2(0.0, 1.0)), dg_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float dg_fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * dg_noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

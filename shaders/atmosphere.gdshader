shader_type canvas_item;
render_mode unshaded;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * vec2(4.3, 2.6) + vec2(TIME * 0.016, -TIME * 0.09);
	float cloud = noise(p) * 0.65 + noise(p * 2.1) * 0.25 + noise(p * 4.0) * 0.1;
	float shadow = smoothstep(0.45, 0.76, cloud) * 0.095;
	vec2 d = UV * vec2(2.2, 11.0) + vec2(-TIME * 0.037, -TIME * 0.045);
	float dust = smoothstep(0.62, 0.86, noise(d)) * 0.035;
	float alpha = shadow + dust;
	vec3 color = mix(vec3(0.065, 0.09, 0.115), vec3(0.79, 0.64, 0.44), dust / max(alpha, 0.0001));
	COLOR = vec4(color, alpha);
}

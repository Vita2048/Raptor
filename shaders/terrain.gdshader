shader_type canvas_item;
varying vec4 tint;
uniform bool animate_water = false;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (animate_water) {
		// Color mask excludes sandstone, gray bridges and white shore foam.
		float water = smoothstep(0.025, 0.12, min(tex.b, tex.g) - tex.r);
		vec2 ripple = vec2(sin(UV.y * 610.0 + TIME * 0.85), cos(UV.x * 480.0 + TIME * 0.6));
		vec3 moving = texture(TEXTURE, UV + ripple * TEXTURE_PIXEL_SIZE * 0.55 * water).rgb;
		float glint = pow(0.5 + 0.5 * sin(UV.y * 930.0 + sin(UV.x * 190.0) * 2.0 - TIME * 1.1), 12.0);
		tex.rgb = mix(tex.rgb, moving, water * 0.65) + vec3(0.003, 0.006, 0.008) * glint * water;
	}
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luminance), tex.rgb, 0.78);
	graded = (graded - 0.5) * 0.94 + 0.5;
	COLOR = vec4(graded * vec3(0.94, 0.95, 0.97), tex.a) * tint;
}

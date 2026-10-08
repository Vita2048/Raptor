shader_type canvas_item;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luminance), tex.rgb, 0.78);
	graded = (graded - 0.5) * 0.94 + 0.5;
	COLOR = vec4(graded * vec3(0.94, 0.95, 0.97), tex.a) * tint;
}

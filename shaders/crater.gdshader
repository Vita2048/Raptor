shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform vec4 ground_tint : source_color = vec4(0.9, 0.85, 0.76, 1.0);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 rock = mix(vec3(luminance), tex.rgb, saturation);
	COLOR = vec4(rock * ground_tint.rgb, tex.a) * vertex_tint;
}

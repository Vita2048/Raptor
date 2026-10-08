shader_type canvas_item;
uniform float hit_amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 tex = texture(TEXTURE, UV) * tint;
	COLOR = vec4(mix(tex.rgb, vec3(1.0, 0.91, 0.73), hit_amount), tex.a);
}

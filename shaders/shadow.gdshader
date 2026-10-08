shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 4.0;
	float alpha = texture(TEXTURE, UV).a * 4.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			alpha += texture(TEXTURE, UV + vec2(float(x), float(y)) * step_uv).a;
		}
	}
	COLOR = vec4(0.055, 0.065, 0.075, alpha / 13.0 * 0.24);
}

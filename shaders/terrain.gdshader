shader_type canvas_item;
varying vec4 tint;
uniform bool animate_water = false;
global uniform vec4 sector_light;
uniform sampler2D current_map : source_color, filter_linear_mipmap;
uniform sampler2D next_map : source_color, filter_linear_mipmap;
uniform float transition_progress = 1.0;

vec4 map_sample(sampler2D map_tex, vec2 uv) {
    // Symmetric edge overlap joins the tile without stretching a single scanline.
    vec4 color = texture(map_tex, uv);
    float edge = 0.5 * (1.0 - smoothstep(0.0, 0.012, min(uv.y, 1.0 - uv.y)));
    return mix(color, texture(map_tex, vec2(uv.x, 1.0 - uv.y)), edge);
}


void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
    float arrival = smoothstep(SCREEN_UV.y - 0.18, SCREEN_UV.y + 0.18, transition_progress * 1.4 - 0.2);
    if (animate_water) {
        tex = mix(map_sample(current_map, UV), map_sample(next_map, UV), arrival);
    }
	if (animate_water) {
		// Color mask excludes sandstone, gray bridges and white shore foam.
		float water = smoothstep(0.025, 0.12, min(tex.b, tex.g) - tex.r);
		vec2 ripple = vec2(sin(UV.y * 610.0 + TIME * 0.85), cos(UV.x * 480.0 + TIME * 0.6));
		vec2 water_uv = UV + ripple * TEXTURE_PIXEL_SIZE * 0.55 * water;
        vec3 moving = mix(map_sample(current_map, water_uv), map_sample(next_map, water_uv), arrival).rgb;
		float glint = pow(0.5 + 0.5 * sin(UV.y * 930.0 + sin(UV.x * 190.0) * 2.0 - TIME * 1.1), 12.0);
		tex.rgb = mix(tex.rgb, moving, water * 0.65) + vec3(0.003, 0.006, 0.008) * glint * water;
	}
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luminance), tex.rgb, 0.67);
	graded = (graded - 0.5) * 0.86 + 0.5;
	COLOR = vec4(graded * sector_light.rgb, tex.a) * tint;
}

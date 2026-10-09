shader_type canvas_item;
uniform float hit_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool player_accent = false;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float luma = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
    // Temper saturated paint while retaining metal highlights and insignia.
    float blue_paint = smoothstep(0.04, 0.25, tex.b - tex.r);
    vec3 metal = mix(vec3(luma), tex.rgb, mix(0.82, 0.38, blue_paint));
    metal = metal * vec3(1.04, 1.015, 0.98) + vec3(0.025);
    if (player_accent) {
        float edge = min(min(texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x * 3.0, 0)).a,
                             texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x * 3.0, 0)).a),
                         min(texture(TEXTURE, UV + vec2(0, TEXTURE_PIXEL_SIZE.y * 3.0)).a,
                             texture(TEXTURE, UV - vec2(0, TEXTURE_PIXEL_SIZE.y * 3.0)).a));
        metal = mix(metal, vec3(0.32, 0.91, 0.96), (1.0 - edge) * 0.65);
        float stripe = (1.0 - smoothstep(0.012, 0.022, abs(abs(UV.x - 0.5) - 0.19)));
        metal = mix(metal, vec3(0.16, 0.68, 0.73), stripe * 0.5);
    }
    COLOR = vec4(mix(metal, vec3(1.0, 0.91, 0.73), hit_amount), tex.a) * tint;
}

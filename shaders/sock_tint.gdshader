shader_type canvas_item;

uniform vec4 sock_tint : source_color = vec4(0.882, 0.353, 0.404, 1.0);
uniform vec4 hair_tint : source_color = vec4(0.208, 0.655, 0.843, 1.0);
uniform vec4 room_light : source_color = vec4(0.94, 0.88, 0.78, 1.0);
uniform bool hair_only = false;

void fragment() {
	vec4 pixel = COLOR;
	bool is_hair = hair_only || (UV.y < 0.6 && pixel.b > 0.12 && pixel.b > pixel.r * 1.3 && pixel.g > pixel.r * 1.25);
	if (!hair_only && pixel.r > 0.12 && pixel.r > pixel.g * 1.3 && pixel.r > pixel.b * 1.18) {
		pixel.rgb = sock_tint.rgb * (pixel.r / 0.882);
	}
	// Authored blue yarn is a reusable color mask, limited to the head area.
	if (is_hair) {
		pixel.rgb = hair_tint.rgb * (max(pixel.g, pixel.b) / 0.843);
	}
	float key_light = mix(1.05, 0.85, smoothstep(0.2, 0.9, UV.y));
	pixel.rgb *= room_light.rgb * key_light;
	COLOR = pixel;
}

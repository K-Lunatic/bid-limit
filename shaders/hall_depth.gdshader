shader_type canvas_item;
uniform vec4 room_light : source_color = vec4(0.94, 0.88, 0.78, 1.0);

void fragment() {
	vec4 texel = COLOR;
	float luminance = dot(texel.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 softened = mix(vec3(luminance), texel.rgb, 0.68);
	COLOR = vec4(softened * room_light.rgb * 0.86, texel.a);
}

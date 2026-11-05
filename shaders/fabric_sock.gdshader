shader_type spatial;

uniform vec4 dye : source_color = vec4(0.8, 0.2, 0.25, 1.0);
uniform float weave_scale = 42.0;

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float warp = sin(UV.y * weave_scale) * 0.045;
	float weft = sin(UV.x * weave_scale * 0.72) * 0.028;
	float fleck = hash(floor(UV * 90.0)) * 0.035;
	ALBEDO = dye.rgb * (0.9 + warp + weft + fleck);
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}

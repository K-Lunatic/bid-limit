shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.3, 0.2, 0.15, 1.0);
uniform vec4 accent_color : source_color = vec4(0.38, 0.28, 0.2, 1.0);
uniform float noise_scale = 1.8;
varying vec3 surface_position;

float hash(vec3 value) {
	return fract(sin(dot(value, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float value_noise(vec3 value) {
	vec3 cell = floor(value);
	vec3 local = fract(value);
	local = local * local * (3.0 - 2.0 * local);
	return mix(mix(mix(hash(cell), hash(cell + vec3(1.0, 0.0, 0.0)), local.x), mix(hash(cell + vec3(0.0, 1.0, 0.0)), hash(cell + vec3(1.0, 1.0, 0.0)), local.x), local.y), mix(mix(hash(cell + vec3(0.0, 0.0, 1.0)), hash(cell + vec3(1.0, 0.0, 1.0)), local.x), mix(hash(cell + vec3(0.0, 1.0, 1.0)), hash(cell + vec3(1.0, 1.0, 1.0)), local.x), local.y), local.z);
}

void vertex() {
	surface_position = VERTEX;
}

void fragment() {
	float low = value_noise(surface_position * noise_scale);
	float grain = sin((surface_position.x + surface_position.z) * 18.0) * 0.025;
	ALBEDO = mix(base_color.rgb, accent_color.rgb, low * 0.42 + grain + 0.2);
	ROUGHNESS = 0.8;
	METALLIC = 0.03;
}

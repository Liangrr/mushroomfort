shader_type canvas_item;
render_mode unshaded;

uniform sampler2D material_map : filter_linear, repeat_disable;
uniform sampler2D root_art : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D road_art : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 map_size = vec2(16.0, 10.0);
uniform float edge_warp = 0.105;
uniform float edge_softness = 0.095;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float organic_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0,0.0)), f.x),
		mix(hash21(cell + vec2(0.0,1.0)), hash21(cell + vec2(1.0,1.0)), f.x), f.y);
}
vec3 terrain_field(vec2 grid) {
	vec2 at = (grid + vec2(1.0)) / map_size;
	vec2 step_uv = vec2(0.22) / map_size;
	// A bounded five-tap Gaussian-style prefilter rounds material corners.
	vec3 field = texture(material_map, at).rgb * 0.48;
	field += texture(material_map, at + vec2(step_uv.x,0.0)).rgb * 0.13;
	field += texture(material_map, at - vec2(step_uv.x,0.0)).rgb * 0.13;
	field += texture(material_map, at + vec2(0.0,step_uv.y)).rgb * 0.13;
	field += texture(material_map, at - vec2(0.0,step_uv.y)).rgb * 0.13;
	return field;
}
void fragment() {
	vec2 grid = UV * map_size - vec2(1.0);
	// World-space variation only: no TIME, zoom-dependent noise or moving borders.
	vec2 wave = vec2(organic_noise(grid * 1.65), organic_noise(grid * 1.65 + 37.4)) - 0.5;
	wave += (vec2(organic_noise(grid * 4.1 + 8.0), organic_noise(grid * 4.1 + 61.0))-0.5)*0.26;
	vec3 field = terrain_field(grid + wave * edge_warp * 2.0);
	float road = smoothstep(0.43 - edge_softness, 0.43 + edge_softness, field.r);
	float platform = smoothstep(0.46 - edge_softness, 0.46 + edge_softness, field.b);
	float coverage = smoothstep(0.43 - edge_softness, 0.43 + edge_softness, field.g);
	// Painted albedo already carries the grove palette. Sample across several
	// cells so repetition never outlines the underlying simulation grid.
	vec3 roots = texture(root_art, grid * 0.32).rgb * mix(vec3(0.94,0.97,0.94),vec3(0.98),platform);
	vec3 path = texture(road_art, grid * 0.58).rgb;
	vec3 surface = mix(roots,path,road);
	// A restrained root-colored shoulder, not a blurred image or dark outline.
	float shoulder = road * (1.0-road) * 4.0;
	surface = mix(surface, surface * vec3(0.91,0.94,0.91), shoulder * 0.25);
	COLOR = vec4(surface,coverage);
}

shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.3, length(centered));
	vec3 tint = mix(vec3(0.72, 0.48, 0.18), vec3(0.04, 0.09, 0.07), edge);
	COLOR = vec4(tint, intensity * mix(0.018, 0.10, edge));
}

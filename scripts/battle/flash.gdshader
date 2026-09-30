shader_type canvas_item;
// Hit flash (to white) and status tint for units.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb * tint.rgb, vec3(1.0, 0.98, 0.9), flash);
	COLOR = c;
}

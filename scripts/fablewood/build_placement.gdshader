shader_type canvas_item;
render_mode unshaded;
uniform vec4 preview_color : source_color = vec4(0.16, 0.64, 1.0, 0.72);
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float detail = mix(0.65, 1.0, dot(source.rgb, vec3(0.2126, 0.7152, 0.0722)));
	COLOR = vec4(preview_color.rgb * detail, source.a * preview_color.a);
}

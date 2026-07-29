shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
	COLOR = vec4(textureLod(screen_texture, SCREEN_UV + vec2(0.06, 0.0), 0.0).rgb, 1.0);
}

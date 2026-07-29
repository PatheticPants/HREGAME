shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
	COLOR = vec4(1.0, 0.0, 1.0, 1.0);
}

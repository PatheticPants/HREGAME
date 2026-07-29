shader_type canvas_item;
render_mode unshaded, blend_mix;

// A deliberately small optical effect. The authored evidence is still redrawn
// at inspection resolution by Lens; this only makes the ordinary desk beneath
// the crown glass bend enough to prove that the aperture contains glass.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 lens_center_screen = vec2(0.5);
uniform float magnification : hint_range(0.0, 0.12) = 0.065;
uniform float fringe_pixels : hint_range(0.0, 1.0) = 0.42;
uniform float active : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	if (radius > 1.0) {
		discard;
	}

	float body = 1.0 - smoothstep(0.08, 1.0, radius);
	vec2 from_center = SCREEN_UV - lens_center_screen;
	vec2 sample_uv = lens_center_screen
		+ from_center / (1.0 + magnification * body * active);

	// Quantise the displaced sample back onto the screen pixel grid. Smooth
	// refraction would airbrush the authored clusters this game's art depends on.
	sample_uv = (floor(sample_uv / SCREEN_PIXEL_SIZE) + vec2(0.5))
		* SCREEN_PIXEL_SIZE;
	vec4 base = textureLod(screen_texture, sample_uv, 0.0);

	// Old crown glass separates a trace of colour at the steep outer edge. Less
	// than half a pixel and nowhere near the readable centre.
	float rim = smoothstep(0.72, 0.96, radius) * (1.0 - smoothstep(0.96, 1.0, radius));
	vec2 radial = normalize(p + vec2(0.0001));
	vec2 fringe = radial * SCREEN_PIXEL_SIZE * fringe_pixels;
	float red = textureLod(screen_texture, sample_uv + fringe, 0.0).r;
	float blue = textureLod(screen_texture, sample_uv - fringe, 0.0).b;
	base.r = mix(base.r, red, rim * 0.34 * active);
	base.b = mix(base.b, blue, rim * 0.34 * active);

	float edge_alpha = 1.0 - smoothstep(0.965, 1.0, radius);
	COLOR = vec4(base.rgb, edge_alpha * active);
}

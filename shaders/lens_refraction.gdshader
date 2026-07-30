shader_type canvas_item;
render_mode unshaded, blend_mix;

// A deliberately small optical effect. The authored evidence is still redrawn
// at inspection resolution by Lens; this only makes the ordinary desk beneath
// the crown glass bend enough to prove that the aperture contains glass.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 lens_center_screen = vec2(0.5);
// IT IS A MAGNIFYING GLASS. It spent its whole life set between 0.048 and
// 0.070 — a five per cent bulge, which is a refraction and not a magnification,
// and the owner reported it as "the glass does not magnify" because it did not.
// At 1.0 the sample is drawn from half the radius, which is 2x. The range is
// open now because the clamp was documenting the bug.
uniform float magnification : hint_range(0.0, 3.0) = 1.0;
uniform float fringe_pixels : hint_range(0.0, 1.0) = 0.42;
uniform float active : hint_range(0.0, 1.0) = 1.0;

// Land a sample on the centre of a screen texel. Smooth refraction would airbrush
// the authored pixel clusters this game's art depends on, so every tap is snapped
// — but each one is snapped AFTER its own displacement, never before.
// SCREEN_PIXEL_SIZE is only in scope inside fragment(), so it is passed in.
vec2 snap_to_pixel(vec2 uv, vec2 texel) {
	return (floor(uv / texel) + vec2(0.5)) * texel;
}

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

	// Old crown glass separates a trace of colour at the steep outer edge. Each
	// channel refracts by a slightly different amount and THEN lands on the pixel
	// grid — which is the order that matters, and the order this originally had
	// backwards.
	//
	// The first version quantised sample_uv to a texel CENTRE and only then added
	// a fringe of 0.42 texels. From a centre you need to travel more than 0.5 of a
	// texel to reach the next one, and with filter_nearest the red and blue taps
	// therefore resolved to the identical texel as base — at every resolution, so
	// `mix(base.r, base.r, k)` returned base.r and the aberration did nothing
	// whatever. Offsetting first lets a sample near a texel boundary fall on the
	// far side of it, so the separation appears as whole displaced pixels along
	// the rim rather than as a smooth halo. Which is also the only form of it this
	// game's art can accept.
	float rim = smoothstep(0.72, 0.96, radius) * (1.0 - smoothstep(0.96, 1.0, radius));
	vec2 radial = normalize(p + vec2(0.0001));
	vec2 fringe = radial * SCREEN_PIXEL_SIZE * fringe_pixels;

	vec4 base = textureLod(screen_texture, snap_to_pixel(sample_uv, SCREEN_PIXEL_SIZE), 0.0);
	float red = textureLod(screen_texture,
		snap_to_pixel(sample_uv + fringe, SCREEN_PIXEL_SIZE), 0.0).r;
	float blue = textureLod(screen_texture,
		snap_to_pixel(sample_uv - fringe, SCREEN_PIXEL_SIZE), 0.0).b;
	base.r = mix(base.r, red, rim * 0.34 * active);
	base.b = mix(base.b, blue, rim * 0.34 * active);

	float edge_alpha = 1.0 - smoothstep(0.965, 1.0, radius);
	COLOR = vec4(base.rgb, edge_alpha * active);
}

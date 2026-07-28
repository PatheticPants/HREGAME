class_name WaxShape
extends RefCounted

## Outlines for wax, shared by the pendant seals that arrive on charters and by
## the pool the player pours.
##
## The outline is generated ONCE from a seed and then only scaled. It must not be
## re-randomised per frame — a pool that reshuffles its own edge while it spreads
## reads as static, not as wax. This is the single most important thing about the
## wax rendering and it is easy to get wrong by putting randf() in _draw.

## Unit-radius outline. Multiply by the current radius to draw.
static func outline(shape: StringName, rng_seed: int, jitter: float,
		count: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var n := maxi(6, count)
	var pts := PackedVector2Array()

	# One low-frequency lobe so the blob has a direction to it — real wax runs
	# somewhere rather than spreading evenly.
	var lobe_angle := rng.randf() * TAU
	var lobe_strength := rng.randf_range(0.04, 0.16) * (jitter / 0.2)

	for i in n:
		var t := float(i) / float(n) * TAU
		var wobble := 1.0 + rng.randf_range(-jitter, jitter)
		var lobe := 1.0 + lobe_strength * cos(t - lobe_angle)
		var rr := wobble * lobe
		pts.append(_profile(shape, t) * rr)
	return _smooth(pts)


## Base profile before jitter: circles for most seals, a pointed oval for the
## church's, which is how you tell a chapter seal from a lay one at a glance.
static func _profile(shape: StringName, t: float) -> Vector2:
	var s := sin(t)
	var c := cos(t)
	match shape:
		&"vesica":
			# Narrowed toward the poles so the ends come to a point.
			return Vector2(0.62 * s * (1.0 - 0.26 * c * c), c)
		&"shield":
			var y := c
			var x := s * (1.0 - 0.30 * maxf(0.0, y))
			return Vector2(x * 0.86, y)
		_:
			return Vector2(s, c)


## Neighbour averaging. Raw per-point jitter looks like a saw blade; smoothing
## turns it into something that has flowed. Two passes rather than one, because
## a single pass still leaves visible straight facets at the sizes wax is drawn
## at — the blob reads as a stop sign, and a stop sign is not a liquid.
static func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts
	for _pass in 2:
		out = _smooth_once(out)
	return out


static func _smooth_once(pts: PackedVector2Array) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		out[i] = (a + b * 2.0 + c) * 0.25
	return out


static func scaled(unit: PackedVector2Array, centre: Vector2, radius: float,
		squash := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(unit.size())
	for i in unit.size():
		out[i] = centre + Vector2(unit[i].x, unit[i].y * squash) * radius
	return out


## Wax is glossy on one side and sunk on the other. Drawing the same outline
## three times — dark and offset, base, then a small light crescent — costs
## nothing and is the difference between "blob" and "wax".
static func draw_body(c: CanvasItem, unit: PackedVector2Array, centre: Vector2,
		radius: float, col: Color, light_dir: Vector2, alpha := 1.0) -> void:
	var lift := light_dir.normalized() * radius * 0.06
	var base := Color(col.r, col.g, col.b, col.a * alpha)

	c.draw_colored_polygon(scaled(unit, centre - lift * 0.7, radius * 1.03),
		Color(base.darkened(0.55), base.a * 0.85))
	c.draw_colored_polygon(scaled(unit, centre, radius), base)
	c.draw_colored_polygon(scaled(unit, centre + lift, radius * 0.80),
		Color(base.lightened(0.16), base.a * 0.55))


## A lens close-up needs more surface information than the desk-scale seal. The
## nested silhouettes describe a rounded shoulder, compressed face, raised rim,
## and the asymmetric gloss of aged resin without swapping to a different asset.
static func draw_magnified_body(c: CanvasItem, unit: PackedVector2Array,
		centre: Vector2, radius: float, col: Color,
		light_dir := Vector2(-0.65, -0.75)) -> void:
	var light := light_dir.normalized()
	var shadow := scaled(unit, centre - light * 3.2 + Vector2(0, 2.0), radius * 1.035)
	c.draw_colored_polygon(shadow, Color(0.055, 0.012, 0.016, 0.52 * col.a))
	c.draw_colored_polygon(scaled(unit, centre, radius), col.darkened(0.43))
	c.draw_colored_polygon(scaled(unit, centre, radius * 0.965), col.darkened(0.18))
	c.draw_colored_polygon(scaled(unit, centre + light * radius * 0.025,
		radius * 0.90), col)
	c.draw_colored_polygon(scaled(unit, centre + light * radius * 0.065,
		radius * 0.78), Color(col.lightened(0.10), col.a * 0.88))

	var outer := _closed(scaled(unit, centre, radius * 0.945))
	var field := _closed(scaled(unit, centre, radius * 0.79))
	c.draw_polyline(outer, Color(col.lightened(0.24), col.a * 0.72),
		maxf(1.4, radius * 0.025), true)
	c.draw_polyline(field, Color(col.darkened(0.48), col.a * 0.92),
		maxf(1.2, radius * 0.022), true)
	var field_lit := _closed(scaled(unit,
		centre + light * radius * 0.018, radius * 0.765))
	c.draw_polyline(field_lit, Color(col.lightened(0.19), col.a * 0.55),
		maxf(0.9, radius * 0.014), true)

	# Two restrained specular ridges. Broad painted white patches look like
	# enamel; thin broken arcs read as glossy wax.
	c.draw_arc(centre + light * radius * 0.07, radius * 0.67,
		PI * 1.06, PI * 1.50, 18, Color(1.0, 0.72, 0.55, 0.20), 2.2)
	c.draw_arc(centre + light * radius * 0.12, radius * 0.48,
		PI * 1.10, PI * 1.35, 12, Color(1.0, 0.80, 0.66, 0.13), 1.4)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points
	if not out.is_empty():
		out.append(out[0])
	return out

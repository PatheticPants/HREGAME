class_name SealTag
extends Draggable

## The pendant seal that arrives attached to a charter.
##
## Physically separate, legally part of the instrument, and hanging off a cord —
## which is how real ones worked and is also the right answer for play. You can
## pull it out from under the pile to look at it without dragging the whole
## charter, and it swings back when you let go, and it follows the charter across
## the desk if you move that instead. All three of those are things a flat
## rendered-on-the-page seal cannot do.
##
## The legend is deliberately NOT legible unaided. There is writing around the
## rim and you can see that there is writing, and you need the lens to read it.

const TETHER := 155.0
const RADIUS := 46.0

var impression: SealImpression = null
var charter: CharterView = null

var _unit: PackedVector2Array = PackedVector2Array()
var _rim_ticks := 0
var _wear_marks: PackedVector3Array = PackedVector3Array()
var _detail_pits: PackedVector3Array = PackedVector3Array()


func bind(imp: SealImpression, owner_charter: CharterView, desk_bounds: Rect2) -> void:
	impression = imp
	charter = owner_charter
	name = "seal_" + String(imp.id)
	hit_size = Vector2(RADIUS * 2.2, RADIUS * 2.4)
	pickup_sound = &"paper_pickup"
	drop_sound = &"paper_drop"
	slide_sound = &""  # too small to make a sliding noise

	# Jitter is low: a struck seal is a fairly clean disc. The irregularity that
	# matters is the *wear*, which is applied when drawing.
	_unit = WaxShape.outline(imp.shape, imp.shape_seed, 0.055, 26)
	_rim_ticks = 34 if imp.shape == &"round" else 28
	_build_surface_marks()

	# setup() takes a position in our parent's space. cord_world() is global, so
	# convert it before adding the hanging offset. Without this conversion the
	# seal spawned a whole desk-width away and snapped violently down its cord.
	var parent_space := get_parent() as Node2D
	# The charter arrives near the desk's lower rim, so drape the pendant down
	# and left rather than straight off-screen. It is still slack on the cord,
	# but its whole face is available to the player's glass from frame one.
	var start: Vector2 = parent_space.to_local(owner_charter.cord_world()) + Vector2(-110, 12)
	setup(start, deg_to_rad(randf_range(-9.0, 9.0)), desk_bounds)


func _build_surface_marks() -> void:
	_wear_marks = PackedVector3Array()
	_detail_pits = PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = impression.shape_seed + 977
	for i in 12:
		var t := rng.randf_range(1.3, 3.4)
		var d := rng.randf_range(0.80, 1.02)
		_wear_marks.append(Vector3(sin(t) * d, cos(t) * d,
			rng.randf_range(2.5, 6.5)))
	rng.seed = impression.shape_seed + 4127
	for i in 11:
		var a := rng.randf_range(0.0, TAU)
		var d := sqrt(rng.randf_range(0.03, 0.62))
		_detail_pits.append(Vector3(cos(a) * d, sin(a) * d,
			rng.randf_range(0.006, 0.017)))


func _process(delta: float) -> void:
	super._process(delta)
	_apply_tether(delta)


## Constraint, not parenting. The tag is a free body that happens to be attached
## to something: it swings when the charter moves, catches at the end of the cord
## rather than snapping to it, and can be laid down on its own several inches
## away. Parenting it would have made it furniture.
func _apply_tether(delta: float) -> void:
	# is_instance_valid as well as null: when a case is swept away the charter
	# and its seal are freed in the same frame, and a freed Node is not null.
	if charter == null or not is_instance_valid(charter) or is_held:
		return
	var anchor := charter.cord_world()
	var to_anchor := anchor - global_position
	var slack := to_anchor.length() - TETHER
	if slack <= 0.0:
		return
	# Only the overshoot pulls, so within the cord's length nothing happens at
	# all and the tag genuinely hangs loose.
	solver.velocity += to_anchor.normalized() * slack * 11.0 * delta
	solver.sleeping = false


func _draw() -> void:
	if impression == null:
		return
	_draw_cord()

	var wax := impression.wax_color
	draw_soft_shadow(Rect2(-Vector2(RADIUS, RADIUS) * 0.92,
		Vector2(RADIUS, RADIUS) * 1.84), 1.0)

	var light := (light_position - global_position).rotated(-global_rotation)
	if light.length() < 1.0:
		light = Vector2(0, -1)
	WaxShape.draw_body(self, _unit, Vector2.ZERO, RADIUS, wax, -light)

	_draw_rim(wax)
	Heraldry.draw_device_incuse(self, impression.device, Vector2(0, 2.0),
		RADIUS * 0.52, wax, 1.0 - impression.wear * 0.55)
	_draw_wear(wax)
	# Wax in the dark half of the desk loses its device before it loses its
	# shape, like every other face here. This was the only piece of evidence in
	# the game still legible at any distance from the flame, because it hangs off
	# the charter instead of being part of it.
	draw_shade(Rect2(-Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0), 1.0)


## Ticks around the rim stand in for a legend you cannot read. The player can
## see there is lettering; what it says needs the glass.
func _draw_rim(wax: Color) -> void:
	var inner := RADIUS * 0.74
	var outer := RADIUS * 0.90
	draw_arc(Vector2.ZERO, inner, 0.0, TAU, 40, wax.darkened(0.38), 1.5)
	for i in _rim_ticks:
		var t := float(i) / float(_rim_ticks) * TAU
		# Wear eats the lettering unevenly, starting at one edge and spreading —
		# which is what damage looks like, as against the uniform fade that
		# would read as "this seal is fake".
		var worn := impression.wear * (0.55 + 0.45 * cos(t - 2.1))
		if worn > 0.62:
			continue
		var dir := Vector2(sin(t), cos(t))
		draw_line(dir * inner, dir * outer, wax.darkened(0.46),
			maxf(0.8, 2.2 - impression.wear * 1.4))


## Chips and rubbing along one side. Wear is not evidence of forgery and the
## game has to make that legible: a damaged seal must look damaged, not wrong.
func _draw_wear(wax: Color) -> void:
	if impression.wear <= 0.02:
		return
	var chips := int(impression.wear * 9.0)
	for i in chips:
		var mark := _wear_marks[i]
		var p := Vector2(mark.x, mark.y) * RADIUS
		draw_circle(p, mark.z * (0.5 + impression.wear),
			Color(wax.darkened(0.62), 0.75))


func _draw_cord() -> void:
	if charter == null or not is_instance_valid(charter):
		return
	var a := to_local(charter.cord_world())
	var b := Vector2(0, -RADIUS * 0.86)
	# A slack cord bows under its own weight; a straight line reads as wire.
	var sag := Vector2(0, clampf(a.distance_to(b) * 0.16, 3.0, 26.0))
	var mid := (a + b) * 0.5 + sag.rotated(-global_rotation)
	var col := Color(0.42, 0.34, 0.24, 0.9)
	var prev := a
	for i in range(1, 13):
		var t := float(i) / 12.0
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		draw_line(prev, p, col, 3.0)
		prev = p
	draw_line(prev, b, col, 3.0)


# ------------------------------------------------------------------- the lens
# Implemented by anything the glass can enlarge. The lens looks for these two
# methods rather than a base class, so a future object becomes inspectable by
# adding them and nothing else.

func has_detail() -> bool:
	return true


func detail_centre() -> Vector2:
	return global_position


## Drawn INTO the lens, at the lens's scale. This is where the legend finally
## becomes readable, and therefore where the seal check actually happens.
func draw_detail(c: CanvasItem, at: Vector2, radius: float) -> void:
	var wax := impression.wax_color
	# A slight value lift represents the broadened reflection visible across an
	# enlarged wax shoulder. It improves separation without inventing a light.
	var inspection_wax := wax.lightened(0.16)
	var r := radius * 0.86
	var depth := clampf(1.06 - impression.wear * 0.48, 0.48, 1.06)

	# Where the flame actually is, in the glass's own upright frame. Everything
	# cut into this wax — the shoulder, the device, the legend — is lit from that
	# one direction, so tilting the candle across the desk rolls the highlight
	# round the seal and the letters change which edge they catch. A seal lit
	# from a constant up-left is a drawing of a seal.
	var light := (light_position - global_position)
	light = light.normalized() if light.length() > 1.0 else Vector2(-0.65, -0.75)

	WaxShape.draw_magnified_body(c, _unit, at, r, inspection_wax, light)
	var light_angle := light.angle()
	# Rubbed high points catch a broken band of candlelight while the far shoulder
	# holds a resin-dark edge. These belong to the wax, not the glass reflection.
	c.draw_arc(at + light * r * 0.018, r * 0.815,
		light_angle - 0.54, light_angle + 0.38, 18,
		Color(inspection_wax.lightened(0.38), 0.26), 1.55)
	c.draw_arc(at - light * r * 0.012, r * 0.825,
		light_angle + PI - 0.45, light_angle + PI + 0.36, 16,
		Color(inspection_wax.darkened(0.58), 0.38), 1.7)

	# Tiny fixed pits make the enlarged field a cast material. Each depression
	# has the same far-lit/near-dark convention as the device and legend.
	for pit in _detail_pits:
		var p := at + Vector2(pit.x, pit.y) * r
		var pit_radius := maxf(0.65, pit.z * r)
		var relief := maxf(0.55, pit_radius * 0.55)
		c.draw_circle(p + Surface.lip_offset(light, relief), pit_radius,
			Color(inspection_wax.lightened(0.25), 0.24))
		c.draw_circle(p + Surface.trough_offset(light, relief), pit_radius,
			Color(inspection_wax.darkened(0.58), 0.36))
		c.draw_circle(p, pit_radius * 0.62,
			Color(inspection_wax.darkened(0.34), 0.46))

	Heraldry.draw_device_incuse(c, impression.device, at, r * 0.38,
		inspection_wax, depth, light)
	Ink.circular_incuse(c, at, _legend_display(), r * 0.67,
		10 if _legend_display().length() > 25 else 11, inspection_wax, depth,
		-c.rotation, light)

	# Chips and rubbing stay physical under the glass; a caption announcing wear
	# was accurate but made the glass look like a tooltip.
	if impression.wear > 0.04:
		for i in mini(_wear_marks.size(),
				maxi(1, int(impression.wear * 11.0))):
			var mark := _wear_marks[i]
			var p := at + Vector2(mark.x, mark.y) * r
			c.draw_circle(p, mark.z * 0.86,
				Color(inspection_wax.darkened(0.62), 0.72))


## Illegible letters are recorded as a middle dot, so the player can see exactly
## how much is missing and judge whether what survives still agrees with a die.
func _legend_display() -> String:
	return impression.legend

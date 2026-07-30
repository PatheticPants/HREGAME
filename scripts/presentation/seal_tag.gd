class_name SealTag
extends Draggable

## The grantor's seal, applied to the foot of the charter it authenticates.
##
## IT WAS A PENDANT ON A 155-UNIT CORD AND IT IS NOT ANY MORE. This docstring
## used to argue for the cord: real ones hung that way, and a free body can be
## pulled out from under a pile, swung back, and carried along when the charter
## moves. The first of those is true history — chanceries used both, sur double
## queue and sur simple queue — and the last two are properties of it being a
## free BODY, not of it being on a string.
##
## The owner reported it and was right: "the papers that come in have a seal that
## is on a string and it should be on the page itself." Hanging off the bottom
## edge, the wax read as an accessory to the document rather than as the thing
## that makes the document an instrument, and it spent most of its time over bare
## desk where nothing could be compared to it.
##
## So it is applied now: it rests on its own patch of the blank foot the chancery
## leaves for wax, the notary's own impression goes on the other side of that
## foot, and all three of the free-body properties survive because it is still a
## free body — just one with a 26-unit tether instead of a 155-unit one.
##
## The legend is deliberately NOT legible unaided. There is writing around the
## rim and you can see that there is writing, and you need the lens to read it.
##
## The legend is deliberately NOT legible unaided. There is writing around the
## rim and you can see that there is writing, and you need the lens to read it.

## How far the seal may be pulled off its patch of parchment before the wax
## drags it back. It was 155 — most of a charter's height — which is a pendant on
## a cord. An applied seal is fixed to the sheet, so this is now just enough
## slack to lift it clear of the writing underneath it and no more.
##
## Not zero, and not parented. It stays a free body because the three things
## that makes possible are all worth having: you can pull it out from under a
## pile without dragging the whole charter, it travels with the charter when you
## move that instead, and it can be picked up and put under the glass on its own.
const TETHER := 26.0
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
	# APPLIED, NOT PENDANT. It starts exactly on its patch of the parchment's
	# blank foot rather than draped 110 units down and to the left of the sheet's
	# bottom edge. A small rotation only, so it reads as a struck disc pressed on
	# by a hand rather than as a decal.
	var start: Vector2 = parent_space.to_local(owner_charter.cord_world())
	setup(start, deg_to_rad(randf_range(-6.0, 6.0)), desk_bounds)


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


## THE TAIL OF THE TAG, not a cord any more.
##
## This drew a bowing plaited cord from the sheet's bottom edge to the top of the
## wax — the "string" the owner reported. An applied seal has no cord: it is wax
## pressed onto the skin, usually over a slit tongue of the parchment itself.
##
## So it is now a short stub of that tongue showing at the wax's edge, drawn only
## when the seal has been lifted off its patch, and fading out as it comes back
## down. When the seal is where it belongs there is nothing to draw at all,
## because the wax is sitting on the page.
func _draw_cord() -> void:
	if charter == null or not is_instance_valid(charter):
		return
	var a := to_local(charter.cord_world())
	var lifted := clampf(a.length() / TETHER, 0.0, 1.0)
	if lifted < 0.25:
		return
	var b := a.normalized() * RADIUS * 0.82
	var col := Color(0.74, 0.68, 0.52, 0.55 * lifted)
	# The parchment tongue: pale, flat, and straight, because a slit tongue does
	# not bow the way a silk cord does.
	draw_line(a, b, col, 5.0)
	draw_line(a, b, Color(0.40, 0.34, 0.24, 0.42 * lifted), 1.6)


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

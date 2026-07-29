class_name WaxSpoon
extends Draggable

## A brass melting spoon charged with one vermilion sealing-wax cake.
##
## The candle is only heat. The red material is visible here before the player
## does anything: beeswax and pine resin already worked with vermilion pigment
## into a hard tablet. Hold the bowl over the flame and that tablet first sweats,
## then slumps, then becomes a glossy reservoir that can be carried and poured.
##
## Its animation and its rules share the same values. `melt` is not cosmetic
## progress painted over a timer; it decides whether the wax will leave the lip.
## `temperature` falls on the walk to the charter, so wax that has skinned over
## must briefly return to the flame.

const BOWL_CENTER := Vector2(54.0, 0.0)
const LIP_FROM_BOWL := Vector2(28.0, 5.0)
const WAX_COLOR := Color(0.61, 0.075, 0.105)

## Driven by PressController.
var melt := 0.0
var temperature := 0.0
var tilt := 0.0
var wax_remaining := 1.0
var heating := false

var _phase := 0.0
var _flow_amount := 0.0


func _ready() -> void:
	super._ready()
	hit_size = Vector2(208.0, 100.0)
	pickup_sound = &"spoon_clink"
	drop_sound = &"spoon_clink"
	slide_sound = &""
	# Only the bowl has any real height; the handle is a flat strip of brass, so
	# the occluder is much smaller than the (deliberately generous) hit box.
	occludes_light = true
	occluder_round = true
	occluder_inset = 0.38
	# Long handle, weighted bowl: it leads with the bowl and trails the grip.
	weight = 0.85
	z_index = 0


## The bowl is sixty units from the node origin. A hit-box-centred ellipse put
## its long cast shadow under empty handle space and left the actual bowl lit.
func light_occluder_polygon() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 14:
		var a := float(i) / 14.0 * TAU
		points.append(BOWL_CENTER + Vector2(cos(a) * 26.0, sin(a) * 22.0))
	return points


func _process(delta: float) -> void:
	super._process(delta)
	_phase += delta
	var feel := Lore.wax_feel()
	var flow_target := 1.0 if tilt > 0.48 and is_pourable(feel) else 0.0
	var flow_time := 0.10 if flow_target > _flow_amount else 0.19
	_flow_amount = move_toward(_flow_amount, flow_target,
		delta / flow_time)
	z_index = 4 if is_held or tilt > 0.01 else 0
	queue_redraw()


func reset_wax() -> void:
	melt = 0.0
	temperature = 0.0
	tilt = 0.0
	wax_remaining = 1.0
	heating = false
	_flow_amount = 0.0
	queue_redraw()


func add_heat(delta: float, feel: WaxFeel) -> bool:
	var was_ready := is_molten(feel)
	heating = true
	temperature = minf(1.0, temperature + delta / maxf(0.01, feel.heat_time))
	if temperature > feel.soften_temperature:
		var heat_strength := inverse_lerp(feel.soften_temperature, 1.0, temperature)
		melt = minf(1.0, melt + delta / maxf(0.01, feel.melt_time) * heat_strength)
	queue_redraw()
	return not was_ready and is_molten(feel)


func lose_heat(delta: float, feel: WaxFeel) -> void:
	heating = false
	temperature = maxf(0.0,
		temperature - delta / maxf(0.01, feel.carry_cool_time))
	queue_redraw()


func is_molten(feel: WaxFeel) -> bool:
	return melt >= feel.melt_ready


func is_pourable(feel: WaxFeel) -> bool:
	return is_molten(feel) \
		and temperature >= feel.pour_temperature \
		and wax_remaining > 0.001


func take_wax(amount: float) -> bool:
	if wax_remaining <= 0.001:
		return false
	wax_remaining = maxf(0.0, wax_remaining - amount)
	queue_redraw()
	return true


## Ease-in on the read, not on the timer. A spoon tips reluctantly through the
## first few degrees and then gravity takes it — a constant 48°/0.55s rotation
## was the most mechanical-looking motion left on the desk.
func tilt_angle(feel: WaxFeel) -> float:
	return deg_to_rad(feel.spoon_tilt_deg) * ease(clampf(tilt, 0.0, 1.0), 1.6)


func bowl_local(feel: WaxFeel = null) -> Vector2:
	return BOWL_CENTER


func bowl_world(feel: WaxFeel = null) -> Vector2:
	return to_global(bowl_local(feel))


func lip_local(feel: WaxFeel = null) -> Vector2:
	var angle := tilt_angle(feel if feel != null else Lore.wax_feel())
	return BOWL_CENTER + LIP_FROM_BOWL.rotated(angle)


func lip_world(feel: WaxFeel = null) -> Vector2:
	return to_global(lip_local(feel))


func _draw() -> void:
	var feel := Lore.wax_feel()
	var angle := tilt_angle(feel)

	# A spoon is a bowl on a stick, and it was throwing the shadow of a brick.
	# Two shadows, drawn from the same light: a round one under the bowl and a
	# thin one under the shaft. The rectangular version read as a grey slab lying
	# across the parchment in every close capture of the press.
	# Registered to what _draw_brass actually puts on screen: the bowl is an
	# ellipse about BOWL_CENTER with radii near (38,30), and the handle runs back
	# from there to about x=-84 in object space.
	draw_soft_shadow(Rect2(BOWL_CENTER.x - 36.0, -30.0, 72.0, 60.0), 1.0)
	draw_soft_shadow(Rect2(-84.0, -6.0, 116.0, 12.0))
	# Rotate about the bowl, which the player holds over the work. The handle
	# rises into the hand while the pouring lip stays spatially stable.
	# The brass is drawn inside a frame rotated about the bowl, so the direction
	# to the flame has to be rotated into that frame as well or the highlight
	# would spin with the handle instead of staying with the candle. WaxPool does
	# the same thing to its struck device for the same reason.
	draw_set_transform(BOWL_CENTER, angle, Vector2.ONE)
	_draw_brass(brass_light_direction(),
		Surface.lit(light_level, light_strength))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Metal rolls; liquid stays level. The solid tablet follows the bowl at first,
	# then progressively decouples from it as it slumps. At full melt it also
	# gathers at the low lip instead of remaining glued to the bowl's centre.
	var fluid := smoothstep(0.24, 0.86, melt)
	var wax_angle := lerpf(angle, angle * 0.055, fluid)
	var low_side := LIP_FROM_BOWL.rotated(angle).normalized()
	var wax_shift := low_side * tilt * fluid * 6.5
	draw_set_transform(BOWL_CENTER + wax_shift, wax_angle, Vector2.ONE)
	_draw_wax(feel)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _flow_amount > 0.015:
		_draw_pour_neck(feel)

	if heating and temperature > 0.18:
		_draw_heat_shimmer(feel)


## Unit direction to the flame, rotated into the frame the brass is drawn in.
##
## The bowl's artwork is drawn inside draw_set_transform(BOWL_CENTER, angle),
## so a direction computed in the spoon's object space is one rotation short —
## and the highlight would follow the HANDLE as it tips rather than staying with
## the candle, which is the same trap WaxPool handles when it rotates the flame
## direction into the struck die's frame.
##
## Named so the suite can assert that the highlight actually travels, rather
## than re-deriving the arithmetic and asserting against its own copy of it.
func brass_light_direction() -> Vector2:
	return Surface.toward(self, light_position).rotated(-tilt_angle(Lore.wax_feel()))


## THE ONE METAL OBJECT THE PLAYER HOLDS DIRECTLY IN THE FLAME.
##
## It read none of the three lighting values. Three hardcoded browns, and a rim
## highlight pinned to a fixed arc from PI*1.04 to PI*1.82 — an assumption that
## the light comes from the upper left, in a game whose entire premise is that
## the light is somewhere you carried it. So the object held ABOVE the candle to
## melt wax was lit identically whether the candle was under it or at the far end
## of the desk, and shot_44 shows it plainly: a room deep in shadow with the
## spoon still at full brightness in the middle of it.
##
## docs/GRAPHICS.md's material table asks metal for "a MOVING specular that
## tracks the flame" and for three metals far enough apart to tell at a glance in
## a dark room. This is the first object migrated onto Surface, and it is a good
## first one precisely because it is held in the light rather than lying in it.
func _draw_brass(toward: Vector2, lit: float) -> void:
	# Brass near a flame goes orange-hot; away from it, a dull tarnished olive.
	var brass_dark := Surface.tint_for(Color(0.25, 0.18, 0.075), lit,
		ambient_daylight, 0.20, 0.34)
	var brass := Surface.tint_for(Color(0.52, 0.39, 0.14), lit,
		ambient_daylight, 0.28, 0.36)
	var brass_light := Surface.tint_for(Color(0.78, 0.62, 0.25), lit,
		ambient_daylight, 0.36, 0.30)

	# Handle. Three strokes create a rounded, tarnished strip with a bright edge
	# — and the bright edge now slides from one side of the shaft to the other as
	# the candle passes it, which is the cheapest possible cue that the thing is
	# round rather than a painted strip.
	var edge := clampf(toward.y * 3.0, -2.4, 2.4)
	draw_line(Vector2(-138, 2), Vector2(-24, 2), brass_dark, 12.0, true)
	draw_line(Vector2(-138, 0), Vector2(-22, 0), brass, 8.0, true)
	draw_line(Vector2(-136, edge), Vector2(-24, edge), brass_light, 2.0, true)
	draw_circle(Vector2(-138, 0), 8.0, brass_dark)
	draw_circle(Vector2(-138, -1), 5.0, brass)
	draw_circle(Vector2(-138, -2), 1.8, Color(0.08, 0.06, 0.03))

	# Broad oval bowl, seen almost from above. The dark inner oval is the metal
	# curving away from the light, not an empty hole.
	var rim := _ellipse(Vector2.ZERO, Vector2(38, 30), 28)
	var inner := _ellipse(Vector2(0, 2), Vector2(31, 22), 28)
	draw_colored_polygon(rim, brass_dark)
	draw_colored_polygon(_ellipse(Vector2(-1, -2),
		Vector2(35, 26), 28), brass)
	draw_colored_polygon(inner, Color(0.34, 0.235, 0.085))

	# The lit arc of the rim, centred on whichever side the flame is actually on.
	# Same 140-degree span the fixed version used; it now travels all the way
	# round the bowl as the candle is carried past.
	var face := toward.angle()
	draw_arc(toward * 3.6, 29.0, face - PI * 0.39, face + PI * 0.39,
		20, brass_light, 2.8)

	# And a hot spot on the rim itself, which is the term that says "polished
	# metal" rather than "brown ellipse". It is only there while the flame is.
	Surface.specular(self, toward * 30.0, toward, lit, 0.0, 2.2, 2.6, 0.06, 0.62)


## The liquid in the bowl.
##
## MOLTEN IS DARKER THAN SET, here as in the pool and as in the candle. Heat used
## to LIGHTEN this by 12%, and the solid cake was then drawn 25% darker than the
## liquid it melts into — so the tablet went brighter as it dissolved, which is
## the reverse of what happens in a spoon and the reverse of what the candle
## eighteen inches away was already doing correctly. Measured before the change:
## the molten reservoir read at luminance 0.241 against the cake's 0.181 cold,
## and 0.332 against 0.249 hot. Both the wrong way round, at every temperature.
##
## Named rather than inline so the suite can assert on the colour that is
## actually drawn rather than on a second copy of the arithmetic.
## It also takes the room's light, like the brass around it. Lighting the metal
## and not the material sitting in it left a dim tarnished bowl carrying a
## bright red disc, which reads as a decal on a photograph. Warm gain is kept
## low: wax is not glossy enough to go orange, it just stops being visible.
func molten_colour() -> Color:
	var hot := clampf(temperature, 0.0, 1.0)
	var remaining := clampf(wax_remaining, 0.0, 1.0)
	var base := WAX_COLOR.darkened(hot * 0.16).darkened((1.0 - remaining) * 0.20)
	return Surface.tint_for(base, Surface.lit(light_level, light_strength),
		ambient_daylight, 0.16, 0.34)


## The solid tablet, which is the PALE one: pigmented beeswax and resin, full of
## scattering microcrystal, with a dry chalky bloom on it. Watching it go dark
## and clear is the cue that it is ready to pour.
func cake_colour() -> Color:
	return molten_colour().lightened(0.22)


func _draw_wax(feel: WaxFeel) -> void:
	var centre := Vector2(0, 2)
	var remaining := clampf(wax_remaining, 0.0, 1.0)
	if remaining <= 0.001:
		# A dark red skin remains in the spoon after the last useful drop.
		draw_colored_polygon(_ellipse(centre, Vector2(25, 15), 24),
			Color(WAX_COLOR.darkened(0.48), 0.72))
		return

	var hot := clampf(temperature, 0.0, 1.0)
	var col := molten_colour()

	if melt < 0.24:
		# The pre-pigmented tablet is deliberately unmistakable: faceted sides,
		# pale resin flecks, and a dry rather than liquid highlight.
		var soften := melt / 0.24
		var r := lerpf(19.0, 21.5, soften) * sqrt(remaining)
		var cake := PackedVector2Array()
		for i in 8:
			var a := float(i) / 8.0 * TAU + PI / 8.0
			cake.append(centre + Vector2(cos(a) * r, sin(a) * r * 0.68))
		draw_colored_polygon(cake, cake_colour())
		draw_polyline(cake, col.lightened(0.34), 2.0, true)
		draw_line(centre + Vector2(-9, -3), centre + Vector2(7, -6),
			Color(0.90, 0.47, 0.31, 0.58), 2.0)
		draw_circle(centre + Vector2(10, 5), 1.7,
			Color(0.88, 0.67, 0.40, 0.70))
		return

	# As the cake melts it occupies more of the bowl and loses its facets.
	var fluid := smoothstep(0.24, 1.0, melt)
	var rx := lerpf(22.0, 29.0, fluid) * sqrt(remaining)
	var ry := lerpf(15.0, 19.0, fluid) * sqrt(remaining)
	draw_colored_polygon(_ellipse(centre + Vector2(1, 2), Vector2(rx, ry), 28),
		col.darkened(0.23))
	draw_colored_polygon(_ellipse(centre, Vector2(rx * 0.94, ry * 0.91), 28), col)
	draw_arc(centre + Vector2(-3, -2), rx * 0.63, PI * 1.08, PI * 1.72,
		16, Color(1.0, 0.63, 0.36, 0.45 + hot * 0.32), 2.2)

	# Bubbles only appear when real heat is reaching a mostly molten reservoir.
	if heating and melt > 0.50:
		for i in 3:
			var pulse := fposmod(_phase * (0.9 + i * 0.19) + i * 0.31, 1.0)
			var at := centre + Vector2(-11 + i * 10, 5 - i * 4)
			draw_arc(at, 1.5 + pulse * 2.4, 0.0, TAU, 12,
				Color(1.0, 0.55, 0.28, (1.0 - pulse) * 0.65), 1.2)


## Surface tension draws a neck out of the reservoir between discrete falling
## beads. Without it the drops appeared from empty air a few pixels off the lip.
func _draw_pour_neck(feel: WaxFeel) -> void:
	var lip := lip_local(feel)
	var outward := (lip - BOWL_CENTER).normalized()
	var pulse := 0.5 + 0.5 * sin(_phase * TAU / maxf(0.06, feel.drip_interval))
	var length := lerpf(7.0, 25.0, tilt * _flow_amount) + pulse * 4.5
	var side := Vector2(-outward.y, outward.x)
	var tip_width := lerpf(4.4, 1.35, pulse)
	var root_width := 5.3 * clampf(wax_remaining * 1.5, 0.35, 1.0) \
		* smoothstep(0.0, 0.35, _flow_amount)
	var curl := sin(_phase * 3.7) * 1.2
	var centres := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 7:
		var f := float(i) / 6.0
		# Surface tension makes a catenary-like neck: it bows, narrows through the
		# middle, then swells again into the bead. A five-point straight strip
		# enlarged into two red sticks with a circle on the end.
		var centre := lip + outward * length * f \
			+ side * (sin(f * PI) * curl + f * f * 1.1)
		var w := lerpf(root_width, tip_width, ease(f, 0.72))
		w *= 1.0 - sin(f * PI) * 0.18
		centres.append(centre)
		left.append(centre - side * w)
		right.append(centre + side * w)
	var strip := PackedVector2Array(left)
	for i in range(right.size() - 1, -1, -1):
		strip.append(right[i])
	var col := molten_colour()
	# The reservoir stretches over the lip before it becomes a free strand.
	draw_line(BOWL_CENTER + outward * 18.0, lip + outward * 2.0,
		col.darkened(0.08), root_width * 1.35, true)
	draw_colored_polygon(strip, col.darkened(0.16))
	var highlight := PackedVector2Array()
	for i in centres.size():
		var f := float(i) / float(centres.size() - 1)
		highlight.append(centres[i] - side * lerpf(1.35, 0.35, f))
	draw_polyline(highlight, Color(1.0, 0.55, 0.31, 0.34 + temperature * 0.24),
		1.6, true)

	var tip := centres[centres.size() - 1] + outward * (2.2 + pulse * 1.5)
	draw_set_transform(tip, outward.angle(), Vector2.ONE)
	draw_colored_polygon(_ellipse(Vector2(0.8, 0.7),
		Vector2(3.9 + pulse * 1.0, 2.5 + pulse * 0.55), 18),
		Color(0, 0, 0, 0.22))
	draw_colored_polygon(_ellipse(Vector2.ZERO,
		Vector2(3.7 + pulse * 1.0, 2.4 + pulse * 0.55), 18),
		col.lightened(0.05))
	draw_circle(Vector2(-1.4, -0.7), 1.0,
		Color(1.0, 0.78, 0.56, 0.42 + temperature * 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_heat_shimmer(feel: WaxFeel) -> void:
	var bowl := bowl_local(feel)
	for i in 3:
		var wave := sin(_phase * (2.2 + i * 0.31) + i * 1.7)
		var start := bowl + Vector2(-12 + i * 12, -28)
		var pts := PackedVector2Array([
			start,
			start + Vector2(wave * 2.5, -9),
			start + Vector2(-wave * 3.0, -18),
			start + Vector2(wave * 2.0, -27),
		])
		draw_polyline(pts, Color(1.0, 0.71, 0.38,
			0.10 + temperature * 0.16), 1.3)


func _ellipse(centre: Vector2, radii: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var a := float(i) / float(count) * TAU
		points.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points

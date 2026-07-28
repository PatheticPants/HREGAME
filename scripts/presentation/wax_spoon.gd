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


func _process(delta: float) -> void:
	super._process(delta)
	_phase += delta
	z_index = 4 if is_held or tilt > 0.01 else 0
	queue_redraw()


func reset_wax() -> void:
	melt = 0.0
	temperature = 0.0
	tilt = 0.0
	wax_remaining = 1.0
	heating = false
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

	draw_soft_shadow(Rect2(-94.0, -34.0, 190.0, 68.0))
	# Rotate about the bowl, which the player holds over the work. The handle
	# rises into the hand while the pouring lip stays spatially stable.
	draw_set_transform(BOWL_CENTER, angle, Vector2.ONE)
	_draw_brass()
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

	if tilt > 0.48 and is_pourable(feel):
		_draw_pour_neck(feel)

	if heating and temperature > 0.18:
		_draw_heat_shimmer(feel)


func _draw_brass() -> void:
	var brass_dark := Color(0.25, 0.18, 0.075)
	var brass := Color(0.52, 0.39, 0.14)
	var brass_light := Color(0.78, 0.62, 0.25)

	# Handle. Three strokes create a rounded, tarnished strip with a bright edge.
	draw_line(Vector2(-138, 2), Vector2(-24, 2), brass_dark, 12.0, true)
	draw_line(Vector2(-138, 0), Vector2(-22, 0), brass, 8.0, true)
	draw_line(Vector2(-136, -2), Vector2(-24, -2), brass_light, 2.0, true)
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
	draw_arc(Vector2(-2, -3), 29.0, PI * 1.04, PI * 1.82,
		20, brass_light, 2.8)


func _draw_wax(feel: WaxFeel) -> void:
	var centre := Vector2(0, 2)
	var remaining := clampf(wax_remaining, 0.0, 1.0)
	if remaining <= 0.001:
		# A dark red skin remains in the spoon after the last useful drop.
		draw_colored_polygon(_ellipse(centre, Vector2(25, 15), 24),
			Color(WAX_COLOR.darkened(0.48), 0.72))
		return

	var hot := clampf(temperature, 0.0, 1.0)
	var col := WAX_COLOR.lightened(hot * 0.12)
	col = col.darkened((1.0 - remaining) * 0.20)

	if melt < 0.24:
		# The pre-pigmented tablet is deliberately unmistakable: faceted sides,
		# pale resin flecks, and a dry rather than liquid highlight.
		var soften := melt / 0.24
		var r := lerpf(19.0, 21.5, soften) * sqrt(remaining)
		var cake := PackedVector2Array()
		for i in 8:
			var a := float(i) / 8.0 * TAU + PI / 8.0
			cake.append(centre + Vector2(cos(a) * r, sin(a) * r * 0.68))
		draw_colored_polygon(cake, col.darkened(0.25))
		draw_polyline(cake, col.lightened(0.16), 2.0, true)
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
	var length := lerpf(5.0, 14.0, tilt) + pulse * 3.0
	var side := Vector2(-outward.y, outward.x)
	var width := lerpf(3.8, 1.2, pulse)
	var root_width := 4.2 * clampf(wax_remaining * 1.5, 0.35, 1.0)
	var tip := lip + outward * length
	var strip := PackedVector2Array([
		lip - side * root_width,
		lip + side * root_width,
		tip + side * width,
		tip + outward * 3.4,
		tip - side * width,
	])
	draw_colored_polygon(strip, WAX_COLOR.darkened(0.20))
	draw_line(lip - side * 1.2, tip - side * 0.4,
		Color(1.0, 0.49, 0.28, 0.42), 1.5)
	draw_circle(tip + outward * 2.6, 2.6 + pulse * 1.5,
		WAX_COLOR.lightened(0.09))


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

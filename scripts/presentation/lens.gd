class_name Lens
extends Draggable

## A glass in a brass ring, on a handle.
##
## The seal's legend is not legible on the desk. You can see that there is
## lettering around the rim and you cannot read a word of it, and the only way to
## read it is to put the glass over the wax. That makes the lens a verb rather
## than decoration, and it makes the seal check a physical act — find the seal in
## the pile, get the glass onto it, keep it there.
##
## Anything can be inspectable: the lens looks for has_detail() and draw_detail()
## by name rather than by base class, so a future document becomes magnifiable by
## adding two methods and nothing else.

const RADIUS := 116.0
const APERTURE_RADIUS := 86.0
const HOME_POSITION := Vector2(665.0, 115.0)
const HOME_ANGLE := -14.0
const CHASSIS := preload("res://art/props/magnifying_glass_chassis.png")
const REFRACTION_SHADER := preload("res://shaders/lens_refraction.gdshader")

# The generated chassis is deliberately kept as one source plate, but the ring
# and handle are drawn as separate regions. That lets the aperture stay broad
# enough to read while the handle is shortened to the desk's established scale.
const RING_SOURCE := Rect2(331, 50, 587, 710)
const HANDLE_SOURCE := Rect2(500, 650, 250, 543)
const RING_TARGET := Rect2(-RADIUS, -RADIUS, RADIUS * 2.0, RADIUS * 2.42)
const HANDLE_TARGET := Rect2(-36.0, 98.0, 72.0, 150.0)

signal focus_confirmed(subject: Node2D)

## Everything the glass might be held over. Set by the desk when it builds.
var subjects: Array[Node2D] = []

var _focus: Node2D = null
var _focus_amount := 0.0
var _focus_dwell := 0.0
var _reported: Dictionary = {}
var _optical_lag := Vector2.ZERO
var _optics_copy: BackBufferCopy
var _optics_quad: Polygon2D
var _optics_material: ShaderMaterial


func _ready() -> void:
	super._ready()
	hit_size = Vector2(RADIUS * 2.1, RADIUS * 2.9)
	pickup_sound = &"ring_pickup"
	drop_sound = &"stamp_set"
	slide_sound = &""
	# The aperture must transmit the candle. A solid LightOccluder2D made the
	# glass opaque; segmenting the ring then projected eight long bars across
	# nearby papers. Its short, candle-relative annular contact shadow is drawn
	# directly instead, which is the physically relevant shadow at desk height.
	occludes_light = false
	weight = 1.25
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The one object that is always on top. You hold a glass OVER things; having
	# to dig the lens out from under a charter would be irritating rather than
	# interesting, which is the line between a mechanic and a nuisance.
	z_index = 2
	_build_optics()


func _process(delta: float) -> void:
	super._process(delta)
	var found := _find_subject()
	if found != _focus:
		_focus = found
		_focus_amount = 0.0
		_focus_dwell = 0.0
	# Fade the enlarged image in rather than snapping, so sweeping the glass
	# across a crowded desk does not strobe. A moving glass resolves more slowly
	# than one set down: the high-detail face is something the player focuses,
	# not a decal that turns on at the edge of a hit radius.
	var motion := solver.speed()
	var focus_rate := 6.2 if motion < 90.0 else 2.8
	_focus_amount = move_toward(_focus_amount, 1.0 if _focus != null else 0.0,
		delta * focus_rate)
	var lag_target := -solver.velocity.rotated(-global_rotation) * 0.014
	if not is_held:
		lag_target *= 0.28
	lag_target = lag_target.limit_length(6.0)
	_optical_lag = _optical_lag.lerp(lag_target,
		1.0 - pow(0.0012, delta))
	# Dwell used to accumulate only while the glass was HELD — but the enlarged
	# image draws whenever a subject is under the lens, held or not, so laying the
	# glass down on a seal looks exactly like inspecting it and reads perfectly.
	# A player who set the glass down to look at it comfortably had done the
	# intended thing and never satisfied the check: in the practice leaf, where
	# the only exit is the inspect_impression beat, that ended the game silently
	# and with everything on screen looking correct. The model was right and only
	# the grip was wrong, which is the worst way for a game to say no.
	#
	# `_reported` still dedupes per subject instance, so a glass left lying on a
	# seal reports exactly once and cannot spam the petitioner's reactions.
	var readable := _focus != null and _focus_amount > 0.78 and motion < 125.0
	if readable:
		_focus_dwell += delta
	else:
		_focus_dwell = 0.0
	if _focus != null and _focus_dwell >= 0.55:
		var subject_id := _focus.get_instance_id()
		if not _reported.has(subject_id):
			_reported[subject_id] = true
			focus_confirmed.emit(_focus)

	if _optics_material != null:
		var viewport_size := get_viewport_rect().size
		var centre_px := get_global_transform_with_canvas().origin
		_optics_material.set_shader_parameter("lens_center_screen",
			centre_px / viewport_size)
		_optics_material.set_shader_parameter("magnification",
			lerpf(0.048, 0.070, _focus_amount))
		_optics_material.set_shader_parameter("active", 1.0)


## A petitioner reacts to an inspection once, not every time the glass wobbles
## off the rim and back. Instance IDs make that rule work for any future
## inspectable object without teaching the lens what a seal is.
func begin_case() -> void:
	_reported.clear()
	_focus = null
	_focus_amount = 0.0
	_focus_dwell = 0.0
	_optical_lag = Vector2.ZERO


func _find_subject() -> Node2D:
	var best: Node2D = null
	var best_d := RADIUS * 0.85
	for s in subjects:
		if s == null or not is_instance_valid(s) or s == self:
			continue
		if not s.has_method("has_detail") or not s.call("has_detail"):
			continue
		var centre: Vector2 = s.call("detail_centre") if s.has_method("detail_centre") \
			else s.global_position
		var d := centre.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


## The old rectangular hit box made empty corners around the circular bezel win
## over papers the player could plainly see. The authored silhouette is a circle
## plus a handle, and the hand should agree with the pixels.
func contains_point(world: Vector2) -> bool:
	if not visible or not draggable_enabled:
		return false
	var local := to_local(world)
	if local.length() <= RADIUS + 7.0:
		return true
	return Rect2(-31.0, RADIUS * 0.70, 62.0, 145.0).has_point(local)


## The shared hover affordance outlines hit_size. That is right for a sheet and
## wrong for a circle-plus-handle: at inspection zoom it exposed the invisible
## rectangular grab area around an otherwise convincing prop.
func _draw_hover() -> void:
	if _hover_amount <= 0.01:
		return
	var a := _hover_amount * 0.42 * clampf(0.45 + light_level, 0.45, 1.15)
	for i in 4:
		var grow := 2.0 + float(i) * 3.5
		var fade := a * (1.0 - float(i) / 4.0) * 0.7
		var col := Color(1.0, 0.84, 0.58, fade)
		_hover_node.draw_arc(Vector2.ZERO, RADIUS + grow,
			0.0, TAU, 42, col, 2.6)
		_hover_node.draw_line(Vector2(0, RADIUS + grow * 0.25),
			Vector2(0, RADIUS + 142.0 + grow), col, 20.0 + grow, true)


func _build_optics() -> void:
	_optics_copy = BackBufferCopy.new()
	_optics_copy.name = "lens_backbuffer"
	_optics_copy.copy_mode = BackBufferCopy.COPY_MODE_RECT
	_optics_copy.rect = Rect2(-Vector2.ONE * (APERTURE_RADIUS + 5.0),
		Vector2.ONE * (APERTURE_RADIUS + 5.0) * 2.0)
	_optics_copy.z_index = -1
	add_child(_optics_copy)

	_optics_quad = Polygon2D.new()
	_optics_quad.name = "optical_aperture"
	var r := APERTURE_RADIUS
	_optics_quad.polygon = PackedVector2Array([
		Vector2(-r, -r), Vector2(r, -r),
		Vector2(r, r), Vector2(-r, r),
	])
	_optics_quad.uv = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
	])
	_optics_quad.color = Color.WHITE
	_optics_quad.z_index = -1
	_optics_quad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_optics_material = ShaderMaterial.new()
	_optics_material.shader = REFRACTION_SHADER
	_optics_quad.material = _optics_material
	add_child(_optics_quad)


func _draw() -> void:
	_draw_lens_shadow()
	var lit := Surface.lit(light_level, light_strength)
	var toward := Surface.toward(self, light_position)
	_draw_authored_handle(toward, lit)

	# The glass itself: dark edge refraction, a warm body, and an almost-clear
	# centre. A flat translucent disc looked like a UI panel placed on the desk.
	# Clear glass transmits almost all of the scene. The older 24% brown disc
	# made inspection darker than looking with the naked eye and buried exactly
	# the seal detail the tool exists to reveal.
	draw_circle(Vector2.ZERO, APERTURE_RADIUS * 1.035,
		Color(0.075, 0.055, 0.035, 0.12))
	draw_circle(Vector2.ZERO, APERTURE_RADIUS,
		Color(0.86, 0.82, 0.72, 0.070 + lit * 0.025))
	draw_circle(Vector2.ZERO, APERTURE_RADIUS * 0.94,
		Color(0.98, 0.97, 0.91, 0.018 + lit * 0.012))
	_draw_caustic(toward, lit)

	if _focus != null and _focus_amount > 0.02 and _focus.has_method("draw_detail"):
		# Counter-rotate so the enlarged image stays upright no matter how the
		# glass is lying. A rotating page of text is unreadable and nobody has
		# ever wanted one.
		# Focus settles over the last few percent rather than growing from a dot:
		# the image belongs to the glass from first contact and gently resolves.
		var resolve_scale := lerpf(0.955, 1.0, _focus_amount)
		var focus_at := Vector2.ZERO
		if _focus.has_method("detail_centre"):
			var subject_centre: Vector2 = _focus.call("detail_centre")
			# A real lens does not teleport an off-axis detail to its centre.
			# Retaining a little of the subject's offset supplies optical parallax
			# while the magnification still keeps the important mark readable.
			focus_at = to_local(subject_centre) * 0.16
			focus_at = focus_at.limit_length(APERTURE_RADIUS * 0.12)
		draw_circle(focus_at + toward * APERTURE_RADIUS * 0.08,
			APERTURE_RADIUS * 0.72,
			Color(1.0, 0.76, 0.48, 0.018 + lit * 0.035))
		# Quantised lag: the image has a fraction of optical inertia while the
		# glass moves, then returns exactly to the evidence when set down.
		var lag := Vector2(round(_optical_lag.x), round(_optical_lag.y))
		draw_set_transform(focus_at + lag, -rotation, Vector2.ONE * resolve_scale)
		_focus.call("draw_detail", self, Vector2.ZERO, APERTURE_RADIUS * 0.94)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_glass_reflections(toward, lit)
	_draw_authored_bezel(toward, lit)


func _chassis_tint(lit: float) -> Color:
	if ambient_daylight:
		return Color(0.78, 0.84, 0.95)
	return Color(0.56, 0.53, 0.55).lerp(
		Color(1.0, 0.91, 0.73), 0.42 + lit * 0.45)


func _draw_authored_bezel(toward: Vector2, lit: float) -> void:
	draw_texture_rect_region(CHASSIS, RING_TARGET, RING_SOURCE,
		_chassis_tint(lit))
	var light_angle := toward.angle()
	# The authored plate supplies form and wear; these moving fragments let the
	# one carried flame remain the authority over its brass.
	draw_arc(Vector2.ZERO, RADIUS * 0.965,
		light_angle - 0.82, light_angle + 0.52, 24,
		Color(1.0, 0.88, 0.56, 0.10 + lit * 0.46), 2.4)
	draw_arc(Vector2.ZERO, RADIUS * 0.985,
		light_angle + PI - 0.58, light_angle + PI + 0.48, 20,
		Color(0.08, 0.045, 0.025, 0.38), 2.8)
	draw_arc(Vector2.ZERO, APERTURE_RADIUS * 1.03,
		light_angle - 0.56, light_angle + 0.34, 18,
		Color(1.0, 0.91, 0.68, 0.12 + lit * 0.28), 1.5)


func _draw_glass_reflections(toward: Vector2, lit: float) -> void:
	# Reflections cross the enlarged object, which is what makes them read as
	# belonging to a sheet of glass rather than to the wax below. They move with
	# the carried flame instead of being painted forever into the upper left.
	var a := toward.angle()
	var offset := toward * APERTURE_RADIUS * 0.045
	draw_arc(offset, APERTURE_RADIUS * 0.79, a - 0.56, a + 0.17, 20,
		Color(1, 1, 1, 0.12 + lit * 0.16), 6.0)
	draw_arc(offset * 1.5, APERTURE_RADIUS * 0.61, a - 0.43, a - 0.04, 14,
		Color(1, 1, 1, 0.07 + lit * 0.11), 3.2)
	draw_arc(-offset, APERTURE_RADIUS * 0.86, a + PI - 0.39, a + PI + 0.19, 16,
		Color(0.34, 0.22, 0.09, 0.060), 4.4)
	# Two tiny seed bubbles in old crown glass. They catch the same light and
	# keep the otherwise perfect disc from reading as a digital mask.
	for p: Vector2 in [Vector2(-0.31, 0.18), Vector2(0.28, -0.36)]:
		var at: Vector2 = p * APERTURE_RADIUS
		draw_circle(at + toward * 1.2, 2.1, Color(1, 1, 1, 0.08 + lit * 0.08))
		draw_circle(at - toward * 0.8, 1.1, Color(0.16, 0.11, 0.07, 0.12))


func _draw_authored_handle(toward: Vector2, lit: float) -> void:
	draw_texture_rect_region(CHASSIS, HANDLE_TARGET, HANDLE_SOURCE,
		_chassis_tint(lit))
	var x := clampf(toward.x * 4.0, -7.0, 7.0)
	draw_line(Vector2(x, 151.0), Vector2(x * 0.45, 218.0),
		Color(0.77, 0.49, 0.24, 0.08 + lit * 0.24), 1.4)


func _draw_lens_shadow() -> void:
	var off := shadow_offset()
	var a := (0.045 + 0.13 * sqrt(clampf(light_level, 0.0, 1.0))) \
		* clampf(light_strength, 0.65, 1.1)
	# Annular contact shadow: the previous stack of filled circles made the clear
	# aperture cast the same shadow as solid brass.
	for i in range(3, 0, -1):
		var grow := float(i) * 1.8
		draw_arc(off, (RADIUS + APERTURE_RADIUS) * 0.5,
			0.0, TAU, 52, Color(0, 0, 0, a / float(i + 1)),
			RADIUS - APERTURE_RADIUS + grow, true)
		draw_line(Vector2(0, 105) + off, Vector2(0, 235) + off,
			Color(0, 0, 0, a / float(i + 1)), 22.0 + grow, true)


func _draw_caustic(toward: Vector2, lit: float) -> void:
	if lit <= 0.04 or ambient_daylight:
		return
	# The brightest transmitted patch sits opposite the flame. It crosses the
	# paper rather than the wax detail and dies immediately when the glass leaves
	# the useful light.
	var at := -toward * APERTURE_RADIUS * 0.54
	draw_set_transform(at, toward.angle(), Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, APERTURE_RADIUS * 0.25,
		-0.62, 0.74, 14, Color(1.0, 0.77, 0.43, 0.025 + lit * 0.065), 5.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

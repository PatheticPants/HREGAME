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

const RADIUS := 104.0

signal focus_confirmed(subject: Node2D)

## Everything the glass might be held over. Set by the desk when it builds.
var subjects: Array[Node2D] = []

var _focus: Node2D = null
var _focus_amount := 0.0
var _focus_dwell := 0.0
var _reported: Dictionary = {}


func _ready() -> void:
	super._ready()
	hit_size = Vector2(RADIUS * 2.1, RADIUS * 2.9)
	pickup_sound = &"ring_pickup"
	drop_sound = &"stamp_set"
	slide_sound = &""
	# Brass and glass standing proud of the desk: it interrupts the candle, and
	# the shadow is round because the object is.
	occludes_light = true
	occluder_round = true
	occluder_inset = 0.66
	weight = 1.25
	# The one object that is always on top. You hold a glass OVER things; having
	# to dig the lens out from under a charter would be irritating rather than
	# interesting, which is the line between a mechanic and a nuisance.
	z_index = 2


func _process(delta: float) -> void:
	super._process(delta)
	var found := _find_subject()
	if found != _focus:
		_focus = found
		_focus_amount = 0.0
		_focus_dwell = 0.0
	# Fade the enlarged image in rather than snapping, so sweeping the glass
	# across a crowded desk does not strobe.
	_focus_amount = move_toward(_focus_amount, 1.0 if _focus != null else 0.0,
		delta * 6.0)
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
	if _focus != null:
		_focus_dwell += delta
	else:
		_focus_dwell = 0.0
	if _focus != null and _focus_dwell >= 0.55:
		var subject_id := _focus.get_instance_id()
		if not _reported.has(subject_id):
			_reported[subject_id] = true
			focus_confirmed.emit(_focus)


## A petitioner reacts to an inspection once, not every time the glass wobbles
## off the rim and back. Instance IDs make that rule work for any future
## inspectable object without teaching the lens what a seal is.
func begin_case() -> void:
	_reported.clear()
	_focus = null
	_focus_amount = 0.0
	_focus_dwell = 0.0


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


func _draw() -> void:
	draw_soft_shadow(Rect2(-Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0), 1.0)
	var lit := Surface.lit(light_level, light_strength)
	var toward := Surface.toward(self, light_position)
	_draw_handle(toward, lit)

	# The glass itself: dark edge refraction, a warm body, and an almost-clear
	# centre. A flat translucent disc looked like a UI panel placed on the desk.
	# Clear glass transmits almost all of the scene. The older 24% brown disc
	# made inspection darker than looking with the naked eye and buried exactly
	# the seal detail the tool exists to reveal.
	draw_circle(Vector2.ZERO, RADIUS, Color(0.075, 0.055, 0.035, 0.15))
	draw_circle(Vector2.ZERO, RADIUS * 0.965,
		Color(0.86, 0.82, 0.72, 0.070 + lit * 0.025))
	draw_circle(Vector2.ZERO, RADIUS * 0.91,
		Color(0.98, 0.97, 0.91, 0.018 + lit * 0.012))

	if _focus != null and _focus_amount > 0.02 and _focus.has_method("draw_detail"):
		# Counter-rotate so the enlarged image stays upright no matter how the
		# glass is lying. A rotating page of text is unreadable and nobody has
		# ever wanted one.
		# Focus settles over the last few percent rather than growing from a dot:
		# the image belongs to the glass from first contact and gently resolves.
		var resolve_scale := lerpf(0.965, 1.0, _focus_amount)
		var focus_at := Vector2.ZERO
		if _focus.has_method("detail_centre"):
			var subject_centre: Vector2 = _focus.call("detail_centre")
			# A real lens does not teleport an off-axis detail to its centre.
			# Retaining a little of the subject's offset supplies optical parallax
			# while the magnification still keeps the important mark readable.
			focus_at = to_local(subject_centre) * 0.16
			focus_at = focus_at.limit_length(RADIUS * 0.13)
		draw_circle(focus_at + toward * RADIUS * 0.08, RADIUS * 0.73,
			Color(1.0, 0.76, 0.48, 0.018 + lit * 0.035))
		draw_set_transform(focus_at, -rotation, Vector2.ONE * resolve_scale)
		_focus.call("draw_detail", self, Vector2.ZERO, RADIUS * 0.91)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_glass_reflections(toward, lit)
	_draw_bezel(toward, lit)


func _draw_bezel(toward: Vector2, lit: float) -> void:
	var brass := Surface.tint(Color(0.66, 0.52, 0.25), lit, 0.34, 0.22)
	var light_angle := toward.angle()
	draw_arc(Vector2.ZERO, RADIUS * 1.025, 0.0, TAU, 64,
		brass.darkened(0.48), 11.0)
	draw_arc(Vector2.ZERO, RADIUS * 1.008, 0.0, TAU, 64, brass, 6.5)
	draw_arc(Vector2.ZERO, RADIUS * 1.006,
		light_angle - 0.82, light_angle + 0.52, 24,
		Color(0.98, 0.82, 0.46, 0.34 + lit * 0.54), 2.8)
	draw_arc(Vector2.ZERO, RADIUS * 1.035,
		light_angle + PI - 0.58, light_angle + PI + 0.48, 20,
		Color(0.17, 0.10, 0.04, 0.55), 3.2)
	# A rubbed inner lip catches a smaller echo of the outer highlight. The gap
	# between the two is what makes this read as a metal channel holding glass.
	draw_arc(Vector2.ZERO, RADIUS * 0.962,
		light_angle - 0.56, light_angle + 0.34, 18,
		Color(1.0, 0.91, 0.68, 0.12 + lit * 0.28), 1.5)


func _draw_glass_reflections(toward: Vector2, lit: float) -> void:
	# Reflections cross the enlarged object, which is what makes them read as
	# belonging to a sheet of glass rather than to the wax below. They move with
	# the carried flame instead of being painted forever into the upper left.
	var a := toward.angle()
	var offset := toward * RADIUS * 0.045
	draw_arc(offset, RADIUS * 0.79, a - 0.56, a + 0.17, 20,
		Color(1, 1, 1, 0.12 + lit * 0.16), 6.0)
	draw_arc(offset * 1.5, RADIUS * 0.61, a - 0.43, a - 0.04, 14,
		Color(1, 1, 1, 0.07 + lit * 0.11), 3.2)
	draw_arc(-offset, RADIUS * 0.86, a + PI - 0.39, a + PI + 0.19, 16,
		Color(0.34, 0.22, 0.09, 0.060), 4.4)
	# Two tiny seed bubbles in old crown glass. They catch the same light and
	# keep the otherwise perfect disc from reading as a digital mask.
	for p: Vector2 in [Vector2(-0.31, 0.18), Vector2(0.28, -0.36)]:
		var at: Vector2 = p * RADIUS
		draw_circle(at + toward * 1.2, 2.1, Color(1, 1, 1, 0.08 + lit * 0.08))
		draw_circle(at - toward * 0.8, 1.1, Color(0.16, 0.11, 0.07, 0.12))


func _draw_handle(toward: Vector2, lit: float) -> void:
	var wood := Surface.tint(Color(0.29, 0.17, 0.095), lit, 0.28, 0.24)
	draw_line(Vector2(0, RADIUS * 0.92), Vector2(0, RADIUS * 1.85),
		wood.darkened(0.42), 19.0)
	draw_line(Vector2(-1.5, RADIUS * 0.98), Vector2(-1.5, RADIUS * 1.84),
		wood, 13.0)
	var grain_x := clampf(toward.x * 4.0 - 1.5, -5.0, 3.0)
	draw_line(Vector2(grain_x, RADIUS * 1.03),
		Vector2(grain_x, RADIUS * 1.79),
		Color(0.62, 0.40, 0.21, 0.25 + lit * 0.28), 2.2)
	draw_circle(Vector2(0, RADIUS * 1.85), 12.5, wood.darkened(0.36))
	draw_circle(Vector2(-1.5, RADIUS * 1.83), 9.0, wood.lightened(0.10))
	draw_line(Vector2(0, RADIUS * 0.92), Vector2(0, RADIUS * 1.10),
		Color(0.66, 0.52, 0.25), 20.0)

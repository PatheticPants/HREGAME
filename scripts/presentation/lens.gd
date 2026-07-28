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
	if is_held and _focus != null:
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
	_draw_handle()

	# The glass itself: dark edge refraction, a warm body, and an almost-clear
	# centre. A flat translucent disc looked like a UI panel placed on the desk.
	draw_circle(Vector2.ZERO, RADIUS, Color(0.10, 0.075, 0.045, 0.24))
	draw_circle(Vector2.ZERO, RADIUS * 0.965, Color(0.89, 0.84, 0.70, 0.16))
	draw_circle(Vector2.ZERO, RADIUS * 0.91, Color(0.99, 0.97, 0.88, 0.055))

	if _focus != null and _focus_amount > 0.02 and _focus.has_method("draw_detail"):
		# Counter-rotate so the enlarged image stays upright no matter how the
		# glass is lying. A rotating page of text is unreadable and nobody has
		# ever wanted one.
		# Focus settles over the last few percent rather than growing from a dot:
		# the image belongs to the glass from first contact and gently resolves.
		var resolve_scale := lerpf(0.965, 1.0, _focus_amount)
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE * resolve_scale)
		_focus.call("draw_detail", self, Vector2.ZERO, RADIUS * 0.91)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_glass_reflections()
	_draw_bezel()


func _draw_bezel() -> void:
	var brass := Color(0.66, 0.52, 0.25)
	var light_angle := (light_position - global_position).angle() - global_rotation
	draw_arc(Vector2.ZERO, RADIUS * 1.025, 0.0, TAU, 64,
		brass.darkened(0.48), 11.0)
	draw_arc(Vector2.ZERO, RADIUS * 1.008, 0.0, TAU, 64, brass, 6.5)
	draw_arc(Vector2.ZERO, RADIUS * 1.006,
		light_angle - 0.82, light_angle + 0.52, 24,
		Color(0.96, 0.79, 0.42, 0.82), 2.8)
	draw_arc(Vector2.ZERO, RADIUS * 1.035,
		light_angle + PI - 0.58, light_angle + PI + 0.48, 20,
		Color(0.17, 0.10, 0.04, 0.55), 3.2)


func _draw_glass_reflections() -> void:
	# Reflections cross the enlarged object, which is what makes them read as
	# belonging to a sheet of glass rather than to the wax below.
	draw_arc(Vector2(-6, -3), RADIUS * 0.79, PI * 1.07, PI * 1.50, 20,
		Color(1, 1, 1, 0.21), 7.0)
	draw_arc(Vector2(-8, -5), RADIUS * 0.61, PI * 1.13, PI * 1.36, 14,
		Color(1, 1, 1, 0.12), 3.8)
	draw_arc(Vector2(4, 4), RADIUS * 0.86, PI * 0.08, PI * 0.39, 16,
		Color(0.42, 0.27, 0.10, 0.085), 5.0)


func _draw_handle() -> void:
	var wood := Color(0.29, 0.17, 0.095)
	draw_line(Vector2(0, RADIUS * 0.92), Vector2(0, RADIUS * 1.85),
		wood.darkened(0.42), 19.0)
	draw_line(Vector2(-1.5, RADIUS * 0.98), Vector2(-1.5, RADIUS * 1.84),
		wood, 13.0)
	draw_line(Vector2(-4.0, RADIUS * 1.03), Vector2(-4.0, RADIUS * 1.79),
		Color(0.56, 0.35, 0.18, 0.45), 2.2)
	draw_circle(Vector2(0, RADIUS * 1.85), 12.5, wood.darkened(0.36))
	draw_circle(Vector2(-1.5, RADIUS * 1.83), 9.0, wood.lightened(0.10))
	draw_line(Vector2(0, RADIUS * 0.92), Vector2(0, RADIUS * 1.10),
		Color(0.66, 0.52, 0.25), 20.0)

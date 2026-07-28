class_name ViewController
extends Node

## Tilts the player's attention between the work and audience planes.
##
## This is intentionally not a menu state. The Camera2D moves continuously,
## while Desk foreshortens only the top-down plane around its far edge. The room
## and petitioner remain upright, so both endpoints and the path between them
## preserve their own perspective.

const WORK_CAMERA := Vector2(960, 590)
const AUDIENCE_CAMERA := Vector2(960, 220)
const WORK_ZOOM := Vector2.ONE
const AUDIENCE_ZOOM := Vector2(1.05, 1.05)

## Rise of the head, 0 at the work plane and 1 at the audience plane.
var amount := 0.0
var target := 0.0

## Looking up from close work is not a camera sliding on a rail. A head dips a
## fraction before it rises, accelerates, and then arrives and steadies with a
## small settle. These three constants are that motion.
const LIFT_STIFFNESS := 78.0
const LIFT_DAMPING := 13.6
## How far the eye drops before it rises, in view units. Tiny — this is felt
## rather than seen, and above about 0.05 it reads as a bug.
const ANTICIPATION := 0.028

var _velocity := 0.0
var _anticipation := 0.0

@onready var camera: Camera2D = get_node("../camera")
@onready var desk: Desk = get_node("../desk")
var hint: ViewHint


func _ready() -> void:
	camera.enabled = true
	camera.position = WORK_CAMERA
	camera.zoom = WORK_ZOOM

	var overlay := CanvasLayer.new()
	overlay.name = "view_overlay"
	overlay.layer = 20
	add_child(overlay)
	hint = ViewHint.new()
	hint.name = "view_hint"
	overlay.add_child(hint)
	desk.set_view_amount(0.0)
	set_process(true)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			look_up()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			look_down()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		var physical: int = event.physical_keycode
		if key == KEY_UP or key == KEY_W or physical == KEY_W:
			look_up()
			get_viewport().set_input_as_handled()
		elif key == KEY_DOWN or key == KEY_S or physical == KEY_S:
			look_down()
			get_viewport().set_input_as_handled()


func look_up() -> void:
	if target < 0.5:
		# The eye drops a fraction before the head comes up. Costs one line and
		# is the difference between a camera move and a person moving.
		_velocity -= ANTICIPATION * 9.0
		Audio.play(&"view_shift", camera.position)
	target = 1.0
	desk.cancel_hand_for_view()


func look_down() -> void:
	if target > 0.5:
		_velocity += ANTICIPATION * 7.0
		Audio.play(&"view_shift", camera.position, -3.0)
	target = 0.0


func is_audience_view() -> bool:
	return amount > 0.92


func is_work_view() -> bool:
	return amount < 0.08


func _process(delta: float) -> void:
	# A damped spring rather than an exponential filter. The old version was
	# smooth but monotonic — it arrived at the target with exactly zero velocity,
	# which is a camera on a rail. This one is slightly underdamped (zeta ~0.77),
	# so the view overshoots by a percent or two and settles back, the way a head
	# does when it comes up and steadies. It still reverses instantly if the
	# player changes their mind mid-tilt, because the spring simply re-targets.
	var substep := minf(delta, 1.0 / 45.0)
	var remaining := delta
	while remaining > 0.0:
		var h := minf(substep, remaining)
		remaining -= h
		var accel := (target - amount) * LIFT_STIFFNESS - _velocity * LIFT_DAMPING
		_velocity += accel * h
		amount += _velocity * h
	if absf(amount - target) < 0.0006 and absf(_velocity) < 0.01:
		amount = target
		_velocity = 0.0

	# The camera gets the raw value including the overshoot; the desk plane gets
	# it clamped, because foreshortening past the endpoint is a glitch rather
	# than a flourish.
	var settled := clampf(amount, 0.0, 1.0)
	camera.position = WORK_CAMERA.lerp(AUDIENCE_CAMERA, amount)
	camera.zoom = WORK_ZOOM.lerp(AUDIENCE_ZOOM, amount)
	# A head that lifts also tilts. Barely more than a degree — enough that the
	# horizon is not perfectly level during the move, which is most of why this
	# now reads as a viewpoint rather than a pan.
	camera.rotation = deg_to_rad(1.15) * amount

	desk.set_view_amount(settled)
	if hint != null:
		hint.set_view_amount(settled)
		# RETIREMENT IS EARNED BY ARRIVING, NOT BY PRESSING.
		#
		# Both captions used to retire on any input to either handler. At t=0 the
		# view is already down, so one stray wheel-down — which moves nothing,
		# makes no sound and gives the player no feedback whatsoever — started the
		# permanent fade on the only instruction in the game. The player lost
		# "look up" without ever having looked up, and lost "return to desk"
		# before ever needing it, which strands them on the audience plane where
		# the desk is deliberately not interactive.
		#
		# Each caption now goes away only once the player has actually been to the
		# plane it describes.
		if amount > 0.94:
			hint.note_looked_up()
		elif amount < 0.06:
			hint.note_returned()

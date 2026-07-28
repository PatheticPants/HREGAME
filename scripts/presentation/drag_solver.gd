class_name DragSolver
extends RefCounted

## A sheet of paper as a spring-driven body with one anchor.
##
## THE IDEA
## --------
## The naive version of mouse dragging sets position = cursor and adds a tilt
## proportional to horizontal speed. It reads as a sprite following a cursor,
## because it is. What paper actually does is resist: you pull it at one point,
## the rest of it lags, and because the pull is off-centre it also turns.
##
## So the cursor is attached to the sheet by a spring at the exact point the
## player grabbed, and the sheet is integrated as a body with mass and a moment
## of inertia. Grab a charter by its top-left corner and yank right and it swings
## behind your hand; grab it dead centre and it slides flat. Nothing special-cases
## either behaviour — both fall out of one cross product.
##
## FIXED TIMESTEP
## --------------
## The whole thing is integrated in fixed 1/120s substeps accumulated inside
## _process, rather than stepping once per frame with a variable delta. Springs
## with a variable dt change their damping ratio with frame rate, which means a
## sheet tuned on a 144 Hz desktop feels different on a 60 Hz laptop — exactly the
## split this project has. The accumulator is capped so an alt-tab stall cannot
## fire two hundred substeps and launch a document across the room.
##
## Every constant lives in PaperFeel (data/tuning/paper_feel.tres) and is read
## fresh each step, so it can be tuned live with the game running.

const SUBSTEP := 1.0 / 120.0
const MAX_ACCUM := 0.10

## Sleep only once the sheet is also roughly back to its resting angle, otherwise
## it can freeze at the far end of an oscillation, permanently crooked at the
## lean limit.
const SLEEP_LEAN := 0.12

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var angle := 0.0
var angular_velocity := 0.0

## What the sheet drifts back toward when nothing is pulling it. Randomised per
## document at spawn, which is why a settled desk still looks untidy.
var rest_angle := 0.0

var held := false
var sleeping := false

## Cursor position in desk space, and the grab point in the body's own
## unrotated frame.
var target := Vector2.ZERO
var grab_offset := Vector2.ZERO

## Soft limits. Papers may overhang the rim; they may not be lost.
var bounds := Rect2()

## How this particular object answers the hand, relative to a sheet of parchment.
##
## PaperFeel is one resource shared by everything on the desk, and its constants
## were tuned for paper — so a signet ring, a boxwood tablet and a candle in a
## dish all had the identical lag and settle as a full charter. Scaling stiffness,
## damping and inverse inertia together preserves the shape of the response while
## changing its character: above 1 is small and dense and follows tightly, below 1
## is heavy, sluggish to accelerate, and overshoots more before it settles.
var weight := 1.0

var _accum := 0.0


func place(p: Vector2, a: float) -> void:
	position = p
	angle = a
	rest_angle = a
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true


func grab(cursor: Vector2) -> void:
	held = true
	sleeping = false
	# Store the grab point in the body frame so it survives the sheet rotating
	# under the hand. This is what keeps the corner you grabbed under the cursor.
	grab_offset = (cursor - position).rotated(-angle)
	target = cursor


func release() -> void:
	held = false


func speed() -> float:
	return velocity.length()


func advance(delta: float, feel: PaperFeel) -> void:
	if sleeping and not held:
		return
	_accum = minf(_accum + delta, MAX_ACCUM)
	while _accum >= SUBSTEP:
		_accum -= SUBSTEP
		if held:
			_step_held(SUBSTEP, feel)
		else:
			_step_free(SUBSTEP, feel)
			_push_from_edges(SUBSTEP, feel)


# --------------------------------------------------------------------- steps

func _step_held(h: float, feel: PaperFeel) -> void:
	# The spring pulls at the grab point, not the centre of mass.
	var arm := grab_offset.rotated(angle)
	var anchor := position + arm
	var force := (target - anchor) * (feel.stiffness * weight) \
		- velocity * (feel.damping * weight)

	velocity += force * h
	position += velocity * h

	# cross(r, F) is the moment that off-centre pull applies about the centre.
	# This one term is the entire "paper leans into the drag" behaviour; set
	# torque_gain to 0 and the sheet slides flat like a decal.
	var torque := arm.cross(force) * feel.torque_gain
	angular_velocity += torque * (feel.inverse_inertia * weight) * h
	# Damping written as a bounded proportion so a large angular_damping cannot
	# overshoot into negative spin at low frame rates.
	angular_velocity -= angular_velocity * minf(feel.angular_damping * h, 1.0)
	angle += angular_velocity * h

	_clamp_lean(feel)


func _step_free(h: float, feel: PaperFeel) -> void:
	position += velocity * h
	# pow(retention, h) rather than (1 - k*h): frame-rate independent, and it
	# cannot flip sign at a large h the way the linear form can.
	velocity *= pow(feel.release_damping, h)

	var lean := _wrap_angle(angle - rest_angle)
	angular_velocity -= lean * feel.settle_spring * h
	angular_velocity *= pow(feel.release_angular_damping, h)
	angle += angular_velocity * h

	if velocity.length() < feel.sleep_speed \
			and absf(angular_velocity) < feel.sleep_spin \
			and absf(lean) < SLEEP_LEAN:
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		sleeping = true


## Soft walls for a sheet that has been let go near the rim. A hard clamp reads
## as an invisible barrier; a spring reads as the sheet catching on the edge of
## the desk and sliding back.
func _push_from_edges(h: float, feel: PaperFeel) -> void:
	if bounds.size == Vector2.ZERO:
		return
	var pad := Vector2(feel.edge_allowance, feel.edge_allowance)
	var lo := bounds.position - pad
	var hi := bounds.end + pad
	var push := Vector2.ZERO
	if position.x < lo.x:
		push.x = lo.x - position.x
	elif position.x > hi.x:
		push.x = hi.x - position.x
	if position.y < lo.y:
		push.y = lo.y - position.y
	elif position.y > hi.y:
		push.y = hi.y - position.y
	if push != Vector2.ZERO:
		velocity += push * feel.edge_spring * h
		sleeping = false


## Hard limit on how far the sheet may turn away from its resting angle. Without
## it a fast flick spins a charter like a propeller, which is funny exactly once.
func _clamp_lean(feel: PaperFeel) -> void:
	var limit := deg_to_rad(feel.max_lean_deg)
	var lean := _wrap_angle(angle - rest_angle)
	if absf(lean) > limit:
		angle = rest_angle + signf(lean) * limit
		# Bleed most of the spin at the stop, or it buzzes against the limit.
		angular_velocity *= 0.35


## While held, the cursor target is clamped instead of the body, so a document
## cannot be dragged off the desk and lost — but it can still be pulled to the
## very rim and left hanging there.
func clamp_target(feel: PaperFeel) -> void:
	if bounds.size == Vector2.ZERO:
		return
	var pad := Vector2(feel.edge_allowance, feel.edge_allowance)
	target.x = clampf(target.x, bounds.position.x - pad.x, bounds.end.x + pad.x)
	target.y = clampf(target.y, bounds.position.y - pad.y, bounds.end.y + pad.y)


static func _wrap_angle(a: float) -> float:
	return wrapf(a, -PI, PI)

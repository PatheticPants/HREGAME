class_name AudienceDoor
extends Polygon2D

## The door to the passage, on real hinges.
##
## WHY THIS IS NOT A LERP
## ----------------------
## Everything else in this game that moves has three phases and a settle. The
## press resists, gives, seats and peels. The rack arms, slides and lands. The
## view anticipates, rises and steadies. The door — the object that opens and
## shuts fourteen times in a two-day campaign, and the only thing on screen
## during the beat between one petitioner and the next — was a constant-velocity
## `move_toward` wearing a smoothstep, with both of its sounds fired half a
## second before it had moved at all.
##
## A door is a heavy slab on two iron pins. It takes a shove to start, carries its
## own momentum, and arrives: outward it fetches up against the check of the hinge
## and rocks; inward it meets the jamb and the latch takes. Both ends are events.
##
## So this owns a spring rather than a ramp, reports its own velocity so the creak
## can track the swing, and emits `settled` on the frame it actually arrives —
## which is where the loud sound belongs.

signal settled(opening: bool)

const DOOR_TEXTURE := preload("res://art/environment/chancery_door_leaf.png")
const DOOR_SIZE := Vector2(390.0, 715.0)

## Heavy and slightly underdamped (zeta ~0.86), so the leaf overshoots by a hair
## and rocks back rather than stopping dead on the number. Deliberately slower
## than the view spring: a door has more mass than a head.
## zeta = DAMPING / (2*sqrt(STIFFNESS)) = 0.61, which overshoots by about 9% and
## puts the rock at a couple of visible pixels. The first version used 11.7 for
## zeta = 0.86 — mathematically "slightly underdamped" and an overshoot of 0.47%,
## which after clamping is a tenth of a pixel. The leaf arrived dead-stop on the
## number, which is precisely the failure this spring exists to avoid. A comment
## claiming a spring is not a spring.
const HINGE_STIFFNESS := 46.0
const HINGE_DAMPING := 8.3

## A shove has to overcome the pin before anything moves. Small, and entirely
## felt rather than seen, but it is the difference between a door being pushed
## and a door being animated.
const SHOVE := 1.35

var open_amount := 0.0
var target := 0.0
var velocity := 0.0

## THE DOOR HAD NEVER MET THE CANDLE.
##
## Fed by Desk._update_lighting like every other object in the room, and until
## now the only large thing that was not. Its face colour was
## `Color(1 - t*0.43, ...)` — a pure function of how far open the leaf is, under
## a comment reading "the face loses direct candlelight as it turns into the
## passage" while reading nothing whatever about where the candlelight was.
##
## So the biggest object on screen during every arrival was drawn at a fixed
## brightness in a room whose whole premise is one carried flame. Carrying the
## candle across the desk relit the parchment, the books, the rings, the spoon
## and the person standing there, and did nothing at all to the door behind them.
var light_position := Vector2(0, -400)
var light_level := 0.25
var light_strength := 1.0
var ambient_daylight := false

## Oak in a dark room still has a silhouette. The door must never fall so far
## that the arrival happens in front of a black rectangle — a door you cannot
## see is a door that cannot be opened dramatically.
const FLOOR_LEVEL := 0.16

var _settled := true
var _rattle := 0.0
var _rattle_phase := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = DOOR_TEXTURE
	uv = PackedVector2Array([
		Vector2(0, 0),
		Vector2(DOOR_TEXTURE.get_width(), 0),
		Vector2(DOOR_TEXTURE.get_width(), DOOR_TEXTURE.get_height()),
		Vector2(0, DOOR_TEXTURE.get_height()),
	])
	set_open_amount(0.0)


## Swing it. The shove goes in as velocity rather than as a new target, so a door
## reversed halfway carries its momentum through the turn instead of kinking.
func swing_to(value: float) -> void:
	var want := clampf(value, 0.0, 1.0)
	if is_equal_approx(want, target):
		return
	velocity += SHOVE * (1.0 if want > target else -1.0)
	target = want
	_settled = false


## Somebody has knocked on the other side of it. The leaf jumps against its latch
## and does not open — which is the whole point, because until now a knock was a
## sound with no consequence anywhere on screen.
func knock() -> void:
	_rattle = 1.0
	_rattle_phase = 0.0


func advance(delta: float) -> void:
	# Fixed substeps, for the same reason DragSolver has them: this must feel
	# identical on the 60 Hz laptop and the 144 Hz desktop.
	var remaining := delta
	while remaining > 0.0:
		var h := minf(1.0 / 120.0, remaining)
		remaining -= h
		var accel := (target - open_amount) * HINGE_STIFFNESS - velocity * HINGE_DAMPING
		velocity += accel * h
		open_amount += velocity * h

	if _rattle > 0.0:
		_rattle_phase += delta * 34.0
		# Exponential, not linear. A latch ringing down does not lose the same
		# amount of amplitude every millisecond, and the linear version had a
		# visible corner where it hit zero.
		_rattle *= pow(0.012, delta)
		if _rattle < 0.004:
			_rattle = 0.0

	if not _settled and absf(open_amount - target) < 0.004 and absf(velocity) < 0.06:
		open_amount = target
		velocity = 0.0
		_settled = true
		# THE EVENT IS THE ARRIVAL, NOT THE REQUEST.
		#
		# door_open and door_close both used to play on the frame the target was
		# set, and the leaf then took another half second to get there — so the
		# thud of the door shutting landed while it was still standing wide open.
		settled.emit(target > 0.5)
	set_open_amount(open_amount)


## How fast the leaf is travelling, 0..1, for the creak.
func swing_rate() -> float:
	return clampf(absf(velocity) * 0.62, 0.0, 1.0)


## Has it actually arrived? The session gates the beat between one caller and the
## next on this rather than on "close was requested", because the request and the
## arrival are most of a second apart and gating on the request meant the next
## petitioner's knock landed on a leaf that was still swinging shut behind the
## last one.
func is_settled() -> bool:
	return _settled


func set_open_amount(value: float) -> void:
	# The spring is allowed to overshoot; the projection is not. A leaf that
	# swings past its own hinge line is a glitch rather than a flourish, so the
	# overshoot is spent on the rock below instead.
	open_amount = value
	var t := clampf(value, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	# The rock: the overshoot the spring earned, applied as a small extra skew so
	# the leaf visibly settles against the hinge check rather than stopping.
	var rock := (value - t) * 26.0
	var rattle := sin(_rattle_phase) * _rattle * 3.4

	var outer_x := lerpf(DOOR_SIZE.x, 19.0, t) + rattle
	var top_skew := 13.0 * t + rock
	var bottom_skew := 8.0 * t + rock * 0.6

	polygon = PackedVector2Array([
		Vector2(rattle * 0.35, 0),
		Vector2(outer_x, top_skew),
		Vector2(outer_x, DOOR_SIZE.y - bottom_skew),
		Vector2(rattle * 0.35, DOOR_SIZE.y),
	])
	color = face_colour(t)


## Where the middle of the leaf actually is, for sampling the flame's falloff.
## The node's own origin is the hinge, in the top corner, which is the worst
## available point to measure a 390x715 slab from.
func centre_world() -> Vector2:
	return to_global(Vector2(projected_width() * 0.5, DOOR_SIZE.y * 0.5))


## Oak, lit by the one flame in the room.
##
## Two separate terms, and they are not the same thing. `t` is how far the leaf
## has turned INTO the passage, so its face stops pointing at the room; that term
## was already here and is correct. How much flame reaches it at all was missing
## entirely, and that is the term the whole game is about.
func face_colour(t: float) -> Color:
	var lit := maxf(Surface.lit(light_level, light_strength), FLOOR_LEVEL)
	# Under the cold morning through the shutter there is nothing warm to lerp
	# toward, and the room is lit uniformly from one direction.
	var warm := 0.0 if ambient_daylight else 0.30
	var face := Surface.tint(Color(1.0, 1.0, 1.0), lit, warm, 0.78)
	return Color(
		face.r * (1.0 - t * 0.43),
		face.g * (1.0 - t * 0.46),
		face.b * (1.0 - t * 0.49),
		1.0)


func projected_width() -> float:
	if polygon.size() < 2:
		return 0.0
	return polygon[1].x

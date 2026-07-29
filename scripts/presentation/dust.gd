class_name Dust
extends Node2D

## What is in the air between the flame and your eye.
##
## The room has been a set of flat layers that move relative to each other:
## a painted wall, a door, a person, a desk, some props. Nothing has ever
## occupied the space BETWEEN them, so the light has had nothing to travel
## through — and a light that illuminates surfaces but never reveals the air is
## the difference between a picture of a dark room and being in one.
##
## Motes belong to the ROOM, not to the candle. They drift on their own slow
## draught and are visible only where the flame actually reaches, so carrying the
## light across the desk sweeps a pool of visible air with it and leaves the rest
## of the room empty. That is the whole effect and it costs about forty circles.
##
## They must stay under the threshold where they read as snow. If a player ever
## notices "there is dust in this game" rather than "this room has air in it",
## the alpha is too high.

const COUNT := 44

## Where they live, in desk-local space: the working volume plus a margin, so
## none of them ever pops in at the edge of the frame.
const FIELD := Rect2(-980.0, -420.0, 1960.0, 900.0)

var candle: Candle
var desk: Desk

## x, y, radius, phase. Position drifts; the phase decorrelates the wander so
## they do not shoal.
var _motes: PackedVector4Array = PackedVector4Array()
var _drift: PackedVector2Array = PackedVector2Array()
var _time := 0.0


func _ready() -> void:
	# One step above the desk plane and everything on it: dust is nearer the eye
	# than the paper is. Below the ledger, which is a whole page being read.
	z_index = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x0d057
	for i in COUNT:
		_motes.append(Vector4(
			rng.randf_range(FIELD.position.x, FIELD.end.x),
			rng.randf_range(FIELD.position.y, FIELD.end.y),
			rng.randf_range(0.7, 1.9),
			rng.randf_range(0.0, TAU)))
		# A slow prevailing draught across the room, plus per-mote variation.
		_drift.append(Vector2(rng.randf_range(-7.0, 4.0),
			rng.randf_range(-5.5, -1.2)))
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	for i in _motes.size():
		var m := _motes[i]
		var d := _drift[i]
		# Rising, because the air over a flame rises, plus a lateral wander that
		# is not a sine wave the eye can lock onto.
		m.x += (d.x + sin(_time * 0.31 + m.w) * 5.0) * delta
		m.y += (d.y + cos(_time * 0.23 + m.w * 1.7) * 3.0) * delta
		# Wrap rather than respawn: a mote that vanishes and reappears is a
		# particle system, and one that keeps going is air.
		if m.y < FIELD.position.y:
			m.y = FIELD.end.y
			m.x = randf_range(FIELD.position.x, FIELD.end.x)
		if m.x < FIELD.position.x:
			m.x = FIELD.end.x
		elif m.x > FIELD.end.x:
			m.x = FIELD.position.x
		_motes[i] = m
	queue_redraw()


func _draw() -> void:
	if candle == null or not is_instance_valid(candle):
		return
	if candle.is_spent():
		_draw_morning_motes()
		return
	var flame := to_local(candle.flame_world())
	var flicker := candle.light_intensity()
	for i in _motes.size():
		var m := _motes[i]
		var at := Vector2(m.x, m.y)
		# Only where the flame actually reaches. The falloff is deliberately
		# steeper than the renderer's, so the pool of VISIBLE AIR is tighter than
		# the pool of usable light — dust catches the light long after the light
		# has stopped being enough to read by.
		var reach := clampf(1.0 - at.distance_to(flame) / 340.0, 0.0, 1.0)
		if reach <= 0.02:
			continue
		var a := reach * reach * 0.44 * flicker
		# A mote passing directly in front of the flame is briefly much brighter,
		# which is what actually catches the eye about firelight.
		var near := clampf(1.0 - at.distance_to(flame) / 90.0, 0.0, 1.0)
		draw_circle(at, m.z * (1.0 + near * 0.5),
			Color(1.0, 0.86, 0.62, a + near * near * 0.22))


## Once the flame is gone the same air becomes visible only inside the cold
## shutter bands. Long, faint strokes replace the round firelit motes: the light
## is distant and directional now, and the change in their shape helps morning
## feel like a different source rather than a brighter candle.
func _draw_morning_motes() -> void:
	if desk == null or desk._morning_amount <= 0.01:
		return
	var rise := smoothstep(0.0, 1.0, desk._morning_amount)
	for i in _motes.size():
		var m := _motes[i]
		var at := Vector2(m.x, m.y)
		var band := morning_band_at(at)
		if band == 0:
			continue
		var band_alpha := 0.15 if band == 1 else 0.08
		var pulse := 0.75 + 0.25 * sin(_time * 0.19 + m.w)
		draw_line(at, at + Vector2(2.2, -5.6),
			Color(0.77, 0.84, 0.98,
				band_alpha * rise * pulse * clampf(m.z / 1.9, 0.4, 1.0)),
			maxf(0.7, m.z * 0.72), true)


## Returns the authored shutter band containing a desk-local point: 0 for
## neither, 1 for the broad band, and 2 for the narrow band.
static func morning_band_at(at: Vector2) -> int:
	var u := clampf(inverse_lerp(
		Desk.DESK_RECT.position.y, Desk.DESK_RECT.end.y, at.y), 0.0, 1.0)
	if at.x >= lerpf(-410.0, 170.0, u) \
			and at.x <= lerpf(-150.0, 520.0, u):
		return 1
	if at.x >= lerpf(95.0, 610.0, u) \
			and at.x <= lerpf(250.0, 820.0, u):
		return 2
	return 0

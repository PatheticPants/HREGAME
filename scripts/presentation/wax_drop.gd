class_name WaxDrop
extends Node2D

## One bead travelling from the lip of the melting spoon to the parchment.
##
## The old pour changed the pool and played the impact sound at the moment a
## timer fired, so the "drop" itself never existed. This tiny transient object
## gives the eye a cause before the pool reacts and lets the sound land exactly
## when the bead does.

signal landed()

var color := Color(0.60, 0.13, 0.16)
var duration := 0.15

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _age := 0.0
var _motion := Vector2(0, 1)
var _stretch := 1.0
var _landed_emitted := false
var _landing_age := 0.0


func setup(from: Vector2, to: Vector2, tint: Color, travel_time := 0.15) -> void:
	_from = from
	_to = to
	color = tint
	duration = maxf(0.05, travel_time)
	position = from
	z_index = 5
	_landed_emitted = false
	_landing_age = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if _landed_emitted:
		_landing_age += delta
		var settle := clampf(_landing_age / 0.085, 0.0, 1.0)
		scale = Vector2(lerpf(1.46, 1.08, settle),
			lerpf(0.34, 0.16, settle))
		modulate.a = 1.0 - ease(settle, 0.45)
		queue_redraw()
		if settle >= 1.0:
			queue_free()
		return

	_age += delta
	var t := clampf(_age / duration, 0.0, 1.0)
	# Accelerate into the page. A small sideways bow stops successive beads from
	# reading as dots moving on a mechanical rail.
	var fall := t * t
	var line := _from.lerp(_to, fall)
	var direction := (_to - _from).normalized()
	var sideways := Vector2(-direction.y, direction.x)
	var next_position := line + sideways * sin(t * PI) * 2.5
	var velocity := next_position - position
	if velocity.length_squared() > 0.0001:
		_motion = velocity.normalized()
	position = next_position
	# Authored along local +Y. The narrow end trails behind the heavy bead.
	rotation = _motion.angle() - PI * 0.5
	_stretch = lerpf(1.68, 0.92, ease(t, 0.65))
	scale = Vector2(lerpf(0.72, 1.0, t), _stretch)
	queue_redraw()

	if t >= 1.0:
		_landed_emitted = true
		position = _to
		rotation = 0.0
		scale = Vector2(1.46, 0.34)
		landed.emit()
		queue_redraw()


func _draw() -> void:
	draw_line(Vector2(0, -16), Vector2(0, -5),
		Color(color.lightened(0.05), 0.34), 1.65)
	var bead := PackedVector2Array([
		Vector2(0, -7.5),
		Vector2(3.4, -1.4),
		Vector2(3.9, 2.7),
		Vector2(1.8, 5.2),
		Vector2(0, 5.9),
		Vector2(-1.8, 5.2),
		Vector2(-3.9, 2.7),
		Vector2(-3.4, -1.4),
	])
	var shadow := PackedVector2Array()
	for p in bead:
		shadow.append(p + Vector2(1.2, 1.7))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.20))
	draw_colored_polygon(bead, color.darkened(0.16))
	draw_circle(Vector2(-0.8, 0.7), 2.9, color.lightened(0.18))
	draw_circle(Vector2(-1.8, -1.0), 0.85, Color(1.0, 0.82, 0.56, 0.72))

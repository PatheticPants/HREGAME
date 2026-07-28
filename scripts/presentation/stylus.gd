class_name Stylus
extends Draggable

## A bronze stylus. Pointed at one end for scratching, flattened at the other for
## smoothing the wax back down.
##
## It is the answer to the one thing this game had no verb for: taking a note.
## Every alternative was software — a text box, a clickable checklist, a journal
## screen — and any of them would have been the first thing here that admitted it
## was a computer program. A stylus is not software. You hold it over the tablet
## and you scratch whatever you like, in whatever notation you invent, and the
## game never reads a single mark you make.
##
## The grammar is the same one the spoon and the rings already taught: hold the
## tool over the thing and move, or hold the tool over the thing and be still.
## Moving scratches. Resting smooths.

const LENGTH := 148.0


func _ready() -> void:
	super._ready()
	hit_size = Vector2(LENGTH * 1.08, 46.0)
	pickup_sound = &"ring_pickup"
	drop_sound = &"stamp_set"
	slide_sound = &""
	occludes_light = true
	occluder_round = true
	occluder_inset = 0.30
	# A slim rod of bronze. Light, quick, almost no swing.
	weight = 1.5
	stow_scale = 0.62
	z_index = 0


## The scratching point, in local space. The stylus is drawn along its own x
## axis, so the nib is simply one end of it.
func tip_local() -> Vector2:
	return Vector2(LENGTH * 0.5, 2.0)


func tip_world() -> Vector2:
	return to_global(tip_local())


func _draw() -> void:
	var half := LENGTH * 0.5
	draw_soft_shadow(Rect2(-half, -7.0, LENGTH, 14.0))

	var dark := Color(0.29, 0.21, 0.09)
	var bronze := Color(0.55, 0.42, 0.18)
	var bright := Color(0.80, 0.66, 0.32)

	# Shaft: three strokes, dark under, body, and a bright edge where the candle
	# runs along the metal.
	draw_line(Vector2(-half + 6, 2), Vector2(half - 10, 2), dark, 9.0, true)
	draw_line(Vector2(-half + 6, 0), Vector2(half - 10, 0), bronze, 6.0, true)
	draw_line(Vector2(-half + 8, -2), Vector2(half - 14, -2), bright, 1.6, true)

	# The nib, drawn as a taper to a point.
	draw_colored_polygon(PackedVector2Array([
		Vector2(half - 14, -4.5),
		Vector2(half, 2.0),
		Vector2(half - 14, 5.5),
	]), bronze)
	draw_colored_polygon(PackedVector2Array([
		Vector2(half - 14, -3.0),
		Vector2(half - 1, 1.6),
		Vector2(half - 14, 0.5),
	]), bright)

	# The spatula: the flattened end that smooths wax back down.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half + 8, -4.0),
		Vector2(-half - 3, -8.0),
		Vector2(-half - 6, 2.0),
		Vector2(-half - 3, 9.0),
		Vector2(-half + 8, 5.0),
	]), bronze)
	draw_line(Vector2(-half - 2, -5.0), Vector2(-half - 4, 5.0), bright, 1.4)

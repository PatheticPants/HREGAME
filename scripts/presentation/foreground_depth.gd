class_name ForegroundDepth
extends Node2D

## The near edge of the clerk's own desk.
##
## The room already has a far wall, a middle-distance petitioner and a work
## plane, but nothing occupied the last handspan between the papers and the
## viewer. This lip lives beyond the authored desk plate rather than painting
## over it. It is visible only while looking down; lifting the head carries it
## below the frame naturally.

var desk: Desk
var _grain: PackedVector3Array = PackedVector3Array()


func bind(owner: Desk) -> void:
	desk = owner
	# The fascia covers loose papers that reach beyond the work plane, but a tool
	# lifted in the hand—and the glass's overhanging handle—belongs in front.
	z_index = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x0f0e6
	for i in 38:
		_grain.append(Vector3(
			rng.randf_range(-930.0, 930.0),
			rng.randf_range(0.08, 0.88),
			rng.randf_range(12.0, 74.0)))
	queue_redraw()


func _draw() -> void:
	if desk == null:
		return
	var lift := smoothstep(0.0, 1.0, desk._view_amount)
	var top := lerpf(356.0, 492.0, lift)
	var bottom := top + 86.0

	# The lip projects toward the player. Its slight widening is the closest and
	# therefore strongest perspective cue in the scene.
	var face := PackedVector2Array([
		Vector2(-925.0, top),
		Vector2(925.0, top),
		Vector2(990.0, bottom),
		Vector2(-990.0, bottom),
	])
	draw_colored_polygon(face, Color(0.088, 0.049, 0.025))
	draw_line(Vector2(-925.0, top), Vector2(925.0, top),
		Color(0.39, 0.225, 0.10, 0.72), 4.0)
	draw_line(Vector2(-940.0, top + 8.0), Vector2(940.0, top + 8.0),
		Color(0.12, 0.067, 0.032), 7.0)
	draw_line(Vector2(-958.0, bottom - 12.0), Vector2(958.0, bottom - 12.0),
		Color(0.025, 0.017, 0.016, 0.92), 12.0)

	# Fixed oak pores, almost lost in the near dark. They are only apparent where
	# the candle reaches the front edge, so the foreground belongs to the same
	# room rather than becoming a black vignette.
	var candle_x := desk.candle.position.x if desk.candle != null else 700.0
	var candle_live := desk.candle != null and not desk.candle.is_spent()
	for g: Vector3 in _grain:
		var y := lerpf(top + 15.0, bottom - 17.0, g.y)
		var near_light := clampf(1.0 - absf(g.x - candle_x) / 680.0, 0.0, 1.0)
		var alpha := (0.025 + near_light * 0.08) if candle_live else 0.035
		draw_line(Vector2(g.x, y), Vector2(g.x + g.z, y + 1.0),
			Color(0.62, 0.31, 0.12, alpha), 1.2)

	# The corners are nearer than the centre and fall away first. These wedges
	# also keep the lip from reading as another horizontal UI bar.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-990, bottom), Vector2(-990, top + 10),
		Vector2(-760, top), Vector2(-850, bottom),
	]), Color(0.012, 0.010, 0.014, 0.48))
	draw_colored_polygon(PackedVector2Array([
		Vector2(990, bottom), Vector2(990, top + 10),
		Vector2(760, top), Vector2(850, bottom),
	]), Color(0.012, 0.010, 0.014, 0.48))

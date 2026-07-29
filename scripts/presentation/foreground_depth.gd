class_name ForegroundDepth
extends Node2D

## The near edge of the clerk's own desk.
##
## The room already has a far wall, a middle-distance petitioner and a work
## plane, but nothing occupied the last handspan between the papers and the
## viewer. This lip lives beyond the authored desk plate rather than painting
## over it. It is visible only while looking down; lifting the head carries it
## below the frame naturally.

## Where the lip sits at rest, and how far its face runs on past that. The runoff
## has to clear the deepest point any document can reach — DESK_RECT.end.y plus
## the drag solver's edge_allowance, plus half the tallest sheet — or content
## reappears below the lip and the whole thing reads as a bar across the page.
## Asserted in test_presentation.
const TOP_REST := 356.0
const TOP_LIFTED := 492.0
const FACE_DEPTH := 86.0
const RUNOFF := 620.0

## HALF-WIDTH OF THE LIP.
##
## It was 925 at the top edge and 990 at the foot, which covers a 1600-wide
## window (visible desk-local x reaches +/-800) and nothing wider. At 2560 the
## camera shows +/-1280, so the lip stopped short of the frame and a sheet
## dragged into either bottom corner reappeared below it — the same defect the
## runoff fixed vertically, surviving horizontally. Sized past a 32:9 frame,
## which is the same extreme the room bleed is sized for — and the first number
## tried here, 1360, was caught short by the assertion rather than by a player.
const HALF_WIDTH := 1980.0

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
			rng.randf_range(-HALF_WIDTH, HALF_WIDTH),
			rng.randf_range(0.08, 0.88),
			rng.randf_range(12.0, 74.0)))
	queue_redraw()


func _draw() -> void:
	if desk == null:
		return
	var lift := smoothstep(0.0, 1.0, desk._view_amount)
	var top := lerpf(TOP_REST, TOP_LIFTED, lift)
	# THE NEAR EDGE OF A DESK IS NOT A BAR ACROSS THE PAGE.
	#
	# The face was 86 units deep and stopped, so a document dragged toward the
	# player — which the drag solver expressly allows, clamping a sheet's centre to
	# DESK_RECT.end.y plus a 120-unit edge_allowance — was sliced by an opaque
	# band with legible text on BOTH sides of it. Reproduced: the Küfergasse
	# charter cut mid-clause at "the right of the well that stands upon it", with
	# "Given in the third year of Kunrad IV" reading clearly underneath. Content
	# above and below an opaque strip does not read as a desk lip. It reads as a
	# rendering fault, and it hides evidence while doing it.
	#
	# Deep enough to leave the frame at every view angle, so it is the edge the
	# desk stops at. Papers may still pass behind it — a sheet pulled to the near
	# rim goes under the lip, which is what a lip is — but nothing of them ever
	# reappears below.
	var depth := FACE_DEPTH
	var bottom := top + RUNOFF

	# The lip projects toward the player. Its slight widening is the closest and
	# therefore strongest perspective cue in the scene.
	var face := PackedVector2Array([
		Vector2(-HALF_WIDTH, top),
		Vector2(HALF_WIDTH, top),
		Vector2(HALF_WIDTH + 65.0, bottom),
		Vector2(-HALF_WIDTH - 65.0, bottom),
	])
	draw_colored_polygon(face, Color(0.088, 0.049, 0.025))
	draw_line(Vector2(-HALF_WIDTH, top), Vector2(HALF_WIDTH, top),
		Color(0.39, 0.225, 0.10, 0.72), 4.0)
	draw_line(Vector2(-HALF_WIDTH - 15.0, top + 8.0),
		Vector2(HALF_WIDTH + 15.0, top + 8.0),
		Color(0.12, 0.067, 0.032), 7.0)
	draw_line(Vector2(-HALF_WIDTH - 33.0, top + depth - 12.0),
		Vector2(HALF_WIDTH + 33.0, top + depth - 12.0),
		Color(0.025, 0.017, 0.016, 0.92), 12.0)

	# Fixed oak pores, almost lost in the near dark. They are only apparent where
	# the candle reaches the front edge, so the foreground belongs to the same
	# room rather than becoming a black vignette.
	var candle_x := desk.candle.position.x if desk.candle != null else 700.0
	var candle_live := desk.candle != null and not desk.candle.is_spent()
	for g: Vector3 in _grain:
		var y := lerpf(top + 15.0, top + depth - 17.0, g.y)
		var near_light := clampf(1.0 - absf(g.x - candle_x) / 680.0, 0.0, 1.0)
		var alpha := (0.025 + near_light * 0.08) if candle_live else 0.035
		draw_line(Vector2(g.x, y), Vector2(g.x + g.z, y + 1.0),
			Color(0.62, 0.31, 0.12, alpha), 1.2)

	# The corners are nearer than the centre and fall away first. These wedges
	# also keep the lip from reading as another horizontal UI bar.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-HALF_WIDTH - 65.0, top + depth),
		Vector2(-HALF_WIDTH - 65.0, top + 10),
		Vector2(-HALF_WIDTH + 165.0, top),
		Vector2(-HALF_WIDTH + 75.0, top + depth),
	]), Color(0.012, 0.010, 0.014, 0.48))
	draw_colored_polygon(PackedVector2Array([
		Vector2(HALF_WIDTH + 65.0, top + depth),
		Vector2(HALF_WIDTH + 65.0, top + 10),
		Vector2(HALF_WIDTH - 165.0, top),
		Vector2(HALF_WIDTH - 75.0, top + depth),
	]), Color(0.012, 0.010, 0.014, 0.48))

class_name RingStand
extends Node2D

## A block of turned oak with three recesses, the words cut into the wood and
## filled with bone.
##
## This is how the player learns which ring is which without a single pixel of
## HUD. The rings are indistinguishable objects until you have used them once;
## the block tells you, permanently, in the world, and it goes on telling you
## after the ring has been carried across the desk and left somewhere else.
##
## WHY IT IS INLAID RATHER THAN BURNT
## ----------------------------------
## It used to be. The words were set at 11pt in Color(0.16,0.10,0.06) on wood of
## Color(0.29,0.20,0.13) — dark brown on brown — and this block stands at the far
## left of the desk, which is the corner the candle almost never reaches. It also
## ignored its own light_level entirely, so it did not brighten when the flame was
## carried to it either. At the default window that is about nine effective pixels
## of near-zero-contrast lettering, which means the object that exists to name the
## three irreversible choices did not name them.
##
## Bone inlay in a cut groove is the same object saying the same thing at a
## contrast a dark room cannot swallow, and it catches the flame when the flame
## comes near, which is the reward for carrying it.

const SLOT_GAP := 92.0

var slot_words: Array[String] = ["CONFIRMO", "NEGO", "REFERO"]
var light_position := Vector2(0, -400)
var light_level := 0.5

## Which hollow is empty because the player is holding that ring. -1 for none.
## A ring in the hand is a ring whose word you can no longer read off the block,
## which is exactly when you most want to know what you picked up.
var lifted_slot := -1


func slot_position(index: int) -> Vector2:
	# The stand and the rings live under sibling Node2Ds with the same transform,
	# so this must be desk-local. Returning global_position here double-counted
	# the desk offset when SignetRing.setup() assigned it as a local position,
	# leaving all three verdict rings off-screen and the game unwinnable.
	return position + Vector2(0.0, (float(index) - 1.0) * SLOT_GAP)


func _draw() -> void:
	var w := 138.0
	var h := SLOT_GAP * 3.0 + 26.0
	var r := Rect2(-w * 0.5, -h * 0.5, w, h)
	var lit := clampf(light_level, 0.0, 1.0)
	var toward := (light_position - global_position).normalized()

	var oak := Color(0.29, 0.20, 0.13).lerp(Color(0.58, 0.40, 0.22), lit * 0.55)

	# Body of the block, with the grain running along it.
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.30))
	draw_rect(r, oak.darkened(0.22))
	draw_rect(r.grow(-3.0), oak)
	for i in 14:
		var y := r.position.y + 8.0 + float(i) * (h / 15.0)
		draw_line(Vector2(r.position.x + 6, y), Vector2(r.end.x - 6, y),
			Color(0.26, 0.18, 0.11, 0.35), 1.0)

	for i in 3:
		var c := Vector2(0.0, (float(i) - 1.0) * SLOT_GAP)
		# Recess: a dished hollow the ring sits in. Its far wall catches the light
		# and its near wall shades, so the hollow reads as cut into the block
		# rather than painted onto it.
		draw_circle(c, 40.0, oak.darkened(0.52))
		draw_circle(c + Vector2(0, -2), 36.0, oak.darkened(0.34))
		draw_arc(c + Vector2(0, -2), 37.0,
			atan2(toward.y, toward.x) - 1.1, atan2(toward.y, toward.x) + 1.1,
			14, Color(1.0, 0.86, 0.60, 0.10 + 0.22 * lit), 2.0)
		if i == lifted_slot:
			# The empty socket keeps a warm rim while its ring is in the hand.
			draw_arc(c + Vector2(0, -2), 33.0, 0.0, TAU, 26,
				Color(1.0, 0.78, 0.44, 0.20 + 0.30 * lit), 2.0)

		# INLAY. A groove cut in the oak, and bone sitting in the groove: the
		# dark cut offset toward the flame, the pale fill on top of it.
		var at := c + Vector2(-w * 0.5 + 8.0, 40.0)
		var bone := Color(0.72, 0.66, 0.52).lerp(Color(0.98, 0.92, 0.76), lit)
		Ink.line_centre(self, at + toward * 1.2, slot_words[i], 13,
			Color(0.10, 0.06, 0.04, 0.85), w - 16.0)
		Ink.line_centre(self, at, slot_words[i], 13, bone, w - 16.0)

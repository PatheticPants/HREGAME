class_name RingStand
extends Node2D

## A block of turned oak with three recesses, the words burnt into the wood.
##
## This is how the player learns which ring is which without a single pixel of
## HUD. The rings are indistinguishable objects until you have used them once;
## the block tells you, permanently, in the world, and it goes on telling you
## after the ring has been carried across the desk and left somewhere else.

const SLOT_GAP := 92.0

var slot_words: Array[String] = ["CONFIRMO", "NEGO", "REFERO"]
var light_position := Vector2(0, -400)
var light_level := 0.5


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

	# Body of the block, with the grain running along it.
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.30))
	draw_rect(r, Color(0.29, 0.20, 0.13))
	draw_rect(r.grow(-3.0), Color(0.35, 0.25, 0.16))
	for i in 14:
		var y := r.position.y + 8.0 + float(i) * (h / 15.0)
		draw_line(Vector2(r.position.x + 6, y), Vector2(r.end.x - 6, y),
			Color(0.26, 0.18, 0.11, 0.35), 1.0)

	for i in 3:
		var c := Vector2(0.0, (float(i) - 1.0) * SLOT_GAP)
		# Recess: a dished hollow the ring sits in.
		draw_circle(c, 40.0, Color(0.20, 0.14, 0.09))
		draw_circle(c + Vector2(0, -2), 36.0, Color(0.25, 0.18, 0.11))
		# The word, burnt in below the hollow.
		var at := c + Vector2(-w * 0.5 + 8.0, 40.0)
		Ink.line_centre(self, at, slot_words[i], 11,
			Color(0.16, 0.10, 0.06), w - 16.0)
		Ink.line_centre(self, at + Vector2(0, -1), slot_words[i], 11,
			Color(0.52, 0.40, 0.26, 0.55), w - 16.0)

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

## THE WORDS DID NOT FIT BETWEEN THE HOLLOWS AND THE HOLLOWS WERE DRAWN OVER
## THEM.
##
## At 92 the recesses (radius 40) left a clear band of twelve units between one
## hollow's bottom and the next hollow's top, and the word was set at 13pt in it.
## Worse, the whole thing was drawn in ONE loop — recess i, then word i, then
## recess i+1 — so each word was painted and then partly buried by the next
## socket. Measured on a capture: the E of NEGO and the E of REFERO were both
## bitten through, and CONFIRMO lost its I and R.
##
## 104 gives the word a 24-unit band, and everything is drawn in two passes now:
## every hollow, then every word. The stand is 338 tall at this gap and sits at
## y=60, so it spans -109..229 inside a DESK_RECT that runs -250..410.
const SLOT_GAP := 104.0

## How near its own hollow a ring has to be let go for the block to take it.
##
## Strictly less than half the gap, or a ring dropped over one hollow could be
## pulled back to the one above it — the catch is to the ring's OWN slot, so a
## generous radius does not seat it in the wrong word, but it would still make
## the ring travel somewhere the hand did not put it.
const SEAT_CATCH := 46.0

var slot_words: Array[String] = ["CONFIRMO", "NEGO", "REFERO"]
var light_position := Vector2(0, -400)
var light_level := 0.5
## Both of these were missing, and the desk was not setting them because they did
## not exist. The block therefore never breathed with the flame — the one object
## on the desk that names the three irreversible choices sat perfectly steady
## while every other surface flickered — and after the candle died it went on
## warming its oak toward brown in a cold grey room.
var light_strength := 1.0
var ambient_daylight := false

## Which hollow is empty because the player is holding that ring. -1 for none.
## A ring in the hand is a ring whose word you can no longer read off the block,
## which is exactly when you most want to know what you picked up.
var lifted_slot := -1


func _ready() -> void:
	# A fixture rather than a Draggable, so it does not get the linear filter
	# from Draggable._ready — and this block is nothing BUT three words cut into
	# wood. See the note there.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


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
	# Flicker reaches the block now. It is one multiply and it is the difference
	# between a prop and a thing standing in the same room as the flame.
	var lit := clampf(light_level * clampf(light_strength, 0.7, 1.1), 0.0, 1.0)
	var toward := (light_position - global_position).normalized()

	# Warm oak under a flame, grey oak under a shutter. The cold morning is
	# defined by having no fire in it, so the one surface that went on warming
	# itself after the candle died read as still being lit by something.
	var warm := Color(0.58, 0.40, 0.22)
	var cold := Color(0.46, 0.45, 0.47)
	var oak := Color(0.29, 0.20, 0.13).lerp(cold if ambient_daylight else warm,
		lit * 0.55)

	# Body of the block, with the grain running along it.
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.30))
	draw_rect(r, oak.darkened(0.22))
	draw_rect(r.grow(-3.0), oak)
	for i in 14:
		var y := r.position.y + 8.0 + float(i) * (h / 15.0)
		draw_line(Vector2(r.position.x + 6, y), Vector2(r.end.x - 6, y),
			Color(0.26, 0.18, 0.11, 0.35), 1.0)

	# EVERY HOLLOW FIRST, THEN EVERY WORD. One loop drawing recess-then-word meant
	# the next iteration's socket was painted straight over the last word, and the
	# words are the entire reason this object exists.
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

	for i in 3:
		var c := Vector2(0.0, (float(i) - 1.0) * SLOT_GAP)
		# INLAY. A groove cut in the oak, and bone sitting in the groove: the
		# dark cut offset toward the flame, the pale fill on top of it.
		var at := c + Vector2(-w * 0.5 + 8.0, 44.0)
		var bone := Color(0.72, 0.66, 0.52).lerp(Color(0.98, 0.92, 0.76), lit)
		Ink.line_centre(self, at + toward * 1.2, slot_words[i], 13,
			Color(0.10, 0.06, 0.04, 0.85), w - 16.0)
		Ink.line_centre(self, at, slot_words[i], 13, bone, w - 16.0)

class_name Surface
extends RefCounted

## How a surface takes the one flame in the room.
##
## Sits beside `Ink` and `WaxShape`: no state, no nodes, all static, and the
## drawing helpers take the CanvasItem to draw into.
##
## WHY THIS EXISTS
## ---------------
## Every object on this desk invented its own lighting from scratch. Nine scripts
## computed a direction to the flame by hand, in four different coordinate
## conventions and with two different unnormalised fallbacks; five clamped the
## `light_level x light_strength` product five different ways. Nothing was shared,
## so every new prop started from zero and every existing one drifted from its
## neighbours — and two objects lying side by side on the same desk went into
## shadow on different curves.
##
## This is an EXTRACTION, not a design. Every function here is lifted from code
## that already shipped and already looked right; `ReferenceBook._draw` and
## `SignetRing._draw` between them were the source of most of it. Nothing is
## migrated onto it in the commit that introduces it, on purpose — a helper that
## arrives together with ten rewritten `_draw` methods is a helper nobody can
## tell apart from a regression.
##
## THE ONE THING THAT WAS ALREADY WRONG
## ------------------------------------
## The two source files disagreed about which side of a cut line is the lit one,
## and extracting them into one place is what surfaced it. See `lip_offset`.

## The colour tanned leather, parchment and bare wood all go toward when the
## flame is close. Lifted from ReferenceBook, which had the most tuned version.
const WARM := Color(0.98, 0.63, 0.34)

## A hot specular on metal is never pure white — it is the flame's own colour.
const SPECULAR := Color(1.0, 0.93, 0.74)

## The flicker is allowed to move the whole desk's brightness by this much and no
## more. Below the floor the room would visibly pump; above the ceiling a gust
## would blow out the parchment.
const FLICKER_FLOOR := 0.7
const FLICKER_CEIL := 1.1

## Where the light is taken to come from when the flame is sitting exactly on top
## of the object and there is no meaningful direction to derive.
##
## Both original call sites had their own fallback and NEITHER was normalised —
## `Vector2(0.4, -1.0)` is 1.077 long and `Vector2(0.3, -1.0)` is 1.044, so an
## object whose flame was directly overhead drew its highlights 4-8% further out
## than one whose flame was anywhere else. Up and slightly to the right, unit
## length: the direction a candle set down beside a right-handed clerk comes from.
##
## Written out to six places rather than as the pleasanter-looking (0.36, -0.93),
## which is 0.9972 long. The suite asserts this to a thousandth and caught it —
## which is the entire argument for having written the assertion, given that the
## two call sites this replaces were out by 4% and 8% and nobody ever noticed.
const OVERHEAD := Vector2(0.360995, -0.932569)


## Unit vector toward the flame, in the node's OWN space.
##
## Local, not global: a highlight has to sit on the side the light is actually on
## however the object has been dropped, and papers on this desk are dropped at an
## angle. Two call sites normalised in global space and then used the result as
## if it were local, which is invisible only because those two objects happen
## never to be rotated.
static func toward(n: Node2D, light_position: Vector2) -> Vector2:
	var away := (light_position - n.global_position).rotated(-n.global_rotation)
	if away.length() < 1.0:
		return OVERHEAD
	return away.normalized()


## How much flame this object is getting, 0..1-ish.
##
## `light_level` is how much of the inverse-square falloff reaches this object;
## `light_strength` is the shared flicker, so everything on the desk pulses
## together rather than each object breathing on its own clock. The product is
## what every material response should read.
##
## Note this can exceed 1.0 at the top of the flicker, deliberately — a surface
## directly under the wick during a flare is allowed to blow out slightly. The
## one caller that clamped the product to 1.0 instead of clamping the factors
## (`Draggable.shade_alpha`) is left alone for now; it is the shade veil rather
## than a material, and changing it would move every page on the desk.
static func lit(level: float, strength: float) -> float:
	return clampf(level, 0.0, 1.0) * clampf(strength, FLICKER_FLOOR, FLICKER_CEIL)


## Warm near the flame, grey away from it.
##
## Two separate moves and they are not the same one: the lerp toward WARM is the
## fire's colour arriving, and the darken is the fall into the room's own shadow.
## An object that only lerps gets bright but never cools; one that only darkens
## turns grey under a candle, which is the single most common way a surface in
## this project has read as painted rather than lit.
static func tint(base: Color, lit_amount: float, warm_gain := 0.30,
		shade_gain := 0.18) -> Color:
	return base.lerp(WARM, lit_amount * warm_gain) \
		.darkened((1.0 - lit_amount) * shade_gain)


# ------------------------------------------------------------------- cut lines
#
# A line stamped or engraved into a surface is a GROOVE, and a groove has two
# walls. The wall on the far side of the groove faces back toward the flame and
# catches it; the wall on the near side faces away and is in shadow. So the lit
# part of a cut line is displaced AWAY from the light and the dark part toward
# it — which is the opposite of the intuition that says "the lit bit goes on the
# side the light is on", and is why this is written down here rather than left
# for each caller to get right.
#
# The two files this helper was extracted from disagreed about it. SignetRing
# drew its device's lit pass at `-toward` (correct — and it is the object whose
# engraving is most visible, being held under the lens). ReferenceBook drew its
# blind tooling with the lit lip at `+toward` and the trough at `-toward`, which
# is inverted, so the boards' stamped borders read as raised rather than
# impressed and swung the wrong way when the candle was carried past them.
#
# Neither is migrated here. The book's tooling is fixed in its own pass, with a
# capture either side of it, because that one is a visible change.

## Offset for the LIT wall of a cut line: away from the flame.
static func lip_offset(toward_light: Vector2, depth := 1.0) -> Vector2:
	return -toward_light * depth


## Offset for the SHADED wall of a cut line: toward the flame.
static func trough_offset(toward_light: Vector2, depth := 1.0) -> Vector2:
	return toward_light * depth


## The lit wall's colour. Gold-white, and only present while the flame is near —
## a groove in an unlit surface has no highlight at all, it is just dark.
static func lip_color(lit_amount: float, alpha := 0.20) -> Color:
	return Color(1.0, 0.86, 0.62, alpha * clampf(lit_amount, 0.0, 1.0))


## The shaded wall's colour. Not scaled by light: the inside of a groove stays
## dark whatever else happens, which is what makes it read as depth rather than
## as a drawn line that fades out with everything around it.
static func trough_color(alpha := 0.30) -> Color:
	return Color(0.0, 0.0, 0.0, alpha)


## A rectangular cut or boss, drawn as its two walls.
##
## `raised` flips it: a boss standing proud of the surface is lit on the side
## facing the flame, which is the exact inverse of a groove.
static func bevel_rect(c: CanvasItem, r: Rect2, toward_light: Vector2,
		lit_amount: float, raised := false, width := 1.5, depth := 1.0,
		lip_alpha := 0.20, trough_alpha := 0.30) -> void:
	var lip := lip_offset(toward_light, depth)
	var trough := trough_offset(toward_light, depth)
	if raised:
		var swap := lip
		lip = trough
		trough = swap
	c.draw_rect(Rect2(r.position + trough, r.size), trough_color(trough_alpha),
		false, width)
	c.draw_rect(Rect2(r.position + lip, r.size), lip_color(lit_amount, lip_alpha),
		false, width)


## The side wall of something with real thickness — a closed book, the ledge, a
## board. Drawn on the face turned AWAY from the flame, because that is the side
## of the block you can see when the light is on the other one, and it swings
## round as the candle is carried past.
static func extrude(c: CanvasItem, r: Rect2, toward_light: Vector2, base: Color,
		thickness: float, darken := 0.66) -> void:
	if thickness <= 0.01:
		return
	c.draw_rect(Rect2(r.position - toward_light * thickness, r.size),
		base.darkened(darken))


## A moving highlight on metal.
##
## The point is that it MOVES. Three metals whose base colours are far apart are
## still three grey discs in a dark room; what tells brass from iron from bronze
## is how each one catches a flame that the player is carrying, and a specular
## pinned to a fixed corner is a painted-on shine.
##
## `reach` is how far off centre the hot spot sits, `grow` how much bigger it
## gets with the flame, `fade` a caller-side multiplier for things like a ring
## sinking into wax and losing its bezel.
static func specular(c: CanvasItem, at: Vector2, toward_light: Vector2,
		lit_amount: float, reach: float, radius: float, grow := 1.1,
		alpha := 0.30, gain := 0.55, fade := 1.0) -> void:
	var l := clampf(lit_amount, 0.0, 1.0)
	var a := (alpha + gain * l) * fade
	if a <= 0.01:
		return
	c.draw_circle(at + toward_light * reach, radius + l * grow,
		Color(SPECULAR, a))

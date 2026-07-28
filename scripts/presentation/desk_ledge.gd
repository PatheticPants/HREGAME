class_name DeskLedge
extends Node2D

## A rack of pigeonholes along the back edge of the desk.
##
## WHY THIS EXISTS
## ---------------
## "The desk is deliberately too small" is only a mechanic if the player has some
## way to act on it. Without one it is just a cramped table and the answer to
## every problem is to shove things off the edge. The rack gives the crowding a
## verb: you decide, one object at a time, what you are not using right now, and
## you pay for that decision by having to fetch it again.
##
## It is emphatically NOT a tidy button. Nothing arranges itself, nothing snaps
## home on its own, and there is no "put everything away". You carry one thing to
## one hole.
##
## The centre is left open on purpose — that is where the petitioner stands, and
## a wall of shelved books in front of their face would be both ugly and rude.

const SLOT_SIZE := Vector2(214.0, 104.0)

## Slot centres in desk space.
##
## The rack stands on the back rail, just beyond the working surface, for two
## reasons. It costs the player the trip without eating the tabletop the whole
## design depends on being cramped — and a rack sitting *on* the desk collided
## with the charter, which is 585 units tall on a 660-unit desk and leaves no
## room for furniture.
##
## Two banks, left and right. The centre is left open because that is where the
## petitioner stands, and a wall of shelved books across their face would be both
## ugly and rude.
const SLOTS := [
	Vector2(-745.0, -310.0),
	Vector2(-510.0, -310.0),
	Vector2(510.0, -310.0),
	Vector2(745.0, -310.0),
]

## How close a drop has to be to count as putting something away. Generous:
## fumbling a book back onto the desk beside the rack is annoying, and the rack
## is unambiguous enough that a near miss is obviously a hit.
const CATCH_MARGIN := 74.0

var light_position := Vector2(0, -400)
var light_level := 0.5

## Which hole would catch what the player is currently carrying, or -1.
##
## Every other verb on this desk telegraphs before it commits — the candle tilts
## before it pours, the ring resists before it gives, the nib dimples before it
## smooths. Racking was the one action that revealed its outcome only in
## hindsight, after the mouse was already released. This is its anticipation.
var armed_slot := -1

## slot index -> the Draggable currently in it.
var _occupants: Dictionary = {}
var _glow: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_glow.resize(SLOTS.size())
	set_process(true)


## Same 7.0/s rate the objects' own hover glow uses, so the rack and the props
## speak the same visual language rather than two different dialects of "this
## will respond".
func _process(delta: float) -> void:
	var changed := false
	for i in SLOTS.size():
		var want := 1.0 if i == armed_slot else 0.0
		var next := move_toward(_glow[i], want, delta * 7.0)
		if not is_equal_approx(next, _glow[i]):
			_glow[i] = next
			changed = true
	if changed:
		queue_redraw()


func slot_count() -> int:
	return SLOTS.size()


func slot_position(index: int) -> Vector2:
	return SLOTS[clampi(index, 0, SLOTS.size() - 1)]


func slot_rect(index: int) -> Rect2:
	return Rect2(slot_position(index) - SLOT_SIZE * 0.5, SLOT_SIZE)


func occupant(index: int) -> Draggable:
	var who = _occupants.get(index, null)
	if not is_instance_valid(who):
		_occupants.erase(index)
		return null
	return who


## Nearest slot that would accept a drop at this point, or -1. Free slots only —
## a rack hole with a book already in it is full, and the second book stays in
## your hand rather than silently evicting the first.
func slot_for_drop(local_point: Vector2, ignoring: Draggable = null) -> int:
	var best := -1
	var best_distance := CATCH_MARGIN
	for i in SLOTS.size():
		var here := occupant(i)
		if here != null and here != ignoring:
			continue
		var r := slot_rect(i).grow(CATCH_MARGIN)
		if not r.has_point(local_point):
			continue
		var d := slot_position(i).distance_to(local_point)
		if d < best_distance or best == -1:
			best_distance = d
			best = i
	return best


func take(index: int, who: Draggable) -> void:
	release(who)
	_occupants[index] = who


func release(who: Draggable) -> void:
	for i in _occupants.keys():
		if _occupants[i] == who:
			_occupants.erase(i)


func slot_of(who: Draggable) -> int:
	for i in _occupants.keys():
		if _occupants[i] == who:
			return i
	return -1


# -------------------------------------------------------------------- drawing

func _draw() -> void:
	for i in SLOTS.size():
		_draw_hole(i)


func _draw_hole(index: int) -> void:
	var r := slot_rect(index)
	var warm := clampf(light_level, 0.0, 1.0)

	# Carcass: a box of dark oak standing on the desk, lit from wherever the
	# candle happens to be.
	var frame := r.grow(11.0)
	draw_rect(Rect2(frame.position + Vector2(4, 6), frame.size),
		Color(0, 0, 0, 0.34))
	draw_rect(frame, Color(0.20, 0.135, 0.078).lerp(
		Color(0.42, 0.27, 0.14), warm * 0.55))
	draw_rect(frame.grow(-4.0), Color(0.26, 0.175, 0.10).lerp(
		Color(0.50, 0.33, 0.17), warm * 0.45))

	# The hole itself. Nothing in a pigeonhole is ever properly lit.
	draw_rect(r, Color(0.055, 0.038, 0.028))
	# Depth: the inside of the top and left walls catch a little light.
	draw_rect(Rect2(r.position, Vector2(r.size.x, 7.0)),
		Color(0.14, 0.095, 0.06, 0.9))
	draw_rect(Rect2(r.position, Vector2(7.0, r.size.y)),
		Color(0.11, 0.075, 0.05, 0.9))

	if occupant(index) == null:
		# A faint runner across the empty hole so it reads as a place for
		# something rather than a hole in the desk.
		draw_line(r.position + Vector2(12, r.size.y - 13),
			Vector2(r.end.x - 12, r.end.y - 13),
			Color(0.30, 0.21, 0.13, 0.55), 2.0)

	# "Let go here and it will catch." Warm, like the flame and like the objects'
	# own hover, and drawn on the carcass where it is visible against dark oak.
	var glow: float = _glow[index]
	if glow > 0.01:
		for i in 3:
			var ring := frame.grow(1.0 + float(i) * 3.5)
			draw_rect(ring, Color(1.0, 0.84, 0.58,
				glow * 0.40 * (1.0 - float(i) / 3.0)), false, 2.5)
		draw_rect(r, Color(1.0, 0.80, 0.52, glow * 0.10))

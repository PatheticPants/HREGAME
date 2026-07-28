class_name DocketTray
extends Node2D

## A shallow passage tray fixed to the far lip of the desk. Docket slips remain
## physical desk objects; this fixture only tells the hand where a hearing begins.

## Five holds the rail without crowding it. The centre is deliberately skipped:
## that is where the hearing notch is, and a slip parked on top of the place you
## drop slips reads as a bug the first time and as a trap thereafter.
const SLOT_CENTERS := [
	Vector2(-640, -214),
	Vector2(-400, -214),
	Vector2(-160, -214),
	Vector2(400, -214),
	Vector2(640, -214),
]
const HEARING_SLOT := Rect2(-145, -180, 290, 105)

var visible_for_day := false
var armed := false


func show_for(count: int) -> void:
	visible_for_day = count > 0
	visible = visible_for_day
	queue_redraw()


func accepts(point: Vector2) -> bool:
	return visible_for_day and HEARING_SLOT.has_point(point)


func _draw() -> void:
	if not visible_for_day:
		return
	# The rail sits behind the protruding slips. The centre notch is deliberately
	# lighter and open toward the player: it reads as a destination, not a button.
	draw_rect(Rect2(-790, -248, 1580, 55), Color(0.16, 0.095, 0.055))
	draw_rect(Rect2(-786, -244, 1572, 47), Color(0.29, 0.18, 0.10))
	draw_line(Vector2(-786, -197), Vector2(786, -197),
		Color(0.08, 0.045, 0.025), 4.0)
	var notch := HEARING_SLOT
	draw_rect(notch, Color(0.12, 0.075, 0.045, 0.72))
	draw_rect(notch, Color(0.67, 0.50, 0.26, 0.65 if armed else 0.32),
		false, 3.0 if armed else 1.5)
	Ink.label(self, Vector2(notch.position.x + 66, notch.end.y - 26),
		"LAY ONE MATTER HERE", 9,
		Color(0.82, 0.69, 0.44, 0.82 if armed else 0.52))

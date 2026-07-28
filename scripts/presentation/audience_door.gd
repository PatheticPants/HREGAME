class_name AudienceDoor
extends Polygon2D

## A real textured door leaf projected onto an animated quadrilateral.
##
## The old door was a narrowing brown rectangle painted over a baked opening.
## This one has a stable hinge, full pixel-art surface and a small perspective
## skew as it swings inward. The passage behind it belongs to the room plate.

const DOOR_TEXTURE := preload("res://art/environment/chancery_door_leaf.png")
const DOOR_SIZE := Vector2(390.0, 715.0)

var open_amount := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = DOOR_TEXTURE
	uv = PackedVector2Array([
		Vector2(0, 0),
		Vector2(DOOR_TEXTURE.get_width(), 0),
		Vector2(DOOR_TEXTURE.get_width(), DOOR_TEXTURE.get_height()),
		Vector2(0, DOOR_TEXTURE.get_height()),
	])
	set_open_amount(0.0)


func set_open_amount(value: float) -> void:
	open_amount = clampf(value, 0.0, 1.0)
	var t := open_amount * open_amount * (3.0 - 2.0 * open_amount)
	var outer_x := lerpf(DOOR_SIZE.x, 19.0, t)
	var top_skew := 13.0 * t
	var bottom_skew := 8.0 * t

	polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(outer_x, top_skew),
		Vector2(outer_x, DOOR_SIZE.y - bottom_skew),
		Vector2(0, DOOR_SIZE.y),
	])
	# The face loses direct candlelight as it turns into the passage.
	color = Color(1.0 - t * 0.43, 1.0 - t * 0.46, 1.0 - t * 0.49, 1.0)


func projected_width() -> float:
	if polygon.size() < 2:
		return 0.0
	return polygon[1].x

class_name DocumentData
extends Resource

## Base for anything that lands on the desk as a physical sheet.
##
## Presentation reads only the fields in this base class — size, tint, label —
## so adding a new document type never means touching the drag or stacking code.

@export var id: StringName = &""
@export var kind: StringName = &"paper"
@export var title: String = ""

## Placeholder sheet size in desk units. Different documents being different
## sizes is most of what makes a pile readable at a glance.
@export var size: Vector2 = Vector2(360, 470)
@export var tint: Color = Color(0.85, 0.80, 0.68)

## Where it starts on the desk, and how askew. Nothing is ever laid down square.
@export var start_offset: Vector2 = Vector2.ZERO
@export var start_angle_deg: float = 0.0

## Can the verdict wax be applied to this sheet? Only the charter, normally.
@export var takes_seal: bool = false

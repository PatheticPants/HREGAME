class_name BookData
extends Resource

## A reference book on the desk. One scene renders all of them; the difference
## between the Almanac and the Book of Matrices is entirely this resource.

@export var id: StringName = &""
@export var title: String = ""
@export var subtitle: String = ""

@export var cover_color: Color = Color(0.35, 0.22, 0.16)
@export var page_color: Color = Color(0.90, 0.86, 0.74)

## Closed size on the desk. Opening doubles the width, which is why the desk is
## too small — two open books and a charter do not fit, and choosing what to
## close is the same decision as choosing what to check.
@export var size: Vector2 = Vector2(300, 380)

@export var start_offset: Vector2 = Vector2.ZERO
@export var start_angle_deg: float = 0.0

@export var pages: Array[BookPage] = []


func spread_count() -> int:
	## Pages are shown two at a time.
	return int(ceil(pages.size() / 2.0))

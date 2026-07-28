class_name ViewHint
extends Control

## The only thing on screen that is not an object, so it is built to leave.
##
## There is one control the world cannot teach you — that you are allowed to look
## up from the desk — and it has to be said once. After the player uses it, the
## hint fades out completely over a few seconds and does not come back. A
## permanent legend in the corner of a game with no HUD is worse than no legend
## at all, and by then they already know.
##
## Drawn as a caption rather than a widget: no panel, no border, just an arrow
## and small lettering, so what remains before it goes reads as part of the room.

const FADE_AFTER := 1.4
const FADE_TIME := 2.6

var amount := 0.0
var has_used_view := false

var _since_used := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func set_view_amount(value: float) -> void:
	amount = clampf(value, 0.0, 1.0)
	queue_redraw()


func note_used() -> void:
	has_used_view = true
	queue_redraw()


func _process(delta: float) -> void:
	if not has_used_view:
		return
	if _since_used <= FADE_AFTER + FADE_TIME:
		_since_used += delta
		queue_redraw()


## 1 until the view has been used, then eased to 0 and gone for good.
func retirement() -> float:
	if not has_used_view:
		return 1.0
	# Curved, like everything else that moves here. If this is going to be the
	# one screen-space element in the game, its single moment of motion should
	# not be the one linear tween left in the build.
	return 1.0 - ease(
		clampf((_since_used - FADE_AFTER) / FADE_TIME, 0.0, 1.0), 0.5)


func _draw() -> void:
	var life := retirement()
	if life <= 0.005:
		return
	var work_alpha := (1.0 - amount) * 0.52 * life
	var audience_alpha := amount * 0.40 * life
	var at := Vector2(maxf(180.0, size.x - 190.0), 24.0)

	if work_alpha > 0.01:
		_draw_hint(at, true, work_alpha, "look up   w / up / scroll")
	if audience_alpha > 0.01:
		_draw_hint(at, false, audience_alpha, "return to desk   s / down / scroll")


func _draw_hint(centre: Vector2, points_up: bool, alpha: float, text: String) -> void:
	var text_size := Ink.measure(text, 11)
	var width := text_size.x + 30.0
	var left := clampf(centre.x - width * 0.5, 12.0,
		maxf(12.0, size.x - width - 12.0))
	var baseline := centre.y + 7.0

	var arrow_x := left + 7.0
	var direction := -1.0 if points_up else 1.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(arrow_x, baseline + 4.0 * direction),
		Vector2(arrow_x - 5.0, baseline - 2.5 * direction),
		Vector2(arrow_x + 5.0, baseline - 2.5 * direction),
	]), Color(0.78, 0.64, 0.40, alpha * 0.9))
	Ink.label(self, Vector2(left + 20.0, centre.y), text, 11,
		Color(0.78, 0.70, 0.56, alpha))

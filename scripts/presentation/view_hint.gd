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

## THE TWO CAPTIONS RETIRE SEPARATELY, AND ONLY ON ARRIVAL.
##
## They used to share one flag set from the input handler, so any key or wheel
## event in either direction retired both — including a wheel-down at t=0, which
## moves nothing and gives no feedback at all. That silently deleted the only
## instruction in the game before the player had followed it once, and took the
## way back with it.
##
## Now each is set from the view amount itself, which means the caption goes away
## exactly when the player has done the thing it was describing.
var has_looked_up := false
var has_returned := false

var _up_since := 0.0
var _back_since := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func set_view_amount(value: float) -> void:
	amount = clampf(value, 0.0, 1.0)
	queue_redraw()


func note_looked_up() -> void:
	if has_looked_up:
		return
	has_looked_up = true
	queue_redraw()


## Only meaningful once they have been up: coming "back" without having left is
## not an accomplishment, and at the start of the day the view is already down.
func note_returned() -> void:
	if has_returned or not has_looked_up:
		return
	has_returned = true
	queue_redraw()


## Retained for older callers and for the tests, which ask one question: has this
## thing begun to go away yet.
func note_used() -> void:
	note_looked_up()


func has_used_view() -> bool:
	return has_looked_up


func _process(delta: float) -> void:
	if has_looked_up and _up_since <= FADE_AFTER + FADE_TIME:
		_up_since += delta
		queue_redraw()
	if has_returned and _back_since <= FADE_AFTER + FADE_TIME:
		_back_since += delta
		queue_redraw()


## 1 until the plane has actually been visited, then eased to 0 and gone for good.
func _retirement(used: bool, since: float) -> float:
	if not used:
		return 1.0
	# Curved, like everything else that moves here. If this is going to be the
	# one screen-space element in the game, its single moment of motion should
	# not be the one linear tween left in the build.
	return 1.0 - ease(clampf((since - FADE_AFTER) / FADE_TIME, 0.0, 1.0), 0.5)


func retirement() -> float:
	return _retirement(has_looked_up, _up_since)


func _draw() -> void:
	var up_life := _retirement(has_looked_up, _up_since)
	var back_life := _retirement(has_returned, _back_since)
	if up_life <= 0.005 and back_life <= 0.005:
		return
	var work_alpha := (1.0 - amount) * 0.52 * up_life
	var audience_alpha := amount * 0.40 * back_life
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

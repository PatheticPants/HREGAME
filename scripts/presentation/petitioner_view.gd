class_name PetitionerView
extends Node2D

## The person on the other side of the desk.
##
## Each petitioner is an authored, straight-on pixel portrait, framed from the
## chest upward behind the far edge of the desk. The face always addresses the
## player. Motion is restricted to breathing, blinks and minute weight shifts:
## enough life to prevent a cutout, never enough to break the confrontation.
##
## Speech appears in world space beside them, on a slip of light. No HUD, no
## portrait box, no dialogue tray at the bottom of the screen.

signal finished_speaking()

const BUBBLE_W := 430.0
const ART_SCALE := 1.36

## Where the doorway is relative to the standing mark, and how far back into the
## room an arriving petitioner starts. They walk in from the door's side and
## forward out of the depth of the room rather than rising on the spot.
const DOOR_SIDE := -300.0
const APPROACH_RISE := 34.0
## How much smaller they are at the far end of that walk. Perspective, applied
## to a person, on the same plane the desk already foreshortens.
const APPROACH_DISTANT_SCALE := 0.72

var data: PetitionerData = null
var light_position := Vector2(0, -400)
var light_strength := 1.0
## Same inverse-square reach the desk objects use, so carrying the candle toward
## the far edge visibly brings the person across the desk out of the dark.
var light_level := 0.4

var _queue: Array[String] = []
var _current := ""
var _reveal := 0.0
var _sway := 0.0
var _shift := 0.0
var _shift_target := 0.0
var _next_shift := 3.0
var _present := 0.0      ## 0 offstage, 1 at the desk
var _speaker := ""
var _departing := false
var _arrived := false
var _step_beat := 0.0
var _portrait: Texture2D = null
var _blink_left := 0.0
var _next_blink := 2.0


func _ready() -> void:
	# The source art was deliberately quantized before import. Nearest filtering
	# preserves those authored clusters instead of airbrushing them at runtime.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func bind(p: PetitionerData) -> void:
	data = p
	name = "petitioner_" + String(p.id)
	_portrait = null
	if not p.portrait_path.is_empty() and ResourceLoader.exists(p.portrait_path):
		_portrait = load(p.portrait_path) as Texture2D
	elif not p.portrait_path.is_empty():
		push_warning("[petitioner] portrait not found: " + p.portrait_path)
	_present = 0.0
	_departing = false
	_arrived = false
	_step_beat = 0.0
	_blink_left = 0.0
	_next_blink = randf_range(1.4, 3.6)
	set_process(true)


func arrive() -> void:
	_present = 0.0
	_departing = false


func depart() -> void:
	_departing = true


func is_speaking() -> bool:
	return not _current.is_empty() or not _queue.is_empty()


func say_all(lines: Array[String], speaker := "") -> void:
	_speaker = speaker
	_queue = lines.duplicate()
	_advance()


func say(line: String, speaker := "") -> void:
	_speaker = speaker
	_queue.append(line)
	if _current.is_empty():
		_advance()


## Click to continue. If the line is still typing itself out, the first click
## completes it and the second moves on — the standard courtesy.
func on_click() -> bool:
	if _current.is_empty():
		return false
	if _reveal < 1.0:
		_reveal = 1.0
		return true
	_advance()
	return true


func _advance() -> void:
	if _queue.is_empty():
		_current = ""
		finished_speaking.emit()
		return
	_current = _queue.pop_front()
	_reveal = 0.0
	Audio.play(&"cloth_shift", global_position)


func clear() -> void:
	_queue.clear()
	_current = ""
	data = null
	_portrait = null
	_present = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if data == null:
		return
	var was_present := _present
	_present = move_toward(_present, 0.0 if _departing else 1.0,
		delta * (1.35 if _departing else 0.9))

	# Footfalls across the room, and a settle when they reach the mark. The
	# figure used to appear in complete silence — the same missing third phase
	# the rack had, on the one object in the room that is a person.
	if not _departing and not _arrived:
		_step_beat += delta
		if _step_beat > 0.42 and _present < 0.94:
			_step_beat = 0.0
			Audio.play(&"footfall", global_position,
				-6.0 - (1.0 - _present) * 7.0)
		if was_present < 1.0 and _present >= 1.0:
			_arrived = true
			Audio.play(&"cloth_shift", global_position, -8.0)

	# Idle sway: a slow figure-of-eight, faster and wider the more restless.
	_sway += delta * (0.6 + data.restlessness * 1.4)

	# Weight shifts: discrete, occasional, and audible. This is what stops a
	# standing figure from looking like a cardboard cutout.
	_shift = lerpf(_shift, _shift_target, clampf(delta * 3.0, 0.0, 1.0))
	_next_shift -= delta
	if _next_shift <= 0.0:
		_shift_target = randf_range(-1.0, 1.0) * (0.4 + data.restlessness)
		_next_shift = randf_range(2.4, 6.5) - data.restlessness * 1.8
		Audio.play(&"cloth_shift", global_position, -6.0)

	if not _current.is_empty() and _reveal < 1.0:
		# Roughly forty letters a second, so a long line takes a beat to land.
		_reveal = minf(1.0, _reveal + delta * 40.0 / maxf(8.0, _current.length()))

	_blink_left = maxf(0.0, _blink_left - delta)
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_left = 0.10
		_next_blink = randf_range(2.7, 6.8) + (1.0 - data.restlessness) * 0.8

	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var enter := ease(clampf(_present, 0.0, 1.0), 0.4)
	# APPROACH AND WITHDRAWAL.
	#
	# People used to leave by walking off toward the door and arrive by
	# materialising upward on the spot — two different physical acts for the same
	# doorway. Now both traverse the room, and arrival additionally comes toward
	# the desk *through the perspective*: they start smaller and further off,
	# nearer the door's side of the room, and grow as they close the distance.
	#
	# This is the first time the room's depth and a character's motion are the
	# same system rather than two that happen to share a screen.
	var from_door := Vector2(DOOR_SIDE, -APPROACH_RISE)
	var offset := Vector2.ZERO
	if _departing:
		offset = Vector2(-(1.0 - enter) * 90.0, (1.0 - enter) * 58.0)
	else:
		offset = from_door * (1.0 - enter)
	var alpha := enter

	_draw_figure(offset, alpha)
	if not _current.is_empty():
		_draw_speech(offset)


func _draw_figure(offset: Vector2, alpha: float) -> void:
	var h := data.height
	var b := data.build
	var speaking := 0.0 if _current.is_empty() else 1.0
	var lean := Vector2(sin(_sway) * 2.0 + _shift * 4.5,
		cos(_sway * 1.7) * 1.0 - speaking * absf(sin(_sway * 3.4)) * 0.7)
	var base := offset + Vector2(0, 0)

	# The person across the desk is lit by the same candle as everything else.
	# Bringing it to the far edge of the desk brings their face out of the dark,
	# which is a thing a player will do without being told to.
	var warm := clampf(light_level * 1.35, 0.0, 1.0) \
		* clampf(light_strength, 0.65, 1.15)
	if _portrait == null:
		_draw_fallback_figure(base, lean, alpha)
		return

	var target_h := h * ART_SCALE
	var target_w := target_h * float(_portrait.get_width()) \
		/ maxf(1.0, float(_portrait.get_height()))
	var breath := sin(_sway * 0.82) * (0.0025 + data.restlessness * 0.0015)
	var turn := _shift * 0.0018 + sin(_sway * 0.57) * 0.0012
	var body_scale := Vector2(1.0 - breath * 0.45, 1.0 + breath)
	# Perspective on the approach: smaller at the far end of the walk, full size
	# at the standing mark. Departure keeps its own established motion.
	if not _departing:
		var closeness := ease(clampf(_present, 0.0, 1.0), 0.4)
		body_scale *= lerpf(APPROACH_DISTANT_SCALE, 1.0, closeness)
	draw_set_transform(base + lean, turn, body_scale)

	var portrait_rect := Rect2(Vector2(-target_w * 0.5, -target_h),
		Vector2(target_w, target_h))

	# A one-pixel warm echo behind the sprite creates a candle-facing rim without
	# tinting the authored skin and cloth colors.
	if warm > 0.02:
		var light_dir := (light_position - global_position).normalized()
		var rim_rect := Rect2(portrait_rect.position + light_dir * 1.8,
			portrait_rect.size)
		draw_texture_rect(_portrait, rim_rect, false,
			Color(1.0, 0.57, 0.24, 0.17 * warm * alpha))
	draw_texture_rect(_portrait, portrait_rect, false, Color(1, 1, 1, alpha))

	# The sprite stays rigid enough to read as pixel art, but the face is alive.
	# A brief dark pair of strokes covers the authored open eyes during a blink.
	if _blink_left > 0.0:
		var eye_y := -target_h * 0.685
		var eye_gap := target_w * 0.105
		var eye_half := maxf(1.3, target_w * 0.030)
		var lid := Color(0.15, 0.095, 0.065, alpha * 0.88)
		draw_line(Vector2(-eye_gap - eye_half, eye_y),
			Vector2(-eye_gap + eye_half, eye_y), lid, 1.5)
		draw_line(Vector2(eye_gap - eye_half, eye_y),
			Vector2(eye_gap + eye_half, eye_y), lid, 1.5)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Robust straight-on bust fallback for a missing import.
func _draw_fallback_figure(base: Vector2, lean: Vector2, alpha: float) -> void:
	var h := data.height
	var b := data.build
	var cloth := Color(data.cloth, data.cloth.a * alpha)
	var accent := Lore.tincture(data.polity_id, cloth.lightened(0.2))
	accent.a = alpha
	var shoulder := base + Vector2(0, -h * 0.43) + lean * 0.7
	var head := base + Vector2(0, -h * 0.72) + lean

	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-b * 0.62, 0),
		shoulder + Vector2(-b * 0.48, 0), shoulder + Vector2(b * 0.48, 0),
		base + Vector2(b * 0.62, 0),
	]), cloth)
	draw_line(shoulder + Vector2(-b * 0.42, 8), base + Vector2(-b * 0.26, -3),
		accent.darkened(0.3), b * 0.22, true)
	draw_line(shoulder + Vector2(b * 0.42, 8), base + Vector2(b * 0.26, -3),
		accent.darkened(0.3), b * 0.22, true)
	draw_circle(head, b * 0.25, Color(0.62, 0.49, 0.39, alpha))
	draw_arc(head + Vector2(0, 2), b * 0.17, PI * 1.08, PI * 1.92, 10,
		Color(0.19, 0.12, 0.08, alpha), 1.5)
	draw_circle(head + Vector2(-b * 0.08, -2), 1.5,
		Color(0.12, 0.08, 0.06, alpha))
	draw_circle(head + Vector2(b * 0.08, -2), 1.5,
		Color(0.12, 0.08, 0.06, alpha))


## A slip of light beside the speaker. Not a UI panel: it is placed in the world
## next to the mouth it came out of, and it goes away when they stop talking.
func _draw_speech(offset: Vector2) -> void:
	var shown := _current.substr(0, int(ceil(_current.length() * _reveal)))
	var size := Ink.measure(_current, 14, BUBBLE_W - 36.0)
	var box := Rect2(Vector2(data.build * 0.9, -data.height * ART_SCALE * 0.95) + offset,
		Vector2(BUBBLE_W, size.y + 46.0))

	draw_rect(box.grow(4.0), Color(0, 0, 0, 0.28))
	draw_rect(box, Color(0.94, 0.90, 0.78, 0.97))
	draw_rect(box, Color(0.62, 0.55, 0.42), false, 1.0)

	# A small tongue pointing back at the speaker.
	draw_colored_polygon(PackedVector2Array([
		box.position + Vector2(0, 26),
		box.position + Vector2(-16, 40),
		box.position + Vector2(0, 52),
	]), Color(0.94, 0.90, 0.78, 0.97))

	var at := box.position + Vector2(18, 14)
	if not _speaker.is_empty():
		at.y += Ink.label(self, at, _speaker, 9, Ink.FADED)
		at.y += 2.0
	Ink.block(self, at, shown, 14, Ink.CHANCERY, BUBBLE_W - 36.0)

	if _reveal >= 1.0:
		# The only affordance in the game that is not an object: a small mark
		# saying there is more. Drawn inside the slip, in ink.
		var tick := box.end - Vector2(20, 16)
		draw_colored_polygon(PackedVector2Array([
			tick, tick + Vector2(-9, -7), tick + Vector2(-9, 7)]),
			Color(Ink.FADED, 0.55 + 0.35 * sin(_sway * 3.0)))

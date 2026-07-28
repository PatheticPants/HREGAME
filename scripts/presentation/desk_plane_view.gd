class_name DeskPlaneView
extends Node2D

## The authored work surface, separated from the far room so it can foreshorten
## around its back edge when the player's gaze tilts upward.

const DESK_TEXTURE := preload("res://art/environment/desk_surface.png")

var desk: Desk


func bind(owner_desk: Desk) -> void:
	desk = owner_desk
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(DESK_TEXTURE, Desk.DESK_RECT.grow(26.0), false)
	if desk == null:
		return
	_draw_wax_memories()
	_draw_sealing_kit()


## A small supply box makes the source of the color legible before the player
## picks up the spoon: beeswax and resin worked with vermilion pigment.
func _draw_sealing_kit() -> void:
	var box := Rect2(Vector2(520, -232), Vector2(118, 58))
	draw_rect(Rect2(box.position + Vector2(5, 6), box.size),
		Color(0, 0, 0, 0.19))
	draw_rect(box, Color(0.18, 0.115, 0.055))
	draw_rect(box.grow(-4), Color(0.33, 0.22, 0.095))
	draw_rect(box.grow(-8), Color(0.22, 0.13, 0.06), false, 1.5)
	Ink.label(self, box.position + Vector2(11, 8), "VERMILION", 8,
		Color(0.80, 0.66, 0.38))
	Ink.label(self, box.position + Vector2(11, 22), "RESIN & WAX", 7,
		Color(0.64, 0.54, 0.34))

	for i in 2:
		var at := box.position + Vector2(77 + i * 17, 39)
		draw_circle(at + Vector2(1.5, 2.0), 8.0, Color(0, 0, 0, 0.22))
		draw_circle(at, 7.4, Color(0.47, 0.045, 0.075))
		draw_line(at + Vector2(-4, 0), at + Vector2(4, 0),
			Color(0.76, 0.20, 0.19, 0.55), 1.2)


func _draw_wax_memories() -> void:
	var wax := Color(0.43, 0.075, 0.09, 0.74)
	for memory: Dictionary in desk._wax_memories:
		var at: Vector2 = memory["at"]
		var grade := int(memory["grade"])
		var radius := 7.0
		if grade == Lex.Grade.BLOTTED:
			radius = 11.0
		elif grade == Lex.Grade.SMEARED:
			radius = 9.0
		elif grade == Lex.Grade.THIN:
			radius = 5.0

		for crumb: Vector3 in memory["crumbs"]:
			draw_circle(at + Vector2(crumb.x, crumb.y), crumb.z,
				wax.darkened(0.08))

		# The authored wax plates live here rather than on the live pool. Each
		# one has a rim and a sunken centre painted into it, which is a *centred*
		# impression baked in — wrong for a pool the player is still choosing
		# where to strike, and exactly right for a cold discarded crumb that will
		# never be struck again.
		var plate: Texture2D = WaxPool.WAX_TEXTURES[
			posmod(int(memory.get("plate", 0)), WaxPool.WAX_TEXTURES.size())]
		var span := radius * 2.6
		draw_texture_rect(plate,
			Rect2(at - Vector2.ONE * span * 0.5 + Vector2(1.5, 2.0),
				Vector2.ONE * span), false, Color(0, 0, 0, 0.16))
		draw_texture_rect(plate,
			Rect2(at - Vector2.ONE * span * 0.5, Vector2.ONE * span),
			false, Color(wax.darkened(0.10), 0.92))

		draw_set_transform(at, float(memory["rotation"]), Vector2.ONE)
		Heraldry.draw_device_incuse(self, memory["device"], Vector2.ZERO,
			radius * 0.62, wax, 0.55)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

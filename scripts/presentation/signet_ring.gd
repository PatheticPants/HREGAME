class_name SignetRing
extends Draggable

## One of the three rings. Which ring you pick up IS the ruling — there is no
## verdict button anywhere in the game, and no confirmation step. Wax and metal,
## and then it is done.
##
## Three physical rings rather than one ring and a selector, because the choice
## has to cost desk space like everything else, and because reaching past the
## Deny ring to get the Confirm one should be a thing your hand does.

const RADIUS := 34.0

## The engraved face that actually touches wax — much smaller than the bezel the
## art draws. The wax pool intersects a circle of this size against its own
## silhouette to work out how much of the device took, so it is a gameplay
## constant, not a drawing one.
const DIE_RADIUS := 30.0
const CONFIRM_TEXTURE := preload("res://art/props/signet_confirm.png")
const DENY_TEXTURE := preload("res://art/props/signet_deny.png")
const REFER_TEXTURE := preload("res://art/props/signet_refer.png")

var verdict := Lex.Verdict.NONE
var device: StringName = &"notary_confirm"
var metal := Color(0.78, 0.72, 0.52)

## Sink amount while pressing, 0..1. Set by PressController.
var press_depth := 0.0

## Per-press rotation jitter, so no two impressions are identical.
var press_rotation := 0.0

## Presentation envelopes driven by PressController. Resistance is the tiny
## lateral fight before the wax gives; peel is the sticky lift afterwards.
var resistance_amount := 0.0
var peel_amount := 0.0
## Short compression pulse at the instant the resistant wax gives.
var seat_impact := 0.0

## Where this ring lives when not in the player's hand.
var home_position := Vector2.ZERO


func _ready() -> void:
	super._ready()
	hit_size = Vector2(RADIUS * 2.3, RADIUS * 2.6)
	pickup_sound = &"ring_pickup"
	drop_sound = &"stamp_set"
	slide_sound = &""
	# Small and solid. The hit box is generous so the ring is easy to grab; the
	# shadow is not, or a ring would darken half a charter.
	occludes_light = true
	occluder_round = true
	occluder_inset = 0.58
	# Small and dense: a signet follows the hand tightly and stops dead.
	weight = 1.65
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 0


func bind(v: int, desk_bounds: Rect2, at: Vector2) -> void:
	verdict = v
	home_position = at
	match v:
		Lex.Verdict.CONFIRM:
			device = &"notary_confirm"
			metal = Color(0.82, 0.74, 0.48)
		Lex.Verdict.DENY:
			device = &"notary_deny"
			metal = Color(0.62, 0.60, 0.58)
		_:
			device = &"notary_refer"
			metal = Color(0.72, 0.62, 0.44)
	name = "ring_" + Lex.verdict_name(v).to_lower()
	setup(at, deg_to_rad(randf_range(-8.0, 8.0)), desk_bounds)


func word() -> String:
	match verdict:
		Lex.Verdict.CONFIRM: return "CONFIRMO"
		Lex.Verdict.DENY: return "NEGO"
		Lex.Verdict.REFER: return "REFERO"
		_: return ""


func ring_texture() -> Texture2D:
	match verdict:
		Lex.Verdict.CONFIRM: return CONFIRM_TEXTURE
		Lex.Verdict.DENY: return DENY_TEXTURE
		_: return REFER_TEXTURE


func _process(delta: float) -> void:
	super._process(delta)
	seat_impact = move_toward(seat_impact, 0.0, delta * 5.8)
	# Child order governs the resting desk, but the pool is a child of the sheet
	# with z=1. Temporarily rise above it while held or peeling, then return to
	# ordinary stack order so a discarded ring can still be buried by paper.
	z_index = 3 if is_held or press_depth > 0.001 or peel_amount > 0.001 else 0


func _draw() -> void:
	# The ring sinks as it presses, so the shadow tightens and the metal gets a
	# little smaller as the bezel disappears into the wax.
	var sink := press_depth
	var r := RADIUS * (1.0 - sink * 0.04 - seat_impact * 0.025)
	var clock := Time.get_ticks_msec() * 0.001
	var fight := Vector2(sin(clock * 71.0), cos(clock * 53.0) * 0.45) \
		* resistance_amount * 1.8
	var sticky_lift := Vector2(0, -sin(peel_amount * PI) * 12.0)
	var visual_offset := fight + sticky_lift
	draw_set_transform(visual_offset, 0.0, Vector2.ONE)

	var art_size := Vector2(r * 2.48, r * 2.48)
	draw_soft_shadow(Rect2(-art_size * Vector2(0.48, 0.34),
		art_size * Vector2(0.96, 0.68)), 1.0)
	draw_texture_rect(ring_texture(), Rect2(-art_size * 0.5, art_size), false,
		Color(1.0 - sink * 0.08, 1.0 - sink * 0.09, 1.0 - sink * 0.11, 1.0))

	# The die itself, cut in reverse. Drawn the right way round anyway, because a
	# mirrored placeholder glyph just reads as a mistake.
	draw_set_transform(visual_offset + Vector2(0, -1.5), press_rotation, Vector2.ONE)
	Heraldry.draw_device(self, device, Vector2.ZERO, r * 0.47,
		metal.darkened(0.55))
	draw_set_transform(visual_offset, 0.0, Vector2.ONE)

	# Rim highlight, cut back as the ring is pushed into wax.
	draw_arc(Vector2(0, -1.5), r * 0.66, PI * 1.05, PI * 1.85, 18,
		Color(1, 1, 1, 0.35 * (1.0 - sink)), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

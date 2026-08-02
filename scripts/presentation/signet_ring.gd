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

## THE BLOCK TAKES THE RING BACK.
##
## Reported from play: "the stamps should lock into place when putting them back
## — right now they can just float off if you are trying to put them back
## quickly." Exactly right, and it is DragSolver._step_free: a released body
## keeps its velocity and bleeds it by pow(release_damping, h), so a ring let go
## on the move coasts past its hollow and settles wherever it ran out. Nothing
## anywhere seated a ring; home_position was written once at bind() and then only
## ever read by the tests.
##
## A turned oak block with a dished recess in it does not let a ring roll back
## out. So within SEAT_CATCH of its OWN hollow — its own, because the words are
## cut into the wood and a ring seated under the wrong word would make the block
## lie — it is drawn down into the dish and stops there.
##
## Its own hollow only, and a catch smaller than half the slot gap, so this can
## never carry a ring somewhere the hand did not put it. Outside that radius a
## ring lies on the desk like anything else and can be buried by paper.
var _seated := false


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
		# Three metals, deliberately far enough apart to tell at a glance in a dark
		# room: gilt brass, cold iron, and a red bronze. CONFIRM and REFER used to
		# be 0.82/0.74/0.48 and 0.72/0.62/0.44 — near-identical plates, on the two
		# rings whose meanings are furthest apart.
		Lex.Verdict.CONFIRM:
			device = &"notary_confirm"
			metal = Color(0.88, 0.76, 0.42)
		Lex.Verdict.DENY:
			device = &"notary_deny"
			metal = Color(0.55, 0.55, 0.58)
		_:
			device = &"notary_refer"
			metal = Color(0.66, 0.46, 0.28)
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
	_settle_into_its_hollow(delta)
	# Child order governs the resting desk. A ring in the hand or in the wax has
	# to be above the sheet it is pressing into — you are holding it over the
	# document — so it rises for exactly as long as that is true and then returns
	# to ordinary stack order, where a discarded ring can be buried by paper like
	# anything else.
	z_index = 3 if is_held or press_depth > 0.001 or peel_amount > 0.001 else 0


## Draw the ring down into its recess once the hand has let go near it.
##
## A direct approach rather than a spring: a spring near a rest point overshoots
## and a ring that bounces in its socket looks like a bug rather than like metal
## in a dished hollow. Speed scales with distance so it eases in, with a floor so
## the last two units do not crawl.
func _settle_into_its_hollow(delta: float) -> void:
	if is_held or press_depth > 0.001 or peel_amount > 0.001 or stowed:
		_seated = false
		return
	var gap := home_position - solver.position
	var distance := gap.length()
	if distance > RingStand.SEAT_CATCH:
		_seated = false
		return
	if distance < 0.6:
		if not _seated:
			_seated = true
			solver.position = home_position
			solver.velocity = Vector2.ZERO
			solver.angular_velocity = 0.0
			solver.angle = solver.rest_angle
			solver.sleeping = true
			position = home_position
			# The END of the action, the same third phase the rack got: metal
			# arriving in wood. Quiet, because the drop already sounded when the
			# hand opened and this is the settle after it.
			Audio.play(&"stamp_set", global_position, -9.0)
		return
	solver.sleeping = false
	solver.position = solver.position.move_toward(home_position,
		delta * maxf(70.0, distance * 7.0))
	# Bleed what the hand threw at it, or the seat fights the release velocity
	# and the ring skates around the socket before it goes in.
	solver.velocity = solver.velocity.lerp(Vector2.ZERO, minf(1.0, delta * 9.0))
	position = solver.position


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

	# THE DIE, CUT INTO METAL RATHER THAN PAINTED ON IT.
	#
	# A single pass in metal.darkened(0.55) was legible on the gold CONFIRM ring
	# and effectively invisible on the dark iron DENY one — so the ring that ends
	# a person's claim was the one you could not identify in your hand. An engraved
	# device has a lit lip and a dark trough, and drawing both makes it read on
	# every metal in the stand at the cost of one extra call.
	var toward := (light_position - global_position).rotated(-global_rotation)
	if toward.length() > 1.0:
		toward = toward.normalized()
	else:
		toward = Vector2(0.3, -1.0)
	draw_set_transform(visual_offset + Vector2(0, -1.5) - toward * 1.3,
		press_rotation, Vector2.ONE)
	Heraldry.draw_device(self, device, Vector2.ZERO, r * 0.47,
		metal.lightened(0.55))
	draw_set_transform(visual_offset + Vector2(0, -1.5), press_rotation, Vector2.ONE)
	Heraldry.draw_device(self, device, Vector2.ZERO, r * 0.47,
		metal.darkened(0.72))
	draw_set_transform(visual_offset, 0.0, Vector2.ONE)

	# A moving specular on the bezel, so brass and iron are told apart by how they
	# catch the flame rather than only by their base colour — and so carrying the
	# candle across the desk does visible work on the metal as well as the paper.
	var spec := toward * r * 0.52
	var sheen := clampf(light_level, 0.0, 1.0) * clampf(light_strength, 0.7, 1.1)
	if sheen > 0.02:
		draw_circle(spec, 2.4 + sheen * 2.0,
			Color(1.0, 0.94, 0.78, (0.18 + 0.42 * sheen) * (1.0 - sink)))

	# Rim highlight, cut back as the ring is pushed into wax.
	draw_arc(Vector2(0, -1.5), r * 0.66, PI * 1.05, PI * 1.85, 18,
		Color(1, 1, 1, 0.35 * (1.0 - sink)), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

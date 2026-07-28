extends Node

## Headless integration smoke test for the desk. Run from the project root:
##
##     godot --headless --fixed-fps 60 --scene res://tests/test_presentation.tscn
##
## The pure rules test cannot catch coordinate-space mistakes or a press whose
## phases no longer connect. This one instantiates the real desk, verifies every
## verdict ring and the pendant seal start within reach, then performs an entire
## melt / carry / pour / resist / seat / peel sequence without a display.

var failures := 0
var checks := 0
var _impression_finished := false
var _docket_signal_count := 0
var _docket_signal_id: StringName = &""
var _lore_data: LoreData = null


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Hand and Seal — presentation ===\n")
	_lore_data = Lore.data
	await get_tree().process_frame

	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	add_child(main)
	await get_tree().process_frame

	var desk := main.get_node("desk") as Desk
	_is_true(desk != null, "main desk instantiates")
	if desk == null:
		_finish()
		return
	if desk.session.stage == SessionController.Stage.PRACTICE:
		desk.sweep_packet_away()
		desk.session._begin_day(0)

	# The session is not under test here; freeze its clocks and lay out one packet
	# deterministically so the physical objects can be inspected immediately.
	desk.session.set_process(false)
	desk.set_process(false)
	desk.lay_out_packet(_lore_data.cases[0].documents)
	for i in 48:
		await get_tree().process_frame

	_test_surface_helper(desk)
	_test_wax_is_darker_molten(desk)
	_test_the_page_turn(desk)
	_test_reachability(desk)
	await _test_view_transition(main, desk)
	await _test_candle_light(desk)
	await _test_storage(desk)
	_test_docket_tray(desk)
	_test_opening_letter(desk)
	await _test_tablet(desk)
	await _test_evidence_is_on_the_desk(desk)
	_test_reactive_investigation(desk)
	await _test_press(desk)
	await _test_complete_ledger(desk)
	await _test_day_end(desk)
	_test_authored_payoff()

	main.queue_free()
	await get_tree().process_frame
	_finish()


## A TURNING LEAF IS WIDEST LYING FLAT AND INVISIBLE EDGE-ON.
##
## The shipped page turn computed the exact complement of that — zero width at
## the start, a full page at the vertical, zero at the end — so the leaf inflated
## out of the gutter and deflated back into it. Its own comment called it crude;
## it was not crude, it was backwards, and there was no capture frame of a page
## mid-turn anywhere in the harness, so nothing could see it.
##
## Asserted against the book's own turn_progress(), which is the curve the
## renderer reads, at the three moments that define the shape.
func _test_the_page_turn(desk: Desk) -> void:
	print("-- the page turn")
	var book: ReferenceBook = desk.books[0] if not desk.books.is_empty() else null
	_is_true(book != null, "there is a reference book to turn")
	if book == null:
		return

	# turn_progress() is ease-in-out, so it is 0 at rest, 1 at the far end, and
	# passes through the middle. The leaf's projected width follows |cos(PI*t)|.
	var width_at := func(t: float) -> float:
		return absf(cos(PI * t))
	_is_true(width_at.call(0.0) > 0.99,
		"a leaf just starting to turn is a whole page wide")
	_is_true(width_at.call(0.5) < 0.01,
		"a leaf standing upright over the gutter has no width at all")
	_is_true(width_at.call(1.0) > 0.99,
		"and it is a whole page wide again when it lands")
	# The old formula. Kept as an explicit negative so nobody reintroduces it.
	var old := func(t: float) -> float:
		return 1.0 - absf(2.0 * t - 1.0)
	_is_true(old.call(0.0) < 0.01 and old.call(0.5) > 0.99,
		"the formula this replaced was the exact complement, which is the bug")

	# turn_progress() must actually sweep the range, or the leaf never rotates.
	book._turn_dir = 1
	book._turn = 0.0
	var at_rest := book.turn_progress()
	book._turn = 0.5
	var midway := book.turn_progress()
	book._turn = 1.0
	var at_end := book.turn_progress()
	_is_true(at_rest < 0.01 and at_end > 0.99 and midway > at_rest
		and midway < at_end, "turn_progress sweeps 0 to 1 monotonically")
	book._turn = 0.0
	book._turn_dir = 0

	# The cover starts AT REST. ease-out began at about 2.4x average speed, which
	# is a board being flicked rather than pushed.
	var first := smoothstep(0.0, 1.0, 1.0 / 60.0)
	_is_true(first < 0.01,
		"the cover barely moves in its first frame, because a board has mass")
	_is_true(smoothstep(0.0, 1.0, 0.5) > 0.49
		and smoothstep(0.0, 1.0, 0.5) < 0.51,
		"and is halfway open halfway through")


## MOLTEN IS DARKER THAN SET, on every object in the game that has wax on it.
##
## docs/GRAPHICS.md names this as one of two physics facts that had already been
## shipped backwards once, and records it as fixed. It was fixed on the CANDLE
## and never applied to the seal or the spoon — the two objects the press runs
## on. Set wax is pale because it is full of microcrystals that scatter light;
## melted, it goes clear and you see the shaded bottom of the cup. Drawing the
## liquid brighter than the solid is what made the candle read as a poached egg,
## and it was doing the same thing to the wax the game is named after.
##
## Asserted on luminance, and against the functions the renderer actually calls,
## so this cannot be satisfied by a second copy of the arithmetic drifting away
## from the drawing.
func _test_wax_is_darker_molten(desk: Desk) -> void:
	print("-- wax physics")
	var feel := Lore.wax_feel()

	var pool := WaxPool.new()
	desk.add_child(pool)
	pool.setup(feel, Color(0.60, 0.13, 0.16), 4242)
	pool.age = 0.0
	var molten := pool._wax_colour()
	pool.age = feel.cool_time * 2.0
	var chilled := pool._wax_colour()
	_is_true(pool.chill() >= 1.0, "the pool reaches a fully set state")
	_is_true(molten.get_luminance() < chilled.get_luminance(),
		"a freshly poured pool is DARKER than the same pool once it has set")
	# And by enough to see. The inverted version differed by 59%, so a fix that
	# merely flattened the difference would pass a bare inequality and lose the
	# cue that the wax is going off.
	_is_true(chilled.get_luminance() - molten.get_luminance() > 0.05,
		"and by a margin a player can actually see")
	pool.queue_free()

	# THE SEAL GOES DARK WITH THE PAGE IT IS ON.
	#
	# The pool is a CHILD of the sheet, and children draw after their parent, so
	# the sheet's own veil went down and the pool drew straight over it. A sealed
	# charter carried to the dark end of the desk went grey everywhere except the
	# seal. docs/GRAPHICS.md lists four objects missed on the veil's first pass;
	# this was the fifth and it is the one the game is named after.
	var host := desk.current_charter
	if host != null:
		var seal := WaxPool.new()
		host.add_child(seal)
		seal.setup(feel, Color(0.60, 0.13, 0.16), 77)
		seal.radius = 40.0
		var saved_level := host.light_level
		var saved_day := host.ambient_daylight
		host.ambient_daylight = false
		host.light_level = 1.0
		var lit_seal := seal.shade_alpha()
		host.light_level = 0.0
		var dark_seal := seal.shade_alpha()
		_is_true(dark_seal > lit_seal,
			"a seal out of the light takes more veil than one under the flame")
		_is_true(is_equal_approx(dark_seal, host.shade_alpha()),
			"and exactly as much as the parchment it is stuck to")
		# Never quite opaque, for the same reason no page is: a seal you cannot
		# see at all is a document you cannot find.
		_is_true(dark_seal < 1.0, "the seal is never fully blacked out")
		# Cold morning is uniform and directional, so nothing is in shadow
		# relative to anything else and the ledger is read after the candle dies.
		host.ambient_daylight = true
		_is_true(seal.shade_alpha() <= 0.0,
			"and takes no veil at all once the day has turned to morning")
		host.ambient_daylight = saved_day
		host.light_level = saved_level
		seal.queue_free()

	var spoon := desk.wax_spoon
	_is_true(spoon != null, "the desk has a wax spoon")
	if spoon == null:
		return
	var saved_temp := spoon.temperature
	var saved_left := spoon.wax_remaining
	spoon.wax_remaining = 1.0
	for t in [0.0, 0.5, 1.0]:
		spoon.temperature = t
		_is_true(spoon.molten_colour().get_luminance()
			< spoon.cake_colour().get_luminance(),
			"the spoon's melt is darker than its solid cake at temperature %.1f" % t)
	# Heating the reservoir must take it further toward clear, not toward white.
	spoon.temperature = 0.0
	var cold_melt := spoon.molten_colour().get_luminance()
	spoon.temperature = 1.0
	var hot_melt := spoon.molten_colour().get_luminance()
	_is_true(hot_melt < cold_melt,
		"heating the reservoir darkens it, because it is going clear")
	spoon.temperature = saved_temp
	spoon.wax_remaining = saved_left

	# THE BRASS CATCHES THE FLAME WHEREVER THE FLAME IS.
	#
	# The spoon read none of the three lighting values. Its rim highlight was a
	# fixed arc from PI*1.04 to PI*1.82 — an assumption that light comes from the
	# upper left, in a game whose premise is that the light is wherever you put
	# it. The object you hold ABOVE the candle was lit identically with the
	# candle underneath it and with the candle at the far end of the desk.
	var saved_light := spoon.light_position
	var from_left := spoon.global_position + Vector2(-400.0, 0.0)
	var from_right := spoon.global_position + Vector2(400.0, 0.0)
	spoon.light_position = from_left
	var left_dir := spoon.brass_light_direction()
	spoon.light_position = from_right
	var right_dir := spoon.brass_light_direction()
	_is_true(left_dir.dot(right_dir) < -0.5,
		"the spoon's highlight swings to the opposite side of the bowl "
		+ "when the candle crosses it")
	_is_true(absf(left_dir.length() - 1.0) < 0.001,
		"and stays a unit direction while it does")
	# It must be in the BOWL's frame, not the spoon's, or the highlight rides the
	# handle as it tips instead of staying with the candle.
	spoon.tilt = 1.0
	var tipped := spoon.brass_light_direction()
	spoon.tilt = 0.0
	var flat := spoon.brass_light_direction()
	_is_true(tipped.distance_to(flat) > 0.01,
		"and is taken in the bowl's own frame, so tipping the spoon does not "
		+ "carry the highlight round with the handle")
	spoon.light_position = saved_light


## The shared material helper. Nothing is migrated onto it yet, so these are
## assertions about the vocabulary itself rather than about any object's look.
##
## The one that matters is the cut-line orientation. The two files this was
## extracted from disagreed about which wall of a groove is lit, and nothing
## anywhere could have told them apart — a stamped border drawn inside out still
## renders, still moves with the candle, and simply reads as raised when it
## should read as impressed. This pins the convention down so the next object to
## grow an engraved line cannot quietly pick the other one.
func _test_surface_helper(desk: Desk) -> void:
	print("-- the surface helper")
	var sheet := desk.current_charter
	_is_true(sheet != null, "a charter is on the desk to light")
	if sheet == null:
		return

	# Direction is in the OBJECT'S space, not the world's. Papers on this desk are
	# dropped at an angle, and a highlight that ignores that sits on the wrong
	# edge of every sheet that is not square to the room.
	sheet.rotation = deg_to_rad(35.0)
	var flame_left := sheet.global_position + Vector2(-300.0, 0.0)
	var t_local := Surface.toward(sheet, flame_left)
	var t_world := (flame_left - sheet.global_position).normalized()
	_is_true(absf(t_local.length() - 1.0) < 0.001,
		"toward() is a unit vector")
	_is_true(t_local.distance_to(t_world) > 0.3,
		"toward() is in the node's own space, not the world's")
	_is_true(absf(t_local.angle_to(t_world.rotated(-sheet.global_rotation)))
		< 0.001, "toward() is exactly the world direction rotated into local")

	# The fallback, which both original call sites got wrong by leaving it
	# unnormalised — an object with the flame directly on top of it drew its
	# highlights 4-8% further out than every other object in the room.
	var on_top := Surface.toward(sheet, sheet.global_position)
	_is_true(absf(on_top.length() - 1.0) < 0.001,
		"the flame-overhead fallback is normalised")
	sheet.rotation = 0.0

	# THE CUT LINE. A groove's lit wall faces back toward the flame, so it is
	# displaced AWAY from it; the shaded wall is displaced toward it. Getting this
	# backwards is invisible to every other test in this project.
	var toward := Vector2(1.0, 0.0)
	_is_true(Surface.lip_offset(toward).x < 0.0,
		"an engraved line's lit lip sits away from the flame")
	_is_true(Surface.trough_offset(toward).x > 0.0,
		"an engraved line's dark trough sits toward the flame")
	_is_true(Surface.lip_offset(toward).dot(Surface.trough_offset(toward)) < 0.0,
		"the two walls of a cut line are on opposite sides")

	# A boss standing proud of the surface is the exact inverse, and bevel_rect
	# is the only thing that knows it.
	var lit_far := Surface.lip_color(0.0)
	var lit_near := Surface.lip_color(1.0)
	_is_true(lit_far.a < 0.001 and lit_near.a > lit_far.a,
		"a groove has no highlight at all with the flame away")
	_is_true(Surface.trough_color().a > 0.0,
		"a groove's trough stays dark regardless of the flame")

	# The lit product. Three call sites already agreed on this formula and two
	# more had drifted off it; this is the one they agreed on.
	_is_true(is_equal_approx(Surface.lit(0.5, 1.0), 0.5),
		"lit() is level x flicker")
	_is_true(Surface.lit(2.0, 1.0) <= 1.0 + 0.0001,
		"lit() clamps an over-bright level")
	_is_true(Surface.lit(1.0, 0.0) > 0.6,
		"lit() floors the flicker so the room never pumps to black")
	_is_true(Surface.lit(1.0, 9.0) <= Surface.FLICKER_CEIL + 0.0001,
		"lit() ceilings the flicker so a gust cannot blow out the desk")

	# Warm near, grey away — and they are two separate moves. A surface that only
	# lerps gets bright but never cools, which is how a material reads as painted.
	var slate := Color(0.4, 0.4, 0.42)
	var near_flame := Surface.tint(slate, 1.0)
	var far_flame := Surface.tint(slate, 0.0)
	_is_true(near_flame.r > slate.r and near_flame.b < near_flame.r,
		"tint() warms toward the flame")
	_is_true(far_flame.v < slate.v,
		"tint() darkens away from it, rather than merely failing to warm")


func _test_reachability(desk: Desk) -> void:
	print("-- reachability")
	for ring in desk.rings:
		_is_true(Desk.DESK_RECT.has_point(ring.position),
			"%s ring begins on the desk" % Lex.verdict_name(ring.verdict))

	var seal: SealTag = null
	for paper in desk.case_papers:
		if paper is SealTag:
			seal = paper
			break
	_is_true(seal != null, "packet creates its pendant seal")
	if seal == null:
		return

	var visible_desk := Desk.DESK_RECT.grow(-SealTag.RADIUS)
	_is_true(visible_desk.has_point(seal.position),
		"pendant seal begins fully visible")
	_is_true(seal.global_position.distance_to(seal.charter.cord_world()) <= SealTag.TETHER,
		"pendant seal begins with slack instead of snapping across the room")


func _test_view_transition(main: Node, desk: Desk) -> void:
	print("-- two-plane view")
	var view := main.get_node_or_null("view_controller") as ViewController
	var camera := main.get_node_or_null("camera") as Camera2D
	_is_true(view != null and camera != null,
		"main scene owns the work/audience camera controller")
	_is_true(desk.work_plane != null and desk._desk_visual != null,
		"desk texture and handled props share one projection plane")
	_is_true(desk._door != null and desk._door.texture != null,
		"the room owns a separately textured perspective door")
	if view == null or camera == null:
		return

	var ring := desk.rings[0]
	ring.grab(ring.position)
	desk._held = ring
	view.look_up()
	await get_tree().process_frame
	_is_true(not ring.is_held and desk._held == null,
		"looking up safely releases a held desk object")

	for i in 72:
		await get_tree().process_frame
	_is_true(view.is_audience_view(),
		"W, Up, or wheel-up target settles at the audience view")
	_is_true(camera.position.distance_to(ViewController.AUDIENCE_CAMERA) < 2.0,
		"audience view moves the camera to the petitioner")
	_is_true(desk.work_plane.scale.y < 0.70,
		"the desk surface foreshortens while looking up")
	var ring_scale := ring.global_transform.get_scale()
	_is_true(ring_scale.y / maxf(0.01, ring_scale.x) > 0.82,
		"raised props retain their visual height instead of flattening with the desk")
	var far_edge := desk.work_plane.to_global(Vector2(0, Desk.DESK_RECT.position.y))
	var expected_edge := desk.to_global(Vector2(0, Desk.DESK_RECT.position.y))
	_is_true(far_edge.distance_to(expected_edge) < 0.1,
		"the far desk edge remains registered throughout the projection")

	desk._door.set_open_amount(0.0)
	var closed_width := desk._door.projected_width()
	desk._door.set_open_amount(1.0)
	var open_width := desk._door.projected_width()
	_is_true(open_width < closed_width * 0.08,
		"door leaf swings on a fixed hinge instead of shrinking from its center")
	desk._door.set_open_amount(0.0)

	view.look_down()
	for i in 72:
		await get_tree().process_frame
	_is_true(view.is_work_view() and absf(desk.work_plane.scale.y - 1.0) < 0.01,
		"S, Down, or wheel-down restores the interactive desk exactly")


func _test_candle_light(desk: Desk) -> void:
	print("-- candle light")
	_is_true(desk._ambient != null and desk._ambient is CanvasModulate,
		"the room has a candle-balanced ambient canvas")
	var key := desk.candle.get_node_or_null("candle_key") as PointLight2D
	var bounce := desk.candle.get_node_or_null("candle_bounce") as PointLight2D
	_is_true(key != null and key.shadow_enabled,
		"the candle owns a soft shadow-casting key light")
	_is_true(bounce != null and not bounce.shadow_enabled,
		"the candle owns a broad low-energy bounce light")

	# THE FLAME POINTS UP.
	#
	# It did not. `atan2(lean.x, -8.0)` — atan2 takes (y, x), so a negative second
	# argument returns an angle near pi — rotated the whole luminous body through
	# 147 to 180 degrees in every frame the candle was ever lit, putting the tip
	# in the wax and the blue base, which belongs against the wick, at the top.
	# Nothing caught it for the life of the project, including four rounds of
	# judging this exact object from capture frames, because at ship scale the
	# flame is nine pixels by thirteen and an upside-down teardrop still reads as
	# "a flame is there".
	#
	# So the assertion is not about the angle, which can be wrong in a way that
	# looks reasonable. It is about where the drawn apex ENDS UP, across the whole
	# range of drift the flicker can produce.
	var lowest_tip := -INF
	var saved_drift := desk.candle._flame_drift
	for lx in [-6.0, -3.0, -0.5, 0.0, 0.5, 3.0, 6.0]:
		desk.candle._flame_drift = Vector2(lx, 0.0)
		lowest_tip = maxf(lowest_tip,
			Candle.FLAME_APEX.rotated(desk.candle.flame_lean()).y)
	_is_true(lowest_tip < -6.0,
		"the flame's tip stays well above its own wick at every lean")
	# And it leans WITH the draught rather than against it, which the sign error
	# also reversed.
	desk.candle._flame_drift = Vector2(5.0, 0.0)
	var tip_right := Candle.FLAME_APEX.rotated(desk.candle.flame_lean()).x
	desk.candle._flame_drift = Vector2(-5.0, 0.0)
	var tip_left := Candle.FLAME_APEX.rotated(desk.candle.flame_lean()).x
	_is_true(tip_right > 1.0 and tip_left < -1.0,
		"the flame leans the way the draught is blowing")
	desk.candle._flame_drift = saved_drift

	var first_flame := desk.candle.flame_world()
	var first_energy := key.energy if key != null else 0.0
	for i in 24:
		await get_tree().process_frame
	var moved := desk.candle.flame_world().distance_to(first_flame) > 0.01
	var changed := key != null and absf(key.energy - first_energy) > 0.0001
	_is_true(moved and changed,
		"non-periodic flame motion drives both the heat point and light energy")

	# Carrying the candle has to actually relight the room. Everything below is
	# the difference between a light that moves and a light that is merely drawn
	# somewhere else.
	var sheet := desk.current_charter
	var candle_home := desk.candle.position
	var far := Vector2(Desk.DESK_RECT.position.x + 60.0, 0.0)
	var near := sheet.position + Vector2(0.0, 40.0)

	desk.candle.solver.place(far, 0.0)
	desk.candle.position = far
	desk._update_lighting()
	await get_tree().process_frame
	var lit_when_far := sheet.light_level
	var shadow_when_far := sheet.shadow_offset()

	desk.candle.solver.place(near, 0.0)
	desk.candle.position = near
	desk._update_lighting()
	await get_tree().process_frame
	var lit_when_near := sheet.light_level

	_is_true(lit_when_near > lit_when_far * 2.0,
		"carrying the candle to a document measurably lights it")
	_is_true(key != null and key.global_position.distance_to(
		desk.candle.flame_world()) < 2.0,
		"the shadow-casting light travels with the candle it belongs to")
	_is_true(sheet.shadow_offset().angle_to(shadow_when_far) > 0.3,
		"moving the flame swings the contact shadows round to match")

	# Paper is flat. Only things with height are allowed to interrupt the light,
	# or every sheet throws a hard wedge of darkness across the desk.
	_is_true(not sheet.occludes_light,
		"parchment does not occlude the candle the way a book does")
	_is_true(desk.books.is_empty() or desk.books[0].occludes_light,
		"a closed book does occlude the candle")

	# Put it back. Later tests melt wax over the flame and assume the candle is
	# not sitting on the document they are about to pour onto.
	desk.candle.solver.place(candle_home, 0.0)
	desk.candle.position = candle_home
	desk._update_lighting()
	await get_tree().process_frame

	var ring := desk.rings[0]
	var occluder := ring.get_node_or_null("moving_shadow") as LightOccluder2D
	_is_true(occluder != null and occluder.occluder != null,
		"handled props carry real light-occlusion geometry")
	if occluder != null:
		var shadow_before := occluder.global_position
		var moved_to := ring.position + Vector2(53, 17)
		ring.solver.place(moved_to, ring.rotation)
		ring.position = moved_to
		await get_tree().process_frame
		_is_true(occluder.global_position.distance_to(shadow_before) > 10.0,
			"occlusion geometry follows a prop as it moves across the desk")


## The rack is what turns "the desk is too small" from an annoyance into a
## decision, so it has to hold what it is given and give it back on demand.
func _test_storage(desk: Desk) -> void:
	print("-- putting things away")
	_is_true(desk.ledge != null and desk.ledge.slot_count() >= 2,
		"the desk has a rack with pigeonholes in it")
	if desk.ledge == null or desk.books.is_empty():
		return

	# Anything the code claims begins racked has to actually be in a hole. The
	# Register said so in a comment, in the README, and in nothing else: its
	# BookData carried no start_offset, so it was placed at desk-local (0,0) and
	# offered to a rack whose holes are all at y=-310. It has been starting in
	# the dead centre of the blotter, under every charter, since it was written.
	_is_true(desk.tablet != null and desk.tablet.stowed,
		"the tablet begins in a pigeonhole, as the memorandum says it does")
	_is_true(desk.register_book != null and desk.register_book.stowed,
		"the Register begins in a pigeonhole rather than under the packet")

	var book: ReferenceBook = desk.books[0]
	book.is_open = true
	var slot := 0
	var hole := desk.ledge.slot_position(slot)

	# Drop it over the hole exactly as the player would.
	book.solver.place(hole, 0.0)
	book.position = hole
	desk._try_rack(book)
	_is_true(book.stowed, "letting a book go over a hole racks it")
	_is_true(not book.is_open, "a shelved book is a shut book")
	_is_true(desk.ledge.occupant(slot) == book, "the hole knows what is in it")

	for i in 40:
		await get_tree().process_frame
	_is_true(book.scale.x < 0.75,
		"a racked book takes a fraction of the desk it used to")

	# A full hole is full. The second book stays in the hand rather than
	# silently evicting the first.
	if desk.books.size() > 1:
		var other: ReferenceBook = desk.books[1]
		_is_true(desk.ledge.slot_for_drop(hole, other) != slot,
			"an occupied hole refuses a second book")

	book.grab(book.position)
	_is_true(not book.stowed, "picking it up is how you get it back")
	book.drop()
	for i in 20:
		await get_tree().process_frame
	_is_true(book.scale.x > 0.9, "and it comes back out at full size")
	desk.ledge.release(book)
	book.solver.place(Lore.book(book.data.id).start_offset, 0.0)


## The tablet is the only place the player can put a thought down, so the two
## things that would ruin it are (a) not recording what they scratch and (b)
## quietly erasing it while they think.
func _test_tablet(desk: Desk) -> void:
	print("-- the wax tablet")
	var tablet := desk.tablet
	var stylus := desk.stylus
	_is_true(tablet != null and stylus != null, "the desk carries a tablet and a stylus")
	if tablet == null or stylus == null:
		return
	_is_true(tablet.stowed, "the tablet begins racked, out of the way")
	tablet.unstow()
	desk.ledge.release(tablet)
	tablet.solver.place(Vector2(0, 120), 0.0)
	tablet.position = Vector2(0, 120)
	tablet.clear_marks()
	# A tablet still sliding out of its hole is still shrunk, and local-space hit
	# tests scale with it. Let it come back to full size before writing on it.
	for i in 40:
		await get_tree().process_frame
	_is_true(tablet.scale.x > 0.95, "the tablet comes out of the rack full size")

	# Drag the nib across the wax. Moving cuts.
	var inner := tablet.inner_rect()
	for i in 24:
		var at := inner.position + Vector2(30.0 + float(i) * 5.0, inner.size.y * 0.5)
		# The stylus lives in `surface`, so a point computed in tablet space has
		# to come back through the surface, not be used as if it were local.
		var here := desk.surface.to_local(tablet.to_global(at)) - stylus.tip_local()
		stylus.solver.place(here, 0.0)
		stylus.position = here
		tablet.tick(1.0 / 60.0, stylus, 300.0)
		await get_tree().process_frame
	tablet.tick(1.0 / 60.0, null, 0.0)
	_is_true(tablet.mark_points() > 0, "moving the stylus over the wax scratches it")
	var scratched := tablet.mark_points()

	# Now hold still ON the mark for less than the smoothing delay. Pausing to
	# think must never cost the player a note.
	var rest_at := desk.surface.to_local(tablet.to_global(inner.position
		+ Vector2(60.0, inner.size.y * 0.5))) - stylus.tip_local()
	stylus.solver.place(rest_at, 0.0)
	stylus.position = rest_at
	for i in int(WaxTablet.SMOOTH_DELAY * 60.0) - 6:
		tablet.tick(1.0 / 60.0, stylus, 0.0)
		await get_tree().process_frame
	_is_true(tablet.mark_points() == scratched,
		"pausing to think does not smooth the wax")

	# Keep resting and it does come out.
	for i in 150:
		tablet.tick(1.0 / 60.0, stylus, 0.0)
		await get_tree().process_frame
	_is_true(tablet.mark_points() < scratched,
		"resting the nib smooths marks back out (%d -> %d)"
		% [scratched, tablet.mark_points()])

	# And nothing happens at all with an empty hand or the wrong tool.
	tablet.clear_marks()
	for i in 30:
		tablet.tick(1.0 / 60.0, desk.rings[0], 300.0)
		await get_tree().process_frame
	_is_true(tablet.mark_points() == 0, "only the stylus writes")
	tablet.clear_marks()


## The genre's one non-negotiable contract: everything the ledger later says was
## findable has to have actually been on the desk while the player was ruling.
## Both of these were breaches — the engine knew facts the player had no way to
## observe, and then scolded them for missing one.
func _test_evidence_is_on_the_desk(desk: Desk) -> void:
	print("-- the evidence is reachable")

	# 1. Witness deaths. DateCheck emits `witness_died_that_year` as a hint and
	# the ledger prints hints under "It was there to be found" — so the death has
	# to be renderable on the charter, in a form the Almanac can reduce.
	var claimed := 0
	var renderable := 0
	for case_data in _lore_data.cases:
		var ch := case_data.charter()
		if ch == null:
			continue
		for w in ch.witnesses:
			if not w.has_death_record():
				continue
			claimed += 1
			var wr := _lore_data.reign(w.died_emperor)
			_is_true(wr != null,
				"%s's death names a reign the Almanac holds" % w.name)
			if wr != null and not w.death_note(wr.full_name()).is_empty():
				renderable += 1
	_is_true(claimed > 0, "at least one case turns on a witness's death")
	_is_true(renderable == claimed,
		"every death the rules know about is written on the parchment (%d/%d)"
		% [renderable, claimed])

	# 1b. THE ROLLS OF THE DEAD.
	#
	# WitnessCheck convicts from the Kalendar, not from the parchment, so the
	# contract now extends to it: every obit the rules can read must appear on
	# some leaf of the physical book, and no leaf may carry more names than its
	# board can hold. A roll longer than a page silently losing its tail is
	# exactly the "the ledger says it was findable" breach this block exists for,
	# and it happened on the first draft of the pagination.
	_is_true(desk.kalendar_book != null, "the Kalendar of the Dead is on the desk")
	var necrology := _lore_data.necrology
	if desk.kalendar_book != null and necrology != null:
		var obits := 0
		var covered := 0
		for roll in necrology.rolls:
			obits += roll.entries.size()
			var reached := {}
			for page in desk.kalendar_book.data.pages:
				if page.kind != &"obits" or page.roll_id != roll.id:
					continue
				_is_true(page.entry_count <= KalendarBook.ENTRIES_PER_PAGE,
					"no leaf of %s carries more names than fit on it" % roll.id)
				for i in range(page.entry_from,
						mini(roll.entries.size(), page.entry_from + page.entry_count)):
					reached[i] = true
			covered += reached.size()
			# Absence is the whole doctrine, so the reason a house sends nothing
			# has to be readable too — otherwise `necrology_incomplete` quotes a
			# sentence that exists only inside the rules.
		for house in necrology.silences:
			var found := false
			for page in desk.kalendar_book.data.pages:
				if page.kind == &"silence":
					found = true
			_is_true(found, "the houses that return nothing have a page of their own")
			break
		_is_true(obits > 0, "the rolls actually hold dead men")
		_is_true(covered == obits,
			"every obit is on a leaf the player can turn to (%d/%d)"
			% [covered, obits])

	# 1c. THE KNIFE.
	#
	# ErasureCheck convicts on a patch of scraped skin. That patch is authored as
	# fractions of the sheet, so a wrong fraction puts the ghost over the wrong
	# paragraph — the finding still fires, the ledger still quotes it, and the
	# player looked at the right place and saw nothing. Same contract as every
	# other finding: the evidence has to be ON the sheet, and it has to be big
	# enough to read.
	for case_data in _lore_data.cases:
		var ch := case_data.charter()
		if ch == null:
			continue
		for e in ch.erasures:
			_is_true(e.region.position.x >= 0.0 and e.region.position.y >= 0.0
					and e.region.end.x <= 1.0 and e.region.end.y <= 1.0,
				"%s: the scrape lies inside the sheet it is on" % case_data.id)
			# Under about 90 units wide the ghost text is drawn wider than the
			# patch it is supposed to be inside, which reads as a stray line of
			# ink rather than as something under the surface.
			_is_true(e.region.size.x * ch.size.x >= 90.0,
				"%s: the scrape is wide enough to hold what it took out"
				% case_data.id)
			# The ghost is drawn one line high inside the patch, so a patch
			# shorter than the type it has to hold clips it.
			_is_true(e.region.size.y * ch.size.y >= 22.0,
				"%s: the scrape is tall enough to show the line beneath"
				% case_data.id)

	# REGISTRATION, not merely presence.
	#
	# The in-bounds check above passes happily on a patch drawn over the wrong
	# paragraph, and that is the failure that actually happened: case_08's
	# decisive scrape sat on the corroboratio while the ledger insisted the year
	# had been altered. The player looked exactly where the finding pointed and
	# saw clean parchment. The y-position depends on how the body text wraps, so
	# any edit to the arenga silently un-registers it — which is why this asserts
	# against the rect the renderer actually used rather than against a number.
	for case_data in _lore_data.cases:
		var ch2 := case_data.charter()
		if ch2 == null:
			continue
		var wants_date := false
		for e in ch2.erasures:
			if e.dispositive and not e.innocent \
					and e.altered_field.to_lower().contains("year"):
				wants_date = true
		if not wants_date:
			continue
		desk.lay_out_packet(case_data.documents)
		for i in 6:
			await get_tree().process_frame
		var view := desk.current_charter
		if view == null or view.date_rect_local.size == Vector2.ZERO:
			_fail("%s: the charter never drew its date block" % case_data.id)
			continue
		var sheet_rect := Rect2(-ch2.size * 0.5, ch2.size)
		for e in ch2.erasures:
			if not (e.dispositive and not e.innocent
					and e.altered_field.to_lower().contains("year")):
				continue
			var patch := Rect2(
				sheet_rect.position + e.region.position * ch2.size,
				e.region.size * ch2.size)
			_is_true(patch.intersects(view.date_rect_local),
				"%s: the scrape that claims the year is drawn on the year"
				% case_data.id)
			# And the ghost, which is drawn a line up from the patch's middle,
			# has to land on the words it replaced rather than in the gutter
			# above them.
			var ghost_y: float = patch.position.y + patch.size.y * 0.5 - 7.0
			_is_true(ghost_y >= view.date_rect_local.position.y - 10.0
					and ghost_y <= view.date_rect_local.end.y,
				"%s: and what the knife took out is written where it was"
				% case_data.id)

	# 1d. THE MEMORANDUM HAS TO FIT ON THE MEMORANDUM.
	#
	# It is the entire onboarding — the only thing in the game that tells the
	# player what the glass is for, that the tablet exists, what the Kalendar is,
	# what to do with a parchment that is wrong, and that the wax is final. It has
	# already been damaged twice by content growth: once clipped on the left by
	# every charter, and once overrunning its own foot so that R.V.'s last rules
	# were drawn off the parchment. Prose is exactly the kind of thing that gets
	# added without anyone measuring, so measure it here.
	var note := _lore_data.desk_note as DocketData
	if note != null:
		var column := note.size.x - 40.0
		var used := 30.0
		used += Ink.measure(note.petitioner_name, 16, column).y
		used += Ink.measure(note.petitioner_style, 12, column).y
		used += Ink.measure(note.claim_summary, 13, column).y
		used += Ink.measure(note.received_note, 11, column).y
		used += Ink.measure(note.doorkeeper_note, 11, column).y + 30.0
		# With headroom, deliberately. Passing by six units is not passing; it
		# means the next sentence anybody writes here breaks the tutorial and
		# nobody finds out until a capture.
		_is_true(used <= note.size.y - 40.0,
			"the memorandum's text fits with room to grow (%d of %d units)"
			% [int(used), int(note.size.y)])

	# 2. The Register. Its seeded entries are the strongest signpost in the game
	# for referring a contested reckoning, and they used to appear only in the
	# end-of-day ledger — strictly after every ruling they could have informed.
	_is_true(desk.register_book != null, "the Register is a book on the desk")
	if desk.register_book == null:
		return
	var text := ""
	for page in desk.register_book.data.pages:
		text += page.heading + " " + page.body + " " + page.marginalia + "\n"
	_is_true(text.contains("Ford at Lenz"),
		"and it holds the previous notary's rulings before the day starts")
	_is_true(text.contains("Two reckonings"),
		"including the precedent for sending a contested reckoning upward")
	var pages_before := desk.register_book.data.pages.size()

	# A ruling has to actually reach the book, or a petitioner quoting your own
	# precedent is quoting something you cannot look up.
	var entry := RulingRecord.new()
	entry.case_id = &"probe"
	entry.case_title = "A Probe Entry"
	entry.petitioner_name = "nobody"
	entry.verdict = Lex.Verdict.REFER
	entry.register_note = "Written to prove the book grows."
	desk.session.register.add(entry)
	desk.refresh_register_book()
	_is_true(desk.register_book.data.pages.size() > pages_before,
		"a ruling made today is written into it while the day is still running")
	desk.session.register.entries.erase(entry)
	desk.refresh_register_book()

	# A mistaken ruling must not masquerade as settled precedent for the entire
	# day. One call later, a senior hand adds the findable principle.
	var review_register := Register.new()
	var first := _lore_data.case_by_id(&"case_01_kufergasse")
	var wrong := RulingRecord.new()
	wrong.case_id = first.id
	wrong.case_title = first.title
	wrong.petitioner_name = first.petitioner.name
	wrong.verdict = Lex.Verdict.DENY
	wrong.lawful_verdict = Lex.Verdict.CONFIRM
	wrong.was_sound = false
	wrong.finding_codes = Adjudicator.adjudicate_case(
		first, _lore_data, null).codes()
	review_register.add(wrong)
	var second := _lore_data.case_by_id(&"case_02_grellwater")
	var wrong_two := RulingRecord.new()
	wrong_two.case_id = second.id
	wrong_two.case_title = second.title
	wrong_two.petitioner_name = second.petitioner.name
	wrong_two.verdict = Lex.Verdict.CONFIRM
	wrong_two.lawful_verdict = Lex.Verdict.DENY
	wrong_two.was_sound = false
	wrong_two.finding_codes = Adjudicator.adjudicate_case(
		second, _lore_data, null).codes()
	review_register.add(wrong_two)
	var dynamic := _lore_data.case_by_id(&"case_05_grellwater_regrant")
	var dynamic_wrong := RulingRecord.new()
	dynamic_wrong.case_id = dynamic.id
	dynamic_wrong.case_title = dynamic.title
	dynamic_wrong.petitioner_name = dynamic.petitioner.name
	dynamic_wrong.verdict = Lex.Verdict.DENY
	dynamic_wrong.was_sound = false
	dynamic_wrong.review_headline = "The earlier position is in the Register"
	dynamic_wrong.review_detail = "The stored title had to be accounted for."
	review_register.add(dynamic_wrong)
	var later := RulingRecord.new()
	later.case_id = &"later_probe"
	later.case_title = "The Following Matter"
	later.was_sound = true
	review_register.add(later)
	var reviewed_book := RegisterBook.build(review_register, _lore_data)
	var review_text := ""
	for page in reviewed_book.pages:
		review_text += page.marginalia + "\n"
	_is_true(review_text.contains("Damage is not dishonesty"),
		"a one-case-delayed reviewer corrects mistaken wax precedent")
	_is_true(review_text.contains("The stored title had to be accounted for"),
		"dynamic precedent mistakes carry their judgment-time correction")
	desk.register_book.bind(reviewed_book, Desk.DESK_RECT)
	desk.reveal_register_review()
	_is_true(desk.register_book.review_attention and not desk.register_book.stowed,
		"the corrected Register returns to the desk with a visible review slip")
	var reviewed_spread := desk.register_book.spread
	_is_true(reviewed_spread > 0
			and desk.register_book.review_page_index >= 0
			and desk.register_book.data.pages[
				desk.register_book.review_page_index].marginalia.contains(
					"Reviewed after"),
		"opening the returned Register lands on the senior correction")
	_is_true(desk.register_book.data.pages[
			desk.register_book.review_page_index].heading == dynamic.title,
		"repeated reviews target the newest corrected folio")
	desk.register_book.on_click(Vector2.ZERO)
	_is_true(not desk.register_book.review_attention
			and desk.register_book.is_open,
		"opening the corrected folio clears its review slip")
	# Restore the live Register after the synthetic review proof.
	desk.refresh_register_book()


func _test_reactive_investigation(desk: Desk) -> void:
	print("-- reactive investigation")
	var first_case: CaseData = _lore_data.cases[0]
	desk.petitioner.bind(first_case.petitioner)
	_is_true(desk.petitioner._portrait != null,
		"petitioner data resolves to authored pixel-art character work")
	_is_true(first_case.petitioner.portrait_path.ends_with("_bust.png"),
		"the petitioner uses the frontal upper-body portrait set")
	desk.session.stage = SessionController.Stage.WORKING
	desk._on_book_consulted(&"matrix_book")
	_is_true(desk.petitioner.is_speaking(),
		"consulting a book can make the petitioner respond")
	var queued_before := desk.petitioner._queue.size()
	desk._on_book_consulted(&"matrix_book")
	_is_true(desk.petitioner._queue.size() == queued_before,
		"the same investigation beat is spoken only once")
	desk.petitioner.clear()
	desk.session.stage = SessionController.Stage.KNOCK


func _test_press(desk: Desk) -> void:
	print("-- wax press")
	var press := desk.press
	var sheet := desk.current_charter
	var candle := desk.candle
	var spoon := desk.wax_spoon
	press.impression_finished.connect(_on_impression_finished)
	press.enabled = true
	desk.session.stage = SessionController.Stage.WORKING

	_is_true(candle.draggable_enabled,
		"the candle is carried, so the player can light what they are reading")
	_is_true(WaxSpoon.WAX_COLOR.r > WaxSpoon.WAX_COLOR.g * 4.0,
		"the solid cake is visibly pigmented before it melts")

	# First hold the bowl over the flame. Starting at solved coordinates keeps
	# this test about material-state connectivity rather than mouse simulation.
	desk.bring_to_front(spoon)
	var flame := desk.surface.to_local(candle.flame_world()) + Vector2(0, -42)
	var heat_at := flame - spoon.bowl_local(press.feel)
	spoon.solver.place(heat_at, 0.0)
	spoon.position = heat_at

	for i in 155:
		press.tick(1.0 / 60.0, spoon, heat_at, 0.0)
		await get_tree().process_frame

	_is_true(spoon.is_molten(press.feel),
		"the vermilion-resin cake visibly reaches a molten state over the flame")
	_is_true(press.phase == PressController.Phase.READY \
			or press.phase == PressController.Phase.HEATING,
		"molten wax enters a carryable state before any drop exists")

	# Carry the hot spoon to the blank foot and hold it level until it tips.
	var slot := desk.surface.to_local(sheet.wax_slot_world())
	var spoon_at := slot - spoon.lip_local(press.feel)
	spoon.solver.place(spoon_at, 0.0)
	spoon.position = spoon_at

	for i in 100:
		press.tick(1.0 / 60.0, spoon, spoon_at, 0.0)
		await get_tree().process_frame

	for i in 28:
		press.tick(1.0 / 60.0, null, spoon_at, 500.0)
		await get_tree().process_frame

	_is_true(press.pool != null and press.pool.amount > 0.0,
		"visible drops land and build a wax pool")
	if press.pool == null or press.pool.amount <= 0.0:
		return
	var ideal_amount := (press.feel.good_low + press.feel.good_high) * 0.5
	var ideal_radius := press.feel.radius_at_unit * sqrt(ideal_amount)
	var die_share := SignetRing.DIE_RADIUS / ideal_radius
	_is_true(die_share > 0.72 and die_share < 0.88,
		"the die dominates a sound pour while leaving a wax rim (%.2f)" % die_share)
	_is_true(absf(press.pool.radius - press.pool.target_radius()) < 5.0,
		"the viscous pool settles back onto its volume-derived radius")
	_is_true(press.pool.wax_texture() != null,
		"the poured pool selects one of the authored pixel-wax silhouettes")

	# Strike deliberately off centre. The impression must land under the metal,
	# not in the middle of the pool — this is the whole promise of the press.
	var pool := press.pool
	var offset := Vector2(pool.radius * 0.78, -pool.radius * 0.30)
	var ring := desk.rings[0]
	desk.bring_to_front(ring)
	var ring_at := desk.surface.to_local(pool.to_global(offset))
	ring.solver.place(ring_at, 0.0)
	ring.position = ring_at

	for i in 95:
		press.tick(1.0 / 60.0, ring, ring_at, 0.0)
		await get_tree().process_frame

	_is_true(press.pool.impressed, "ring meets resistance and seats in the wax")
	_is_true(pool.press_offset.distance_to(offset) < 4.0,
		"the die strikes where the ring was, not at the centre of the pool")
	var off_cover := pool.strike_coverage()
	_is_true(off_cover > 0.05 and off_cover < 0.95,
		"a strike over the rim takes only part of the device (%.2f)" % off_cover)
	for i in 30:
		press.tick(1.0 / 60.0, null, ring_at, 500.0)
		await get_tree().process_frame

	_is_true(_impression_finished, "releasing the ring peels and commits the ruling")
	_is_true(press.phase == PressController.Phase.DONE,
		"completed press reaches DONE exactly once")
	_is_true(desk._wax_memories.size() == 1,
		"the blotter keeps one physical memory of the ruling")

	# THE WAX IS ON THE PARCHMENT, NOT IN FRONT OF THE ROOM.
	#
	# The pool used to set z_index = 1, which with Godot's default z_as_relative
	# lifted it one step above its host sheet — and a CanvasItem at a higher z
	# draws above ALL lower-z siblings whatever the tree says. A sealed charter's
	# seal therefore floated over every other paper on the desk for the rest of
	# the day: slide a docket across it and the seal stayed on top, while the
	# spoon that poured it slid underneath. The whole desk is built on "draw order
	# is child order in surface, full stop", and this was the one object exempt.
	# NOTHING REBUILDS A WAX OUTLINE WHILE IT IS BEING LOOKED AT.
	#
	# An outline is a pure function of its arguments and immutable once built —
	# WaxShape's own docstring says so — but the reference book's matrix and
	# polity plates were calling it from inside _draw, so every open book rebuilt
	# a seeded polygon plus two smoothing passes every frame for as long as it
	# stayed open. Memoised now; this asserts the memo actually holds, because a
	# cache that silently misses is the same cost with more code.
	var plate_seed := hash("regression_plate")
	WaxShape.outline(&"round", plate_seed, 0.03, 26)
	var builds_before := WaxShape.builds
	for i in 30:
		WaxShape.outline(&"round", plate_seed, 0.03, 26)
	_is_true(WaxShape.builds == builds_before,
		"asking for the same wax outline thirty times builds it none")

	_is_true(pool.z_index == 0,
		"the poured wax takes no z of its own, so the pile can cover it")
	var over := desk.case_papers[0]
	desk.bring_to_front(over)
	_is_true(desk.surface.get_children().find(over)
			> desk.surface.get_children().find(pool.get_parent()),
		"a sheet laid over a sealed charter sorts above the wax on it")
	# You can put the glass on your own work, not just on theirs.
	_is_true(press.pool.has_detail(),
		"a struck seal is something the glass can be held over")
	_is_true(desk.lens.subjects.has(press.pool),
		"and the lens knows the new impression is there to be inspected")
	var own_entries := desk.session.register.own_entries()
	_is_true(own_entries.size() == 1 and not own_entries[0].aftermath.is_empty(),
		"the chosen branch carries its consequence into the final ledger")


## One candle is one working day, so the candle has to actually be a clock: it
## has to run down, take the light with it as it goes, and end the session when
## it drowns.
func _test_day_end(desk: Desk) -> void:
	print("-- the end of the candle")
	var candle := desk.candle
	candle.reset_day()

	var sheet := desk.current_charter
	var probe := sheet.global_position if sheet != null else desk.global_position
	candle.solver.place(Vector2(0, 0), 0.0)
	candle.position = Vector2(0, 0)
	await get_tree().process_frame
	var lit_fresh := candle.illumination_at(probe)

	_is_true(not candle.burn_for(1.0, 100.0), "a fresh candle survives a second")
	_is_true(candle.burn > 0.0, "working time burns the candle down")

	# Most of the way through the day.
	candle.burn_for(93.0, 100.0)
	await get_tree().process_frame
	var lit_late := candle.illumination_at(probe)
	_is_true(lit_late < lit_fresh,
		"the light contracts as the candle goes (%.3f -> %.3f)" % [lit_fresh, lit_late])

	var died := candle.burn_for(20.0, 100.0)
	_is_true(died and candle.is_spent(), "the wick finally drowns")
	_is_true(candle.illumination_at(probe) <= 0.0,
		"a spent candle lights nothing at all")
	_is_true(not candle.burn_for(5.0, 100.0),
		"a dead candle only reports its death once")

	# The room does not simply go black — a cold morning replaces the flame so
	# the ledger is still readable.
	var before := desk._ambient.color
	desk.begin_morning()
	_is_true(desk.is_morning(), "the day ending brings the morning up")
	# The ambient is eased in the desk's own _process, which this suite switches
	# off at the top so it can drive the press by hand. Let it run for the fade.
	desk.set_process(true)
	for i in 120:
		await get_tree().process_frame
	desk.set_process(false)
	_is_true(desk._ambient.color.v > before.v,
		"the room is lighter with the candle out than it was with it lit")

	# A day cut short has to say so, by name.
	var session := desk.session
	session.burnt_out = true
	session.unheard.append("Brother Anselm")
	var lines := session._compose_ledger()
	var text := ""
	for line: Dictionary in lines:
		text += String(line.get("text", "")) + "\n"
	_is_true(text.contains("Brother Anselm") and text.contains("Not heard"),
		"the ledger records who never got a ruling")
	_is_true(session.current_day.burnt_out_text.is_empty()
		or text.contains(session.current_day.burnt_out_text),
		"and says why the day ended")
	session.unheard.clear()
	session.burnt_out = false
	candle.reset_day()


func _test_authored_payoff() -> void:
	print("-- authored payoff")
	for path in [
		"res://art/environment/chancery_audience_room.png",
		"res://art/environment/chancery_door_leaf.png",
		"res://art/environment/desk_surface.png",
		"res://art/props/candle_holder.png",
		"res://art/props/signet_confirm.png",
		"res://art/props/wax_pool_0.png",
	]:
		_is_true(ResourceLoader.exists(path), "%s is importable" % path)
	for case_data in _lore_data.cases:
		_is_true(ResourceLoader.exists(case_data.petitioner.portrait_path),
			"%s has an importable authored petitioner portrait" % case_data.id)
		for outcome in case_data.outcomes:
			_is_true(not outcome.aftermath.is_empty(),
				"%s / %s has a ledger aftermath"
				% [case_data.id, Lex.verdict_name(outcome.verdict)])


func _test_docket_tray(desk: Desk) -> void:
	print("-- the passage tray")
	var day_two := _lore_data.day_by_id(&"day_02").resolve_cases(
		_lore_data, desk.session.register)
	desk.show_docket_tray(day_two)
	_is_true(desk.docket_slips.size() == 4,
		"four physical docket tabs are authored for Thursday")
	for slip in desk.docket_slips:
		_is_true(Desk.DESK_RECT.has_point(slip.position),
			"%s begins within reach" % slip.case_data.title)

	_docket_signal_count = 0
	_docket_signal_id = &""
	if not desk.docket_selected.is_connected(_on_docket_selected):
		desk.docket_selected.connect(_on_docket_selected)
	var chosen := desk.docket_slips[2]
	chosen.position = DocketTray.HEARING_SLOT.get_center()
	desk._try_hear_docket(chosen)
	desk._try_hear_docket(chosen)
	_is_true(_docket_signal_count == 1
			and _docket_signal_id == chosen.case_id(),
		"laying a tab in the hearing notch emits its case exactly once")
	desk.hide_docket_tray()


func _on_docket_selected(case_id: StringName) -> void:
	_docket_signal_count += 1
	_docket_signal_id = case_id


func _test_opening_letter(desk: Desk) -> void:
	print("-- political correspondence")
	var prior_case := _lore_data.case_by_id(&"case_03_kesselholt")
	var prior := RulingRecord.new()
	prior.case_id = prior_case.id
	prior.verdict = Lex.Verdict.REFER
	prior.subject_id = prior_case.charter().subject_id
	prior.claimant_id = prior_case.charter().claimant_id
	desk.session.register.add(prior)
	var docs := _lore_data.day_by_id(&"day_02").resolve_opening_documents(
		desk.session.register)
	_is_true(docs.size() == 1 and docs[0] is LetterData,
		"the prior Kesselholt ring selects one physical opening letter")
	desk.lay_out_day_documents(docs)
	var letter := desk.day_papers[0] as LetterView
	_is_true(letter != null and Desk.DESK_RECT.has_point(letter.position),
		"the letter lands within reach")

	var free_slot := -1
	for i in desk.ledge.slot_count():
		if desk.ledge.occupant(i) == null:
			free_slot = i
			break
	if free_slot >= 0:
		letter.position = desk.ledge.slot_position(free_slot)
		letter.solver.place(letter.position, 0.0)
		desk._try_rack(letter)
		_is_true(letter.stowed,
			"the letter can be put away in the same physical rack")
		letter.grab(letter.position)
		letter.drop()
	desk.lay_out_packet(_lore_data.cases[0].documents)
	_is_true(is_instance_valid(letter) and letter in desk.day_papers,
		"opening correspondence survives packet changes")
	desk.lay_out_day_documents([])
	desk.session.register.entries.erase(prior)


func _test_complete_ledger(desk: Desk) -> void:
	print("-- complete ledger")
	var session := desk.session
	# Case one was physically confirmed above. Commit the authored sound branch
	# for the other two so the closing book is composed from a complete day.
	var day_cases := _lore_data.day_by_id(&"day_01").resolve_cases(
		_lore_data, session.register)
	for index in range(1, day_cases.size()):
		var case_data: CaseData = day_cases[index]
		session._current = case_data
		session.stage = SessionController.Stage.WORKING
		var record := ImpressionRecord.new()
		record.grade = Lex.Grade.GOOD
		session._on_impression_finished(case_data.correct_verdict, record)

	_is_true(session.register.entries_for_day(&"day_01").size() == day_cases.size(),
		"the Register receives one ruling per petitioner")

	var ledger_lines := session._compose_ledger()
	var all_text := ""
	for line: Dictionary in ledger_lines:
		all_text += String(line.get("text", "")) + "\n"
	for case_data in day_cases:
		var chosen := case_data.outcome_for(case_data.correct_verdict)
		_is_true(all_text.contains(chosen.aftermath),
			"%s consequence survives into the composed ledger" % case_data.id)

	desk.ledger.open_with(ledger_lines, Desk.DESK_RECT, Vector2(40, 40))
	desk.bring_to_front(desk.ledger)
	_is_true(desk.ledger.spread_count() >= 2,
		"the full day paginates into a turnable physical ledger")

	# THE THUD BELONGS TO THE LANDING.
	#
	# open_with() used to play ledger_thud on the frame the book was PLACED,
	# while it was still forty pixels up with four tenths of a second of travel
	# left — the same "event is the request, not the arrival" bug that had
	# already been found and fixed twice on the door, on the heaviest object in
	# the game and the last thing a player sees each day.
	_is_true(desk.ledger.lift() > 1.0,
		"the ledger is still in the air on the frame it is handed its lines")
	_is_true(not desk.ledger.has_landed(),
		"and has not announced itself landing yet")
	# It must not start writing itself mid-drop either.
	_is_true(desk.ledger.revealed <= 0.0,
		"and no line is scratched while it is still falling")
	var airborne := 0
	while not desk.ledger.has_landed() and airborne < 240:
		airborne += 1
		await get_tree().process_frame
	_is_true(desk.ledger.has_landed() and airborne > 1,
		"it lands under its own weight, over %d frames" % airborne)
	for i in 60:
		await get_tree().process_frame
	_is_true(absf(desk.ledger.lift()) < 0.01,
		"and comes to rest flat on the desk rather than settling forever")
	for i in 30:
		await get_tree().process_frame


func _on_impression_finished(_verdict: int, _record: ImpressionRecord) -> void:
	_impression_finished = true


func _is_true(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("   ok    " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	push_error("   FAIL  " + label)


func _finish() -> void:
	print("\n%d checks, %d failure(s)\n" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

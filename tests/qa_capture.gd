extends Node

## Visual capture harness. Runs the real desk in a real window and writes PNGs.
##
##     godot --path . --resolution 1600x900 --scene res://tests/qa_capture.tscn
##
## Godot cannot render 2D lights with the dummy driver, so this deliberately does
## NOT run headless — lighting is exactly the thing it exists to check. Frames
## land in .tools/shot_*.png, which is gitignored.
##
## Each shot isolates one claim:
##   01  the desk as the player first sees it
##   02  the candle carried to the far left — every shadow should swing round
##   03  the candle set on the charter — a small fierce pool of light
##   04  wax poured and struck dead centre
##   05  wax poured and struck hard off the rim: partial device, bulged wax
##   06  the same, seen close
##   22  the charged spoon after the tablet has become a level liquid reservoir
##   23  the tipped spoon, viscous neck, falling bead, and growing hot pool
##   24  the fresh pool settling before the signet descends
##   25  a received pendant seal filling the glass, at ordinary desk scale
##   26  the same optical detail close enough to inspect its circular legend
##   27  the door mid-swing with somebody still walking out of the room's depth
##   28  the audience view with a person actually standing in it
##   29  the same, speaking
##   30  the withdrawal, back toward the door they came in by

const OUT := "res://.tools/"

var _desk: Desk
var _main: Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_main = packed.instantiate()
	add_child(_main)
	await get_tree().process_frame
	_desk = _main.get_node("desk") as Desk
	await _settle(40)
	await _shot("19_practice_before_first_knock")
	await _hold_to_the_flame()
	if _desk.session.stage == SessionController.Stage.PRACTICE:
		_desk.sweep_packet_away()
		_desk.session._begin_day(0)
	_desk.session.set_process(false)
	_desk.lay_out_packet(Lore.data.cases[0].documents)
	await _settle(60)

	await _shot("01_desk_default")
	await _inspect_pendant_seal()

	# Put both books away, and hover the charter, so one frame shows the rack in
	# use and the grab affordance at the same time.
	for i in mini(2, _desk.books.size()):
		var book: ReferenceBook = _desk.books[i]
		var hole := _desk.ledge.slot_position(i * 2)
		book.solver.place(hole, 0.0)
		book.position = hole
		_desk._try_rack(book)
	await _settle(50)
	# Hover is normally recomputed from the cursor every frame by the desk, so
	# it has to be stopped before it can be posed for a capture.
	_desk.set_process(false)
	# Hover a ring: small, against dark wood, so the affordance is unambiguous
	# in the capture rather than lost against lit parchment.
	_desk.rings[1].hovered = true
	if _desk.current_charter != null:
		_desk.current_charter.hovered = true
	await _settle(24)
	await _shot("10_books_racked")
	_desk.rings[1].hovered = false
	if _desk.current_charter != null:
		_desk.current_charter.hovered = false
	_desk.set_process(true)
	for i in mini(2, _desk.books.size()):
		var book: ReferenceBook = _desk.books[i]
		book.unstow()
		_desk.ledge.release(book)
		var home: Vector2 = Lore.book(book.data.id).start_offset
		book.solver.place(home, 0.0)
		book.position = home
	await _settle(20)

	var home := _desk.candle.position
	await _move_candle(Vector2(-560.0, 120.0))
	await _shot("02_candle_far_left")

	await _move_candle(Vector2(-30.0, 150.0))
	await _shot("03_candle_on_charter")

	# The audience view foreshortens the whole desk plane; the lights are
	# counter-scaled so the room does not get a bright horizontal stripe.
	await _move_candle(home)
	var view_up := _main.get_node_or_null("view_controller")
	if view_up != null and view_up.has_method("look_up"):
		view_up.look_up()
		await _settle(80)
		await _shot("09_audience_view")
		view_up.look_down()
		await _settle(80)

	await _show_the_petitioner()

	await _pour_and_strike(Vector2.ZERO, "04_strike_centre")
	# Far enough out that the die genuinely hangs over the edge of the material:
	# this is the shot that proves the impression is clipped by the wax and not
	# merely translated within it.
	await _pour_and_strike(Vector2(38.0, -16.0), "05_strike_off_rim")

	# Close crops of both impressions. The view controller owns the camera every
	# frame, so it has to be stopped before the camera will hold a pose.
	var view := _main.get_node_or_null("view_controller")
	if view != null:
		view.set_process(false)
		view.set_process_input(false)
	var camera := _main.get_node("camera") as Camera2D
	if _desk.press.pool != null and is_instance_valid(_desk.press.pool):
		camera.position = _desk.press.pool.global_position
		camera.zoom = Vector2(4.5, 4.5)
		await _settle(8)
		await _shot("06_strike_off_rim_close")

	# And a centred strike at the same magnification, for comparison.
	camera.zoom = Vector2(1.0, 1.0)
	camera.position = Vector2(960, 590)
	await _settle(4)
	await _pour_and_strike(Vector2.ZERO, "07_strike_centre_again")
	if _desk.press.pool != null and is_instance_valid(_desk.press.pool):
		camera.position = _desk.press.pool.global_position
		camera.zoom = Vector2(4.5, 4.5)
		await _settle(8)
		await _shot("08_strike_centre_close")

	await _show_the_kalendar()
	await _show_charter_foot()
	await _show_the_register()
	await _show_reviewed_register()
	await _inspect_own_seal()
	await _show_day_two()
	await _the_knife()
	await _candle_close()
	await _write_on_tablet()
	await _burn_series()

	print("captured")
	get_tree().quit(0)


## Thursday as it first appears: the chosen Kesselholt consequence on paper,
## four protruding passage tabs, and a new person rather than a menu.
func _show_day_two() -> void:
	# Pose the real CHOOSING composition: no stale Tuesday packet and nobody at
	# the desk until a docket has actually been laid in the hearing notch.
	_desk.sweep_packet_away()
	_desk._finish_sweep()
	_desk.petitioner.clear()
	var kessel := Lore.data.case_by_id(&"case_03_kesselholt")
	var prior := RulingRecord.new()
	prior.case_id = kessel.id
	prior.day_id = &"day_01"
	prior.case_title = kessel.title
	prior.verdict = Lex.Verdict.REFER
	prior.lawful_verdict = Lex.Verdict.REFER
	prior.was_sound = true
	prior.subject_id = kessel.charter().subject_id
	prior.claimant_id = kessel.charter().claimant_id
	prior.authority_verdicts = Adjudicator.adjudicate_case(
		kessel, Lore.data, null).authority_split()
	_desk.session.register.add(prior)
	var day := Lore.data.day_by_id(&"day_02")
	_desk.lay_out_day_documents(day.resolve_opening_documents(
		_desk.session.register))
	_desk.show_docket_tray(day.resolve_cases(Lore.data, _desk.session.register))
	var camera := _main.get_node("camera") as Camera2D
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	_desk.set_process(true)
	await _settle(70)
	await _shot("20_thursday_docket_and_letter")
	_desk.hide_docket_tray()
	_desk.lay_out_day_documents([])
	_desk.session.register.entries.erase(prior)


## Close on the foot of the charter: the witness list, the chancery annotation
## against a dead witness, and the closing formula. Adding the annotation pushed
## the list downward, so this is checking it has not collided with anything.
func _show_charter_foot() -> void:
	var sheet := _desk.current_charter
	if sheet == null:
		return
	var view := _main.get_node_or_null("view_controller")
	if view != null:
		view.set_process(false)
		view.set_process_input(false)
	var camera := _main.get_node("camera") as Camera2D
	camera.position = sheet.to_global(Vector2(0, sheet.data.size.y * 0.26))
	camera.zoom = Vector2(2.6, 2.6)
	await _settle(20)
	await _shot("18_charter_foot")
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	await _settle(6)


## The Register open on the desk, showing the previous notary's entries — the
## precedent that used to arrive only after every ruling had been made.
func _show_the_register() -> void:
	var book := _desk.register_book
	if book == null:
		return
	var camera := _main.get_node("camera") as Camera2D
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	_desk.set_process(true)
	book.unstow()
	_desk.ledge.release(book)
	_desk.bring_to_front(book)
	var at := Vector2(-330.0, 120.0)
	book.solver.place(at, deg_to_rad(-1.5))
	book.position = at
	book.is_open = true
	# Second spread: the previous notary's contested-reckoning entry.
	book.spread = mini(1, maxi(0, book.data.spread_count() - 1))
	await _settle(50)
	await _shot("17_the_register")


## A senior correction arriving as a physical event: the book has returned from
## the rack and a vermilion slip protrudes beyond its cover.
func _show_reviewed_register() -> void:
	var first := Lore.data.case_by_id(&"case_01_kufergasse")
	var wrong := RulingRecord.new()
	wrong.case_id = first.id
	wrong.case_title = first.title
	wrong.petitioner_name = first.petitioner.name
	wrong.verdict = Lex.Verdict.DENY
	wrong.lawful_verdict = Lex.Verdict.CONFIRM
	wrong.was_sound = false
	wrong.finding_codes = Adjudicator.adjudicate_case(
		first, Lore.data, null).codes()
	var later := RulingRecord.new()
	later.case_id = &"review_probe"
	later.case_title = "The Following Matter"
	later.was_sound = true
	var review_register := Register.new()
	review_register.add(wrong)
	review_register.add(later)
	_desk.register_book.bind(RegisterBook.build(
		review_register, Lore.data), Desk.DESK_RECT)
	_desk.reveal_register_review()
	await _settle(45)
	await _shot("21_reviewed_register")
	_desk.register_book.bind(RegisterBook.build(
		_desk.session.register, Lore.data), Desk.DESK_RECT)


## Hold the glass over the seal the player has just struck. This reads back what
## their own hands did, which is the point of grading the press at all.
func _inspect_own_seal() -> void:
	var pool := _desk.press.pool
	if pool == null or not is_instance_valid(pool) or not pool.has_detail():
		return
	var camera := _main.get_node("camera") as Camera2D
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	_desk.set_process(true)
	_desk.bring_to_front(_desk.lens)
	var over := _desk.surface.to_local(pool.detail_centre())
	_desk.lens.solver.place(over, 0.0)
	_desk.lens.position = over
	await _settle(45)
	await _shot("16_glass_on_own_seal")
	# Put it back where it lives.
	_desk.lens.solver.place(Vector2(700, 250), deg_to_rad(-14.0))
	_desk.lens.position = Vector2(700, 250)
	await _settle(10)


## The incoming seal is the actual evidence-reading use of the lens: its device,
## rubbed letters and physical wear all need to survive enlargement.
func _inspect_pendant_seal() -> void:
	var seal: SealTag = null
	for paper in _desk.case_papers:
		if paper is SealTag:
			seal = paper
			break
	if seal == null:
		return
	var view := _main.get_node_or_null("view_controller")
	var camera := _main.get_node("camera") as Camera2D
	_desk.bring_to_front(_desk.lens)
	var over := _desk.surface.to_local(seal.detail_centre())
	_desk.lens.solver.place(over, 0.0)
	_desk.lens.position = over
	await _settle(45)
	await _shot("25_glass_on_pendant_seal")

	if view != null:
		view.set_process(false)
		view.set_process_input(false)
	camera.position = _desk.lens.global_position
	camera.zoom = Vector2(2.5, 2.5)
	await _settle(12)
	await _shot("26_glass_pendant_close")
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	if view != null:
		view.set_process(true)
		view.set_process_input(true)
	_desk.lens.solver.place(Vector2(700, 250), deg_to_rad(-14.0))
	_desk.lens.position = Vector2(700, 250)
	await _settle(12)


## The case the erasure mechanic exists for, against the flame.
##
## Its two patches are authored as fractions of the sheet, and a fraction that is
## slightly wrong puts the ghost over the wrong paragraph — which is worse than no
## patch, because it teaches the player to look in the wrong place. There is no
## way to check that except to look, so this frame is the check.
func _the_knife() -> void:
	var case_data := Lore.data.case_by_id(&"case_08_mill_on_the_aue")
	if case_data == null:
		return
	var camera := _main.get_node("camera") as Camera2D
	_desk.sweep_packet_away()
	_desk._finish_sweep()
	_desk.lay_out_packet(case_data.documents)
	await _settle(50)
	var leaf := _desk.current_charter
	if leaf == null:
		return
	_desk.bring_to_front(leaf)
	leaf.is_held = true
	# Put the SCRAPE at the flame, not the sheet. Each patch is lit at its own
	# position, so posing this by the middle of the parchment shows a charter near
	# a candle and nothing coming up on it — which is the mechanic working and the
	# capture failing. The dispositive patch sits about 57 units below centre.
	var at := _desk.candle.position + Vector2(-95.0, -57.0)
	leaf.solver.place(at, deg_to_rad(-1.0))
	leaf.position = at
	camera.zoom = Vector2(1.9, 1.9)
	camera.position = _desk.to_global(at) + Vector2(-40, 40)
	await _settle(46)
	await _shot("35_the_knife_against_the_flame")
	leaf.is_held = false

	# AND THE NEGATIVE READING, which is the half of this verb that matters more.
	#
	# A sound charter against the light has to ANSWER — even amber, the laid lines
	# standing up, the follicles showing — or a player who tries the gesture on a
	# clean packet learns that it is broken rather than that the parchment is
	# whole. These two frames side by side are the entire skill the mechanic
	# teaches, and if they ever stop being obviously different, it has stopped
	# being a mechanic.
	_desk.sweep_packet_away()
	_desk._finish_sweep()
	_desk.lay_out_packet(Lore.data.cases[0].documents)
	await _settle(50)
	var clean := _desk.current_charter
	if clean != null:
		_desk.bring_to_front(clean)
		clean.is_held = true
		var here := _desk.candle.position + Vector2(-95.0, -40.0)
		clean.solver.place(here, deg_to_rad(-1.0))
		clean.position = here
		camera.position = _desk.to_global(here) + Vector2(-30, 30)
		await _settle(46)
		await _shot("42_whole_skin_against_the_flame")
		clean.is_held = false

	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	await _settle(16)


## The fourth investigative verb, on the leaf that teaches it.
##
## At rest the scrape is a difference in the nap and nothing else; lifted into the
## flame the thin place transmits and the word that was cut out comes back. Both
## states are captured, because the whole design of this mechanic is the gap
## between them — if the "at rest" frame reads as a highlighted box then the verb
## is decoration, and if it reads as nothing at all then the verb is unfair.
func _hold_to_the_flame() -> void:
	var leaf: Sheet = null
	for node in _desk.case_papers:
		if node is CharterView:
			leaf = node
	if leaf == null:
		return
	var camera := _main.get_node("camera") as Camera2D
	_desk.bring_to_front(leaf)
	camera.zoom = Vector2(2.1, 2.1)
	camera.position = _desk.to_global(leaf.position) + Vector2(0, -20)
	await _settle(24)
	await _shot("33_scrape_at_rest")

	# Exactly what a player does: pick the sheet up and carry it to the candle.
	leaf.is_held = true
	# Beside the flame rather than on top of it, so the candle sprite does not
	# cover the very patch this frame exists to show. Still inside BACKLIT_LEVEL.
	# The practice leaf's scrape sits about 52 units BELOW its centre, so posing
	# this by the middle of the sheet puts the patch a hand's width further from
	# the wick than it looks and the ghost never comes up. Each patch is lit at
	# its own position; the capture has to respect that or it lies about the
	# mechanic.
	var flame := _desk.candle.position + Vector2(-95.0, -52.0)
	leaf.solver.place(flame, leaf.rotation)
	leaf.position = flame
	camera.position = _desk.to_global(flame) + Vector2(0, 40)
	await _settle(40)
	await _shot("34_scrape_against_the_flame")

	leaf.is_held = false
	leaf.solver.place(Vector2(-20, 52), deg_to_rad(-2.0))
	leaf.position = Vector2(-20, 52)
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	await _settle(20)


## The Kalendar of the Dead, open at a house's roll. Everything WitnessCheck can
## convict on has to be legible here or the ledger is quoting evidence that was
## never on the desk, so this frame is a contract test with pixels.
func _show_the_kalendar() -> void:
	if _desk.kalendar_book == null:
		return
	var camera := _main.get_node("camera") as Camera2D
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	var book := _desk.kalendar_book
	_desk.ledge.release(book)
	book.unstow()
	_desk.bring_to_front(book)
	var at := Vector2(-120.0, 150.0)
	book.solver.place(at, deg_to_rad(-1.5))
	book.position = at
	book.is_open = true
	# The head of a roll: coverage, reckoning, and how far it is written up.
	book.spread = 1
	await _move_candle(Vector2(60.0, -10.0))
	await _settle(50)
	await _shot("31_kalendar_of_the_dead")
	book.spread = 2
	await _settle(30)
	await _shot("32_kalendar_a_roll")
	book.is_open = false
	await _settle(20)
	_desk._park_in_rack(book, 2)
	await _settle(20)


## The one thing this capture set never showed: a person in the room.
##
## Arrival, the open door behind them, the audience view with somebody actually
## standing in it, and the withdrawal. The door and the approach are the two
## motions that share a plane, so they have to be looked at in the same frame or
## a mismatch between them is invisible.
func _show_the_petitioner() -> void:
	var view := _main.get_node_or_null("view_controller")
	var who := Lore.data.cases[0].petitioner
	_desk.petitioner.bind(who)
	_desk.petitioner.arrive()
	_desk.open_door()
	# Early enough that the leaf is still swinging and the figure is still at the
	# far end of its walk. A shot of either at rest proves nothing.
	await _settle(14)
	await _shot("27_door_and_approach")

	if view != null and view.has_method("look_up"):
		view.look_up()
	await _settle(90)
	await _shot("28_petitioner_at_the_desk")

	_desk.petitioner.say(
		"Wilhelm Ott, master cooper, of the Free City of Marchfeld.", who.name)
	await _settle(46)
	await _shot("29_petitioner_speaking")

	_desk.open_door()
	_desk.petitioner.depart()
	await _settle(22)
	await _shot("30_withdrawal")

	_desk.close_door()
	await _settle(70)
	_desk.petitioner.clear()
	if view != null and view.has_method("look_down"):
		view.look_down()
	await _settle(80)


## THE CANDLE, CLOSE, AT FIVE HOURS OF THE DAY.
##
## The wide burn series (11-14) shows what the ROOM does as the light goes. It
## cannot show what the object does, because at the size the candle occupies in a
## desk-wide frame it is about ninety pixels and any change to it is a handful of
## them. Every judgement about whether the melt is satisfying has to be made here.
func _candle_close() -> void:
	var camera := _main.get_node("camera") as Camera2D
	var view := _main.get_node_or_null("view_controller")
	if view != null:
		view.set_process(false)
		view.set_process_input(false)
	_desk.set_process(true)
	await _move_candle(Vector2(60.0, 40.0))
	camera.zoom = Vector2(4.0, 4.0)
	camera.position = _desk.candle.global_position + Vector2(0, -14)

	for step in [
		{"burn": 0.00, "label": "36_candle_close_fresh"},
		{"burn": 0.30, "label": "37_candle_close_third"},
		{"burn": 0.62, "label": "38_candle_close_half"},
		{"burn": 0.90, "label": "39_candle_close_low"},
		{"burn": 0.99, "label": "40_candle_close_guttering"},
	]:
		_desk.candle.reset_day()
		_desk.candle.burn = float(step["burn"])
		await _settle(26)
		await _shot(String(step["label"]))

	_desk.candle.snuff()
	await _settle(30)
	await _shot("41_candle_close_out")
	_desk.candle.reset_day()
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	if view != null:
		view.set_process(true)
		view.set_process_input(true)
	await _settle(16)


## Scratch a note onto the tablet, the way a player would: drag the stylus
## across the wax and let the marks fall where the nib went.
func _write_on_tablet() -> void:
	var tablet := _desk.tablet
	var stylus := _desk.stylus
	if tablet == null or stylus == null:
		return
	var camera := _main.get_node("camera") as Camera2D
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	_desk.set_process(false)
	tablet.unstow()
	_desk.ledge.release(tablet)
	# Taking it out of the rack brings it to the top of the pile, as picking
	# anything up does; a capture has to do the same or it lands under a charter.
	_desk.bring_to_front(tablet)
	var at := Vector2(-520.0, 292.0)
	tablet.solver.place(at, deg_to_rad(-2.0))
	tablet.position = at
	tablet.clear_marks()
	await _settle(40)

	# "1213" and a struck-through line, in the notary's own bad hand.
	var pen := tablet.inner_rect().position + Vector2(26.0, 44.0)
	var paths := [
		[Vector2(0, 0), Vector2(4, -14), Vector2(6, 34)],
		[Vector2(22, -12), Vector2(38, -14), Vector2(40, 2), Vector2(22, 20),
			Vector2(20, 34), Vector2(42, 33)],
		[Vector2(58, -12), Vector2(74, -13), Vector2(66, 8), Vector2(76, 20),
			Vector2(60, 33)],
		[Vector2(92, 0), Vector2(96, -14), Vector2(98, 34)],
		[Vector2(0, 66), Vector2(120, 62)],
		[Vector2(6, 96), Vector2(38, 92), Vector2(70, 98), Vector2(118, 92)],
		[Vector2(6, 122), Vector2(52, 118)],
	]
	for path in paths:
		for step in path:
			var target: Vector2 = pen + step
			var here := _desk.surface.to_local(tablet.to_global(target)) \
				- stylus.tip_local()
			# A few frames per control point so the stroke records intermediate
			# positions rather than teleporting between corners.
			for _f in 3:
				stylus.solver.place(here, 0.0)
				stylus.position = here
				tablet.tick(1.0 / 60.0, stylus, 320.0)
				await get_tree().process_frame
		tablet.tick(1.0 / 60.0, null, 0.0)
		await get_tree().process_frame

	# Park the stylus beside the tablet so it is not lying across the note.
	var park := at + Vector2(210.0, 110.0)
	stylus.solver.place(park, deg_to_rad(14.0))
	stylus.position = park
	_desk.set_process(true)
	await _settle(30)
	await _shot("15_tablet_note")


## One candle is one day. These four frames are the whole arc of it: the light
## pulling in around the wick, the saucer flooding, and the cold morning that
## replaces the flame when it finally drowns.
func _burn_series() -> void:
	var camera := _main.get_node("camera") as Camera2D
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	_desk.set_process(true)
	_desk.candle.reset_day()
	await _move_candle(Vector2(120.0, 40.0))

	for step in [
		{"burn": 0.0, "label": "11_candle_fresh"},
		{"burn": 0.62, "label": "12_candle_half"},
		{"burn": 0.95, "label": "13_candle_guttering"},
	]:
		_desk.candle.reset_day()
		_desk.candle.burn = float(step["burn"])
		await _settle(20)
		await _shot(String(step["label"]))

	_desk.candle.snuff()
	_desk.begin_morning()
	await _settle(150)
	await _shot("14_day_over")


func _move_candle(to: Vector2) -> void:
	# Picking anything up brings it to the top of the stack; teleporting it in a
	# capture has to do the same or the shot is not what the player would see.
	_desk.bring_to_front(_desk.candle)
	_desk.candle.solver.place(to, _desk.candle.rotation)
	_desk.candle.position = to
	await _settle(12)


## Melt, carry, pour, then strike at a chosen offset from the pool's centre.
func _pour_and_strike(offset: Vector2, label: String) -> void:
	var press := _desk.press
	var sheet := _desk.current_charter
	var spoon := _desk.wax_spoon
	# The desk ticks the press once per frame with whatever is actually in the
	# player's hand — which is nothing here. Leaving it running fought every
	# manual tick below and silently aborted the descent, so the ring never
	# reached the wax. Drive the press by hand only.
	_desk.set_process(false)
	press.reset_for_new_case(sheet)
	press.enabled = true
	_desk.bring_to_front(spoon)

	var flame := _desk.surface.to_local(_desk.candle.flame_world()) + Vector2(0, -42)
	var heat_at := flame - spoon.bowl_local(press.feel)
	spoon.solver.place(heat_at, 0.0)
	spoon.position = heat_at
	for i in 170:
		press.tick(1.0 / 60.0, spoon, heat_at, 0.0)
		await get_tree().process_frame
	if label == "04_strike_centre":
		await _shot("22_wax_molten")

	var slot := _desk.surface.to_local(sheet.wax_slot_world())
	var spoon_at := slot - spoon.lip_local(press.feel)
	spoon.solver.place(spoon_at, 0.0)
	spoon.position = spoon_at
	for i in 105:
		press.tick(1.0 / 60.0, spoon, spoon_at, 0.0)
		await get_tree().process_frame
		if label == "04_strike_centre" and i == 48:
			await _shot("23_wax_pouring")
	for i in 40:
		press.tick(1.0 / 60.0, null, spoon_at, 500.0)
		await get_tree().process_frame

	if press.pool == null:
		push_error("[qa] no pool formed for " + label)
		return
	if label == "04_strike_centre":
		await _shot("24_wax_pool_fresh")

	var ring := _desk.rings[0]
	_desk.bring_to_front(ring)
	var ring_at := _desk.surface.to_local(
		press.pool.to_global(offset))
	ring.solver.place(ring_at, 0.0)
	ring.position = ring_at
	for i in 110:
		press.tick(1.0 / 60.0, ring, ring_at, 0.0)
		await get_tree().process_frame
	for i in 40:
		press.tick(1.0 / 60.0, null, ring_at, 500.0)
		await get_tree().process_frame

	var p := press.pool
	print("   pool  %s  impressed=%s device=%s seat=%.2f r=%.1f offset=%s cover=%.2f struck=%d"
		% [label, p.impressed, p.device, p.seat_depth, p.radius,
			str(p.press_offset), p.strike_coverage(), p._struck_polygons().size()])

	# Put the ring back so it does not sit on top of the seal in the shot.
	ring.solver.place(ring.home_position, 0.0)
	ring.position = ring.home_position
	await _settle(8)
	await _shot(label)


func _settle(frames: int) -> void:
	for i in frames:
		# Lighting normally updates from the desk's own _process, which the press
		# captures switch off. Keep the flame driving the room regardless.
		if _desk != null and not _desk.is_processing():
			_desk._update_lighting()
		await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT + "shot_" + label + ".png"
	image.save_png(ProjectSettings.globalize_path(path))
	print("   shot  ", label)

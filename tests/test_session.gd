extends Node

## The whole day, driven through the real session controller.
##
##     godot --headless --fixed-fps 60 --scene res://tests/test_session.tscn
##
## Every other test in this project deliberately freezes SessionController so it
## can pose the desk and drive the press by hand. That leaves the actual loop —
## knock, arrival, speech, work, ruling, reaction, departure, the next knock, and
## finally the ledger — completely unexercised. This runs it for real, at real
## timings, and asserts it gets all the way to the end without stalling.
##
## It also runs the other ending: a candle set short enough to drown mid-day, to
## prove the session closes out properly with people still in the passage.

const STEP := 1.0 / 60.0

var failures := 0
var checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Hand and Seal — the day ===\n")
	await get_tree().process_frame

	await _practice_contract()
	await _work_clock_contract()
	await _full_day()
	await _day_two_tray()
	await _full_thursday()
	await _day_cut_short()
	await _the_week_chases_you()

	print("\n%d checks, %d failure(s)\n" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


# ------------------------------------------------------- working-time contract

func _practice_contract() -> void:
	print("-- judgment is practiced before the first knock")
	var main := _open(false)
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	_is_true(session.stage == SessionController.Stage.PRACTICE
			and desk.current_charter != null,
		"the office opens on a sealable practice leaf")
	await _step(1.5)
	_is_true(session.stage == SessionController.Stage.PRACTICE,
		"the first petitioner waits until practice is complete")
	var record := ImpressionRecord.new()
	record.grade = Lex.Grade.GOOD
	session._on_impression_finished(Lex.Verdict.CONFIRM, record)
	_is_true(session.stage == SessionController.Stage.PRACTICE_REVIEW,
		"the practice judgment leaves time to inspect the device")
	_is_true(session.register.own_entries().is_empty(),
		"practice never enters the legal Register")
	await _step(5.2)
	_is_true(session.stage == SessionController.Stage.PRACTICE_REVIEW,
		"the practice leaf waits until its impression is actually inspected")
	session._on_investigation_performed(&"inspect_impression")
	_is_true(session.stage == SessionController.Stage.PRACTICE_REVIEW
			and session._practice_inspected,
		"confirmed focus leaves the readable impression under the glass")
	session._on_practice_lens_dropped(desk.lens)
	_is_true(session.current_day != null and session.current_day.id == &"day_01",
		"putting the glass down after reading begins the first working day")
	_close(main)


# ------------------------------------------------------- working-time contract

func _work_clock_contract() -> void:
	print("-- the candle measures work, not dialogue state")
	var main := _open()
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	session.current_day.day_seconds = 20.0

	var arrived := await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
	_is_true(arrived, "the timing test reaches arrival speech")

	var before := desk.candle.burn
	await _step(0.75)
	_is_true(is_equal_approx(desk.candle.burn, before),
		"listening before touching the case costs no candle")

	# Drive the same signal a real grab emits. The player may begin sorting the
	# packet before the arrival speech is clicked away; that is work and must
	# count even though the session still says SPEAKING.
	desk.case_work_engaged.emit(desk.current_charter)
	await _step(0.75)
	_is_true(desk.candle.burn > before,
		"handling evidence during arrival speech burns the candle")

	await _hear_them_out(desk)
	await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
	var during_work := desk.candle.burn
	session._work_time = SessionController.WAIT_FIRST + 1.0
	await _step(0.25)
	_is_true(desk.petitioner.is_speaking(),
		"an authored waiting interjection begins during work")
	await _step(0.50)
	_is_true(desk.candle.burn > during_work,
		"the candle keeps burning while work is interrupted by speech")

	_close(main)


# ------------------------------------------------------------- a whole day

func _full_day() -> void:
	print("-- three petitioners, heard to the end")
	var main := _open()
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	# Long enough that the candle is not the thing under test here.
	session.current_day.day_seconds = 100000.0

	var seen: Array[StringName] = []
	var day_cases := Lore.data.day_by_id(&"day_01").resolve_cases(
		Lore.data, session.register)
	for expected in day_cases:
		var arrived := await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
		if not arrived:
			_fail("petitioner '%s' never reached the desk" % expected.id)
			break
		_is_true(session._current != null and session._current.id == expected.id,
			"'%s' is the case on the desk" % expected.id)
		_is_true(desk.current_charter != null,
			"'%s' laid out its charter" % expected.id)

		# The session must not proceed until the petitioner has been heard out.
		_is_true(not desk.press.enabled,
			"the rings are locked while '%s' is still speaking" % expected.id)
		await _hear_them_out(desk)

		var working := await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
		_is_true(working and desk.press.enabled,
			"'%s' hands over to the player" % expected.id)

		# Rule the lawful way, through the same entry point the press uses.
		var record := ImpressionRecord.new()
		record.grade = Lex.Grade.GOOD
		session._on_impression_finished(expected.correct_verdict, record)
		seen.append(expected.id)

		# The reaction has to be heard out too, or the day stalls here.
		await _step(0.4)
		await _hear_them_out(desk)
		var gone := await _await_not_stage(desk,
			[SessionController.Stage.REACTING, SessionController.Stage.DEPARTING], 14.0)
		_is_true(gone, "'%s' leaves the room" % expected.id)

	_is_true(seen.size() == day_cases.size(),
		"every petitioner in the day got a ruling")

	var closed := await _await_stage(desk, SessionController.Stage.LEDGER, 20.0)
	_is_true(closed, "the day closes into the ledger without stalling")
	_is_true(desk.ledger.visible and desk.ledger.total_lines() > 0,
		"the ledger opens with the day written in it")
	_is_true(desk.candle.is_spent(),
		"the notary puts his own candle out at the end of a finished day")
	_is_true(desk.is_morning(), "and the morning comes up")
	_is_true(session.register.own_entries().size() == day_cases.size(),
		"the Register holds one entry per petitioner")
	_is_true(session.unheard.is_empty() and not session.burnt_out,
		"nobody went unheard")

	_close(main)


# ---------------------------------------------------------- the second candle

func _day_two_tray() -> void:
	print("-- Thursday is chosen from the passage tray")
	var main := _open()
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	session.current_day.day_seconds = 100000.0

	# Close Tuesday through the real loop.
	var day_one := Lore.data.day_by_id(&"day_01").resolve_cases(
		Lore.data, session.register)
	for expected in day_one:
		await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
		await _hear_them_out(desk)
		await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
		var record := ImpressionRecord.new()
		record.grade = Lex.Grade.GOOD
		session._on_impression_finished(expected.correct_verdict, record)
		await _step(0.25)
		await _hear_them_out(desk)
		await _await_not_stage(desk,
			[SessionController.Stage.REACTING, SessionController.Stage.DEPARTING],
			14.0)

	await _await_stage(desk, SessionController.Stage.LEDGER, 20.0)
	# Derived from the day, not hardcoded. A count written into the test is a
	# count that has to be edited every time the content changes, and the thing
	# actually being asserted is "every matter heard reached the Register",
	# which the day itself already knows the size of.
	_is_true(session.register.entries_for_day(&"day_01").size() == day_one.size(),
		"Tuesday's rulings are bound into the persistent Register")

	# The folded Thursday corner, not an arbitrary empty click, advances.
	desk.ledger.skip_to_end()
	desk.ledger.spread = maxi(0, desk.ledger.spread_count() - 1)
	var advanced := desk.ledger.on_click(Vector2(
		Ledger.SIZE.x * 0.5 - 20, Ledger.SIZE.y * 0.5 - 20))
	await get_tree().process_frame
	_is_true(advanced and session.current_day.id == &"day_02",
		"turning the folded Thursday corner lights the second candle")
	_is_true(session.stage == SessionController.Stage.CHOOSING,
		"Thursday waits for the notary to choose a docket")
	_is_true(desk.docket_slips.size() == 4,
		"four named matters protrude from the passage tray")
	# Counted by CONTENT, not by size. Thursday used to deliver exactly one
	# document — the Kesselholt letter — because that was the only Tuesday matter
	# with any next-day consequence at all. The knife answers for itself now, so
	# a full Tuesday produces two arrivals, and asserting "== 1" was asserting
	# that the day had nothing else to say.
	var thursday_ids := {}
	for paper in desk.day_papers:
		if is_instance_valid(paper) and paper.data != null:
			thursday_ids[paper.data.id] = true
	_is_true(thursday_ids.has(&"letter_kesselholt_refer"),
		"Tuesday's Kesselholt choice arrives as sealed correspondence")
	_is_true(thursday_ids.has(&"letter_aue_receipt"),
		"and the office receipts the knife the player refused")

	# THE CANDLE FINALLY BUYS SOMETHING.
	#
	# It used to reset to full every morning, so the only scarce thing in the
	# game purchased nothing and an hour spent re-reading the Almanac was free.
	# Thursday is now as long as what Tuesday left in the dish, floored so that a
	# day nobody can finish is never handed out as a punishment.
	_is_true(desk.last_candle_remaining >= Candle.NEXT_DAY_FLOOR
			and desk.last_candle_remaining <= 1.0,
		"what was left of Tuesday's candle is carried into Thursday")
	var thursday := Lore.data.day_by_id(&"day_02")
	_is_true(is_equal_approx(session.day_seconds(),
			thursday.day_seconds * desk.last_candle_remaining),
		"and Thursday is exactly that much shorter than it is authored to be")

	var candle_before := desk.candle.burn
	var chosen := desk.docket_slips[-1].case_id()
	desk.docket_selected.emit(chosen)
	await get_tree().process_frame
	_is_true(chosen == &"case_07_daughters_portion"
			and session._current.id == chosen,
		"the last docket may be heard first")
	_is_true(desk.docket_slips.size() == 3,
		"the selected docket disappears exactly once")
	var still_there := 0
	for paper in desk.day_papers:
		if is_instance_valid(paper):
			still_there += 1
	_is_true(still_there == thursday_ids.size() and still_there > 0,
		"the morning's correspondence remains on the desk during the hearing")
	_is_true(is_equal_approx(candle_before, desk.candle.burn),
		"choosing from the tray spends no candle")

	# Drown this candle with Elsbeth heard and the other three still in the tray.
	session.current_day.day_seconds = 0.6
	await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
	await _hear_them_out(desk)
	await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
	desk.case_work_engaged.emit(desk.current_charter)
	await _await_stage(desk, SessionController.Stage.LEDGER, 12.0)
	_is_true(session.unfinished == session._current.petitioner.name,
		"Thursday records the selected petitioner as heard but unruled")
	_is_true(session.unheard.size() == 3,
		"the three unselected tray matters remain unheard")
	var day_two_ledger := ""
	for line: Dictionary in session._compose_ledger():
		day_two_ledger += String(line.get("text", "")) + "\n"
	_is_true(not day_two_ledger.contains("The Plot on Küfergasse")
			and not day_two_ledger.contains("The Mill at Grellwater"),
		"Thursday's ledger does not reprint Tuesday's judgments")
	_is_true(session.register.entries_for_day(&"day_01").size() == day_one.size(),
		"the earlier Register survives the new day unchanged")

	_close(main)


# ----------------------------------------------------- the complete campaign

func _full_thursday() -> void:
	print("-- Thursday can be completed in reverse docket order")
	var main := _open()
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	session.current_day.day_seconds = 100000.0

	# Complete Tuesday and turn the authored ledger corner.
	var tuesday := Lore.data.day_by_id(&"day_01").resolve_cases(
		Lore.data, session.register)
	for expected in tuesday:
		await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
		await _hear_them_out(desk)
		await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
		var impression := ImpressionRecord.new()
		impression.grade = Lex.Grade.GOOD
		session._on_impression_finished(expected.correct_verdict, impression)
		await _step(0.25)
		await _hear_them_out(desk)
		await _await_not_stage(desk,
			[SessionController.Stage.REACTING, SessionController.Stage.DEPARTING],
			14.0)
	await _await_stage(desk, SessionController.Stage.LEDGER, 20.0)
	desk.ledger.skip_to_end()
	desk.ledger.spread = maxi(0, desk.ledger.spread_count() - 1)
	desk.ledger.on_click(Vector2(
		Ledger.SIZE.x * 0.5 - 20, Ledger.SIZE.y * 0.5 - 20))
	await get_tree().process_frame
	session.current_day.day_seconds = 100000.0

	var chosen_order: Array[StringName] = []
	while not desk.docket_slips.is_empty():
		var chosen := desk.docket_slips[-1].case_id()
		chosen_order.append(chosen)
		desk.docket_selected.emit(chosen)
		_is_true(await _await_stage(
			desk, SessionController.Stage.SPEAKING, 20.0),
			"%s reaches the desk from the chosen docket" % chosen)
		await _hear_them_out(desk)
		await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
		var decision := Adjudicator.adjudicate_case(
			session._current, Lore.data, session.register)
		var impression := ImpressionRecord.new()
		impression.grade = Lex.Grade.GOOD
		session._on_impression_finished(decision.verdict, impression)
		await _step(0.25)
		await _hear_them_out(desk)
		await _await_not_stage(desk,
			[SessionController.Stage.REACTING, SessionController.Stage.DEPARTING],
			14.0)

	_is_true(chosen_order.size() == 4
			and chosen_order[0] == &"case_07_daughters_portion",
		"all four Thursday dockets may be heard in reverse order")
	_is_true(await _await_stage(desk, SessionController.Stage.LEDGER, 20.0),
		"the final Thursday ruling closes into its ledger")
	_is_true(session.register.entries_for_day(&"day_02").size() == 4,
		"Thursday binds four rulings into the persistent Register")
	var dynamic_reviews_ready := true
	for entry in session.register.entries_for_day(&"day_02"):
		var case_data := Lore.data.case_by_id(entry.case_id)
		if case_data != null and case_data.dynamic_precedent \
				and entry.review_headline.is_empty():
			dynamic_reviews_ready = false
	_is_true(dynamic_reviews_ready,
		"dynamic rulings preserve their judgment-time review evidence")
	_is_true(session.unheard.is_empty() and session.unfinished.is_empty(),
		"the completed second day leaves nobody in the passage")
	_is_true(not desk.ledger.allow_next_day,
		"the campaign ends without inventing a third-day corner")

	var register_data := RegisterBook.build(session.register, Lore.data)
	var divider_text := ""
	for page in register_data.pages:
		divider_text += page.heading + "\n"
	_is_true(divider_text.contains("TUESDAY")
			and divider_text.contains("THURSDAY"),
		"the physical Register preserves both day boundaries")

	_close(main)


# --------------------------------------------------------- a day cut short

func _day_cut_short() -> void:
	print("-- the candle goes first")
	var main := _open()
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	# Six seconds of working time: enough to reach the first petitioner and not
	# enough to finish them.
	session.current_day.day_seconds = 6.0

	var arrived := await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
	_is_true(arrived, "the first petitioner still gets through the door")
	await _hear_them_out(desk)
	await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
	desk.case_work_engaged.emit(desk.current_charter)

	# Now simply wait. The candle is the only thing that happens next.
	var ended := await _await_stage(desk, SessionController.Stage.LEDGER, 30.0)
	_is_true(ended, "a drowned candle ends the day on its own")
	_is_true(session.burnt_out, "the session records that the light went first")
	var day_cases := Lore.data.day_by_id(&"day_01").resolve_cases(
		Lore.data, session.register)
	_is_true(session.unfinished == day_cases[0].petitioner.name,
		"the one at the desk is recorded as heard but not ruled")
	_is_true(session.unheard.size() == day_cases.size() - 1,
		"and only the ones still in the passage count as unheard")
	_is_true(desk.candle.is_spent() and desk.is_morning(),
		"the room turns over to morning either way")

	var text := ""
	for line: Dictionary in session._compose_ledger():
		text += String(line.get("text", "")) + "\n"
	_is_true(text.contains("Not heard") and text.contains("Heard, not ruled"),
		"and the ledger keeps the two failures apart, by name")
	_is_true(session.register.own_entries().is_empty(),
		"an unruled day writes no rulings")

	_close(main)


# --------------------------------------------------- the day you did not have

## THE THIRD DAY IS A CONSEQUENCE, NOT A FIXTURE.
##
## Saturday's slots are all gated `requires_unruled` on themselves, so it holds
## exactly what the week failed to hear. Two things have to be true and only a
## real run can show them: a notary who cleared his week is never offered it (the
## older assertion in _full_thursday covers that, and still passes word for word),
## and a notary the candle beat IS — with the right people in the passage.
##
## It also exercises the chain the third day exists for. Thursday's length is
## Tuesday's remainder; Saturday's is Thursday's. Two days can never show that,
## because a chain needs a day that is ENTERED short.
func _the_week_chases_you() -> void:
	print("-- the matters you never heard chase you to the end of the week")
	var main := _open()
	var desk := main.get_node("desk") as Desk
	var session := desk.session

	# Tuesday: rule exactly one matter on a candle that is not under test, then
	# shorten the candle and let the wick go with the rest still in the passage.
	# The order matters — _work_engaged resets per caller, so a drowning has to be
	# arranged on the matter that is actually at the desk.
	session.current_day.day_seconds = 100000.0
	await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
	await _hear_them_out(desk)
	await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
	var heard := session._current.id
	var record := ImpressionRecord.new()
	record.grade = Lex.Grade.GOOD
	session._on_impression_finished(session._current.correct_verdict, record)
	await _step(0.3)
	await _hear_them_out(desk)

	# Now the second caller, on a wick with six seconds left in it.
	await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
	await _hear_them_out(desk)
	await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
	session.current_day.day_seconds = 6.0
	desk.case_work_engaged.emit(desk.current_charter)
	_is_true(await _await_stage(desk, SessionController.Stage.LEDGER, 30.0),
		"Tuesday drowns with matters still in the passage")
	_is_true(session.burnt_out and session.unheard.size() >= 2,
		"and they are recorded as unheard (%d)" % session.unheard.size())
	_is_true(desk.ledger.allow_next_day
			and desk.ledger.next_day_label == "THURSDAY",
		"Thursday is offered")

	desk.ledger.skip_to_end()
	desk.ledger.spread = maxi(0, desk.ledger.spread_count() - 1)
	desk.ledger.on_click(Vector2(Ledger.SIZE.x * 0.5 - 20,
		Ledger.SIZE.y * 0.5 - 20))
	await get_tree().process_frame
	_is_true(session.current_day != null and session.current_day.id == &"day_02",
		"and turning the corner opens it")
	_is_true(desk.last_candle_remaining <= Candle.NEXT_DAY_FLOOR + 0.001,
		"on a candle Tuesday already spent down to the floor (%.2f)"
		% desk.last_candle_remaining)

	# Thursday: drown it too, immediately, so the week ends owing people.
	session.current_day.day_seconds = 0.6
	if session.stage == SessionController.Stage.CHOOSING \
			and not desk.docket_slips.is_empty():
		desk.docket_selected.emit(desk.docket_slips[0].case_id())
	await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
	await _hear_them_out(desk)
	await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
	desk.case_work_engaged.emit(desk.current_charter)
	_is_true(await _await_stage(desk, SessionController.Stage.LEDGER, 20.0),
		"Thursday drowns as well")

	# NOW the third day exists, and it exists BECAUSE the week failed.
	_is_true(desk.ledger.allow_next_day
			and desk.ledger.next_day_label == "SATURDAY",
		"Saturday is offered to a notary the candle beat")

	var owed := Lore.data.day_by_id(&"day_03").resolve_cases(
		Lore.data, session.register)
	var owed_ids := PackedStringArray()
	for c in owed:
		owed_ids.append(String(c.id))
	_is_true(not owed.is_empty(), "and there is somebody in the passage for it")
	_is_true(not owed_ids.has(String(heard)),
		"the matter that WAS ruled is not among them")
	for entry in session.register.own_entries():
		if owed_ids.has(String(entry.case_id)):
			_fail("Saturday re-hears '%s', which was already ruled"
				% entry.case_id)
	checks += 1

	desk.ledger.skip_to_end()
	desk.ledger.spread = maxi(0, desk.ledger.spread_count() - 1)
	desk.ledger.on_click(Vector2(Ledger.SIZE.x * 0.5 - 20,
		Ledger.SIZE.y * 0.5 - 20))
	await get_tree().process_frame
	_is_true(session.current_day != null and session.current_day.id == &"day_03",
		"the third day opens")
	_is_true(session.cases.size() == owed.size(),
		"holding exactly the arrears (%d)" % session.cases.size())
	# THE CHAIN. Saturday is short because Thursday was short because Tuesday
	# was. This is the assertion two days could not carry.
	_is_true(is_equal_approx(session.day_seconds(),
			Lore.data.day_by_id(&"day_03").day_seconds
			* desk.last_candle_remaining),
		"and it is shortened again by what Thursday left")
	_is_true(session.stage == SessionController.Stage.CHOOSING
			and not desk.docket_slips.is_empty(),
		"with the people who have waited longest protruding from the tray")

	_close(main)


# -------------------------------------------------------------------- harness

func _open(skip_practice := true) -> Node:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	if skip_practice:
		var desk := main.get_node("desk") as Desk
		if desk.session.stage == SessionController.Stage.PRACTICE:
			desk.sweep_packet_away()
			desk.session._begin_day(0)
	return main


func _close(main: Node) -> void:
	main.queue_free()
	for i in 3:
		await get_tree().process_frame


## Click through whatever the petitioner is saying. Dialogue only advances on a
## click, so a test that does not do this hangs forever — which is itself worth
## knowing, and is why the stall guards below have timeouts.
func _hear_them_out(desk: Desk) -> void:
	var guard := 0
	while desk.petitioner.is_speaking() and guard < 400:
		desk.petitioner.on_click()
		desk.petitioner.on_click()
		await get_tree().process_frame
		guard += 1


func _await_stage(desk: Desk, stage: int, seconds: float) -> bool:
	var frames := int(seconds * 60.0)
	for i in frames:
		if desk.session.stage == stage:
			return true
		# Speech blocks several stages, so keep the room moving while waiting.
		if desk.petitioner.is_speaking():
			desk.petitioner.on_click()
		await get_tree().process_frame
	return false


func _await_not_stage(desk: Desk, stages: Array, seconds: float) -> bool:
	var frames := int(seconds * 60.0)
	for i in frames:
		if not stages.has(desk.session.stage):
			return true
		if desk.petitioner.is_speaking():
			desk.petitioner.on_click()
		await get_tree().process_frame
	return false


func _step(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await get_tree().process_frame


func _is_true(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("   ok    " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	push_error("   FAIL  " + label)
	print("   FAIL  " + label)

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
	await _servant_delivery_contract()
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

	await _practice_cannot_trap_anybody()
	await _practice_asks_for_one_thing_at_a_time()


## THE OPENING ASKED FOR FOURTEEN THINGS AT ONCE AND FOR NOTHING IN PARTICULAR.
##
## Counted at the first frame: six sentences on the memorandum, five on the
## practice slip, three paragraphs on the practice leaf — the glass, the closing
## formula, the Almanac, the tablet, the stylus, the Kalendar, the spoon, the
## pour, the ring, the candle rule, the resistance, the knife. All present
## simultaneously, none of them saying which to do first. Reported from play as
## not knowing how to do anything and not knowing where to start.
##
## The slip asks for one thing and asks for the next when that thing is done.
## This walks it in order and asserts the slip actually changes each time —
## because the failure mode is silent: a mis-keyed step simply never fires and
## the player is left staring at an instruction they have already carried out.
func _practice_asks_for_one_thing_at_a_time() -> void:
	print("-- the opening asks for one thing at a time")
	var main := _open(false)
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	_is_true(session.stage == SessionController.Stage.PRACTICE,
		"the office opens on practice")

	var card: DocketView = session._practice_card()
	_is_true(card != null, "the doorkeeper's slip is on the desk")
	if card == null:
		_close(main)
		return

	var seen: Array[String] = []
	seen.append(card.docket_data().claim_summary)
	_is_true(seen[0].length() < 120,
		"and it opens on ONE sentence (%d characters)" % seen[0].length())

	# Every step, driven through the signal the desk really emits for it. No
	# step is completed by calling _practice_did directly, or the test would
	# pass against a controller wired to nothing.
	desk.case_work_engaged.emit(desk.current_charter)
	seen.append(card.docket_data().claim_summary)
	_is_true(seen[-1] != seen[-2], "picking something up moves it on")

	desk.investigation_performed.emit(&"hold_to_light")
	seen.append(card.docket_data().claim_summary)
	_is_true(seen[-1] != seen[-2], "the flame moves it on")

	desk.investigation_performed.emit(&"scorch")
	seen.append(card.docket_data().claim_summary)
	_is_true(seen[-1] != seen[-2], "and touching the flame moves it on again")

	desk.press.pour_began.emit()
	seen.append(card.docket_data().claim_summary)
	_is_true(seen[-1] != seen[-2], "pouring moves it on")

	# Out of order, and deliberately: it must be ignored rather than skipping
	# ahead, or a player fiddling with the glass loses their place in the list.
	var before_stray := card.docket_data().claim_summary
	desk.investigation_performed.emit(&"hold_to_light")
	_is_true(card.docket_data().claim_summary == before_stray,
		"doing something out of order does not skip a step")

	desk.press.gave_way.emit()
	seen.append(card.docket_data().claim_summary)
	_is_true(seen[-1] != seen[-2], "the wax giving moves it on")

	var record := ImpressionRecord.new()
	record.grade = Lex.Grade.GOOD
	session._on_impression_finished(Lex.Verdict.CONFIRM, record)
	desk.investigation_performed.emit(&"inspect_impression")
	seen.append(card.docket_data().claim_summary)
	_is_true(seen[-1].contains("Put the glass down"),
		"and reading your own mark is the last of them")

	# Six distinct instructions, never repeating: a list that shows the same
	# line twice is a list the player cannot tell they have advanced.
	var distinct := {}
	for s in seen:
		distinct[s] = true
	_is_true(distinct.size() == seen.size(),
		"every step said something different (%d of %d)"
		% [distinct.size(), seen.size()])
	_close(main)
	await _the_music_is_the_clock()


## THE MELODY PLAYS WHILE THE CANDLE IS BEING SPENT, AND AT NO OTHER TIME.
##
## That is the whole design of the score, and it is the half that is easy to
## break without noticing: a music layer that plays continuously is still music,
## still sounds fine, and has quietly stopped saying anything. The four stems are
## generated by tools/make_music.py and mixed by _drive_music; a composer
## replacing the files must not have to re-derive when each one belongs.
func _the_music_is_the_clock() -> void:
	print("-- the score is on the same rule as the flame")
	var main := _open()
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	session.current_day.day_seconds = 100000.0

	await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
	await _step(0.2)
	_is_true(Audio.music_level(&"music_bed") > 0.5,
		"the room is under everything from the moment it exists")
	# ALL FOUR VOICES ARE ALREADY RUNNING, SILENTLY. They share one chord
	# progression so they can be crossfaded against each other, and that is worth
	# nothing unless they started together — a stem created on first use begins at
	# whatever bar happens to be passing and holds that offset all session.
	for stem: StringName in Audio.MUSIC_STEMS:
		_is_true(Audio.is_music_running(stem),
			"%s is running from the first frame, at whatever volume" % stem)
	_is_true(Audio.music_level(&"music_work") <= 0.001,
		"but listening to a petitioner is free, and silent of melody")

	desk.case_work_engaged.emit(desk.current_charter)
	await _step(0.2)
	_is_true(Audio.music_level(&"music_work") > 0.5,
		"the melody starts on the first hand to the packet, with the clock")

	# Past the guttering line the closing layer takes over. Same threshold the
	# flame uses, so the light going and the music going are one event.
	desk.candle.burn = (Candle.GUTTERING_FROM + 1.0) * 0.5
	await _step(0.2)
	_is_true(Audio.music_level(&"music_close") > 0.3,
		"and the light going is the music going (%.2f)"
		% Audio.music_level(&"music_close"))
	_is_true(Audio.music_level(&"music_work")
			< Audio.music_level(&"music_bed"),
		"with the working melody giving way rather than fighting it")

	# And the wax stops it. _on_impression_finished only rules from WORKING, so
	# the petitioner has to have finished first — ruling over the top of them
	# returns early and leaves the melody playing, which is what this assertion
	# caught the first time it ran.
	desk.candle.burn = 0.2
	await _hear_them_out(desk)
	await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
	var record := ImpressionRecord.new()
	record.grade = Lex.Grade.GOOD
	session._on_impression_finished(session._current.correct_verdict, record)
	await _step(0.3)
	_is_true(session.stage != SessionController.Stage.WORKING,
		"the ruling actually landed")
	_is_true(Audio.music_level(&"music_work") <= 0.001,
		"the wax struck stops the melody, because it stops the clock")
	_close(main)


## THE TUTORIAL WAS A SOFTLOCK AND NOTHING TESTED THAT IT WAS NOT.
##
## PRACTICE_REVIEW had no branch in _process, so the ONLY exit was
## inspect_impression followed by releasing the lens — and the only sentence in
## the game that said so lived in the practice docket's `doorkeeper_note`, the
## faint slanted hand this project had already measured, already documented as
## "never authoritative", and already moved the candle rule out of. A player who
## skimmed it, as five case dockets train them to, sat at a desk with no
## petitioner, no clock and no menu, permanently.
##
## This plays the one thing the old suite never did: a player who strikes the
## practice seal and then does NOTHING AT ALL.
func _practice_cannot_trap_anybody() -> void:
	print("-- and a player who does nothing is not trapped at the desk")
	var main := _open(false)
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	var record := ImpressionRecord.new()
	record.grade = Lex.Grade.GOOD
	session._on_impression_finished(Lex.Verdict.CONFIRM, record)
	_is_true(session.stage == SessionController.Stage.PRACTICE_REVIEW,
		"the practice judgment leaves time to inspect the device")

	# Hands off the mouse from here. Nothing below touches the desk.
	session._timer = SessionController.PRACTICE_PATIENCE - 0.2
	await _step(0.5)
	_is_true(session._practice_inspected and session._practice_gave_up,
		"the doorkeeper eventually opens the door himself")
	_is_true(session.stage == SessionController.Stage.PRACTICE_REVIEW,
		"and the leaf is still there to be read, because opening a door is not "
		+ "a deadline")
	session._timer = SessionController.PRACTICE_PATIENCE \
		+ SessionController.PRACTICE_GRACE - 0.2
	await _step(0.5)
	_is_true(session.current_day != null and session.current_day.id == &"day_01",
		"and the first working day begins without the player ever finding the "
		+ "one faint sentence that used to be the only way out")
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
	var thursday_case_count := Lore.data.day_by_id(&"day_02").resolve_cases(
		Lore.data, session.register).size()
	_is_true(desk.docket_slips.size() == thursday_case_count,
		"every named Thursday matter protrudes from the passage tray")
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

	# THE CANDLE FINALLY BUYS SOMETHING, AND IT BUYS IT BY ADDING.
	#
	# It used to reset to full every morning, so the only scarce thing in the
	# game purchased nothing and an hour spent re-reading the Almanac was free.
	# Then it multiplied, which welded the days together: a shorter Tuesday was a
	# lower carry was a shorter Thursday, for exactly the player already drowning
	# on Thursday. What carries now is the stub, in seconds, lit on top of
	# Thursday's own candle and capped at CARRY_CAP of it.
	_is_true(desk.last_candle_seconds > 0.0,
		"a stub of Tuesday's candle is carried into Thursday (%.1f s)"
		% desk.last_candle_seconds)
	var thursday := Lore.data.day_by_id(&"day_02")
	_is_true(is_equal_approx(session.day_seconds(),
			thursday.day_seconds + desk.last_candle_seconds),
		"and Thursday is exactly that much LONGER than it is authored to be")
	_is_true(session.day_seconds() >= thursday.day_seconds,
		"a day is never shorter than the office authored it")
	# The cap is what stops an efficient player accumulating until the clock is
	# decoration again on the day they have finally learnt to beat it.
	_is_true(session.day_seconds()
			<= thursday.day_seconds * (1.0 + SessionController.CARRY_CAP) + 0.001,
		"and never longer than its own candle and a third")

	var candle_before := desk.candle.burn
	var chosen := desk.docket_slips[-1].case_id()
	desk.docket_selected.emit(chosen)
	await get_tree().process_frame
	_is_true(chosen == &"case_07_daughters_portion"
			and session._current.id == chosen,
		"the last docket may be heard first")
	_is_true(desk.docket_slips.size() == thursday_case_count - 1,
		"the selected docket disappears exactly once")
	var still_there := 0
	for paper in desk.day_papers:
		if is_instance_valid(paper):
			still_there += 1
	_is_true(still_there == thursday_ids.size() and still_there > 0,
		"the morning's correspondence remains on the desk during the hearing")
	_is_true(is_equal_approx(candle_before, desk.candle.burn),
		"choosing from the tray spends no candle")

	# Drown this candle with Elsbeth heard and the other matters still in the tray.
	_force_short_day(desk, 0.6)
	await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
	await _hear_them_out(desk)
	await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
	desk.case_work_engaged.emit(desk.current_charter)
	await _await_stage(desk, SessionController.Stage.LEDGER, 12.0)
	_is_true(session.unfinished == session._current.petitioner.name,
		"Thursday records the selected petitioner as heard but unruled")
	_is_true(session.unheard.size() == thursday_case_count - 1,
		"the unselected tray matters remain unheard")
	var day_two_ledger := ""
	for line: Dictionary in session._compose_ledger():
		day_two_ledger += String(line.get("text", "")) + "\n"
	_is_true(not day_two_ledger.contains("The Plot on Küfergasse")
			and not day_two_ledger.contains("The Mill at Grellwater"),
		"Thursday's ledger does not reprint Tuesday's judgments")
	_is_true(session.register.entries_for_day(&"day_01").size() == day_one.size(),
		"the earlier Register survives the new day unchanged")

	_close(main)

	await _a_wrong_ruling_costs_candle()


## THE COUNTERWEIGHT TO A CLOCK THAT FINALLY BITES.
##
## A tight day rewards skipping the books that cannot answer this packet — which
## is the skill the Kalendar's covering line and the Matrices' plates spend their
## front matter teaching, and the whole reason the day was shortened. But it
## rewards GUESSING exactly as much unless being wrong costs something, and
## before this it cost one line of ledger prose, a favour tally nothing reads,
## and a review slip. Bank the time you would have spent looking, take the odds.
##
## So the stub is scaled by the day's soundness. This plays Tuesday with one
## matter deliberately ruled against the law and asserts the wager actually pays
## out — including that the CAP does not swallow it, which it did in the first
## draft: capping after scaling left three quarters of 183 s still clipping to
## the same 136 s, so one wrong ruling in four cost precisely nothing.
func _a_wrong_ruling_costs_candle() -> void:
	print("-- and what you carry into tomorrow is only as good as today's rulings")
	var main := _open()
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	session.current_day.day_seconds = 100000.0

	var day_one := Lore.data.day_by_id(&"day_01").resolve_cases(
		Lore.data, session.register)
	var wronged := ""
	for expected in day_one:
		await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0)
		await _hear_them_out(desk)
		await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
		var record := ImpressionRecord.new()
		record.grade = Lex.Grade.GOOD
		# Küfergasse is the one matter in the day that is a plain finding of
		# fact: no authority contest, so DENY is simply unsound. Everything else
		# is ruled correctly, which is what makes the fraction assertable.
		var ring := expected.correct_verdict
		if expected.id == &"case_01_kufergasse":
			ring = Lex.Verdict.DENY
			wronged = String(expected.id)
		session._on_impression_finished(ring, record)
		await _step(0.25)
		await _hear_them_out(desk)
		await _await_not_stage(desk,
			[SessionController.Stage.REACTING, SessionController.Stage.DEPARTING],
			14.0)

	await _await_stage(desk, SessionController.Stage.LEDGER, 20.0)
	_is_true(not wronged.is_empty(), "a matter was ruled against the law")
	var kept := session.register.sound_fraction_for_day(&"day_01")
	_is_true(kept > 0.0 and kept < 1.0,
		"the day is recorded as partly unsound (%.2f)" % kept)
	# Captured before the corner is turned, because reset_for_next_day zeroes it.
	var raw := desk.candle.carry_forward_seconds()
	var thursday := Lore.data.day_by_id(&"day_02")
	var allowed := thursday.day_seconds * SessionController.CARRY_CAP

	# THE LEDGER SAYS SO TONIGHT, BEFORE THE MORNING CHARGES FOR IT. A rule the
	# player only meets by having already been billed under it is a trap.
	var closing := ""
	for line: Dictionary in session._compose_ledger():
		closing += String(line.get("text", "")) + "\n"
	_is_true(closing.contains("reviewing room"),
		"and the ledger says where the rest of the candle went")

	desk.ledger.skip_to_end()
	desk.ledger.spread = maxi(0, desk.ledger.spread_count() - 1)
	desk.ledger.on_click(Vector2(Ledger.SIZE.x * 0.5 - 20,
		Ledger.SIZE.y * 0.5 - 20))
	await get_tree().process_frame
	_is_true(session.current_day != null and session.current_day.id == &"day_02",
		"Thursday opens")
	_is_true(is_equal_approx(desk.last_candle_seconds, minf(raw, allowed) * kept),
		"the stub is capped and then scaled by soundness (%.1f s)"
		% desk.last_candle_seconds)
	_is_true(desk.last_candle_seconds < allowed - 1.0,
		"so being wrong costs real candle rather than being clipped away by the "
		+ "cap (%.1f s of an allowed %.1f)" % [desk.last_candle_seconds, allowed])
	_close(main)


# ------------------------------------------------------ unattended delivery

func _servant_delivery_contract() -> void:
	print("-- one Thursday packet is delivered and left with the notary")
	var main := _open()
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	session._begin_day(1)
	session.current_day.day_seconds = 60.0

	var delivered := Lore.data.case_by_id(&"case_09_breitenau_weir")
	var ordinary := Lore.data.case_by_id(&"case_04_second_lion")
	var unattended := 0
	for case_data in Lore.data.cases:
		if not case_data.petitioner_waits:
			unattended += 1
	_is_true(delivered != null and not delivered.petitioner_waits,
		"the six-seal matter is the servant-delivered matter")
	_is_true(unattended == 1,
		"exactly one authored matter uses unattended delivery")
	_is_true(ordinary != null and ordinary.petitioner_waits,
		"the following Thursday matter keeps an attending petitioner")

	var same_candle := desk.candle
	desk.docket_selected.emit(delivered.id)
	_is_true(await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0),
		"the servant reaches the desk and gives the handover")
	await _hear_them_out(desk)
	_is_true(await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
			and desk.press.enabled,
		"the packet becomes sealable when the handover ends")

	# No hand has touched the matter yet, so the candle remains free while the
	# servant crosses back to the door.
	var before_work := same_candle.burn
	await _step(3.0)
	_is_true(desk.petitioner.data == null and desk.door_is_settled(),
		"the servant has left and the door is shut before deliberation")
	_is_true(is_equal_approx(same_candle.burn, before_work),
		"the messenger's departure itself spends no candle")

	# An unattended packet can still cost working time, but cannot speak an
	# investigation line from an empty room.
	desk.case_work_engaged.emit(desk.current_charter)
	await _step(0.5)
	_is_true(same_candle.burn > before_work,
		"work on the unattended packet burns the same Thursday candle")
	session._on_investigation_performed(&"inspect_seal")
	await get_tree().process_frame
	_is_true(not desk.petitioner.is_speaking(),
		"an absent servant never answers an investigation beat")

	var impression := ImpressionRecord.new()
	impression.grade = Lex.Grade.GOOD
	session._on_impression_finished(delivered.correct_verdict, impression)
	await get_tree().process_frame
	_is_true(not desk.petitioner.is_speaking(),
		"an absent servant never voices the authored outcome reaction")
	_is_true(await _await_stage(desk, SessionController.Stage.CHOOSING, 12.0),
		"the delivered matter clears back to the same passage tray")
	var after_delivery := same_candle.burn

	# Choose the untouched ordinary matter immediately after it. No day turn, no
	# new candle, and this caller stays in the room through WORKING.
	desk.docket_selected.emit(ordinary.id)
	_is_true(await _await_stage(desk, SessionController.Stage.SPEAKING, 20.0),
		"the ordinary matter follows the servant delivery back-to-back")
	_is_true(desk.candle == same_candle
			and is_equal_approx(same_candle.burn, after_delivery),
		"both matters use one continuous Thursday candle")
	await _hear_them_out(desk)
	_is_true(await _await_stage(desk, SessionController.Stage.WORKING, 8.0)
			and desk.petitioner.has_arrived()
			and desk.petitioner.data != null,
		"the ordinary petitioner remains present while the next matter is worked")

	session.unfinished = delivered.petitioner.name
	session.unfinished_unattended = true
	var ledger_text := ""
	for line: Dictionary in session._ledger_unheard():
		ledger_text += String(line.get("text", "")) + "\n"
	_is_true(ledger_text.contains("Delivered, not ruled")
			and not ledger_text.contains("Stood at the desk"),
		"an unfinished delivery is not recorded as a waiting petitioner")

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

	var thursday_count := Lore.data.day_by_id(&"day_02").resolve_cases(
		Lore.data, Register.new()).size()
	_is_true(chosen_order.size() == thursday_count
			and chosen_order[0] == &"case_07_daughters_portion",
		"all Thursday dockets may be heard in reverse order")
	_is_true(await _await_stage(desk, SessionController.Stage.LEDGER, 20.0),
		"the final Thursday ruling closes into its ledger")
	_is_true(session.register.entries_for_day(&"day_02").size() == thursday_count,
		"Thursday binds every ruling into the persistent Register")
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

	# THE CAMPAIGN HAD NO LAST PAGE. It printed a Thursday tally and stopped, and
	# the three functions written to say what a WEEK came to — sound_count,
	# ruled_count, favor_totals — had zero callers anywhere in the repository.
	var final_ledger := ""
	for line: Dictionary in session._compose_ledger():
		final_ledger += String(line.get("text", "")) + "\n"
	_is_true(final_ledger.contains("THE WEEK"),
		"a finished week closes on a page about the week")
	var week_total := session.register.ruled_count()
	_is_true(week_total > Lore.data.day_by_id(&"day_02").resolve_cases(
			Lore.data, Register.new()).size(),
		"whose count spans both days rather than only the last (%d)" % week_total)
	_is_true(final_ledger.contains("Matters ruled at this desk: %d" % week_total),
		"and reports every matter this desk ruled, not this day's")

	# AND THE STUB PARAGRAPH DOES NOT PROMISE A MORNING THAT IS NOT COMING.
	# It tested day_index + 1 < days.size() while the ledger corner tested
	# _next_day_has_anybody(); Saturday exists as a file but not as a day for a
	# notary who cleared his week, so the two disagreed on exactly this run.
	_is_true(not final_ledger.contains("lit on top of tomorrow's"),
		"and does not offer a stub for a day nobody is waiting for")

	_close(main)


# --------------------------------------------------------- a day cut short

func _day_cut_short() -> void:
	print("-- the candle goes first")
	var main := _open()
	var desk := main.get_node("desk") as Desk
	var session := desk.session
	# Six seconds of working time: enough to reach the first petitioner and not
	# enough to finish them.
	_force_short_day(desk, 6.0)

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
	_force_short_day(desk, 6.0)
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
	_is_true(desk.last_candle_seconds <= 0.001,
		"with no stub at all, because Tuesday drowned (%.2f s)"
		% desk.last_candle_seconds)
	# AND THE DAY IS STILL ITS OWN FULL LENGTH. Under the old multiplication a
	# player who lost Tuesday was handed a Thursday a third shorter as well, so
	# the punishment for falling behind was to fall further behind. Losing a day
	# now costs the stub and nothing more.
	_is_true(is_equal_approx(session.day_seconds(),
			Lore.data.day_by_id(&"day_02").day_seconds),
		"and Thursday is not also shortened for having lost Tuesday")

	# Thursday: drown it too, immediately, so the week ends owing people.
	_force_short_day(desk, 0.6)
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
	# THE CHAIN, AND IT NO LONGER COMPOUNDS DOWNWARD.
	#
	# Saturday used to be short because Thursday was short because Tuesday was —
	# so the only player who ever reached the third day, the one the candle had
	# already beaten twice, was handed a third day a third shorter as well. A
	# carry that adds cannot do that. Saturday is exactly its own authored length
	# here, because Thursday drowned and left no stub.
	_is_true(is_equal_approx(session.day_seconds(),
			Lore.data.day_by_id(&"day_03").day_seconds),
		"and Saturday is its own full length, not a debt collected from the week")
	_is_true(session.stage == SessionController.Stage.CHOOSING
			and not desk.docket_slips.is_empty(),
		"with the people who have waited longest protruding from the tray")

	_close(main)


# -------------------------------------------------------------------- harness

## THE DAY LENGTHS ARE SHARED MUTABLE STATE AND THIS SUITE REWRITES THEM.
##
## `Lore.data.days` holds one DayData per day for the whole process, and half the
## tests below shorten `current_day.day_seconds` to drown a candle on purpose.
## Those writes persisted, so by the sixth test day_02 was authored at 0.6
## seconds and any later assertion that reasoned about a day's real length was
## quietly reasoning about 0.6. Restoring the authored figures on every _open()
## costs nothing and removes a whole class of order-dependent lie.
var _authored_day_seconds := {}


func _restore_authored_days() -> void:
	for d in Lore.data.days:
		if _authored_day_seconds.has(d.id):
			d.day_seconds = _authored_day_seconds[d.id]
		else:
			_authored_day_seconds[d.id] = d.day_seconds


func _open(skip_practice := true) -> Node:
	_restore_authored_days()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	if skip_practice:
		var desk := main.get_node("desk") as Desk
		if desk.session.stage == SessionController.Stage.PRACTICE:
			desk.sweep_packet_away()
			desk.session._begin_day(0)
	return main


## Force the current day to a length the harness can actually drown.
##
## A day's length is its authored candle PLUS the stub the last day left, so
## writing day_seconds alone no longer shortens anything — it left a 0.6 second
## Thursday running for 136 seconds and two "the candle drowned" assertions
## failing with no hint as to why. Anything arranging a burnout has to put out
## the stub as well.
func _force_short_day(desk: Desk, seconds: float) -> void:
	desk.session.current_day.day_seconds = seconds
	desk.last_candle_seconds = 0.0
	if desk.candle != null:
		desk.candle.issue(desk.session.day_seconds())


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

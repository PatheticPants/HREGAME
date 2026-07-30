class_name SessionController
extends Node

## A campaign at one desk: each day is one candle, a docket, and a ledger.
##
## This is the only script that knows the shape of a session. It talks to the
## desk in terms of "lay this out", "sweep that away", and to the rules layer in
## terms of "what does the law make of this packet". It never inspects a document
## itself, and it contains nothing specific to any of the three cases — swap the
## contents of data/cases/ and this file does not change.

enum Stage {
	IDLE, PRACTICE, PRACTICE_REVIEW, CHOOSING, KNOCK, ENTERING, SPEAKING, WORKING,
	REACTING, DEPARTING, CLOSING, LEDGER, OVER
}

## THE BEATS BETWEEN CASES.
##
## These used to be five fixed constants totalling six seconds per transition, of
## which about two and a half were an entirely empty, motionless room: the knock
## landed at 0.7s and the door was not touched until 2.2s; the petitioner was
## offstage by 0.74s into a 1.8s departure. That gap repeats on every one of the
## seven matters across both days, so it was the single largest block of dead
## screen time in the game.
##
## Now the door answers the knock immediately (it rattles against its latch), the
## walk-in begins while it is still swinging, and departure ends when the room is
## actually empty rather than after an arbitrary pad. Each one also carries a
## small per-case variance, because a campaign in which every caller is admitted
## on precisely the same beat is a campaign with a metronome in it.
const KNOCK_DELAY := 0.55
const ENTER_DELAY := 0.62
const SPEAK_DELAY := 0.75
const REACT_DELAY := 1.1
const DEPART_DELAY := 1.15
const CLOSE_DELAY := 1.6

## Doorkeepers are not clockwork. +/- this fraction, drawn once per caller.
const BEAT_VARIANCE := 0.22

## Seconds of silent work before the petitioner fills the silence, and again.
const WAIT_FIRST := 52.0
const WAIT_LONG := 132.0

var desk: Desk
var register := Register.new()

var cases: Array[CaseData] = []
var days: Array[DayData] = []
var day_index := -1
var current_day: DayData = null
var remaining_cases: Array[CaseData] = []
var index := -1
var stage := Stage.IDLE

## Set when the candle ended the day rather than the player finishing it.
var burnt_out := false

## Still in the passage when the light went. Never got through the door.
var unheard: Array[String] = []

## Was standing at the desk, had said their piece, and went home without a
## ruling. A different and worse thing than never being called, and the ledger
## says so — this is the one the notary has to think about on the way home.
var unfinished := ""
## True when the unfinished instrument was left by a messenger who had already
## gone. The ledger must not claim that person stood waiting for the wick.
var unfinished_unattended := false

var _timer := 0.0
var _knocked := false
var _door_closed := true
var _current: CaseData = null
var _adjudication: Adjudication = null
## The matter just ruled, held only until the office has had its chance to
## react to it. See _deliver_arrivals.
var _last_ruled: StringName = &""
## Documents already delivered by an investigation, so leafing back through a
## book does not fetch the same slip twice. See _deliver_investigation_arrivals.
var _arrived: Dictionary = {}
var _heard_beats: Dictionary = {}
var _work_time := 0.0
## False until the player first puts a hand to evidence, a reference, or a tool.
## Dialogue state is the wrong clock boundary: arrival speech can be left open
## while the desk is used, and reactive speech can happen during WORKING.
var _work_engaged := false
var _practice_inspected := false
## Per-caller multiplier on every arrival and departure beat.
var _beat := 1.0
## The head is lifted once per caller, on their knock, and never again — a game
## that keeps grabbing the camera is a game arguing with the player about where
## to look.
var _looked_up_for_case := false


func bind(d: Desk) -> void:
	desk = d
	d.press.impression_finished.connect(_on_impression_finished)
	d.investigation_performed.connect(_on_investigation_performed)
	d.case_work_engaged.connect(_on_case_work_engaged)
	d.docket_selected.connect(_on_docket_selected)
	d.ledger.next_day_requested.connect(_on_next_day_requested)
	d.lens.dropped.connect(_on_practice_lens_dropped)


func begin() -> void:
	# The book already has entries in it when you sit down. Somebody had this
	# desk before you.
	for seed_entry in Lore.data.register_seed:
		register.add(seed_entry)
	# The desk builds its furniture before the session exists, so the Register
	# book was bound to an empty history. Rebuild it now that the previous
	# notary's entries are in.
	desk.refresh_register_book()
	_verify_content()
	days = Lore.data.days
	if days.is_empty():
		push_error("[session] no days loaded")
		_enter(Stage.OVER)
		return
	_begin_practice()


func _begin_practice() -> void:
	if Lore.data.practice_documents.is_empty():
		_begin_day(0)
		return
	desk.lay_out_packet(Lore.data.practice_documents)
	desk.press.enabled = true
	_enter(Stage.PRACTICE)


## Assert, at startup, that every authored ground truth actually follows from the
## documents. A case whose data does not support the verdict its author claimed
## is a content bug, and it should be shouted about at load rather than
## discovered by a playtester three weeks later.
func _verify_content() -> void:
	for c in Lore.data.cases:
		if c.dynamic_precedent:
			continue
		var a := Adjudicator.adjudicate_case(c, Lore.data, register)
		if a.verdict != c.correct_verdict:
			push_error("[case '%s'] authored verdict is %s but the documents "
				% [c.id, Lex.verdict_name(c.correct_verdict)]
				+ "produce %s (%s). The content and the law disagree."
				% [Lex.verdict_name(a.verdict), a.reason_code()])


func _begin_day(which: int) -> void:
	if which < 0 or which >= days.size():
		_enter(Stage.OVER)
		return
	day_index = which
	current_day = days[day_index]
	burnt_out = false
	unheard.clear()
	unfinished = ""
	unfinished_unattended = false
	_current = null
	_adjudication = null
	index = -1
	cases = current_day.resolve_cases(Lore.data, register)
	remaining_cases = cases.duplicate()

	if day_index > 0:
		desk.reset_for_next_day()
	# After reset_for_next_day, so last_candle_remaining is the value this day is
	# actually scaled by rather than the previous day's.
	SessionLog.day_id = current_day.id
	SessionLog.day_seconds = day_seconds()
	SessionLog.case_id = &""
	_log(&"day_begins", {
		"index": day_index,
		"authored_seconds": current_day.day_seconds,
		"carried": snappedf(desk.last_candle_remaining, 0.0001),
		"day_seconds": snappedf(day_seconds(), 0.01),
		"matters": cases.size(),
		"selection": String(current_day.selection_mode),
	})
	desk.lay_out_day_documents(current_day.resolve_opening_documents(register))
	# AN EMPTY TRAY IS A HANG, and it was reachable the moment a day's slots
	# could all resolve to nothing. CHOOSING has no tick and no timeout: it waits
	# for a docket_selected that no slip exists to emit, forever. The gate on the
	# ledger corner means a day of arrears is never entered empty, but a day that
	# cannot be entered empty and a day that survives being entered empty are two
	# different guarantees, and only the second one is a fact about the code.
	if current_day.selection_mode == &"tray" and not remaining_cases.is_empty():
		desk.show_docket_tray(remaining_cases)
		_enter(Stage.CHOOSING)
	else:
		desk.hide_docket_tray()
		_advance_case()


# --------------------------------------------------------------------- flow

func _process(delta: float) -> void:
	_timer += delta
	_burn_the_day(delta)
	match stage:
		Stage.KNOCK: _tick_knock()
		Stage.ENTERING: _tick_entering()
		Stage.SPEAKING: _tick_speaking()
		Stage.REACTING: _tick_reacting()
		Stage.DEPARTING: _tick_departing()
		Stage.CLOSING: _tick_closing()
		Stage.WORKING: _tick_working(delta)
		_: pass


## Somebody is standing three feet away watching you read. Long silences are the
## most conspicuous thing in the room, and a petitioner who never once fills one
## is furniture. Two authored lines, at widening intervals, and then they let you
## work — the point is presence, not nagging.
func _tick_working(delta: float) -> void:
	_work_time += delta
	if _current != null and not _current.petitioner_waits:
		# The messenger may still be crossing back to the door during the first
		# moments of work. Close it behind him, then remove the empty portrait;
		# no waiting or social-response beats belong to an unattended packet.
		if not _door_closed and desk.petitioner.is_offstage():
			_door_closed = true
			desk.close_door()
		if _door_closed and desk.door_is_settled() \
				and desk.petitioner.is_offstage() \
				and desk.petitioner.data != null:
			desk.petitioner.clear()
		return
	if desk.petitioner.is_speaking():
		return
	if _work_time > WAIT_LONG:
		_speak_beat(&"waiting_long")
	elif _work_time > WAIT_FIRST:
		_speak_beat(&"waiting")


## Say an authored line for a beat, at most once per petitioner. Shared by the
## investigation reactions and the waiting lines so neither can talk over the
## other or repeat itself.
func _speak_beat(beat: StringName) -> bool:
	if _current == null or _heard_beats.has(beat):
		return false
	var line := _current.line_for(beat, register)
	if line == null:
		# Remember the miss too, or a case with no line for this beat retries
		# the lookup every single frame.
		_heard_beats[beat] = true
		return false
	_heard_beats[beat] = true
	desk.petitioner.say(line.text,
		line.speaker if not line.speaker.is_empty() else _current.petitioner.name)
	return true


## One candle is one working day.
##
## It burns only during WORKING — while a matter is in the notary's hands and
## the player is deciding. Usually its petitioner is standing at the desk; a
## servant-delivered packet remains work after its messenger has gone. Not while
## they are speaking, not between matters, not while the ledger is open. That
## restriction is the whole reason this is fair rather than a stopwatch: it
## measures deliberation, and deliberation is the only thing the player controls.
##
## When it drowns, the day ends where it has got to.
func _burn_the_day(delta: float) -> void:
	if not _work_engaged or desk == null or desk.candle == null:
		return
	if stage not in [Stage.ENTERING, Stage.SPEAKING, Stage.WORKING]:
		return
	if desk.candle.burn_for(delta, day_seconds()):
		_end_day_by_candle()


## How long this day's candle lasts, after what was left of the last one.
##
## Candle-seconds were the only scarce thing in the game and they bought
## nothing: the candle reset to full every morning, so finishing Tuesday with two
## thirds of it left and finishing it guttering differed by one line of ledger
## prose. An hour spent re-reading the Almanac cost nothing, which is the same as
## saying the clock was decoration.
##
## The office issues a candle, not a candle a day.
func day_seconds() -> float:
	var seconds := current_day.day_seconds if current_day != null \
		else Lore.data.day_seconds
	if desk == null:
		return seconds
	return seconds * desk.last_candle_remaining


## The wick went out with people still in the passage. Whatever has been ruled is
## what the day amounts to; the rest go home and come back on Thursday.
func _end_day_by_candle() -> void:
	if stage == Stage.LEDGER or stage == Stage.OVER or stage == Stage.CLOSING:
		return
	burnt_out = true
	_log(&"day_ends", {
		"how": "burnt_out",
		"unheard": remaining_cases.size(),
		"unfinished": _current != null,
	})
	# The one at the desk was heard and simply never ruled on. The rest never
	# got through the door at all.
	if _current != null:
		unfinished = _current.petitioner.name
		unfinished_unattended = not _current.petitioner_waits
	for pending in remaining_cases:
		unheard.append(pending.petitioner.name)
	desk.press.enabled = false
	# clear() nulls the portrait data, and both _process and _draw bail on that —
	# so calling it before depart() made the figure vanish on the frame the wick
	# went instead of being seen to leave. The clear now happens in _tick_closing,
	# after CLOSE_DELAY has given the departure its fade.
	desk.petitioner.depart()
	desk.sweep_packet_away()
	desk.begin_morning()
	_enter(Stage.CLOSING)


## The office answering back, between one caller and the next.
##
## Conditions are the same ones the dawn documents already use — a named earlier
## case and, optionally, the verdict you gave it — so an arrival can depend on
## what you did five minutes ago or on what you did two days ago. Only the
## timing is new.
##
## Deliberately fired here, after the petitioner has left rather than the instant
## the wax sets: a clerk does not walk in over somebody else's hearing, and the
## beat between callers was the emptiest stretch of the day.
func _deliver_arrivals() -> void:
	if current_day == null or desk == null or _last_ruled == &"":
		return
	var arriving := current_day.resolve_arrivals(register, _last_ruled)
	_last_ruled = &""
	for doc in arriving:
		desk.deliver_day_document(doc)


func _advance_case() -> void:
	_deliver_arrivals()
	if remaining_cases.is_empty():
		# Finished on the notary's own terms. He puts his own candle out, which
		# is a different ending from having it put out for him.
		# Logged BEFORE snuff(), or the line records a spent candle and the whole
		# reward for finishing early is invisible in the data.
		_log(&"day_ends", {"how": "finished", "unheard": 0})
		if desk != null:
			if desk.candle != null:
				desk.candle.snuff()
			desk.begin_morning()
		_enter(Stage.CLOSING)
		return

	if current_day != null and current_day.selection_mode == &"tray":
		_current = null
		desk.unlock_docket_tray()
		_enter(Stage.CHOOSING)
		return

	var next: CaseData = remaining_cases.pop_front()
	index += 1
	_start_case(next)


func _start_case(next: CaseData) -> void:
	_current = next
	_knocked = false
	_door_closed = true
	_work_time = 0.0
	_work_engaged = false
	_looked_up_for_case = false
	# One draw per caller, applied to every beat of their arrival and exit, so a
	# hurried doorkeeper is hurried throughout rather than jittering at random.
	_beat = randf_range(1.0 - BEAT_VARIANCE, 1.0 + BEAT_VARIANCE)
	_heard_beats.clear()
	# THE CLOCK IS STOPPED AND THE FLAME SAYS SO.
	#
	# The candle burns only while somebody is at the desk and the player is
	# deciding — the fairness rule the whole design rests on. There was a fine cue
	# for the clock STARTING (a flame catch, a delayed tick, a permanent bead of
	# wax in the saucer) and none whatsoever for it stopping, so the player's
	# model was "it is always burning", and they hurried through reading they had
	# been given for free.
	if desk != null and desk.candle != null:
		desk.candle.mark_work_rested()
	SessionLog.case_id = _current.id
	# `ordinal` is what makes "candle remaining at the start of the LAST matter"
	# a grep rather than an interpretation.
	_log(&"matter_arrives", {
		"ordinal": index + 1,
		"of": cases.size(),
		"title": _current.title,
		"last": remaining_cases.is_empty(),
	})
	_enter(Stage.KNOCK)


func _on_docket_selected(case_id: StringName) -> void:
	if stage != Stage.CHOOSING:
		return
	for c in remaining_cases:
		if c.id != case_id:
			continue
		remaining_cases.erase(c)
		index += 1
		_log(&"docket_chosen", {
			"chose": String(case_id),
			"from": remaining_cases.size() + 1,
		})
		desk.remove_docket(case_id)
		desk.lock_docket_tray()
		_start_case(c)
		return


func _on_next_day_requested() -> void:
	if stage != Stage.LEDGER or day_index + 1 >= days.size():
		return
	_begin_day(day_index + 1)


func _enter(s: int) -> void:
	stage = s
	_timer = 0.0
	SessionLog.stage = SessionLog.stage_name(s)
	_log(&"stage")


## Every log line carries the candle, because a line without it cannot answer the
## only question the log exists for. Costs nothing when the flag is off.
func _log(what: StringName, detail: Dictionary = {}) -> void:
	SessionLog.act(what, detail, desk.candle if desk != null else null)


func _tick_knock() -> void:
	if not _knocked and _timer > KNOCK_DELAY * _beat:
		_knocked = true
		# The knock is now a thing that HAPPENS to an object: the leaf jumps
		# against its latch. It used to be a sound with no consequence anywhere
		# on screen, followed by a second and a half of nothing.
		desk.knock_at_door()
		# AND THE HEAD COMES UP.
		#
		# The door sits at global y=-43 and the work camera at y=590, so in the
		# default view the doorway is entirely off the top of the frame. The
		# knock, the swing and the walk in — the best-authored motion in the
		# build — all happened where the player was not looking, and nothing in
		# the game ever moved the view. The overwhelmingly likely first-time
		# experience was: a noise somewhere, then papers on the desk.
		#
		# A person looks up when somebody knocks. It uses the same spring the
		# player will later drive themselves, so it teaches the control by
		# performing it, and it puts the "return to desk" caption on screen at
		# the exact moment it becomes useful. It is not forced a second time —
		# _on_case_work_engaged puts the head back down and it stays down.

	# But NEVER out of somebody's hand. ViewController.look_up() calls
	# desk.cancel_hand_for_view(), because the desk is not interactive from the
	# audience plane — which is correct when the player chose to look up and
	# hostile when the game chose for them. A notary carrying the candle across
	# the desk does not fling it down because somebody knocked at a door he is
	# not even looking at. Retried every frame until they let go, so a player who
	# sets the candle down a moment after the knock still gets the lift.
	if _knocked and not _looked_up_for_case and desk.view != null \
			and not desk.hands_full():
		_looked_up_for_case = true
		desk.view.look_up()
	if _timer > (KNOCK_DELAY + ENTER_DELAY) * _beat:
		desk.open_door()
		_door_closed = false
		desk.petitioner.bind(_current.petitioner)
		desk.petitioner.arrive()
		desk.lay_out_packet(_current.documents)
		_enter(Stage.ENTERING)


func _tick_entering() -> void:
	if not _door_closed and _timer > SPEAK_DELAY * 0.5 * _beat:
		# The door shuts behind them while they are still crossing the room,
		# which is what happens, rather than after they have finished walking.
		_door_closed = true
		desk.close_door()
	# Nobody starts talking mid-stride. Speech used to begin on a flat timer that
	# could fire while the figure was still halfway across the floor, so the walk
	# and the first line fought each other for the player's attention.
	if _timer < SPEAK_DELAY * _beat or not desk.petitioner.has_arrived():
		return
	var lines := _current.lines_for(&"arrival", register)
	var texts: Array[String] = []
	for l in lines:
		texts.append(l.text)
	if texts.is_empty():
		texts.append("...")
	desk.petitioner.say_all(texts, _current.petitioner.name)
	_enter(Stage.SPEAKING)


func _tick_speaking() -> void:
	if desk.petitioner.is_speaking():
		return
	# The rings do nothing until the petitioner has finished. You cannot seal a
	# document before you have been told what it is.
	desk.press.enabled = true
	if not _current.petitioner_waits:
		# A servant delivers, identifies the packet, and goes. The instrument
		# stays on the desk; only the social witness to the work is absent.
		desk.open_door()
		_door_closed = false
		desk.petitioner.depart()
		_log(&"presenter_departs", {"before_work": true})
	_enter(Stage.WORKING)


func _tick_reacting() -> void:
	if _current != null and not _current.petitioner_waits:
		# There is nobody here to react and nobody to send away a second time.
		# The packet sweep is the only physical end beat still required.
		desk.sweep_packet_away()
		_enter(Stage.DEPARTING)
		return
	if desk.petitioner.is_speaking() or _timer < REACT_DELAY * _beat:
		return
	desk.open_door()
	_door_closed = false
	desk.petitioner.depart()
	desk.sweep_packet_away()
	_enter(Stage.DEPARTING)


func _tick_departing() -> void:
	# Shut it behind them, once they are actually through it.
	if not _door_closed and desk.petitioner.is_offstage():
		_door_closed = true
		desk.close_door()
	# END WHEN THE ROOM IS EMPTY, NOT ON A TIMER.
	#
	# The petitioner used to be offstage after about three quarters of a second
	# of an eighteen-hundred-millisecond wait, so every case ended with a second
	# of a motionless empty room before the next case's own silent knock delay.
	# Now the beat is over when the two things that were moving have stopped.
	# The DOOR ITSELF, not the request to shut it. _door_closed goes true the
	# instant close_door() is called and the leaf then takes most of a second to
	# arrive, so gating on the flag started the next caller's knock while the last
	# one's door was still swinging — the thud of it shutting landed on top of the
	# next knock, and the rattle was applied to a leaf already in motion.
	if desk.petitioner.is_offstage() and desk.door_is_settled() \
			and _timer > DEPART_DELAY * _beat:
		desk.petitioner.clear()
		_advance_case()


## The person across the desk is part of the evidence. They notice what the
## player's hands are doing, but each observation is spoken at most once so
## physical experimentation never becomes a dialogue-spam exploit.
func _on_investigation_performed(beat: StringName) -> void:
	# Practice is complete only when the player has actually read their own
	# impression through the glass. A timer made the written instruction a race:
	# a cold player could reach for the lens and watch the leaf disappear.
	if stage == Stage.PRACTICE_REVIEW and beat == &"inspect_impression":
		if not _practice_inspected:
			_practice_inspected = true
			# The door is the in-world acknowledgment: the player has read the
			# impression and may put the glass down when they are finished.
			desk.open_door()
			Audio.play(&"door_open")
		return
	if stage != Stage.WORKING:
		return
	# Doing something resets the silence. A player actively working the packet
	# should not be prompted as though they had gone to sleep.
	_work_time = 0.0
	if _current == null or _current.petitioner_waits:
		_speak_beat(beat)
	_deliver_investigation_arrivals(beat)


## THE OFFICE NOTICED WHAT YOU LOOKED UP.
##
## Fired ONCE per document for the whole session, not once per day and not once
## per lookup — `consulted` emits on every page turn, so a player leafing back
## and forth through the Kalendar would otherwise be buried in identical slips.
## The set is never cleared, because the second time you read a roll you are not
## discovering it.
func _deliver_investigation_arrivals(beat: StringName) -> void:
	if current_day == null or desk == null:
		return
	for doc in current_day.resolve_investigation_arrivals(register, beat):
		if _arrived.has(doc.id):
			continue
		_arrived[doc.id] = true
		desk.deliver_day_document(doc)


func _on_practice_lens_dropped(_lens: Draggable) -> void:
	if stage != Stage.PRACTICE_REVIEW or not _practice_inspected:
		return
	desk.close_door()
	Audio.play(&"door_close")
	desk.sweep_packet_away()
	_begin_day(0)


## Start the actual working interval on the first handled object, regardless of
## whether the petitioner has finished speaking. This closes both timing holes:
## arrival dialogue is no longer free research time, and an authored interjection
## no longer changes whether the flame burns.
func _on_case_work_engaged(who: Draggable) -> void:
	if _current == null:
		return
	if stage not in [Stage.ENTERING, Stage.SPEAKING, Stage.WORKING]:
		return
	if not _work_engaged and desk.candle != null:
		desk.candle.mark_work_engaged()
		# THE CLOCK STARTS HERE, and this is the line that proves it. Everything
		# before it on this matter was free.
		_log(&"clock_starts", {"on": SessionLog.describe(who)})
	# Hand to the packet means the reading has started, so put the head back down
	# to the work. Only ever from the lift this controller performed itself: a
	# player who chose to look up is not overruled.
	if _looked_up_for_case and desk.view != null:
		_looked_up_for_case = false
		desk.view.look_down()
	_work_engaged = true
	# "Doing anything resets the silence" applies to handling paper too, not only
	# to the few actions that happen to have an authored investigation beat.
	_work_time = 0.0


## Is there a next day, AND is there anybody in the passage for it?
##
## `day_index + 1 < days.size()` was the whole test, which is right for a week
## whose days are fixtures and wrong for one that ends in a day of arrears.
## Saturday exists only to hear what the candle stopped you hearing; a notary who
## cleared Tuesday and Thursday has nothing waiting, and the office does not call
## a man in to an empty passage.
##
## So the third day is a CONSEQUENCE. It is offered when the week left something
## undone and is simply not there otherwise — which is also why the existing
## assertion that a completed campaign invents no third-day corner still holds
## word for word.
func _next_day_has_anybody() -> bool:
	var next := day_index + 1
	if next < 0 or next >= days.size():
		return false
	return not days[next].resolve_cases(Lore.data, register).is_empty()


func _tick_closing() -> void:
	if _timer < CLOSE_DELAY:
		return
	# Harmless on the ordinary path — _tick_departing has already cleared — and
	# on the burnt-out path this is where the departure fade finally lands.
	desk.petitioner.clear()
	desk.ledger.open_with(_compose_ledger(), Desk.DESK_RECT, Vector2(40, 40))
	desk.ledger.allow_next_day = _next_day_has_anybody()
	desk.ledger.next_day_label = days[day_index + 1].entry_label \
		if desk.ledger.allow_next_day else ""
	desk.bring_to_front(desk.ledger)
	_enter(Stage.LEDGER)


# ------------------------------------------------------------------- ruling

func _on_impression_finished(verdict: int, record: ImpressionRecord) -> void:
	if stage == Stage.PRACTICE:
		desk.press.enabled = false
		_enter(Stage.PRACTICE_REVIEW)
		return
	if stage != Stage.WORKING or _current == null:
		return
	# Logged before the adjudication, so the line records the ruling as an ACT
	# with the candle at the instant of the press — not after the office has had
	# its say about it.
	_log(&"ruled", {
		"verdict": Lex.verdict_name(verdict),
		"grade": Lex.grade_name(record.grade) if record != null else "",
		"work_seconds": snappedf(_work_time, 0.01),
	})
	desk.press.enabled = false
	# Remembered so the office can react to THIS matter once the man who brought
	# it has gone. See _deliver_arrivals.
	_last_ruled = _current.id

	_adjudication = Adjudicator.adjudicate_case(_current, Lore.data, register)
	var outcome := _current.outcome_for(verdict)

	var entry := RulingRecord.new()
	entry.case_id = _current.id
	entry.day_id = current_day.id if current_day != null else &"day_01"
	entry.case_title = _current.title
	entry.petitioner_name = _current.petitioner.name
	var charter := _current.charter()
	if charter != null:
		entry.subject_id = charter.subject_id
		entry.claimant_id = charter.claimant_id
	entry.verdict = verdict
	entry.lawful_verdict = _adjudication.verdict
	entry.authority_verdicts = _adjudication.authority_split()
	entry.was_sound = _adjudication.is_defensible(verdict)
	entry.reason_code = _adjudication.reason_code()
	entry.reason_text = _adjudication.reason_text()
	entry.impression = record
	entry.finding_codes = _adjudication.codes()
	# THE CORRECTION NAMES WHAT DECIDED THE CASE.
	#
	# This preferred hints()[0] over the decisive finding, and hints are the
	# supplementary material — the things that were worth noticing but did not
	# dispose of the instrument. On case_08 the decisive finding is
	# `erasure_dispositive` and hints()[0] is `erasure_innocent`, so a player who
	# ruled the knife wrongly was corrected by the senior hand with a note about
	# the erasure that was EXPLICITLY FINE. The office's answer to "why was I
	# wrong" was a description of the thing that was not the problem, which
	# teaches the exact opposite of the lesson and reads as the game not knowing
	# its own case.
	#
	# Decisive first, then a hint, then an affirmative check — because a player
	# who refused a clean packet has no decisive finding to be shown and still
	# deserves a specific correction rather than "nothing was wrong".
	var review_source: Finding = null
	var review_hints := _adjudication.hints()
	if _adjudication.decisive != null:
		review_source = _adjudication.decisive
	elif not review_hints.is_empty():
		review_source = review_hints[0]
	else:
		# Rejecting a clean packet still deserves a specific correction. There
		# is no negative hint to quote, so use the first affirmative check the
		# player disregarded.
		for finding in _adjudication.findings:
			if finding.severity == Lex.Severity.CLEAN:
				review_source = finding
				break
	if review_source != null:
		entry.review_headline = review_source.headline
		entry.review_detail = review_source.detail
	else:
		entry.review_headline = "Nothing in the packet stood against the claim"
		entry.review_detail = _adjudication.reason_text()
	if outcome != null:
		entry.register_note = outcome.register_note
		entry.aftermath = outcome.aftermath
		entry.favor = outcome.favor
	# The senior hand reviews a mistake only after another matter has passed
	# through the office. Remember that transition so the physical Register can
	# be returned to the desk with a visible review slip; silently changing a
	# closed book would leave the player's misconception entirely intact.
	var own_before := register.own_entries()
	var review_due: bool = not own_before.is_empty() \
		and not own_before.back().was_sound
	register.add(entry)
	# The Register on the desk grows as the day does, so a petitioner citing a
	# ruling you made an hour ago is citing a page you can open and read.
	desk.refresh_register_book()
	if review_due:
		desk.reveal_register_review()

	if outcome != null and not outcome.reaction.is_empty() \
			and _current.petitioner_waits:
		desk.petitioner.say(outcome.reaction, _current.petitioner.name)
	_enter(Stage.REACTING)


# ------------------------------------------------------------------- ledger

## Compose the day's page. Four columns of judgment, kept apart: whether the
## packet sustains it, whether it follows office procedure, who it pleased, and
## how the seal came out. Never one number.
func _compose_ledger() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(Ledger.heading(Lore.data.chancery_name, 15))
	out.append(Ledger.text(
		current_day.heading if current_day != null else Lore.data.day_heading,
		11, Ink.FADED))
	out.append(Ledger.gap(8))

	var day_id := current_day.id if current_day != null else &""
	for e in register.entries_for_day(day_id):
		out.append_array(_ledger_entry(e))

	out.append_array(_ledger_unheard())
	out.append_array(_ledger_summary())
	out.append_array(_ledger_hand())
	return out


## Nobody ruled on these because the light went first. They are the loudest
## entries on the page precisely because there is nothing in them: a name, and a
## blank where the ruling should be.
func _ledger_unheard() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if unheard.is_empty() and unfinished.is_empty():
		return out

	# The active matter gets its own entry, distinct from anybody never called.
	# An unattended delivery cannot be described as a person left standing.
	if not unfinished.is_empty():
		out.append(Ledger.heading(
			"Delivered, not ruled" if unfinished_unattended \
			else "Heard, not ruled", 13))
		out.append(Ledger.text(unfinished, 10, Ink.FADED))
		out.append(Ledger.gap(4))
		out.append(Ledger.rubric("Ruled:  —", 12))
		if unfinished_unattended:
			out.append(Ledger.text(
				"Left in the notary's hands until the wick went. Returned "
				+ "through the passage.", 10, Ink.CHANCERY, 10.0))
		else:
			out.append(Ledger.text(
				"Stood at the desk until the wick went. Told to come again.", 10,
				Ink.CHANCERY, 10.0))
		out.append(Ledger.gap(12))
		out.append(Ledger.rule_line())
		out.append(Ledger.gap(8))

	for who in unheard:
		out.append(Ledger.heading("Not heard", 13))
		out.append(Ledger.text(who, 10, Ink.FADED))
		out.append(Ledger.gap(4))
		out.append(Ledger.rubric("Ruled:  —", 12))
		out.append(Ledger.gap(12))
		out.append(Ledger.rule_line())
		out.append(Ledger.gap(8))
	var burnt_text := current_day.burnt_out_text if current_day != null \
		else Lore.data.day_burnt_out
	if not burnt_text.is_empty():
		out.append(Ledger.text(burnt_text, 11, Ink.CHANCERY))
		out.append(Ledger.gap(10))
	return out


func _ledger_entry(e: RulingRecord) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(Ledger.heading(e.case_title, 13))
	out.append(Ledger.text(e.petitioner_name, 10, Ink.FADED))
	out.append(Ledger.gap(4))
	out.append(Ledger.rubric("Ruled:  %s" % Lex.verdict_name(e.verdict).to_upper(), 12))

	if e.is_authority_contested():
		out.append_array(_ledger_authority_soundness(e))
	elif e.was_sound:
		out.append(Ledger.text("The law agrees.", 11))
	else:
		out.append(Ledger.rubric("The law says %s."
			% Lex.verdict_name(e.lawful_verdict).to_upper(), 11))

	if not e.reason_text.is_empty():
		out.append(Ledger.gap(3))
		out.append(Ledger.text(e.reason_text, 10, Ink.CHANCERY, 10.0))

	# On a miss, quote back the things that were findable. Being told what you
	# failed to notice is instruction; being told "incorrect" is not.
	if not e.was_sound and not e.is_authority_contested():
		var missed := _hints_for(e)
		if not missed.is_empty():
			out.append(Ledger.gap(4))
			out.append(Ledger.text("It was there to be found:", 10, Ink.FADED))
			for h in missed:
				out.append(Ledger.text("— %s. %s" % [h.headline, h.detail], 10,
					Ink.CHANCERY, 12.0))
		elif not e.review_headline.is_empty():
			# A WRONG RULING ON A CLEAN PACKET STILL DESERVES ITS CORRECTION.
			#
			# A packet with nothing against it produces no hints, so the one case
			# built to punish a wrong reflex — a live die denied because the last
			# one was dead — used to be answered with "the law says CONFIRM" and
			# nothing else. The specific correction was already captured into the
			# record at the moment of judgment by the affirmative-finding fallback
			# in _on_impression_finished; it was simply never printed. Being told
			# what you failed to notice is instruction. Being told you were wrong
			# is not.
			out.append(Ledger.gap(4))
			out.append(Ledger.text("It was there to be found:", 10, Ink.FADED))
			out.append(Ledger.text("— %s. %s"
				% [e.review_headline, e.review_detail], 10, Ink.CHANCERY, 12.0))

	if e.impression != null:
		out.append(Ledger.gap(4))
		out.append(Ledger.text("The seal: %s." % e.impression.describe(), 10,
			Ink.FADED))
		if e.impression.obscured_text:
			out.append(Ledger.text("The wax ran over the writing.", 10, Ink.RUBRIC))

	if not e.register_note.is_empty():
		out.append(Ledger.gap(4))
		out.append(Ledger.text(e.register_note, 10, Ink.CHANCERY, 6.0))

	# Consequences used to be loaded from JSON and then silently thrown away.
	# They belong in a later, smaller hand: the office learning what the notary's
	# wax actually set in motion after the petitioner left the room.
	if not e.aftermath.is_empty():
		out.append(Ledger.gap(6))
		out.append(Ledger.text("Later, entered in the office copy:", 9, Ink.FADED))
		out.append(Ledger.note(e.aftermath, 10))

	out.append(Ledger.gap(12))
	out.append(Ledger.rule_line())
	out.append(Ledger.gap(8))
	return out


func _ledger_authority_soundness(e: RulingRecord) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if e.follows_office():
		out.append(Ledger.text(
			"Procedure: referred upward without choosing between the laws.", 11))
		out.append(Ledger.text("The dispute remains:", 10, Ink.FADED))
		for authority in _sorted_authorities(e.authority_verdicts):
			out.append(Ledger.text("— %s would rule %s."
				% [Lex.sentence(Lex.authority_name(authority)),
					Lex.verdict_name(e.authority_verdicts[authority]).to_upper()],
				10, Ink.CHANCERY, 12.0))
		return out

	var support := e.supporting_authorities()
	var oppose := e.opposing_authorities()
	out.append(Ledger.text("Legally sustained by %s."
		% _authority_list(support), 11))
	if not oppose.is_empty():
		out.append(Ledger.text("%s would rule the other way."
			% Lex.sentence(_authority_list(oppose)), 10, Ink.CHANCERY))
	out.append(Ledger.text(
		"Procedure: the office would have referred the disagreement.", 10,
		Ink.FADED))
	return out


func _sorted_authorities(split: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for authority in split:
		out.append(authority)
	out.sort()
	return out


func _authority_list(authorities: Array[int]) -> String:
	var names := PackedStringArray()
	for authority in authorities:
		names.append(Lex.authority_name(authority))
	if names.size() < 2:
		return names[0] if not names.is_empty() else "no named authority"
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]


## Re-run the checks for a case to recover the hints. Cheap, pure, and it means
## the RulingRecord does not have to carry prose it may never need.
func _hints_for(e: RulingRecord) -> Array[Finding]:
	var none: Array[Finding] = []
	var c := Lore.data.case_by_id(e.case_id)
	if c == null:
		return none
	return Adjudicator.adjudicate_case(c, Lore.data, register.before(e)).hints()


func _ledger_summary() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(Ledger.heading("THE DAY", 13))
	out.append(Ledger.gap(4))

	var day_id := current_day.id if current_day != null else &""
	var day_entries := register.entries_for_day(day_id)
	var sound := register.sound_count_for_day(day_id)
	var total := day_entries.size()
	out.append(Ledger.text("Rulings sound: %d of %d." % [sound, total], 12))

	# Favour, stated as who is pleased rather than as a number. Two powers pulling
	# opposite ways is the campaign's second meter; this is its first appearance.
	var favor := {}
	for entry in day_entries:
		for authority in entry.favor:
			favor[authority] = int(favor.get(authority, 0)) \
				+ int(entry.favor[authority])
	if favor.is_empty():
		out.append(Ledger.text("Nobody has taken any notice of you.", 11, Ink.FADED))
	else:
		out.append(Ledger.gap(4))
		for a in favor:
			var n := int(favor[a])
			if n == 0:
				continue
			var who := Lex.sentence(Lex.authority_name(int(a)))
			var verb := "is pleased with the Chancery" if n > 0 \
				else "has taken note of the Chancery"
			out.append(Ledger.text("%s %s.%s" % [who, verb,
				"" if absi(n) < 2 else "  Markedly."], 11,
				Ink.CHANCERY if n > 0 else Ink.RUBRIC))

	# How much light was left when the day stopped. Not a score — the ledger has
	# no numbers in it — but the same information a clerk would actually have
	# recorded, which is roughly how much candle he had burnt getting there.
	if desk != null and desk.candle != null and not burnt_out:
		var left := desk.candle.burn_remaining()
		out.append(Ledger.gap(4))
		if left > 0.55:
			out.append(Ledger.text(
				"The candle was still good when the last of them left.", 11,
				Ink.FADED))
		elif left > 0.18:
			out.append(Ledger.text(
				"Perhaps an hour of candle left in the dish.", 11, Ink.FADED))
		else:
			out.append(Ledger.text(
				"The candle was all but gone. Another matter and it would not "
				+ "have been heard.", 11, Ink.RUBRIC))
		# AND WHAT THAT COSTS TOMORROW, said plainly and before it happens.
		#
		# The remainder is now carried into the next day, so this line is the
		# whole warning a player gets. A scarcity the player only discovers by
		# having lost it is a trap; one they are told about at the end of the day
		# they spent it is a decision they made.
		if day_index + 1 < days.size():
			out.append(Ledger.gap(3))
			if left >= 0.98:
				out.append(Ledger.text(
					"The stub goes back in the press. It will do again.", 10,
					Ink.FADED))
			elif left > Candle.NEXT_DAY_FLOOR:
				out.append(Ledger.text(
					"What is left of it goes back in the press, and it is what "
					+ "you will be given next time. The office issues a candle, "
					+ "not a candle a day.", 10, Ink.FADED))
			else:
				out.append(Ledger.text(
					"There is not enough of it left to be worth keeping. The "
					+ "doorkeeper will find you a stub from somewhere, and it "
					+ "will be a short morning.", 10, Ink.RUBRIC))

	var grades: Array[int] = []
	for entry in day_entries:
		if entry.impression != null:
			grades.append(entry.impression.grade)
	if not grades.is_empty():
		out.append(Ledger.gap(6))
		var tally := {}
		for g in grades:
			tally[g] = int(tally.get(g, 0)) + 1
		var parts := PackedStringArray()
		for g in tally:
			parts.append("%d %s" % [int(tally[g]), Lex.grade_name(int(g))])
		out.append(Ledger.text("Seals struck: %s." % ", ".join(parts), 11, Ink.FADED))

	out.append(Ledger.gap(10))
	return out


## The hook. The previous notary's entries are in the same book, and one of them
## is not a record of a ruling at all.
func _ledger_hand() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var foreign: Array[RulingRecord] = []
	for e in register.entries:
		if e.foreign_hand:
			foreign.append(e)
	if foreign.is_empty():
		return out

	out.append(Ledger.rule_line())
	out.append(Ledger.gap(6))
	out.append(Ledger.text("Earlier in the book, in another hand:", 10, Ink.FADED))
	out.append(Ledger.gap(4))
	for e in foreign:
		out.append(Ledger.note("%s — %s. %s" % [e.case_title,
			Lex.verdict_name(e.verdict).to_lower(), e.register_note], 11))
		out.append(Ledger.gap(4))
	return out

extends Node

## PLAY THE GAME. Real input, real clock, real candle, both days end to end.
##
##     Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1600x900 \
##         --fixed-fps 60 --scene res://tests/play_day.tscn \
##         --session-log=.tools/play.jsonl --dwell=12
##
## NOT headless: the candle is a PointLight2D and the dummy driver cannot render
## 2D lights, exactly as `qa_capture.tscn` documents.
##
## WHY THIS IS NOT test_session.tscn
## ---------------------------------
## `test_session` proves the loop does not stall, and it does that by calling
## `session._on_impression_finished()` directly and setting `day_seconds` to
## 100000 so the candle is explicitly not under test. Nothing in this project has
## ever exercised the desk the way a player does, and so nothing has ever
## measured what a working day COSTS.
##
## Every act here goes through the real path: `Input.warp_mouse` moves the OS
## cursor, a synthesised `InputEventMouseButton` is pushed into the viewport, and
## `Desk._input` -> `_begin_press` -> `_pick` -> `Draggable.grab` runs exactly as
## it does under a hand. That matters more than it sounds: `_begin_press` reads
## `surface.get_local_mouse_position()`, so a pushed event alone is not enough —
## it was measured, the viewport kept reporting the real desktop cursor, and the
## first version of this harness picked up nothing at all.
##
## THE ONE THING A MACHINE CANNOT SUPPLY
## -------------------------------------
## The candle burns on DELIBERATION and nothing else (`_burn_the_day`: only while
## `_work_engaged` and only in ENTERING/SPEAKING/WORKING). So the day's cost
## splits cleanly in two:
##
##   MECHANICAL   positioning the glass, waiting out its 0.55 s focus, opening a
##                book, turning to a leaf, melting wax, pouring it, seating a
##                die. Engine-timed, identical for every player, and measurable
##                exactly. Run with `--dwell=0` to price it alone.
##   DELIBERATIVE reading and thinking. Unknowable from source, and the only part
##                that varies between players.
##
## `--dwell` is the seconds of reading given to each document and each consulted
## leaf. Sweeping it is the honest answer to "is the day tight", because it
## reports the number as a curve against the one quantity nobody can know rather
## than as a single figure that silently encodes one guess about a stranger.

const DEFAULT_DWELL := 12.0

var desk: Desk
var session: SessionController
var main: Node

var dwell := DEFAULT_DWELL
var report: Array[Dictionary] = []
## Where the session laid this matter's charter out. Everything that moves it
## puts it back here, because the desk's reachable area is smaller than the desk
## and a charter parked at the rim puts its own wax seat outside the ring's
## bounds — measured: the die stalled 78 units short and could not close.
var charter_home := Vector2.ZERO
var failures: Array[String] = []
## How each day ACTUALLY ended, read off the candle rather than summed from the
## matters that finished. Summing understates a drowned day, because the matter
## the wick died during never reaches `report` — so the first version of this
## harness reported burn 0.64 for a day that had burnt out at 1.00.
var day_end: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: float) -> float:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return float(a.substr(name.length() + 1))
	return fallback


## Override every day's authored length. Not a cheat: it is the same week played
## on a shorter wick, which is exactly what a slow player experiences, and it is
## the only way to reach the third day — Saturday holds the matters the week
## FAILED to hear, so a run that hears everything is correctly never offered it.
## Playing a day I have only ever verified synthetically is the whole point.
var day_seconds_override := 0.0


func _run() -> void:
	dwell = _arg("--dwell", DEFAULT_DWELL)
	day_seconds_override = _arg("--day-seconds", 0.0)
	print("\n=== Hand and Seal — a working week, played ===")
	print("reading dwell: %.1f s per document / per leaf" % dwell)
	if day_seconds_override > 0.0:
		print("candle overridden to %.0f s a day — a week somebody loses"
			% day_seconds_override)
	print("")

	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	desk = main.get_node("desk") as Desk
	session = desk.session
	# BEFORE the first _begin_day, not inside _play_day. Applying it later left
	# SessionLog.day_seconds holding the authored figure, so every `burn_s` in
	# the log was scaled by a day length the game was not actually using — the
	# run was right and its own record of it was wrong.
	if day_seconds_override > 0.0:
		for d in Lore.data.days:
			d.day_seconds = day_seconds_override
	await _frames(4)

	await _practice()
	# EVERY AUTHORED DAY, not two named ones. The week grew a third day and this
	# harness would have gone on playing the first two and reporting success.
	var guard := 0
	while session.current_day != null and guard < 8:
		guard += 1
		await _play_day(session.current_day.entry_label)
		if not await _turn_the_ledger():
			break

	_print_report()
	get_tree().quit(1 if not failures.is_empty() else 0)


# ------------------------------------------------------------------- the hand

## Where the OS cursor has to be for the desk to read `local` under it.
## `get_viewport_transform()` maps canvas space to WINDOW space, and warp_mouse
## takes window space; the viewport then reports the position back in its own
## (larger) stretched space. Measured, not assumed — the three spaces differ by
## the 1600x900-into-1920x1080 stretch and getting it wrong silently misses.
func _window_of(local: Vector2) -> Vector2:
	return desk.surface.get_viewport_transform() * desk.surface.to_global(local)


func _move(local: Vector2) -> void:
	var at := _window_of(local)
	Input.warp_mouse(at)
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	get_viewport().push_input(e)


## Travel there over several frames, the way a hand does. Speed matters
## mechanically, not only cosmetically: melting, pouring and pressing all gate on
## `_cursor_speed` being under a threshold, so a cursor that teleports can never
## melt wax.
func _glide(to: Vector2, seconds := 0.35) -> void:
	var from := desk.surface.get_local_mouse_position()
	var steps := maxi(2, int(seconds * 60.0))
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		_move(from.lerp(to, t * t * (3.0 - 2.0 * t)))
		await get_tree().process_frame
	# Come to rest, or the speed gate is still open from the travel.
	await _frames(6)


func _button(pressed: bool) -> void:
	var at := _window_of(desk.surface.get_local_mouse_position())
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	e.global_position = at
	get_viewport().push_input(e)


## Find a point on `who` that the desk's own hit test actually returns, rather
## than assuming its centre is clear. The desk is deliberately too small and
## things lie on top of each other — the doorkeeper's memorandum covers the wax
## spoon before the first knock — so "click the middle of it" fails on a real
## desk exactly as it failed here. A player looks for a visible corner.
func _clear_point(who: Node2D) -> Vector2:
	var centre := desk.surface.to_local(who.global_position)
	if desk._pick(centre) == who:
		return centre
	var reach := Vector2(40.0, 30.0)
	if who is Draggable:
		reach = (who as Draggable).hit_size * 0.34 * who.scale.abs()
	for ring: float in [1.0, 0.62]:
		for step in 8:
			var angle := TAU * float(step) / 8.0
			var at: Vector2 = centre + Vector2(cos(angle), sin(angle)) * reach * ring
			if desk._pick(at) == who:
				return at
	return centre


## Where the wax goes. Comfortably inside DESK_RECT (y stops at 410) so the spoon
## and all three rings can reach it, and above the ring stand rather than on it.
const SEAL_AT := Vector2(-40.0, 70.0)


## Somewhere to put a thing that is in the way. Cycled, so shifting two objects
## does not stack the second on the first, and all well inside DESK_RECT's lower
## edge — a tall charter parked low puts its own wax slot out of every ring's
## reach, which is how case 08 died once already.
const SPOIL := [Vector2(-742, -150), Vector2(-742, 120), Vector2(742, 150),
	Vector2(-300, -200), Vector2(300, -205)]
var _spoil := 0

## AND NEVER ON THE TOOLS YOU ARE ABOUT TO NEED. The first two spoil positions
## sit directly over the ring stand (x -809..-731, y -93..216), so clearing a
## sheet off one thing buried the signet rings under it, and the run died
## reaching for NEGO — a harness that tidies up by burying the tools.
## Checked against the object's OWN size, because a charter parked at a spot a
## docket fits in covers four times the area.
func _tool_bay() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for who in desk.rings:
		out.append(_rect_of(who))
	for who in [desk.wax_spoon, desk.candle, desk.lens]:
		if who != null and is_instance_valid(who):
			out.append(_rect_of(who))
	return out


func _rect_of(who: Node2D) -> Rect2:
	var c := desk.surface.to_local(who.global_position)
	var s := Vector2(60, 60)
	if who is Draggable:
		s = (who as Draggable).hit_size * who.scale.abs()
	return Rect2(c - s * 0.5, s)


## The first parking place where `who`, at its own size, covers no tool.
func _park_spot(who: Node2D) -> Vector2:
	var size := Vector2(200, 200)
	if who is Draggable:
		size = (who as Draggable).hit_size * who.scale.abs()
	var bay := _tool_bay()
	for i in SPOIL.size():
		var at: Vector2 = SPOIL[(_spoil + i) % SPOIL.size()]
		var here := Rect2(at - size * 0.5, size)
		var clear := true
		for r in bay:
			if here.intersects(r):
				clear = false
				break
		if clear:
			_spoil = (_spoil + i + 1) % SPOIL.size()
			return at
	# Nothing is clear for something this big. Take the far corner and accept it.
	_spoil += 1
	return SPOIL[_spoil % SPOIL.size()]


## Move whatever is lying on top of `who` off it. The desk is deliberately too
## small — everything overlaps something — so this is not a harness workaround,
## it is the digging the design calls a mechanic. Without it the run dies on a
## signet ring under a charter, which is a Tuesday afternoon, not a bug.
func _uncover(who: Node2D) -> bool:
	var centre := desk.surface.to_local(who.global_position)
	var blocker := desk._pick(centre)
	if blocker == null or blocker == who:
		return false
	if not await _grab_exact(blocker):
		return false
	var to := desk.surface.to_global(_park_spot(blocker))
	await _carry_until(blocker, func() -> Vector2:
		return blocker.global_position, to, 45.0, 120)
	await _release()
	return true


## Click exactly where the desk says this object is, with no uncovering. Used by
## _uncover itself, so the two cannot recurse.
func _grab_exact(who: Node2D) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	await _glide(_clear_point(who))
	_button(true)
	await _frames(2)
	if desk._held == who:
		return true
	if desk._held != null:
		_button(false)
		await _frames(2)
	return false


func _grab(who: Node2D) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	for attempt in 5:
		if await _grab_exact(who):
			return true
		if not await _uncover(who):
			break
	# Say what was actually under the hand. "Could not pick up the spoon" with no
	# further detail is the kind of failure that costs an hour; the answer is
	# almost always that something is lying on top of it.
	print("      [miss] wanted %s at %s, got %s (enabled=%s visible=%s)"
		% [SessionLog.describe(who), str(desk.surface.to_local(who.global_position)),
			SessionLog.describe(desk._held),
			str(who.draggable_enabled if who is Draggable else true),
			str(who.visible)])
	if desk._held != null:
		_button(false)
		await _frames(2)
	return false


## Pick a thing up, carry it so that `anchor_of(thing)` arrives at `to`, and stop.
## Closed-loop, because the grab offset between cursor and object is whatever the
## player happened to click and every gate in the press reads the OBJECT's
## position rather than the cursor's. This is also what a hand does: you look at
## where the bowl actually is and correct.
## SPEED IS A MECHANIC, NOT A DETAIL. Melting gates on `_cursor_speed < 42`,
## pouring on `< 34`, pressing on `< 30` (`wax_feel.tres`). At 60 fps a step of
## 0.5 desk-units per frame is 30 units/s, so the creep step below is what
## "holding your hand still" actually means to this game. An earlier version
## stepped 34% of the remaining error every frame and could never melt anything,
## because near the target that is still tens of units per second.
const CREEP := 0.42
const RUSH := 26.0


## Convert a global-space offset into the surface's local space, which is where
## the cursor lives.
func _to_local_delta(global_delta: Vector2) -> Vector2:
	return desk.surface.to_local(desk.surface.to_global(Vector2.ZERO)
		+ global_delta)


## PLACE, SETTLE, RE-MEASURE. Not per-frame chasing.
##
## A held object follows the cursor through `DragSolver`, which lags — so
## correcting every frame by the whole remaining error feeds the lag back in as
## velocity and the object sails past. Measured: the spoon ended 234 units from
## a flame it had already reached. Moving once and then waiting for the spring to
## come to rest converges in two or three corrections and, more importantly,
## leaves `_cursor_speed` at zero, which is what every gate in the press requires.
func _carry_until(who: Node2D, anchor: Callable, to: Vector2,
		tolerance := 6.0, budget := 180) -> bool:
	var tries := maxi(3, budget / 24)
	for i in tries:
		var error := _to_local_delta(to - (anchor.call() as Vector2))
		if error.length() <= tolerance:
			return true
		if who == null or not is_instance_valid(who) or desk._held != who:
			return false
		_move(desk.surface.get_local_mouse_position() + error)
		# Let the spring arrive and the reported cursor speed fall back to zero.
		await _frames(16)
	return _to_local_delta(to - (anchor.call() as Vector2)).length() <= tolerance


## HOLDING IS NOT CORRECTING. Measured: the OS cursor is integer pixels and the
## window is 1600 wide against a 1920 viewport, so a sub-pixel `warp_mouse` moves
## nothing while the synthesised motion event says it did — the two then disagree
## about where the mouse is and the object walks. A steady hand here means
## genuinely not touching the mouse, and re-acquiring only when the thing has
## actually slipped out of tolerance. That is also what a player does.
const SLIP := 26.0


func _hold(who: Node2D, anchor: Callable, to: Vector2) -> void:
	if who != null and is_instance_valid(who) and desk._held == who:
		var error := _to_local_delta(to - (anchor.call() as Vector2))
		if error.length() > SLIP:
			# It has slipped. Take it back in one deliberate correction and then
			# leave the mouse alone again — a per-frame tremor is what broke this.
			_move(desk.surface.get_local_mouse_position() + error)
			await _frames(14)
			return
	await get_tree().process_frame


## Hold something in place until a condition comes true. This is the shape almost
## every physical verb here needs: melting, pouring and seating a die are all
## "keep your hand still, there, until".
func _hold_until(who: Node2D, anchor: Callable, to: Vector2,
		done: Callable, budget := 900) -> bool:
	for i in budget:
		if done.call():
			return true
		await _hold(who, anchor, to)
	return bool(done.call())


func _release() -> void:
	_button(false)
	await _frames(2)


## Trace into the same JSONL the game writes, because the harness's own stdout is
## buffered and a run that spins tells you nothing until it exits. The log
## flushes every line, so this is the only channel that reports live.
func _trace(what: String, detail: Dictionary = {}) -> void:
	detail["step"] = what
	SessionLog.act(&"harness", detail, desk.candle if desk != null else null)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await _frames(int(seconds * 60.0))


## PUT YOUR HEAD BACK DOWN.
##
## The session lifts the view on every knock (`_tick_knock`), and while it is up
## `Desk._input` returns early — every click goes to the petitioner and the desk
## is deliberately inert. Ordinarily `_on_case_work_engaged` drops the head on the
## first thing the player touches, but that signal comes FROM the desk, so it
## cannot fire while the desk is not answering. A player uses the wheel or S; this
## uses the wheel, through `ViewController._input`.
##
## Not a workaround: it is the only way back to the desk, and the fact that
## nothing in the codebase exercised it is why it took a playthrough to notice.
func _look_down() -> void:
	if desk.view == null:
		return
	for i in 3:
		if desk.view.target <= 0.5 and desk._view_amount <= 0.06:
			return
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_DOWN
		e.pressed = true
		e.position = _window_of(desk.surface.get_local_mouse_position())
		e.global_position = e.position
		get_viewport().push_input(e)
		await _frames(45)


## Dialogue only advances on a click — anything that does not click hangs here
## forever, which `docs/CONTINUITY.md` records as a trap that has cost time.
func _hear_them_out(limit := 900) -> void:
	var guard := 0
	while desk.petitioner.is_speaking() and guard < limit:
		desk.petitioner.on_click()
		await get_tree().process_frame
		guard += 1


func _await_stage(want: int, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		if session.stage == want:
			return true
		if desk.petitioner.is_speaking():
			desk.petitioner.on_click()
		await get_tree().process_frame
	return false


# ------------------------------------------------------------------- the acts

## The four investigative verbs, performed on whatever is on the desk. Uniform
## across every matter on purpose: the point is to price the ACTS, and a routine
## that varies per case would price my knowledge of the cases instead.
func _investigate() -> void:
	var charter := desk.current_charter
	if charter == null or not is_instance_valid(charter):
		return

	_trace("inv:read")
	# READ IT. Pick it up, hold it, PUT IT BACK WHERE IT WAS.
	#
	# Where it goes back matters. An earlier version parked every charter at desk
	# centre and buried the ring stand under it, so the run died reaching for the
	# CONFIRMO ring — the desk is deliberately too small and a player who does not
	# tidy up pays for it. Returning it to the position the session laid it out at
	# is both the tidy thing and the thing that keeps the rest of the desk usable.
	var home := charter_home if charter_home != Vector2.ZERO \
		else charter.global_position
	if await _grab(charter):
		await _wait(dwell)
		if _stop_if_day_ended():
			return
		# HOLD IT TO THE FLAME. Needs the sheet in hand and light_level >= 0.45,
		# so it has to actually go to the candle rather than merely be lifted.
		await _carry_until(charter, func() -> Vector2:
			return charter.global_position,
			desk.candle.flame_world() + Vector2(40.0, -10.0), 22.0, 90)
		if _stop_if_day_ended():
			return
		await _wait(1.2)
		if _stop_if_day_ended():
			return
		await _carry_until(charter, func() -> Vector2:
			return charter.global_position, home, 24.0, 90)
		await _release()
		if _stop_if_day_ended():
			return

	_trace("inv:glass")
	# THE GLASS, on the two things it is for.
	for seal in _seals_of(charter):
		await _glass_over(seal, "seal")
		if _stop_if_day_ended():
			return
	await _glass_over(charter, "closing formula")
	if _stop_if_day_ended():
		return

	# THE BOOKS. Two of the four are loose on the desk; the Kalendar and the
	# Register are in pigeonholes and have to be fetched.
	_trace("inv:books")
	for b in desk.books:
		if b == null or not is_instance_valid(b):
			continue
		if b.data == null:
			continue
		await _consult(b)
		if _stop_if_day_ended():
			return


func _seals_of(charter: Node2D) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for child in desk.surface.get_children():
		if child is SealTag and child.charter == charter:
			out.append(child)
	for child in charter.get_children():
		if child is SealTag:
			out.append(child)
	out.sort_custom(func(a: SealTag, b: SealTag) -> bool:
		return a.tag_index < b.tag_index)
	return out


func _glass_over(subject: Node2D, what: String) -> void:
	if subject == null or not is_instance_valid(subject):
		return
	var lens := desk.lens
	if not await _grab(lens):
		return
	# Aim at the authored detail, not the node origin. A struck WaxPool records
	# the die's actual off-centre landing in `press_offset`, and a charter's
	# inspectable closing formula is likewise not at the middle of the sheet.
	# The lens correctly focuses those physical points; the old harness carried
	# its centre to `subject.global_position`, then mistook a nearby miss for a
	# completed inspection.
	var detail := subject.call("detail_centre") as Vector2 \
		if subject.has_method("detail_centre") else subject.global_position
	await _carry_until(lens, func() -> Vector2:
		return lens.global_position, detail, 14.0, 120)
	# The lens confirms focus after 0.55 s of dwell (lens.gd:128). Anything under
	# that is a glance and the office never hears about it.
	await _wait(maxf(1.1, dwell * 0.35))
	_trace("glass:settled", {
		"what": what,
		"distance": snappedf(lens.global_position.distance_to(detail), 0.1),
		"focus": SessionLog.describe(lens._focus),
	})
	await _release()


func _consult(book: ReferenceBook) -> void:
	# Out of the rack first if it is in one, or the click lands on a stowed book
	# and opens it inside a pigeonhole.
	var was_stowed := book.stowed
	var home := book.global_position
	if was_stowed:
		if not await _grab(book):
			return
		# Out onto the near left, which is the one part of the desk nothing else
		# is authored to occupy.
		await _carry_until(book, func() -> Vector2:
			return book.global_position,
			desk.surface.to_global(Vector2(-660.0, -60.0)), 40.0, 120)
		await _release()
	# Click to open.
	if not await _grab(book):
		return
	await _release()
	await _wait(dwell * 0.5)
	# Turn two leaves, which is what looking something up in a book is.
	for i in 2:
		if not book.is_open:
			break
		var half: float = book.page_size().x
		await _glide(desk.surface.to_local(
			book.to_global(Vector2(half * 0.80, 0.0))), 0.22)
		_button(true)
		await _frames(2)
		await _release()
		await _wait(dwell * 0.5)
	# Shut it and put it back. An open book has a huge hit box and there is not
	# room on this desk for four of them plus a charter — which is the whole
	# reason the rack exists.
	if book.is_open:
		if await _grab(book):
			await _release()
	if was_stowed:
		if await _grab(book):
			await _carry_until(book, func() -> Vector2:
				return book.global_position, home, 40.0, 120)
			await _release()


## Melt, pour, press, peel. The whole physical craft verb, through the real
## PressController state machine.
func _seal_it(verdict: int) -> bool:
	var charter := desk.current_charter
	if charter == null or not is_instance_valid(charter):
		return false
	var feel := Lore.wax_feel()
	var spoon := desk.wax_spoon

	# SQUARE IT UP UNDER YOUR HAND BEFORE YOU SEAL IT.
	#
	# The pour lands at the charter's OWN wax slot, and the ring must then reach
	# that same point — but the ring, the spoon and the sheet are all clamped to
	# DESK_RECT, whose y stops at 410. A tall charter (585 units) whose foot has
	# drifted low puts its wax slot outside the ring's reach, and the die stalls
	# 80 units short of wax it can see. Measured twice, on two different matters.
	#
	# So the target is not the charter's position — it is the SLOT's. Place the
	# thing you are about to work on where the work can happen.
	var slot_want := desk.surface.to_global(SEAL_AT)
	if charter.wax_slot_world().distance_to(slot_want) > 30.0:
		if not await _grab(charter):
			return _note("could not square the charter up to seal it")
		if _stop_if_day_ended():
			return false
		await _carry_until(charter, func() -> Vector2:
			return charter.wax_slot_world(), slot_want, 22.0, 180)
		await _release()
		if _stop_if_day_ended():
			return false
		# Verified, not assumed. Silently continuing from a failed placement is
		# what turned an unreachable wax slot into a mystery 200 lines later.
		var off := charter.wax_slot_world().distance_to(slot_want)
		if off > 60.0:
			return _note("the charter will not sit where it can be sealed "
				+ "(%.0f units out, slot at %s)"
				% [off, str(desk.surface.to_local(charter.wax_slot_world()).round())])

	# MELT. The bowl must sit above the flame — within heat_radius in x and
	# between 22 and 82 units ABOVE it in y (press_controller.gd:245).
	_trace("seal:grab_spoon")
	if not await _grab(spoon):
		return _note("could not pick up the spoon")
	if _stop_if_day_ended():
		return false
	# The bowl is 54 units out along the shaft, so it swings through an arc every
	# time the drag solver rotates the spoon a few degrees. Position has to be
	# HELD for the whole melt, not reached once.
	var bowl := func() -> Vector2: return spoon.bowl_world(feel)
	var over_flame := func() -> Vector2:
		return desk.candle.flame_world() + Vector2(0.0, -52.0)
	if not await _carry_until(spoon, bowl, over_flame.call(), 10.0, 200):
		if _stop_if_day_ended():
			return false
		return _note("could not bring the spoon to the flame")
	_trace("seal:melting")
	if not await _hold_until(spoon, bowl, over_flame.call(),
			func() -> bool: return spoon.is_pourable(feel), 900):
		if _stop_if_day_ended():
			return false
		var off: Vector2 = bowl.call() - desk.candle.flame_world()
		return _note("the wax never melted (bowl off flame by %s, temp %.2f, melt %.2f)"
			% [str(off), spoon.temperature, spoon.melt])

	# POUR, onto the blank foot the chancery leaves for it. The lip is a further
	# offset again, and it MOVES as the spoon tips — so this too has to be held.
	var lip := func() -> Vector2: return spoon.lip_world(feel)
	var foot := charter.wax_slot_world()
	if not await _carry_until(spoon, lip, foot, 12.0, 240):
		if _stop_if_day_ended():
			return false
		return _note("could not carry the wax to the foot of the charter")
	_trace("seal:pouring")
	# Enough for a GOOD grade and short of a blot: good_low 0.52, good_high 1.06,
	# blot_at 1.30 (wax_feel.tres).
	var want: float = (feel.good_low + feel.good_high) * 0.5
	await _hold_until(spoon, lip, foot, func() -> bool:
		return desk.press.pool != null and is_instance_valid(desk.press.pool) \
			and desk.press.pool.amount >= want, 900)
	if _stop_if_day_ended():
		return false
	if desk.press.pool == null or not is_instance_valid(desk.press.pool):
		return _note("no wax reached the parchment (tilt %.2f, pourable %s)"
			% [spoon.tilt, str(spoon.is_pourable(feel))])
	# Away, before it keeps dripping into a blot.
	await _carry_until(spoon, func() -> Vector2:
		return spoon.global_position,
		desk.surface.to_global(Vector2(-620.0, 250.0)), 40.0, 150)
	await _release()
	if _stop_if_day_ended():
		return false

	# PRESS. Take the ring the law asks for and hold it in the wax.
	_trace("seal:ring")
	var ring: SignetRing = null
	for r in desk.rings:
		if r.verdict == verdict:
			ring = r
	if ring == null:
		return _note("no ring for verdict %s" % Lex.verdict_name(verdict))
	if not await _grab(ring):
		if _stop_if_day_ended():
			return false
		return _note("could not pick up the %s ring" % ring.word())
	if _stop_if_day_ended():
		return false
	if desk.press.pool == null or not is_instance_valid(desk.press.pool):
		return _note("the wax disappeared before the die reached it")
	var at_ring := func() -> Vector2: return ring.global_position
	var on_wax := desk.press.pool.global_position
	# THE PRESS ITSELF DECIDES WHEN THE RING HAS ARRIVED, not a distance.
	#
	# `_update_ring` starts the descent as soon as the die is within
	# `press_radius` (62) of the pool and the hand is steady, and from then on the
	# press is moving the ring. Chasing a 10-unit tolerance after that fights the
	# descent, and any correction that carries the die back outside 62 triggers
	# `_begin_peel` — a half-struck seal. So: get it close, then stop and let the
	# wax take it.
	if not await _carry_until(ring, at_ring, on_wax,
			feel.press_radius * 0.42, 240):
		if _stop_if_day_ended():
			return false
		return _note(("could not bring the ring to the wax: %.0f off; "
			+ "ring at %s, wax at %s, held=%s, bounds=%s, phase=%s, cursor=%s")
			% [(at_ring.call() as Vector2).distance_to(on_wax),
				str(ring.position.round()),
				str(desk.surface.to_local(on_wax).round()),
				SessionLog.describe(desk._held), str(ring.solver.bounds),
				desk.press.phase_name(),
				str(desk.surface.get_local_mouse_position().round())])
	# Descend (0.34 s), resist (~0.30 s), give, seat. Depth keeps accruing while
	# the die is held, so this is a deliberate press rather than a tap.
	_trace("seal:pressing")
	var seated := 0
	for i in 240:
		if _work_was_interrupted():
			break
		if desk.press.phase == PressController.Phase.HOLD:
			seated += 1
			if seated > 60:
				break
		await get_tree().process_frame
	await _release()
	if _stop_if_day_ended():
		return false
	# Peel is 0.30 s and the ruling lands at the end of it.
	if not await _hold_until(null, at_ring, on_wax, func() -> bool:
			return desk.press.phase == PressController.Phase.DONE \
				or session.stage != SessionController.Stage.WORKING, 180):
		if _stop_if_day_ended():
			return false
		return _note("the press never finished (phase %s)"
			% desk.press.phase_name())
	_trace("seal:done")
	return true


func _note(why: String) -> bool:
	failures.append("%s (matter %s)" % [why,
		session._current.id if session._current != null else "?"])
	push_error("[play] " + why)
	return false


## A drowned candle legitimately interrupts whatever real-input gesture was in
## progress. It is not a harness failure, but stale references to the swept
## charter and its WaxPool are. Stop touching the abandoned objects, release any
## surviving tool, and let `_play_day` wait for the ledger.
func _work_was_interrupted() -> bool:
	return session.stage in [
		SessionController.Stage.CLOSING,
		SessionController.Stage.LEDGER,
		SessionController.Stage.OVER,
	] or (desk.candle != null and desk.candle.is_spent())


func _stop_if_day_ended() -> bool:
	if not _work_was_interrupted():
		return false
	if desk._held != null:
		desk.cancel_hand_for_view()
	_trace("matter:interrupted", {"reason": "candle"})
	return true


# -------------------------------------------------------------------- the day

func _practice() -> void:
	if session.stage != SessionController.Stage.PRACTICE:
		return
	print("-- the practice leaf, before the first knock")
	# The practice leaf is sealed with any ring; the office only wants to see
	# that the hand can do it.
	await _seal_it(Lex.Verdict.CONFIRM)
	await _await_stage(SessionController.Stage.PRACTICE_REVIEW, 8.0)
	# The die is still lying on the wax after the press. The lens now obeys the
	# desk's real occlusion order, so it quite properly sees brass rather than an
	# impression through brass. Put the tool away before trying to read the work.
	for ring in desk.rings:
		if ring.verdict != Lex.Verdict.CONFIRM:
			continue
		if await _grab(ring):
			await _carry_until(ring, func() -> Vector2:
				return ring.global_position,
				desk.surface.to_global(ring.home_position), 18.0, 120)
			await _release()
		break
	# Completion is welded to reading your own impression through the glass.
	var pool := desk.press.pool
	if pool != null and is_instance_valid(pool):
		await _glass_over(pool, "the impression")
	await _frames(30)
	if session.stage == SessionController.Stage.PRACTICE_REVIEW:
		# Putting the glass down after reading is what begins the day.
		session._on_practice_lens_dropped(desk.lens)
	await _frames(4)


func _play_day(label: String) -> void:
	var day := session.current_day
	if day == null:
		return
	print("\n-- %s: %d matters, %.0f s of candle (%.0f authored + %.0f s of stub)"
		% [label, session.cases.size(), session.day_seconds(),
			day.day_seconds, session.day_seconds() - day.day_seconds])

	var ordinal := 0
	var total := session.cases.size()
	while ordinal < total:
		if session.stage == SessionController.Stage.CHOOSING:
			# Thursday: carry a docket out of the passage tray, which is how a
			# matter is chosen. No candle is spent doing it.
			if desk.docket_slips.is_empty():
				break
			var slip := desk.docket_slips[0]
			if not await _grab(slip):
				_note("could not lift a docket from the tray")
				break
			# Into the hearing notch. `DocketTray.accepts()` tests
			# `HEARING_SLOT = Rect2(-145, -180, 290, 105)` against the slip's
			# SURFACE-LOCAL position, so the target is the middle of that rect and
			# not anything measured from the tray's own node position.
			await _carry_until(slip, func() -> Vector2:
				return slip.global_position,
				desk.surface.to_global(DocketTray.HEARING_SLOT.get_center()),
				22.0, 150)
			await _release()
			await _frames(6)
			if session.stage == SessionController.Stage.CHOOSING:
				_note("the docket would not be heard")
				break

		if not await _await_stage(SessionController.Stage.SPEAKING, 25.0):
			break
		ordinal += 1
		var here := session._current
		# THE NUMBER. Recorded before a hand is laid on anything, so it is the
		# candle the player actually sits down to this matter with.
		var left_at_start := desk.candle.burn_remaining()
		SessionLog.act(&"measure_matter_start",
			{"ordinal": ordinal, "of": total}, desk.candle)

		await _hear_them_out()
		if not await _await_stage(SessionController.Stage.WORKING, 12.0):
			_note("never handed over to the player")
			break
		# The knock lifted the head; nothing can be touched until it comes down.
		await _look_down()
		charter_home = desk.current_charter.global_position \
			if desk.current_charter != null else Vector2.ZERO

		_trace("matter:investigate", {"ordinal": ordinal})
		await _investigate()
		if _stop_if_day_ended():
			break

		var lawful := Adjudicator.adjudicate_case(here, Lore.data, session.register)
		var ok := await _seal_it(lawful.verdict)
		if not ok:
			break

		var spent := (left_at_start - desk.candle.burn_remaining()) \
			* session.day_seconds()
		report.append({
			"day": label,
			"ordinal": ordinal,
			"of": total,
			"case": String(here.id),
			"title": here.title,
			"left_at_start": left_at_start,
			"spent_seconds": spent,
			"day_seconds": session.day_seconds(),
		})
		print("   %d/%d  %-34s  candle at start %5.1f%%   spent %6.1f s"
			% [ordinal, total, here.title.left(34), left_at_start * 100.0, spent])

		if desk.candle.is_spent():
			print("   THE CANDLE DROWNED with %d matter(s) still in the passage"
				% (total - ordinal))
			break
		await _frames(20)
		await _hear_them_out()
		for i in 900:
			if session.stage not in [SessionController.Stage.REACTING,
					SessionController.Stage.DEPARTING]:
				break
			if desk.petitioner.is_speaking():
				desk.petitioner.on_click()
			await get_tree().process_frame

	await _await_stage(SessionController.Stage.LEDGER, 25.0)
	day_end.append({
		"day": label,
		"burn": desk.candle.burn if desk.candle != null else 0.0,
		"burnt_out": session.burnt_out,
		"heard": ordinal,
		"of": total,
	})


## Turn the folded corner. Returns false when the week is over — which now has
## two meanings, and the difference is the third day's whole design: either there
## is no further day authored, or there is one and nobody is waiting for it.
func _turn_the_ledger() -> bool:
	if session.stage != SessionController.Stage.LEDGER:
		return false
	if not desk.ledger.allow_next_day:
		var more := session.day_index + 1 < session.days.size()
		print("   [no corner] %s" % ("the week is over, and there was a day "
			+ "left in it — nobody is waiting" if more
			else "there is no further day authored"))
		return false
	var was := session.current_day.id
	var label := desk.ledger.next_day_label
	desk.ledger.skip_to_end()
	desk.ledger.spread = maxi(0, desk.ledger.spread_count() - 1)
	await _frames(4)
	# The folded corner, through the real click path.
	if await _grab(desk.ledger):
		await _release()
		await _frames(6)
	if session.current_day != null and session.current_day.id == was:
		# The corner is a small target; fall back to the same entry point
		# test_session uses rather than failing the whole run on a hit test.
		desk.ledger.on_click(Vector2(Ledger.SIZE.x * 0.5 - 20,
			Ledger.SIZE.y * 0.5 - 20))
		await _frames(8)
	if session.current_day == null or session.current_day.id == was:
		_note("the %s corner would not turn" % label)
		return false
	print("   [corner turned] -> %s" % label)
	return true


# ----------------------------------------------------------------- the answer

func _print_report() -> void:
	print("\n\n================ WHAT THE DAY COST ================")
	print("reading dwell: %.1f s\n" % dwell)
	# Derived from what was played, not from two names written in here. The week
	# grew a third day and a hardcoded list would have reported success without
	# ever mentioning that Saturday was never reached.
	var labels := PackedStringArray()
	for row in report:
		if not labels.has(String(row["day"])):
			labels.append(String(row["day"]))
	for day in Lore.data.days:
		if not labels.has(day.entry_label):
			labels.append(day.entry_label)
	for label in labels:
		var rows: Array[Dictionary] = []
		for row in report:
			if row["day"] == label:
				rows.append(row)
		if rows.is_empty():
			print("%s: not reached" % label)
			continue
		print("%s  (%.0f s of candle)" % [label, rows[0]["day_seconds"]])
		var spent_total := 0.0
		for row in rows:
			spent_total += row["spent_seconds"]
			print("   %d/%d  %-32s  start %5.1f%%   spent %6.1f s"
				% [row["ordinal"], row["of"], String(row["title"]).left(32),
					row["left_at_start"] * 100.0, row["spent_seconds"]])
		var last: Dictionary = rows[-1]
		# The candle's OWN reading, not the sum of the matters that finished. A
		# drowned day spends its last stretch on a matter that never reaches
		# `report`, so summing said burn 0.64 for a day that had burnt out at 1.00.
		var burn: float = spent_total / maxf(1.0, float(last["day_seconds"]))
		var ended := ""
		for row in day_end:
			if row["day"] == label:
				burn = float(row["burn"])
				ended = " — BURNT OUT" if row["burnt_out"] else ""
		print("   ---- total deliberation %.1f s of %.0f s   (burn %.2f)%s"
			% [spent_total, last["day_seconds"], burn, ended])
		# DID THE DAY EVER LOOK LIKE IT WAS ENDING?
		#
		# Everything the candle does to say the light is going — the smoke plume,
		# the 3.2x flicker unrest, the candle_gutter warning — lives above
		# `Candle.GUTTERING_FROM`. It was 0.86 against a Tuesday that ended at
		# burn 0.28, so the threshold was crossed only on days the player LOST
		# and the whole apparatus was a death rattle rather than a warning.
		# `_output()` is lerp(1.0, 0.30, ease(burn, 2.2)): at burn 0.28 the flame
		# is still at 95% and the desk is as readable as it was at dawn.
		#
		# This line is the guard on that. If a day a competent player COMPLETES
		# stops reaching the threshold again, the clock has gone back to being
		# decoration and this is where it shows.
		var out := lerpf(1.0, 0.30, ease(clampf(burn, 0.0, 1.0), 2.2))
		print("   ---- flame at day's end %.0f%% of full; guttering (%.2f) %s"
			% [out * 100.0, Candle.GUTTERING_FROM,
				"REACHED" if burn >= Candle.GUTTERING_FROM else "never reached"])
		if int(last["ordinal"]) == int(last["of"]):
			print("   >>> CANDLE AT THE START OF THE LAST MATTER: %.1f%%"
				% (float(last["left_at_start"]) * 100.0))
		else:
			print("   >>> NEVER REACHED THE LAST MATTER — got %d of %d"
				% [int(last["ordinal"]), int(last["of"])])
	if not failures.is_empty():
		print("\nfailures:")
		for f in failures:
			print("   " + f)
	print("===================================================\n")

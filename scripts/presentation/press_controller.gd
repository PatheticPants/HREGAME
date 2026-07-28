class_name PressController
extends Node

## The signet press. Melt, carry, pour, ring, lift — the money moment.
##
## THE VERB
## --------
## Every phase runs on the same single instruction: HOLD STILL. Hold the charged
## brass spoon above the fixed candle and the vermilion cake softens. Carry it to
## the sheet, hold still, and the spoon leans and pours. Hold the ring steady on
## the pool and it descends, meets resistance, gives, and seats. Nothing here is
## a button or a timed prompt.
##
## That choice is deliberate and it is why the drag solver matters. Stopping a
## heavy, momentum-carrying object exactly where you want it and keeping it there
## is a physical skill the player has to acquire in the first thirty seconds of
## handling paper — and the press then cashes that skill in. If dragging were
## position = cursor, holding still would be free and the press would be a
## progress bar.
##
## PHASES
## ------
##   HEATING   the pigmented cake sweats, slumps and bubbles over the flame
##   READY     molten wax is carried to the charter before it skins over
##   POURING   spoon leans, drops land, pool spreads by area
##   COOLING   wax sits; too long and it takes the die badly
##   DESCEND   ring sinks into the pool
##   RESIST    it stops sinking. brief. the wax is fighting back
##   HOLD      it gave; now it seats, and depth accrues while you wait
##   PEEL      the ring comes away and the wax strings after it
##
## Each phase emits its own signal, because each wants its own sound and its own
## visual response, and because "make the press feel good" is not one problem but
## six small ones.
##
## FAILURE IS AVAILABLE
## --------------------
## Pour too little and the impression is thin. Pour too long and it blots over
## the writing. Lift immediately and it is shallow. Drift while it seats and it
## smears. None of these affect whether the ruling was *lawful* — they go in the
## ledger as craft, which is a separate column, because a notary can be right and
## clumsy and the office notices both.

enum Phase {
	IDLE,
	HEATING,
	READY,
	POURING,
	COOLING,
	DESCEND,
	RESIST,
	HOLD,
	PEEL,
	DONE,
}

const WAX_DROP_SCRIPT = preload("res://scripts/presentation/wax_drop.gd")

signal pour_began()
signal drop_landed(total_amount: float)
signal pour_ended(total_amount: float)
signal descent_began()
signal resistance_began()
signal gave_way()
signal peel_began()
signal impression_finished(verdict: int, record: ImpressionRecord)

var feel: WaxFeel
var candle: Candle = null
var spoon: WaxSpoon = null
var target_sheet: Sheet = null
var pool: WaxPool = null

var phase := Phase.IDLE

## Locked until the session says a ruling may be made, so the player cannot seal
## a document before the petitioner has finished speaking.
var enabled := false

var _held: Draggable = null
var _cursor := Vector2.ZERO
var _cursor_speed := 0.0

var _active_ring: SignetRing = null
var _descend_t := 0.0
var _resist_t := 0.0
var _seat_t := 0.0
var _peel_t := 0.0
var _drip_t := 0.0

var _press_origin := Vector2.ZERO
var _drift := 0.0
var _committed := false

## Strike point and subsequent hand drift, both in the pool's own space, so the
## smear is drawn along the direction the hand actually travelled rather than a
## random vector.
var _strike_pool := Vector2.ZERO
var _drag_pool := Vector2.ZERO

## Rolled fresh on every press, per the brief: no two impressions identical.
var _this_resist_time := 0.0
var _this_seat_time := 0.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	feel = Lore.wax_feel()
	_rng.randomize()


func reset_for_new_case(sheet: Sheet) -> void:
	target_sheet = sheet
	if _active_ring != null and is_instance_valid(_active_ring):
		_active_ring.press_depth = 0.0
		_active_ring.resistance_amount = 0.0
		_active_ring.peel_amount = 0.0
		_active_ring.seat_impact = 0.0
	if pool != null and is_instance_valid(pool):
		pool.queue_free()
	pool = null
	phase = Phase.IDLE
	enabled = false
	_active_ring = null
	_drift = 0.0
	_committed = false
	_drip_t = 0.0
	if spoon:
		spoon.reset_wax()
	Audio.set_loop(&"wax_melt", 0.0)
	Audio.set_loop(&"wax_pour", 0.0)
	Audio.set_loop(&"ring_press", 0.0)


## Called once per frame by the desk with the current hand state.
func tick(delta: float, held: Draggable, cursor: Vector2, cursor_speed: float) -> void:
	feel = Lore.wax_feel()
	_held = held
	_cursor = cursor
	_cursor_speed = cursor_speed

	if not enabled or phase == Phase.DONE:
		_relax(delta)
		return

	if phase == Phase.PEEL:
		_update_peel(delta)
		return

	if phase == Phase.IDLE or phase == Phase.HEATING or phase == Phase.READY \
			or phase == Phase.POURING or phase == Phase.COOLING:
		_update_spoon(delta)

	if pool != null:
		_update_ring(delta)


func _relax(delta: float) -> void:
	if spoon:
		spoon.tilt = maxf(0.0, spoon.tilt - delta / feel.untilt_time)
		spoon.lose_heat(delta, feel)
	Audio.set_loop(&"wax_melt", 0.0)
	Audio.set_loop(&"wax_pour", 0.0)
	Audio.set_loop(&"ring_press", 0.0)


# ---------------------------------------------------------------------- spoon

func _update_spoon(delta: float) -> void:
	if spoon == null:
		return

	var holding_spoon := _held == spoon
	var steady_for_heat := _cursor_speed < feel.heat_steady_speed
	var over_flame := false
	if candle != null:
		var from_flame := spoon.bowl_world(feel) - candle.flame_world()
		# The bowl must actually be above the flame. A radial check alone allowed
		# the red reservoir to sit directly on top of and visually erase it.
		over_flame = absf(from_flame.x) < feel.heat_radius \
			and from_flame.y < -22.0 and from_flame.y > -82.0
	var heating_now := holding_spoon and steady_for_heat and over_flame \
		and pool == null

	if heating_now:
		if not spoon.is_molten(feel):
			phase = Phase.HEATING
		var just_molten := spoon.add_heat(delta, feel)
		if just_molten:
			phase = Phase.READY
			Audio.play(&"wax_ready", spoon.bowl_world(feel))
		elif spoon.is_molten(feel):
			phase = Phase.READY
	else:
		spoon.lose_heat(delta, feel)
		if phase == Phase.HEATING:
			phase = Phase.READY if spoon.is_molten(feel) else Phase.IDLE

	var heat_sound := 0.0
	if heating_now:
		heat_sound = clampf((spoon.temperature - feel.soften_temperature) /
			maxf(0.01, 1.0 - feel.soften_temperature), 0.0, 1.0)
	Audio.set_loop(&"wax_melt", heat_sound)

	var pouring := false
	# You cannot tip the spoon while it is still over the flame. Physically it is
	# the obvious thing — you lift it away before you pour — and it removes a
	# genuine trap: now that the candle is carried, a player who sets it down on
	# the charter would otherwise be unable to melt anything without spilling on
	# the document they were about to seal.
	if holding_spoon and not over_flame and target_sheet != null \
			and spoon.is_pourable(feel):
		# Wax goes where you tip it, anywhere on the instrument. The chancery
		# leaves a blank foot for the seal and the memorandum says to use it, but
		# nothing stops you pouring across the witness list — and if you do, the
		# ledger records that the writing was fouled. Freedom with a consequence
		# beats a magnet that snaps the wax to the correct place.
		var steady_for_pour := _cursor_speed < feel.pour_steady_speed
		pouring = _sheet_accepts(spoon.lip_world(feel)) and steady_for_pour

	# The spoon rolls around the player's grip. It rights quickly if the hand
	# moves, so a visible wobble costs drops without ever cancelling the melt.
	if pouring:
		spoon.tilt = minf(1.0, spoon.tilt + delta / feel.tilt_time)
	else:
		spoon.tilt = maxf(0.0, spoon.tilt - delta / feel.untilt_time)

	var tilt := spoon.tilt
	Audio.set_loop(&"wax_pour", clampf((tilt - 0.30) / 0.70, 0.0, 1.0))

	if tilt > 0.55 and spoon.is_pourable(feel):
		if phase != Phase.POURING:
			phase = Phase.POURING
			pour_began.emit()
		_drip_t += delta
		var interval := feel.drip_interval / maxf(0.6, tilt)
		while _drip_t >= interval:
			_drip_t -= interval
			# One cake contains enough material to over-pour if the player keeps
			# going; blotting remains a real craft failure, not dead documentation.
			if not spoon.take_wax(feel.drop_volume /
					maxf(feel.blot_at * 1.20, 0.01)):
				break
			_land_drop()
	elif phase == Phase.POURING:
		phase = Phase.COOLING if pool != null else Phase.READY
		pour_ended.emit(pool.amount if pool else 0.0)


## Is the spoon's lip over parchment that will take wax? A small inset keeps a
## pool from forming half off the edge of the sheet.
func _sheet_accepts(world_point: Vector2) -> bool:
	if target_sheet == null:
		return false
	return target_sheet.rect().grow(-34.0).has_point(
		target_sheet.to_local(world_point))


func _land_drop() -> void:
	if pool == null:
		_make_pool()
	var drop = WAX_DROP_SCRIPT.new()
	target_sheet.add_child(drop)
	var from := target_sheet.to_local(spoon.lip_world(feel))
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(1.5, 8.0)
	# Drops land under the lip, but the pool has surface tension: material that
	# falls near an existing bead is pulled into it. So a steady hand builds one
	# clean pool and a wandering one drags it out of shape.
	var toward := from.lerp(pool.position, 0.62)
	var to := toward + Vector2.from_angle(angle) * distance
	drop.setup(from, to, pool.color, _rng.randf_range(0.12, 0.18))
	drop.landed.connect(_on_drop_landed)


func _on_drop_landed() -> void:
	if pool == null or not is_instance_valid(pool) or pool.is_queued_for_deletion():
		return
	var first := pool.amount <= 0.0
	pool.add_drop()
	if first:
		Audio.play(&"wax_sizzle", pool.global_position)
	# Pitch rises very slightly as the pool deepens: a drop into more wax is a
	# duller, higher sound. Almost subliminal, and it is the cue that tells you
	# you are getting close to over-pouring before you can see it.
	Audio.play(&"wax_drip", pool.global_position,
		-2.0 * clampf(pool.amount, 0.0, 2.0))
	drop_landed.emit(pool.amount)


func _make_pool() -> void:
	pool = WaxPool.new()
	# Parented to the sheet, so the wax travels with the document afterwards.
	target_sheet.add_child(pool)
	# The bead forms under the lip, wherever that happens to be. Where the wax
	# ends up is the player's decision and it is recorded on the document for as
	# long as the document exists.
	var at := target_sheet.to_local(spoon.lip_world(feel))
	var room := target_sheet.rect().grow(-46.0)
	pool.position = Vector2(
		clampf(at.x, room.position.x, room.end.x),
		clampf(at.y, room.position.y, room.end.y))
	var tint := Color(0.60, 0.13, 0.16)
	pool.setup(feel, tint, _rng.randi())
	# Anything closer to the middle of the sheet than this is writing.
	pool.text_guard_radius = target_sheet.data.size.x * 0.20


# ----------------------------------------------------------------------- ring

func _update_ring(delta: float) -> void:
	var ring := _held as SignetRing

	# Letting go of the ring is the lift gesture. There is no separate button.
	if ring == null:
		if _in_press():
			_begin_peel()
		return

	var over := ring.global_position.distance_to(pool.global_position) < feel.press_radius
	if not over:
		if _in_press():
			_begin_peel()
		else:
			ring.press_depth = move_toward(ring.press_depth, 0.0, delta * 5.0)
		return

	var steady := _cursor_speed < feel.press_steady_speed

	match phase:
		Phase.IDLE, Phase.COOLING:
			if steady:
				_begin_descent(ring)
		Phase.DESCEND:
			_track_drift()
			_descend_t += delta
			ring.resistance_amount = 0.0
			# Ease-OUT, not linear. Wax resists harder the deeper the die goes,
			# so the descent has to be visibly slowing as it reaches the stall —
			# a constant-speed sink gave the resistance phase nothing to arrive
			# from, and the give had no run-up.
			ring.press_depth = ease(
				clampf(_descend_t / feel.descend_time, 0.0, 1.0), 0.55) * 0.70
			if _descend_t >= feel.descend_time:
				phase = Phase.RESIST
				_resist_t = 0.0
				Audio.set_loop(&"ring_press", 1.0)
				resistance_began.emit()
		Phase.RESIST:
			_track_drift()
			_resist_t += delta
			ring.resistance_amount = clampf(_resist_t / 0.08, 0.0, 1.0)
			# The give is the whole point of the press. Descent all but stops —
			# but NOT completely, because a dead stop reads as dropped input. It
			# creeps, and it shudders, and then it goes.
			var t := _resist_t / maxf(0.01, _this_resist_time)
			var creep := feel.resistance_creep * t
			var shudder := sin(_resist_t * 46.0) * 0.004 * feel.resistance_shudder
			ring.press_depth = 0.70 + creep + shudder
			if _resist_t >= _this_resist_time:
				_give_way(ring)
		Phase.HOLD:
			_track_drift()
			_seat_t += delta
			ring.press_depth = 1.0
			# The die is seated now, so further hand movement drags the material
			# rather than relocating the strike.
			_drag_pool = pool.to_local(ring.global_position) - _strike_pool
			# Depth keeps accruing while you hold. Lift at once and the device
			# is faint; wait and it is crisp.
			# Ease-out, so a quick tap already reads as a decent impression and
			# patience refines it. Linear made holding feel like filling a bar.
			pool.seat_depth = clampf(0.35 + ease(
				clampf(_seat_t / maxf(0.01, _this_seat_time), 0.0, 1.0), 0.55) * 0.65,
				0.0, 1.0)


func _in_press() -> bool:
	return phase == Phase.DESCEND or phase == Phase.RESIST or phase == Phase.HOLD


func _begin_descent(ring: SignetRing) -> void:
	phase = Phase.DESCEND
	_active_ring = ring
	ring.resistance_amount = 0.0
	ring.peel_amount = 0.0
	_descend_t = 0.0
	_seat_t = 0.0
	_press_origin = _cursor
	_drift = 0.0
	_committed = false

	# Everything randomised for this one press.
	ring.press_rotation = deg_to_rad(_rng.randf_range(
		-feel.ring_jitter_deg, feel.ring_jitter_deg))
	_this_resist_time = feel.resistance_time * (1.0 + _rng.randf_range(
		-feel.resistance_jitter, feel.resistance_jitter))
	_this_seat_time = feel.seat_time * (1.0 + _rng.randf_range(
		-feel.seat_time_jitter, feel.seat_time_jitter))

	descent_began.emit()


func _give_way(ring: SignetRing) -> void:
	phase = Phase.HOLD
	ring.resistance_amount = 0.0
	ring.seat_impact = 1.0
	_seat_t = 0.0
	_committed = true
	Audio.set_loop(&"ring_press", 0.0)
	Audio.play(&"ring_seat", pool.global_position)

	# THE STRIKE. Where the ring is at the instant the wax gives is where the die
	# lands, and it is recorded once and never recomputed — a seal is a permanent
	# consequence of one moment, not a decal that follows the ring around. Press
	# the middle and you get a whole device; press the rim and the wax gives you
	# exactly as much of it as there was material under the metal.
	_strike_pool = pool.to_local(ring.global_position)
	_drag_pool = Vector2.ZERO
	pool.strike(_strike_pool, ring.device, ring.press_rotation,
		SignetRing.DIE_RADIUS)
	# Wax that has sat too long takes the die badly no matter how well you press.
	if pool.is_cool():
		pool.seat_depth *= 0.7

	gave_way.emit()


func _track_drift() -> void:
	_drift = maxf(_drift, _cursor.distance_to(_press_origin))


# ----------------------------------------------------------------------- peel

func _begin_peel() -> void:
	phase = Phase.PEEL
	_peel_t = 0.0
	if _active_ring != null and is_instance_valid(_active_ring):
		_active_ring.resistance_amount = 0.0
		_active_ring.peel_amount = 0.0
	Audio.set_loop(&"ring_press", 0.0)
	Audio.play(&"ring_lift", pool.global_position if pool else Vector2.ZERO)
	peel_began.emit()


func _update_peel(delta: float) -> void:
	_peel_t += delta
	var t := clampf(_peel_t / feel.peel_time, 0.0, 1.0)

	if _active_ring != null and is_instance_valid(_active_ring):
		# Ease out: the ring resists at first, then comes away all at once.
		_active_ring.press_depth = (1.0 - ease(t, 0.35)) * 1.0
		_active_ring.peel_amount = t

	if pool != null:
		pool.peel = t

	if t < 1.0:
		return

	if _committed and pool != null:
		pool.smeared = _drift > feel.smear_distance
		if pool.smeared:
			# Along the line the hand actually travelled while the die was seated.
			# A random direction was cheaper and read as a rendering glitch rather
			# than as evidence of what the player's hand did.
			pool.smear_offset = _drag_pool.limit_length(11.0)
			if pool.smear_offset.length() < 1.0:
				pool.smear_offset = Vector2(minf(_drift * 0.22, 9.0), 0.0)
		pool.peel = 0.0
		var record := pool.grade(_drift)
		phase = Phase.DONE
		if _active_ring != null:
			_active_ring.press_depth = 0.0
			_active_ring.peel_amount = 0.0
			impression_finished.emit(_active_ring.verdict, record)
	else:
		# Aborted mid-descent. The wax is still there; try again.
		phase = Phase.COOLING
		if pool != null:
			pool.peel = 0.0

	if _active_ring != null and is_instance_valid(_active_ring):
		_active_ring.press_depth = 0.0
		_active_ring.resistance_amount = 0.0
		_active_ring.peel_amount = 0.0
	_active_ring = null


func phase_name() -> String:
	return Phase.keys()[phase]

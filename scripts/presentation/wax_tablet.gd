class_name WaxTablet
extends Draggable

## A boxwood tablet filled with blackened wax. The notary's own memory.
##
## THE PROBLEM IT SOLVES
## --------------------
## Three cases, two reference books, a date that needs reducing and a die that
## needs dating — and nowhere to put a number down. The player either holds it
## all in their head or reaches for real paper beside the keyboard, and reaching
## for real paper means the game failed to be a desk.
##
## THE RULE
## --------
## The game never reads a mark you make. Not one. There is no parser, no
## validation, no "correct note". You scratch whatever notation you invent —
## 1213, a tick, a cross, the shape of a lion — and the only thing that ever
## interprets it is you, later, when you have forgotten why you wrote it.
##
## That is the entire reason it works as a mechanic. A notebook the game grades
## is a quiz. A notebook the game ignores is a tool.
##
## THE VERBS
## ---------
## Both are the ones the desk has already taught:
##
##   move the stylus over the wax  ->  it scratches
##   rest  the stylus on the wax   ->  it warms and smooths back flat
##
## Resting is telegraphed by a pale bloom under the nib for well over half a
## second before anything is lost, so nobody smooths a page by pausing to think.

const SIZE := Vector2(320.0, 224.0)
const FRAME := 20.0

## Seconds of stillness before the nib starts sinking in and taking wax with it.
const SMOOTH_DELAY := 0.62
const SMOOTH_RADIUS := 26.0
const STILL_SPEED := 26.0

## Minimum travel before a stroke records another point. Below this the arrays
## fill with hundreds of near-identical points for no visible gain.
const STROKE_STEP := 3.2

var strokes: Array[PackedVector2Array] = []

var _current: PackedVector2Array = PackedVector2Array()
var _still := 0.0
var _smoothing := 0.0
var _nib := Vector2.ZERO
var _nib_on := false
var _scratch_run := 0.0


func _ready() -> void:
	super._ready()
	hit_size = SIZE
	pickup_sound = &"book_close"
	drop_sound = &"ledger_thud"
	slide_sound = &"paper_slide"
	occludes_light = true
	occluder_inset = 0.92
	# A block of boxwood full of wax. It takes a moment to get moving.
	weight = 0.62
	stow_scale = 0.50
	z_index = 0


func light_occluder_polygon() -> PackedVector2Array:
	return bevelled_light_occluder(12.0)


func inner_rect() -> Rect2:
	return Rect2(-SIZE * 0.5 + Vector2(FRAME, FRAME),
		SIZE - Vector2(FRAME, FRAME) * 2.0)


func mark_count() -> int:
	var n := strokes.size()
	if _current.size() > 1:
		n += 1
	return n


## How much is actually written. Note this is the meaningful measure and stroke
## COUNT is not: smoothing through the middle of a line splits it in two, so the
## number of strokes goes up while the amount of writing goes down.
func mark_points() -> int:
	var n := _current.size()
	for stroke in strokes:
		n += stroke.size()
	return n


func clear_marks() -> void:
	strokes.clear()
	_current = PackedVector2Array()
	queue_redraw()


## Driven once per frame by the desk with whatever is in the player's hand.
func tick(delta: float, held: Draggable, cursor_speed: float) -> void:
	var stylus := held as Stylus
	if stylus == null:
		_end_stroke()
		_nib_on = false
		_still = 0.0
		_smoothing = 0.0
		Audio.set_loop(&"stylus_scratch", 0.0)
		return

	_nib = to_local(stylus.tip_world())
	var was_on := _nib_on
	_nib_on = inner_rect().has_point(_nib)
	# The START of the action. Crossing onto the wax used to be silent until the
	# player happened to move far enough to cut a mark, so the first thing the
	# tablet ever did was already the middle of the gesture. A tick on contact
	# is what says "this surface is live" before anything is written.
	if _nib_on and not was_on:
		Audio.play(&"stamp_set", global_position, -16.0)
	if not _nib_on:
		_end_stroke()
		_still = 0.0
		_smoothing = 0.0
		Audio.set_loop(&"stylus_scratch", 0.0)
		return

	if cursor_speed > STILL_SPEED:
		_still = 0.0
		_smoothing = maxf(0.0, _smoothing - delta * 3.0)
		_scratch(delta, cursor_speed)
	else:
		_end_stroke()
		Audio.set_loop(&"stylus_scratch", 0.0)
		_still += delta
		if _still > SMOOTH_DELAY:
			_smoothing = minf(1.0, _smoothing + delta * 2.2)
			_smooth_at(_nib, delta)
	queue_redraw()


func _scratch(delta: float, cursor_speed: float) -> void:
	if _current.is_empty() or _current[_current.size() - 1].distance_to(_nib) > STROKE_STEP:
		_current.append(_nib)
	# A dry scratch that only sounds while the nib is actually cutting wax.
	_scratch_run += delta
	Audio.set_loop(&"stylus_scratch",
		clampf(cursor_speed / 340.0, 0.0, 1.0) * 0.9)


func _end_stroke() -> void:
	if _current.size() > 1:
		strokes.append(_current)
	_current = PackedVector2Array()
	_scratch_run = 0.0


## Warm bronze resting on wax takes the marks out from under it. Points inside
## the nib's reach are dropped and the stroke is split where they were, so
## smoothing through the middle of a line leaves the two ends behind rather than
## deleting the whole thing.
func _smooth_at(at: Vector2, delta: float) -> void:
	var reach := SMOOTH_RADIUS * _smoothing
	if reach < 3.0:
		return
	var kept: Array[PackedVector2Array] = []
	var removed := false
	for stroke in strokes:
		var run := PackedVector2Array()
		for p in stroke:
			if p.distance_to(at) <= reach:
				removed = true
				if run.size() > 1:
					kept.append(run)
				run = PackedVector2Array()
			else:
				run.append(p)
		if run.size() > 1:
			kept.append(run)
	strokes = kept
	if removed:
		Audio.play_throttled(&"wax_smooth", 0.18)


# -------------------------------------------------------------------- drawing

func _draw() -> void:
	var r := Rect2(-SIZE * 0.5, SIZE)
	draw_soft_shadow(r)

	var warm := clampf(light_level, 0.0, 1.0)
	var wood := Color(0.34, 0.24, 0.13).lerp(Color(0.55, 0.40, 0.20), warm * 0.55)
	draw_rect(r, wood.darkened(0.35))
	draw_rect(r.grow(-4.0), wood)
	# Grain along the frame.
	for i in 7:
		var y := r.position.y + 6.0 + float(i) * (SIZE.y / 8.0)
		draw_line(Vector2(r.position.x + 5, y), Vector2(r.end.x - 5, y),
			Color(0.22, 0.15, 0.08, 0.30), 1.0)

	var inner := inner_rect()
	# Blackened wax. Almost no light comes back off it, which is what makes the
	# scratches legible: they are the pale ground showing through.
	draw_rect(inner.grow(3.0), wood.darkened(0.55))
	draw_rect(inner, Color(0.115, 0.085, 0.062).lerp(
		Color(0.20, 0.15, 0.10), warm * 0.35))

	_draw_marks(warm)
	# YOUR OWN NOTES NEED LIGHT TOO.
	#
	# A scratch in blackened wax is legible only because the pale boxwood shows
	# through it, and that contrast is entirely a matter of what is falling on it.
	# The tablet is the one object whose whole purpose is to be re-read twenty
	# minutes later, so making it the one thing you can read in the dark would
	# quietly say the candle is decoration.
	#
	# Above the nib telegraph, deliberately: a smoothing you cannot see coming is
	# the one thing this object may never do.
	draw_shade(r)
	if _nib_on:
		_draw_nib_state()


func _draw_marks(warm: float) -> void:
	# Scratched wax reveals the pale boxwood under it, so a mark is a light line
	# with a darker lip on the side the stylus threw the wax.
	var groove := Color(0.78, 0.70, 0.53).lerp(Color(0.94, 0.82, 0.58), warm * 0.5)
	var lip := Color(0.06, 0.045, 0.03, 0.75)
	for stroke in strokes:
		_draw_stroke(stroke, groove, lip)
	if _current.size() > 1:
		_draw_stroke(_current, groove, lip)


func _draw_stroke(stroke: PackedVector2Array, groove: Color, lip: Color) -> void:
	if stroke.size() < 2:
		return
	var raised := PackedVector2Array()
	raised.resize(stroke.size())
	for i in stroke.size():
		raised[i] = stroke[i] + Vector2(1.2, 1.6)
	draw_polyline(raised, lip, 3.4, true)
	draw_polyline(stroke, groove, 2.6, true)


## The telegraph. Long before any wax is lost, the nib visibly settles and a pale
## ring warms under it — so smoothing is always something the player watched
## begin, never something that happened while they were thinking.
func _draw_nib_state() -> void:
	if _smoothing > 0.005:
		var shown := ease(clampf(_smoothing, 0.0, 1.0), 0.5)
		var reach := SMOOTH_RADIUS * shown
		draw_circle(_nib, reach, Color(0.62, 0.52, 0.36, 0.22 * shown))
		draw_arc(_nib, reach, 0.0, TAU, 24,
			Color(0.86, 0.74, 0.50, 0.45 * shown), 1.6)
	elif _still > 0.12:
		# Warming up. Eased in hard so it is barely there early and swells over
		# the last fraction of a second — a commitment cue rather than a
		# progress bar counting down to erasure.
		var t := ease(clampf(_still / SMOOTH_DELAY, 0.0, 1.0), 2.2)
		draw_circle(_nib, 3.0 + t * 6.0, Color(0.55, 0.46, 0.32, 0.16 + t * 0.18))

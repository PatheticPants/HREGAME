class_name Sheet
extends Draggable

## A physical piece of parchment. Base for every document on the desk.
##
## Handles the substrate — shadow, body, deckled edge, how the candle warms it —
## and leaves the writing to _draw_face(). A charter and a docket slip are then
## two twenty-line overrides rather than two objects.

var data: DocumentData = null

## Slight per-sheet variation so a stack of parchment does not look printed.
var _grain_seed := 0
var _deckle: PackedFloat32Array = PackedFloat32Array()
## Hair follicles, as fractions of the sheet. Only ever visible against the
## flame, and generated once so a skin's pores do not crawl between frames.
var _follicles: PackedVector3Array = PackedVector3Array()
var _arrival_from := Vector2.ZERO
var _arrival_t := 1.0


func bind(doc: DocumentData, desk_bounds: Rect2) -> void:
	data = doc
	hit_size = doc.size
	name = "sheet_" + String(doc.id)
	_grain_seed = hash(String(doc.id))
	_build_deckle()
	setup(doc.start_offset, deg_to_rad(doc.start_angle_deg),
		_near_edge_bounds(doc, desk_bounds))
	# Packets are handed down over the far edge of the desk. The physics body is
	# already at its authored resting place; this short presentation offset
	# brings the visible sheet in from the petitioner's side without creating a
	# second drag solver or changing where it will settle.
	var side := -1.0 if (_grain_seed & 1) == 0 else 1.0
	_arrival_from = Vector2(side * 24.0, -105.0)
	_arrival_t = 0.0
	position = solver.position + _arrival_from


## A SHEET MAY HANG OVER THE FRONT OF THE DESK BY ITS OWN EDGE, NOT BY ITS
## MIDDLE — and until this existed there were places on the desk where a
## document could not be sealed at all.
##
## `DragSolver` clamps the object's CENTRE to `bounds` grown by
## `PaperFeel.edge_allowance` (120). That is right for a signet ring, which is 68
## units tall, and wrong for a charter, which is 585: the ring may hang 154 units
## past the rim and the charter 412. Since the poured pool rides on the sheet and
## the press requires the die within `press_radius` of it, the two allowances
## have to agree or the wax goes somewhere the die cannot follow.
##
## Measured before it was fixed: charter centres from y=325 to y=530 were all
## legal, and every one of them put the wax slot out of reach of every ring. Two
## hundred and five units of the desk on which a matter could be poured and then
## never struck, with no feedback of any kind — the die simply stopped short of
## wax it was sitting next to. It is also just wrong to look at; a sheet centred
## at 530 is most of a charter hanging in the air past the desk's front lip.
##
## Only the near edge. The far edge is where packets are handed in and where the
## passage tray's hearing notch lives, and nothing up there can be poured on.
func _near_edge_bounds(doc: DocumentData, desk_bounds: Rect2) -> Rect2:
	var out := desk_bounds
	var lift: float = doc.size.y * 0.5
	# Never invert the rect: a sheet taller than the desk keeps the old rule
	# rather than acquiring an empty one.
	if lift >= out.size.y:
		return out
	out.size.y -= lift
	return out


func _process(delta: float) -> void:
	super._process(delta)
	_tick_backlight(delta)
	_tick_burning(delta)
	# A SHEET IN THE HAND RISES ABOVE THE FLAME.
	#
	# The candle carries z_index 1 so that a sheet cannot slide across a lit wick
	# and look like a glowing patch of desk — right for a sheet lying on the
	# table, and wrong for one you are holding, which was therefore drawn BEHIND
	# the candle every time it was brought to the light. Reported plainly: "the
	# paper is always below the flame". Every other object you can pick up
	# already does this — the ring takes 3, the spoon 4 — and the sheet, the one
	# thing the gesture is actually about, took none.
	#
	# 2 rather than 1: equal z falls back to child order, and the candle is built
	# before any packet, so a tie would still have put the flame on top.
	z_index = 2 if is_held else 0
	if _arrival_t >= 1.0:
		return
	_arrival_t = minf(1.0, _arrival_t + delta / 0.62)
	var arrived := ease(_arrival_t, 0.32)
	position += _arrival_from * (1.0 - arrived)
	rotation += deg_to_rad(side_sign() * 2.5) * (1.0 - arrived)


func side_sign() -> float:
	return -1.0 if (_grain_seed & 1) == 0 else 1.0


func settle_immediately() -> void:
	_arrival_t = 1.0
	position = solver.position
	rotation = solver.angle


## Irregular edge, generated once. Parchment is cut from a skin and never comes
## out square; a perfectly rectangular sheet is the single fastest way to make a
## desk look like a UI.
func _build_deckle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _grain_seed
	_deckle = PackedFloat32Array()
	for i in 24:
		_deckle.append(rng.randf_range(-1.6, 1.6))
	_follicles = PackedVector3Array()
	for i in 44:
		_follicles.append(Vector3(rng.randf(), rng.randf(),
			rng.randf_range(0.5, 1.1)))


func rect() -> Rect2:
	return Rect2(-data.size * 0.5, data.size)


## Where the verdict wax goes. Bottom right of the sheet, clear of the text —
## the same place a chancery would leave room for it.
func wax_slot_local() -> Vector2:
	return Vector2(data.size.x * 0.24, data.size.y * 0.34)


func wax_slot_world() -> Vector2:
	return to_global(wax_slot_local())


func _draw() -> void:
	if data == null:
		return
	var r := rect()
	if is_consumed():
		# Nothing is left to draw. The desk removes the object a beat later; this
		# is the frame in between.
		return
	draw_soft_shadow(r)
	_draw_body(r)
	_draw_face(r)
	_draw_erasures(r)
	# The fire goes OVER the writing, because that is the point of it — a charred
	# charter has lost the words under the char and no amount of light brings
	# them back. Above _draw_face for the same reason the shade is: a new
	# document type cannot forget to do it.
	_draw_burn(r)
	# Last, over everything the subclass drew. A page out of the candle's reach
	# loses its writing before it loses its shape, and a new document type cannot
	# forget to do this because it happens above _draw_face rather than inside it.
	draw_shade(r)


func _draw_body(r: Rect2) -> void:
	# Candle warmth, on the same inverse-square curve the renderer uses. Parchment
	# is a warm, slightly translucent material: near the flame it goes distinctly
	# amber and slightly luminous, away from it the pigment drops toward grey.
	# Between this and the contact shadow, carrying the candle across the desk
	# does visible work on every sheet it passes.
	var reach := clampf(light_level, 0.0, 1.0)
	var glow := reach * clampf(light_strength, 0.7, 1.1)
	var base := data.tint.lerp(Color(1.0, 0.82, 0.55), glow * 0.46)
	base = base.darkened((1.0 - reach) * 0.30)

	# A gradient across the sheet itself, brighter on the side facing the flame.
	# A single flat tint per sheet reads as a tinted rectangle; the falloff across
	# the page is what says the light has a position in the room.
	var toward := (light_position - global_position).rotated(-global_rotation)
	if toward.length() > 1.0:
		toward = toward.normalized()
	var near_edge := base.lerp(Color(1.0, 0.86, 0.62), glow * 0.16)
	var far_edge := base.darkened(glow * 0.10 + 0.05)

	draw_rect(r, base)
	_draw_light_gradient(r, toward, near_edge, far_edge, glow)
	_draw_deckle(r, base)

	# Laid lines: the faint horizontal ribbing of a real skin. Almost invisible,
	# does a surprising amount of work.
	var ribs := int(r.size.y / 9.0)
	for i in ribs:
		var y := r.position.y + float(i) * 9.0 + float(_grain_seed % 5)
		draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y),
			Color(0, 0, 0, 0.020), 1.0)

	# Edge: darker at the rim, lighter along the top-left, so the sheet has a
	# side rather than being a coloured rectangle.
	draw_rect(r, base.darkened(0.30), false, 1.0)
	draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1),
		base.lightened(0.32), 1.0)
	draw_line(r.position + Vector2(1, 1), Vector2(r.position.x + 1, r.end.y - 1),
		base.lightened(0.22), 1.0)


## Banded gradient across the page, running from the edge nearest the flame to
## the edge furthest from it. Eight strips is enough that it reads as a smooth
## falloff at this size, and it costs eight draw_rects instead of a shader —
## which matters because gl_compatibility is the target and this runs on every
## sheet, every frame.
func _draw_light_gradient(r: Rect2, toward: Vector2, near_col: Color,
		far_col: Color, glow: float) -> void:
	if glow < 0.02:
		return
	const BANDS := 8
	# Project the page corners onto the light direction so the bands always run
	# along it, whichever way the sheet has been dropped.
	var horizontal := absf(toward.x) >= absf(toward.y)
	# TRIED AND REVERTED, 2026-08-02: sampling illumination_at per band instead of
	# ramping between two colours derived from the sheet's single light value.
	# It is the same fix that genuinely mattered on the reference books, and on a
	# sheet it MOVES NOTHING — measured on shot_01, the four thirds of the charter
	# and the memorandum changed by between 0.0 and 0.2 out of means of 22 to 44.
	#
	# The reason is that a 430-unit sheet is small enough that inverse-square
	# falloff across it is very close to linear, so the fixed ramp was already
	# right. The books are 640 units open and sit either side of a gutter, which
	# is where the approximation breaks.
	#
	# Do not do it again. The falloff you can see across a sheet in a capture is
	# coming from the actual PointLight2D and is correct; this band is a warm tint
	# on top of it and one sample is enough for that job.
	for i in BANDS:
		var t := (float(i) + 0.5) / float(BANDS)
		# t == 0 is the near edge, so flip when the flame is the other way.
		var along := t if (toward.x if horizontal else toward.y) < 0.0 else 1.0 - t
		var col := far_col.lerp(near_col, 1.0 - along)
		col.a = 0.30 * glow
		if horizontal:
			draw_rect(Rect2(r.position.x + r.size.x * t - r.size.x / BANDS * 0.5,
				r.position.y, r.size.x / BANDS + 1.0, r.size.y), col)
		else:
			draw_rect(Rect2(r.position.x,
				r.position.y + r.size.y * t - r.size.y / BANDS * 0.5,
				r.size.x, r.size.y / BANDS + 1.0), col)


func _draw_deckle(r: Rect2, base: Color) -> void:
	# Bite small notches out of the rim by overdrawing with the desk-side colour.
	# Cheaper and steadier than building an irregular polygon every frame.
	var notch := Color(0, 0, 0, 0.10)
	for i in _deckle.size():
		var d := _deckle[i]
		var t := float(i) / float(_deckle.size())
		if i % 2 == 0:
			var x := r.position.x + t * r.size.x
			draw_rect(Rect2(x, r.position.y, 6.0, absf(d)), notch)
			draw_rect(Rect2(x, r.end.y - absf(d), 6.0, absf(d)), notch)
		else:
			var y := r.position.y + t * r.size.y
			draw_rect(Rect2(r.position.x, y, absf(d), 6.0), notch)
			draw_rect(Rect2(r.end.x - absf(d), y, absf(d), 6.0), notch)


## HOLD IT UP TO THE FLAME.
##
## Scraped vellum is thinner than the skin around it. At rest that shows only as
## a slightly different nap — a patch you might notice and might not, and which
## means nothing on its own, because scribes correct themselves. Lift the sheet
## and bring it near the candle and the thin place TRANSMITS: the patch goes
## amber and translucent and the ghost of the word that was taken out comes back
## through it.
##
## This is the fourth investigative verb, after reading, the glass and the books,
## and it is the first one that is not a lookup. It also gives the candle a second
## job. Up to now the flame has been pressure — light and a clock — and every
## second spent carrying it was a second spent. Now it is an instrument, and the
## most-argued-about object in the design pays for itself twice.
##
## The threshold is deliberately BOTH conditions. Holding it is not enough (the
## sheet has to be in the light) and standing near the candle is not enough (it
## has to be lifted off the pile, which is what a person does). Neither can be
## stumbled into while shuffling papers, and both together are one gesture.
## Tuned against Candle.illumination_at: 0.45 puts the threshold at roughly a
## hand's width from the wick. Far enough that it cannot be stumbled into while
## shuffling papers past the light, close enough that "hold it up to the flame"
## is one deliberate gesture rather than a pixel hunt.
const BACKLIT_LEVEL := 0.45

var _backlit := 0.0

## PARCHMENT BURNS.
##
## Reported as wanted, and it is the right verb for this game: the candle was
## already light, a clock and an instrument, and it becomes the one thing on the
## desk that can destroy evidence. Nothing else here is irreversible except the
## wax, and the wax is a decision you are asked to make. This is one you are not.
##
## THE GESTURE HAS THREE STAGES AND THE FIRST TWO ARE SURVIVABLE.
##
##   scorch   a brown bloom at the point of contact. Permanent, ugly, harmless.
##            Take the sheet away here and you have marked a document and
##            learned what the flame does.
##   catch    a black char with a live orange edge that keeps spreading for a
##            moment after you pull away, because paper does. Now the sheet
##            carries visible damage over its own writing.
##   gone     the sheet is destroyed.
##
## The burn starts AT THE FLAME rather than at any authored point: the ignition
## position is recorded in the sheet's own space the first time the flame gets
## close enough, so a charter lit at its foot burns from its foot and one lit at
## the corner burns from the corner.
##
## IT IS THE EDGE THAT CATCHES, NOT THE MIDDLE, AND THAT IS THE WHOLE SAFETY
## MARGIN OF THE READING VERB.
##
## Distance alone cannot separate the two gestures, and assuming it could was the
## first thing the test caught: reading a charter by the flame means putting the
## charter over the flame, so the wick is INSIDE the sheet's rectangle for the
## entire reading. Any rule of the form "near the wick ignites" sets fire to the
## page every time somebody looks through it.
##
## Paper does not work that way either. A sheet held flat above a candle is
## backlit and gets warm; a sheet whose EDGE is put into the flame catches. So
## ignition asks how far the wick is from the boundary of the sheet — deep inside
## is reading, at the rim is burning — which is both the physical truth and a
## gesture a player can aim: put a corner of it in the fire.
const EDGE_BITE := 30.0
## And it still has to be a live flame close enough to do anything.
const IGNITE_LEVEL := 0.62
## Seconds in the flame before a scorch becomes a fire that carries on by itself.
const CATCH_AT := 0.34
## And how long the whole sheet takes after that. Long enough to be a mistake you
## can watch happening and still fail to stop.
const CONSUMED_AT := 2.6

signal scorched(sheet: Sheet)
signal caught_fire(sheet: Sheet)
signal burnt_away(sheet: Sheet)

## 0 clean, rising through scorch and char to 1, at which the sheet is gone.
var burn := 0.0
## Where the flame first touched, in local space. Meaningless while burn == 0.
var burn_origin := Vector2.ZERO
## True once the fire no longer needs the candle. Paper does not stop because you
## moved it.
var alight := false
## Some sheets must not burn: the practice leaf is the one thing a player is
## invited to experiment on, and destroying it before the first knock would end
## the tutorial with nothing on the desk.
var burnable := true

var _burn_reported := 0


func is_backlit() -> bool:
	return _backlit > 0.55


func is_scorched() -> bool:
	return burn > 0.0


func is_consumed() -> bool:
	return burn >= 1.0


## How far the char has spread from the ignition point, in local units. Grows
## faster than linearly so the first moment is slow and the end is not.
func burn_radius() -> float:
	var r := rect()
	var reach := maxf(r.size.x, r.size.y) * 1.15
	return ease(clampf((burn - _scorch_share()) / maxf(0.001,
		1.0 - _scorch_share()), 0.0, 1.0), 0.72) * reach


## What fraction of `burn` is the survivable brown bloom.
func _scorch_share() -> float:
	return CATCH_AT / CONSUMED_AT


## The point on the rim of `r` closest to a point already inside it.
static func _nearest_rim(r: Rect2, p: Vector2) -> Vector2:
	var left := p.x - r.position.x
	var right := r.end.x - p.x
	var top := p.y - r.position.y
	var bottom := r.end.y - p.y
	var least := minf(minf(left, right), minf(top, bottom))
	if is_equal_approx(least, left):
		return Vector2(r.position.x, p.y)
	if is_equal_approx(least, right):
		return Vector2(r.end.x, p.y)
	if is_equal_approx(least, top):
		return Vector2(p.x, r.position.y)
	return Vector2(p.x, r.end.y)


func _tick_burning(delta: float) -> void:
	if not burnable or burn >= 1.0:
		return
	var in_flame := false
	if is_held:
		var flame := _flame()
		if flame != null and not flame.is_spent():
			var local_flame := to_local(flame.flame_world())
			var r := rect()
			# The point of the sheet nearest the wick — on the rim when the wick
			# is outside, and the wick itself when it is under the page.
			var nearest := Vector2(
				clampf(local_flame.x, r.position.x, r.end.x),
				clampf(local_flame.y, r.position.y, r.end.y))
			var to_edge := 0.0
			if r.has_point(local_flame):
				# Inside: how far from the nearest rim. Deep inside is reading.
				to_edge = minf(
					minf(local_flame.x - r.position.x, r.end.x - local_flame.x),
					minf(local_flame.y - r.position.y, r.end.y - local_flame.y))
				# Burn from the rim it is nearest to, so the char eats inward from
				# the edge the player put in the fire.
				nearest = _nearest_rim(r, local_flame)
			else:
				to_edge = local_flame.distance_to(nearest)
			if to_edge <= EDGE_BITE \
					and flame.illumination_at(to_global(nearest)) >= IGNITE_LEVEL:
				in_flame = true
				if burn <= 0.0:
					burn_origin = nearest
	if not in_flame and not alight:
		return
	burn = minf(1.0, burn + delta / CONSUMED_AT)
	if burn >= _scorch_share():
		alight = true
	queue_redraw()

	# Each threshold announced once. The desk turns these into a case beat and
	# the session into a consequence; the sheet itself knows nothing about either.
	if _burn_reported < 1 and burn > 0.0:
		_burn_reported = 1
		Audio.play(&"wax_sizzle", global_position, -4.0)
		scorched.emit(self)
	if _burn_reported < 2 and alight:
		_burn_reported = 2
		Audio.play(&"candle_catch", global_position, 2.0)
		caught_fire.emit(self)
	if _burn_reported < 3 and burn >= 1.0:
		_burn_reported = 3
		Audio.play(&"candle_out", global_position)
		burnt_away.emit(self)


## EACH PATCH LIGHTS ON ITS OWN.
##
## The first version sampled `light_level`, which the desk computes at the
## sheet's CENTRE — so on a 430x585 charter you could hold the top edge in the
## flame and reveal a scrape 290 units away at the foot. The fiction is that you
## put the thin place in front of the light; the implementation was that you put
## the sheet somewhere near it. Sampling each patch at its own position costs one
## distance per erasure per frame and makes the gesture what it says it is: you
## pass the parchment across the flame and the marks come up as they cross it.
## THE STRUCK SEAL WAS LIT FROM THE MIDDLE OF THE PAGE. WaxPool is a CHILD of the
## sheet rather than of `surface`, so the desk never lit it directly and it
## inherited the sheet's single value wholesale — sampled at the sheet's origin,
## which on a 585-unit charter is up to 290 units from the blank foot the wax
## sits in. The most inspected object in the game rendered dark while sitting
## directly beside the flame. Draggable.illumination_at is the general fix; this
## comment is here because this is where the symptom was.
func _patch_light(patch_centre_local: Vector2) -> float:
	if not is_held:
		return 0.0
	var flame := _flame()
	if flame == null:
		return light_level
	return flame.illumination_at(to_global(patch_centre_local))


## Moved up to Draggable, where every object can use it. This alias keeps the
## sheet's own call sites reading the way they did.
func _flame() -> Candle:
	return flame()


func _tick_backlight(delta: float) -> void:
	# The sheet-wide value still drives the once-per-case dialogue beat: the
	# petitioner reacts to you holding their charter up to the light, not to
	# which particular clause you happened to reach.
	var want := 1.0 if (is_held and light_level >= BACKLIT_LEVEL) else 0.0
	# Eased, and faster to rise than to fall, so bringing a sheet to the flame
	# rewards immediately and taking it away lets you finish reading.
	_backlit = move_toward(_backlit, want, delta * (3.4 if want > 0.0 else 1.6))


func _draw_erasures(r: Rect2) -> void:
	var ch := data as CharterData
	if ch == null:
		return
	if ch.erasures.is_empty():
		# A VERB THAT SOMETIMES DOES NOTHING IS A VERB THAT IS BROKEN.
		#
		# Holding a sound charter up to the flame returned literally no feedback,
		# so a player who tried the new gesture on the first case learned that it
		# does not work rather than that the parchment is clean. Every other
		# investigative act in this game answers every time it is performed: the
		# glass always magnifies, the books always open, and "nothing here" is a
		# result. This is the negative reading, and it is what turns a stunt that
		# happens twice in the campaign into a step you can run on anything.
		#
		# Whole skin transmits evenly. The laid lines — the ribbing of the hide,
		# already drawn in _draw_body — come UP against the light rather than
		# disappearing, because that is exactly what backlighting vellum does and
		# it is the same evidence a scraped patch destroys.
		_draw_whole_skin(r)
		return
	for e in ch.erasures:
		var patch := Rect2(
			r.position + Vector2(e.region.position.x * r.size.x,
				e.region.position.y * r.size.y),
			Vector2(e.region.size.x * r.size.x, e.region.size.y * r.size.y))

		# AT REST: a difference in the nap. Present, findable, and meaningless on
		# its own — which is the whole point. It must never be a marker saying
		# "look here"; it is the same class of thing as a rubbed seal rim.
		draw_rect(patch, Color(0.42, 0.36, 0.26, 0.055 + 0.03 * (1.0 - _backlit)))
		for i in 4:
			var y := patch.position.y + (float(i) + 0.5) * patch.size.y / 4.0
			draw_line(Vector2(patch.position.x + 2.0, y),
				Vector2(patch.end.x - 2.0, y),
				Color(0.35, 0.30, 0.22, 0.05), 1.0)

		# AGAINST THE LIGHT: the thin place transmits. Sampled at the patch, so a
		# long charter has to be passed across the flame rather than merely
		# brought near it.
		var here := clampf(
			(_patch_light(patch.get_center()) - BACKLIT_LEVEL * 0.62)
			/ maxf(0.01, 1.0 - BACKLIT_LEVEL * 0.62), 0.0, 1.0)
		var glow := ease(minf(_backlit + 0.0, 1.0) * here, 0.5)
		if glow <= 0.01:
			continue
		for i in 3:
			var g := float(3 - i) * 2.4
			draw_rect(patch.grow(g),
				Color(1.0, 0.72, 0.34, 0.10 * glow * (1.0 - float(i) / 3.0)))
		draw_rect(patch, Color(1.0, 0.80, 0.45, 0.30 * glow))

		if e.original_value.is_empty():
			# Taken down to the nap. Nothing comes back, and the emptiness is
			# itself what the player has found.
			continue

		# The removed word, feathered: ink that sat on scraped nap spread into it,
		# so it comes back soft-edged rather than crisp. Three offset passes at
		# low alpha, which is the same trick the contact shadows use.
		var at := patch.position + Vector2(3.0, patch.size.y * 0.5 - 7.0)
		var ghost := Color(0.30, 0.19, 0.12, 0.30 * glow)
		for off in [Vector2(-0.6, 0), Vector2(0.6, 0), Vector2(0, 0.6)]:
			Ink.line(self, at + off, e.original_value, 12, ghost)
		Ink.line(self, at, e.original_value, 12,
			Color(0.22, 0.13, 0.08, 0.52 * glow))


## Sound skin against the light: even amber, and the laid lines standing up.
##
## The point is that it looks NOTHING like a scrape. A patch is a bright island
## with feathered ink under it; whole hide is a uniform warmth with the ribbing
## of the animal coming through it, unbroken all the way across. A player who has
## seen both once can tell them apart at a glance forever, which is the entire
## skill this verb exists to teach — and it can only be taught if the negative
## case answers.
func _draw_whole_skin(r: Rect2) -> void:
	if _backlit <= 0.01:
		return
	var glow := ease(_backlit, 0.5)
	# Transmission is strongest through the middle of a stretched skin and falls
	# off toward the edges, where it was pinned on the frame and is thicker.
	for i in 3:
		var t := float(i) / 3.0
		draw_rect(r.grow(-r.size.x * 0.06 * t),
			Color(1.0, 0.74, 0.38, 0.055 * glow))
	# The laid lines come up. Same spacing as the ones _draw_body lays down at
	# 2% opacity, so this reads as the same feature getting brighter rather than
	# as a second set of stripes arriving.
	var ribs := int(r.size.y / 9.0)
	for i in ribs:
		var y := r.position.y + float(i) * 9.0 + float(_grain_seed % 5)
		draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y),
			Color(0.86, 0.60, 0.30, 0.085 * glow), 1.0)
	# And the hair follicles, which only ever show against a light. The single
	# detail that says "this was an animal" rather than "this is paper" — and the
	# pattern is generated once per sheet, because a skin whose pores move between
	# frames is not a skin.
	for f in _follicles:
		draw_circle(r.position + Vector2(f.x * r.size.x, f.y * r.size.y), f.z,
			Color(0.58, 0.40, 0.22, 0.14 * glow))


## Overridden by each document type.
## Scorch, char and ember, drawn from the point the flame actually touched.
##
## Concentric rings rather than a texture: the burn has to start anywhere on any
## sheet at any size, and a ring set is the one shape that is correct wherever it
## is centred and however far it has spread. Drawn coarsely on purpose — a soft
## airbrushed gradient would read as a lighting effect, and this is damage.
func _draw_burn(r: Rect2) -> void:
	if burn <= 0.0:
		return
	# THE SURVIVABLE STAGE. A brown bloom, and nothing else, so a player who
	# brushed the flame and pulled away gets a mark on the document and keeps the
	# document. Reported as wanted in exactly those terms.
	var bloom := clampf(burn / _scorch_share(), 0.0, 1.0)
	var scorch_r := 9.0 + bloom * 26.0
	for i in 4:
		var t := float(i) / 4.0
		draw_circle(burn_origin, scorch_r * (1.0 - t * 0.55),
			Color(0.32, 0.20, 0.10, 0.10 + 0.16 * bloom))

	var eaten := burn_radius()
	if eaten <= 1.0:
		return

	# THE CHAR. Solid, ragged, and it takes the writing with it. Clipped to the
	# sheet by drawing the rings and then re-cutting the rectangle's outside,
	# which costs nothing and keeps the hole inside the parchment.
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = _grain_seed
	var points := PackedVector2Array()
	const SPOKES := 30
	for i in SPOKES:
		var a := TAU * float(i) / float(SPOKES)
		# A fixed per-sheet wobble, so the edge is irregular but does not crawl
		# between frames the way a fresh random would.
		var wobble := 0.78 + seed_rng.randf() * 0.44
		points.append(burn_origin + Vector2.from_angle(a) * eaten * wobble)
	draw_colored_polygon(points, Color(0.07, 0.05, 0.04, 0.93))

	# The live edge. Only while the fire is still going, and brightest where the
	# char is youngest.
	if alight and burn < 1.0:
		var ember := Color(1.0, 0.46, 0.10,
			0.55 + 0.35 * sin(Time.get_ticks_msec() * 0.011))
		for i in SPOKES:
			var a := TAU * float(i) / float(SPOKES)
			var wob := 0.78 + seed_rng.randf() * 0.44
			var at := burn_origin + Vector2.from_angle(a) * eaten * wob
			if not r.grow(2.0).has_point(at):
				continue
			draw_circle(at, 2.6, ember)


func _draw_face(_r: Rect2) -> void:
	pass

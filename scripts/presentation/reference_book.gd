class_name ReferenceBook
extends Draggable

## A physical book on the desk. One scene, two books: the Almanac of Reigns and
## the Book of Matrices differ only by the BookData they are handed.
##
## Opening one DOUBLES its footprint. That is the point. Two open books and a
## charter do not fit on this desk, so deciding which reference to have open is
## the same decision as deciding which check you are actually going to run — and
## closing the Almanac to make room for the Matrices is a real cost, paid in
## having to reopen it and find the page again.
##
## No scrollbars, no index, no search. You turn pages.

const MARGIN := 22.0

signal consulted(book_id: StringName)

var data: BookData = null
var is_open := false
var spread := 0

var _turn := 0.0            ## -1..1, raw page-turn progress
var _turn_dir := 0
var _open_t := 0.0          ## raw 0..1 cover progress
var _open_amount := 0.0     ## eased, and what everything else reads

## Leather is not a flat colour. Grain, scuffing and the worn patches where a
## hand has opened the same board four hundred times are generated once per book
## from its id and then never regenerated — the shape must not crawl, and this
## draws every frame the book is on screen.
var _grain: PackedVector3Array = PackedVector3Array()
var _scuffs: PackedVector3Array = PackedVector3Array()
## A senior hand has inserted a correction since the player last ruled. This is
## deliberately a physical slip, not a notification overlay.
var review_attention := false
var review_page_index := -1


func bind(book: BookData, desk_bounds: Rect2) -> void:
	data = book
	name = "book_" + String(book.id)
	pickup_sound = &"book_close"
	drop_sound = &"ledger_thud"
	slide_sound = &"paper_slide"
	# A closed book is a brick. It is the one object on this desk that genuinely
	# throws a room-length shadow, and putting the candle behind one should black
	# out everything past it.
	occludes_light = true
	occluder_inset = 0.94
	# Books are the biggest things on the desk and shrink furthest to fit a hole.
	stow_scale = 0.34
	_build_leather()
	_update_hit_size()
	setup(book.start_offset, deg_to_rad(book.start_angle_deg), desk_bounds)


## Grain and wear, generated once from the book's own id. Two books never look
## alike and neither one crawls, which is what a per-frame RNG would do.
func _build_leather() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(data.id)) ^ 0x5eaf
	_grain = PackedVector3Array()
	for i in 74:
		# x, y as fractions of the board; z is the fleck's length.
		_grain.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(2.0, 9.0)))
	_scuffs = PackedVector3Array()
	for i in 9:
		_scuffs.append(Vector3(rng.randf_range(0.08, 0.92),
			rng.randf_range(0.08, 0.92), rng.randf_range(9.0, 26.0)))


## Shelved books are shut. An open book will not go in a pigeonhole, and if it
## did it would keep its doubled hit box and swallow clicks meant for the rack.
func close_for_storage() -> void:
	if is_open:
		Audio.play(&"book_close", global_position)
	is_open = false
	_turn_dir = 0
	_turn = 0.0


func _update_hit_size() -> void:
	hit_size = Vector2(data.size.x * (1.0 + _open_amount), data.size.y)


func light_occluder_polygon() -> PackedVector2Array:
	var half := hit_size * 0.5 * occluder_inset
	if _open_amount < 0.08:
		return bevelled_light_occluder(10.0)
	# Two boards meet at a recessed gutter. The shallow notches are enough to
	# break the ruler-straight bar cast by the old hit rectangle.
	var c := minf(10.0, half.y * 0.18)
	var gutter := minf(7.0, half.x * 0.06)
	return PackedVector2Array([
		Vector2(-half.x + c, -half.y),
		Vector2(-gutter, -half.y),
		Vector2(0, -half.y + 6.0),
		Vector2(gutter, -half.y),
		Vector2(half.x - c, -half.y),
		Vector2(half.x, -half.y + c),
		Vector2(half.x, half.y - c),
		Vector2(half.x - c, half.y),
		Vector2(gutter, half.y),
		Vector2(0, half.y - 6.0),
		Vector2(-gutter, half.y),
		Vector2(-half.x + c, half.y),
		Vector2(-half.x, half.y - c),
		Vector2(-half.x, -half.y + c),
	])


func _process(delta: float) -> void:
	super._process(delta)

	# The cover was moving linearly, which is the one thing a hinged board never
	# does. Raw progress is still linear; everything that reads _open_amount now
	# gets it through a curve.
	#
	# It used to be ease(_open_t, 0.42). That is ease-OUT, which begins at about
	# 2.4x average speed — right for something released under tension, wrong for
	# a board that starts flat on the desk with nothing moving it yet. The board
	# has mass and begins AT REST, so it wants a curve that starts at zero speed
	# and ends at zero speed, and smoothstep is exactly that.
	#
	# (The rulebook used to justify avoiding this curve by claiming ease(x, 0.4)
	# has an infinite derivative at zero and snaps on the first frame. It does
	# not — measured, it covers 4% of the distance in the first frame. The reason
	# to change it here is the physics, not the phantom snap.)
	_open_t = move_toward(_open_t, 1.0 if is_open else 0.0, delta * 4.2)
	_open_amount = smoothstep(0.0, 1.0, _open_t)
	_update_hit_size()

	if _turn_dir != 0:
		_turn = move_toward(_turn, float(_turn_dir), delta * 4.6)
		if absf(_turn) >= 1.0:
			spread = clampi(spread + _turn_dir, 0, maxi(0, data.spread_count() - 1))
			_turn = 0.0
			_turn_dir = 0


## Eased page-turn progress, 0..1. A leaf accelerates off the fore-edge, is at
## its fastest crossing the gutter, and decelerates as it lands — ease-in-out,
## which the linear version had no trace of.
func turn_progress() -> float:
	return ease(absf(_turn), -1.8)


# ------------------------------------------------------------------ interaction

func on_click(local: Vector2) -> bool:
	if not is_open:
		is_open = true
		# The slip did its job by bringing the reader to this folio. Once the
		# cover opens, the corrected marginalium itself is the visible cue.
		review_attention = false
		Audio.play(&"book_open", global_position)
		consulted.emit(data.id)
		return true

	var half := page_size().x
	# Outer third of either page turns it; the middle closes the book. Marked
	# by drawn corner curls, which is the only affordance a book needs.
	if local.x > half * 0.62:
		return _turn_page(1)
	if local.x < -half * 0.62:
		return _turn_page(-1)

	is_open = false
	Audio.play(&"book_close", global_position)
	return true


func _turn_page(dir: int) -> bool:
	if _turn_dir != 0:
		return true
	var next := spread + dir
	if next < 0 or next >= data.spread_count():
		return true  # consumed: hitting the end of a book is not a miss
	_turn_dir = dir
	Audio.play(&"page_turn", global_position)
	consulted.emit(data.id)
	return true


func page_size() -> Vector2:
	return Vector2(data.size.x * _open_amount, data.size.y)


func mark_review_attention() -> void:
	review_attention = true
	review_page_index = -1
	# Opening the returned book should reveal the correction, not make the
	# player turn through old entries hunting for an unexplained flag.
	for i in range(data.pages.size() - 1, -1, -1):
		if data.pages[i].marginalia.begins_with("Reviewed after the next call:"):
			review_page_index = i
			spread = i / 2
			break
	queue_redraw()


# --------------------------------------------------------------------- drawing

## How much of the flame actually lands on these boards. The two books are the
## largest silhouettes on the desk and were the only objects drawn at a fixed
## cover colour regardless of where the candle stood — so the biggest things in
## the room were the least material. Everything below reads from this.
func _lit() -> float:
	return Surface.lit(light_level, light_strength)


## AND THE SAME, MEASURED AT ONE LEAF RATHER THAN AT THE SPINE.
##
## An open book is twice its closed width — 640 units for the Almanac, which is
## more than a third of the reachable desk and comparable to the whole pool of
## usable light. The desk hands every object ONE light value sampled at its
## origin, so a candle set down beside the left leaf lit the right leaf exactly
## as brightly, and the two largest silhouettes in the room reported the flame's
## position by their highlight direction while flatly contradicting it with their
## brightness.
##
## Reading by candlelight is the whole game. This is the object it matters most
## on and it was the object least able to say so.
func _leaf_lit(leaf: Rect2) -> float:
	if light_level <= 0.0:
		return 0.0
	var at := to_global(leaf.get_center())
	return Surface.lit(illumination_at(at), light_strength)


## Unit vector toward the flame in the book's own space, so a highlight sits on
## the side the light is actually on however the book has been dropped.
func _toward_light() -> Vector2:
	return Surface.toward(self, light_position)


func _draw() -> void:
	if data == null:
		return
	var w := data.size.x * (1.0 + _open_amount)
	var full := Rect2(-w * 0.5, -data.size.y * 0.5, w, data.size.y)
	var glow := _lit()
	var toward := _toward_light()

	# Tanned hide near a flame goes distinctly red-brown and then falls away hard.
	# Sheet already does this for parchment; a board that ignores it reads as a
	# coloured rectangle sitting on a lit desk rather than a thing in the room.
	# Only the warm tint lives here. The fall into shadow is the shared veil at the
	# foot of this function, so a board and a charter lying beside each other go
	# dark together instead of on two different curves.
	var cover := Surface.tint_for(data.cover_color, glow, ambient_daylight,
		0.30, 0.18)

	draw_soft_shadow(full)

	# THE BOARDS HAVE THICKNESS. A closed book is a brick — the one object here
	# that genuinely stands proud of the desk — so the side of the block shows on
	# whichever face is turned away from the candle, and swings round when the
	# candle is carried past.
	var rim := full.grow(5.0)
	var thick := 6.0 * (1.0 - _open_amount * 0.55)
	Surface.extrude(self, rim, toward, cover, thick, 0.66)
	draw_rect(rim, cover.darkened(0.34))
	if _open_amount < 0.02:
		_draw_text_block(full, glow)
	draw_rect(full.grow(3.0), cover)

	if _open_amount < 0.02:
		_draw_closed(full, cover, toward, glow)
	else:
		_draw_open(full, glow)
	draw_shade(full.grow(5.0))
	# The slip is vermilion and it is the office telling you something. It sits
	# above the veil deliberately: a correction you cannot see because you left
	# the candle at the other end of the desk is a correction that does not exist.
	if review_attention:
		_draw_review_slip(full)


## The leaves themselves, showing past the boards along the fore-edge and foot.
## Parchment is thick and never cut perfectly true, so the stack is uneven — the
## fastest single cue that a closed book is made of pages rather than of paint.
func _draw_text_block(r: Rect2, glow: float) -> void:
	var leaf := data.page_color.lerp(Color(1.0, 0.86, 0.62), glow * 0.35)
	leaf = leaf.darkened((1.0 - glow) * 0.45)
	var block := Rect2(r.position + Vector2(2.0, 2.0),
		r.size + Vector2(4.0, 4.0))
	draw_rect(block, leaf.darkened(0.22))
	# Individual leaf edges. Uneven lengths from the same seeded grain, so no two
	# books show the same stack.
	var count := mini(16, _grain.size())
	for i in count:
		var t := float(i) / float(count)
		var jitter: float = _grain[i].z * 0.30
		var y := block.position.y + 6.0 + t * (block.size.y - 12.0)
		draw_line(Vector2(block.end.x - 5.0 - jitter, y),
			Vector2(block.end.x, y), leaf.lightened(0.18), 1.0)
		var x := block.position.x + 8.0 + t * (block.size.x - 16.0)
		draw_line(Vector2(x, block.end.y - 4.0 - jitter * 0.5),
			Vector2(x, block.end.y), leaf.lightened(0.10), 1.0)


func _draw_review_slip(r: Rect2) -> void:
	# A narrow vermilion docket slip protrudes beyond the top board whether the
	# book is closed or open. It survives racking and candlelight, and names the
	# event in the fiction's own material language.
	var slip := Rect2(r.end.x - 112.0, r.position.y - 24.0, 88.0, 46.0)
	draw_rect(Rect2(slip.position + Vector2(3, 4), slip.size),
		Color(0, 0, 0, 0.28))
	draw_rect(slip, Color(0.57, 0.20, 0.14))
	draw_rect(slip.grow(-3.0), Color(0.80, 0.55, 0.34), false, 1.0)
	Ink.line_centre(self, slip.position + Vector2(5.0, 14.0), "REVIEWED", 9,
		Color(0.96, 0.82, 0.57), slip.size.x - 10.0)


func _draw_closed(r: Rect2, cover: Color, toward: Vector2, glow: float) -> void:
	_draw_hide(r, cover, glow)
	_draw_spine(r, cover, toward, glow)

	# BLIND TOOLING, AND IT WAS STAMPED INSIDE OUT.
	#
	# A line pressed into damp leather with a hot iron is a GROOVE, and a groove
	# has two walls: the far one faces back toward the flame and catches it, the
	# near one faces away and is in shadow. So the lit lip belongs on the side
	# AWAY from the light and the dark trough toward it.
	#
	# This drew them the other way round — lip at +toward, trough at -toward — so
	# the boards' stamped borders read as RAISED rather than impressed, and swung
	# the wrong way as the candle was carried past them. SignetRing had the same
	# vocabulary and had it right; putting the two in one file is what made them
	# disagree out loud. The convention and the physics now live in Surface, with
	# an assertion, so the next engraved line cannot pick the other one.
	for inset in [14.0, 20.0]:
		Surface.bevel_rect(self, r.grow(-inset), toward, glow, false,
			1.5, 1.0, 0.20, 0.30)

	var at := Vector2(r.position.x + MARGIN, r.position.y + r.size.y * 0.34)
	var w := r.size.x - MARGIN * 2.0
	# Gilt. Gold leaf on a board is the one thing in this room brighter than the
	# parchment, and it is only bright while the candle is anywhere near it.
	var gilt := data.page_color.lerp(Color(1.0, 0.84, 0.42), 0.30 + glow * 0.55)
	gilt = gilt.darkened((1.0 - glow) * 0.42)
	Ink.line_centre(self, at + toward * 1.0, data.title.to_upper(), 15,
		Color(0, 0, 0, 0.42), w)
	Ink.line_centre(self, at, data.title.to_upper(), 15, gilt, w)
	Ink.line_centre(self, at + Vector2(0, 26), data.subtitle, 11,
		Color(gilt, 0.72), w)

	_draw_clasp(r, toward, glow)


## Flecking, and the patches worn pale where a hand takes hold of the same board
## every time. Both come out of the cached grain, so this is a dozen draw calls
## and no allocation.
func _draw_hide(r: Rect2, cover: Color, glow: float) -> void:
	var dark := Color(0, 0, 0, 0.10 + 0.05 * glow)
	# Wear has to stay under the threshold where it reads as a stain rather than
	# as leather. At the alpha this first ran at, the boards looked spilt on.
	var pale := Color(cover.lightened(0.22), 0.030 + 0.045 * glow)
	for scuff in _scuffs:
		draw_circle(r.position + Vector2(scuff.x * r.size.x, scuff.y * r.size.y),
			scuff.z, pale)
	for fleck in _grain:
		var at := r.position + Vector2(fleck.x * r.size.x, fleck.y * r.size.y)
		draw_line(at, at + Vector2(fleck.z, fleck.z * 0.34), dark, 1.0)


## The spine, with the raised cords the sections are sewn onto. Four ridges, each
## with its own lit and shaded side — this is the detail that says "bound" rather
## than "rectangle", and it is only three draw calls a band.
func _draw_spine(r: Rect2, cover: Color, toward: Vector2, glow: float) -> void:
	var spine := Rect2(r.position, Vector2(26.0, r.size.y))
	draw_rect(spine, cover.darkened(0.16))
	draw_rect(Rect2(spine.end.x - 2.0, spine.position.y, 3.0, spine.size.y),
		Color(0, 0, 0, 0.24))
	for i in 4:
		var y := spine.position.y + spine.size.y * (0.18 + 0.215 * float(i))
		var band := Rect2(spine.position.x - 3.0, y - 4.5,
			spine.size.x + 6.0, 9.0)
		draw_rect(band, cover.darkened(0.06))
		# The cord catches the flame on the side facing it and shades on the other.
		draw_line(Vector2(band.position.x, y - 4.0 + toward.y * 1.6),
			Vector2(band.end.x, y - 4.0 + toward.y * 1.6),
			Color(1.0, 0.84, 0.58, 0.22 * glow), 1.5)
		draw_line(Vector2(band.position.x, y + 4.0),
			Vector2(band.end.x, y + 4.0), Color(0, 0, 0, 0.26), 1.5)


## Brass catches tarnish everywhere except where a thumb touches them. The
## highlight tracks the flame, which is the cheapest specular in the game and the
## one that most repays a player who carries the candle across the desk.
func _draw_clasp(r: Rect2, toward: Vector2, glow: float) -> void:
	var centre := Vector2(r.end.x - 1.0, r.get_center().y)
	var plate := Rect2(centre.x - 7.0, centre.y - 24.0, 18.0, 48.0)
	draw_rect(Rect2(plate.position - toward * 2.0, plate.size),
		Color(0, 0, 0, 0.34))
	draw_rect(plate, Color(0.44, 0.37, 0.21))
	draw_rect(plate.grow(-3.0), Color(0.66, 0.57, 0.33))
	# The strap running back onto the board, and the pin it hooks over.
	draw_rect(Rect2(plate.position.x - 16.0, centre.y - 7.0, 18.0, 14.0),
		Color(0.31, 0.22, 0.14))
	draw_circle(centre + Vector2(1.0, 0.0), 4.2, Color(0.52, 0.44, 0.26))
	Surface.specular(self, centre, toward, glow, 3.4, 2.1, 1.1, 0.30, 0.55)


func _draw_open(r: Rect2, glow: float) -> void:
	var pw := r.size.x * 0.5
	var left := Rect2(r.position + Vector2(6, 6), Vector2(pw - 9, r.size.y - 12))
	var right := Rect2(Vector2(r.position.x + pw + 3, r.position.y + 6),
		Vector2(pw - 9, r.size.y - 12))

	# EACH LEAF TAKES THE LIGHT WHERE THAT LEAF IS. See _leaf_lit: an open book is
	# 640 units across and the two halves were drawn at one brightness taken from
	# the spine, so the candle beside one page lit the other page identically.
	# Reading by candlelight is the whole game and this is the object it happens
	# on. `glow` still drives the boards, the clasp and the specular, which are
	# small enough that one sample at the spine is the right answer for them.
	for pr in [left, right]:
		var leaf := data.page_color.lerp(Color(1.0, 0.87, 0.64),
			_leaf_lit(pr) * 0.30)
		draw_rect(pr, leaf)
		draw_rect(pr, leaf.darkened(0.20), false, 1.0)

	# Gutter shadow: pages curve down into the spine.
	for i in 8:
		var t := float(i) / 8.0
		var a := 0.10 * (1.0 - t)
		draw_rect(Rect2(r.position.x + pw - 12.0 * (1.0 - t), r.position.y + 6,
			24.0 * (1.0 - t), r.size.y - 12), Color(0, 0, 0, a))

	if _open_amount < 0.75:
		return  # mid-swing; do not draw text into a half-open book

	var under := pages_under_turn()
	_draw_page(left, under.x)
	_draw_page(right, under.y)
	_draw_corners(left, right)
	_draw_turning_page(r, pw)


## THE TURNING LEAF, AND ITS WIDTH WAS INSIDE OUT.
##
## A leaf is a rigid page hinged at the spine. Its projected width is
## `pw * |cos(theta)|` with theta running 0..PI: FULL WIDTH lying flat on the
## page it starts from, ZERO edge-on above the gutter, full width again as it
## lands. The shipped version computed `pw * (1 - |2t-1|)`, which is the exact
## complement of that — zero at the start, full width at the vertical, zero at
## the end. Measured at pw=200:
##
##     t     shipped   rigid leaf
##     0.0       0.0        200.0    lying flat, should be a whole page
##     0.5     200.0          0.0    edge-on, should be invisible
##     1.0       0.0        200.0    landed, should be a whole page
##
## So the leaf inflated out of the gutter and deflated back into it. Its own
## comment called it crude and said "at the speed it moves it reads"; it was not
## crude, it was backwards, and what it read as was a wipe. Books are open for
## most of every case and this is the only animation in them.
##
## With the geometry right, three cheap things finish it: the leaf shows its
## VERSO after it passes the vertical, it casts a shadow on whatever it is
## standing over, and it bows under its own weight instead of staying square.
func pages_under_turn() -> Vector2i:
	if _turn_dir > 0:
		return Vector2i(spread * 2, (spread + 1) * 2 + 1)
	if _turn_dir < 0:
		return Vector2i((spread - 1) * 2, spread * 2 + 1)
	return Vector2i(spread * 2, spread * 2 + 1)


func turning_leaf_index(after_vertical: bool) -> int:
	if _turn_dir > 0:
		return spread * 2 + (2 if after_vertical else 1)
	if _turn_dir < 0:
		return spread * 2 + (-1 if after_vertical else 0)
	return -1


func _draw_turning_page(r: Rect2, pw: float) -> void:
	if _turn_dir == 0:
		return
	var t := turn_progress()
	var theta := PI * t
	var lift := sin(theta)          ## 0 flat, 1 standing straight up
	# Foreshortening, with a floor. Strictly, a page seen edge-on in a top-down
	# projection is a line of zero width — but parchment is thick, and a leaf
	# that disappears completely for a frame or two in the middle of the turn
	# reads as a dropped frame rather than as a page standing up.
	var projected := maxf(absf(cos(theta)), 0.018)
	var width := pw * projected
	var gutter := r.position.x + pw
	var top := r.position.y + 6.0
	var h := r.size.y - 12.0

	# Which side of the gutter the leaf is over. It crosses at the vertical, so a
	# forward turn is on the right until halfway and on the left after it.
	var on_right := (_turn_dir > 0) != (t > 0.5)
	var dir := 1.0 if on_right else -1.0

	# A leaf standing off the page shades what it is standing over, hardest when
	# it is upright — which is also the moment the leaf itself has no width, so
	# without this the middle of every turn is a page that vanishes.
	var shadow_reach := width + 34.0 * lift
	var shadow_free := gutter + dir * shadow_reach + dir * 5.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(gutter + dir * 2.0, top + 3.0),
		Vector2(shadow_free, top + 8.0 + lift * 5.0),
		Vector2(shadow_free, top + h + 3.0 + lift * 5.0),
		Vector2(gutter + dir * 2.0, top + h),
	]), Color(0.0, 0.0, 0.0, 0.12 + 0.19 * lift))

	# Recto until it goes over the top, verso after. The swap at the vertical is
	# the single clearest cue that the thing rotated rather than slid sideways.
	var glow := _lit()
	var after_vertical := t > 0.5
	var face := data.page_color.lightened(0.06) if not after_vertical \
		else data.page_color.darkened(0.11)
	face = Surface.tint_for(face, glow, ambient_daylight, 0.22, 0.26)

	# Bowed, not square. Parchment under its own weight curves away from the
	# spine, and the straight-edged version is most of why this read as a wipe.
	var local_leaf := Rect2(
		Vector2(3.0, -h * 0.5) if on_right else Vector2(-pw + 6.0, -h * 0.5),
		Vector2(pw - 9.0, h))
	draw_set_transform(Vector2(gutter, top + h * 0.5), 0.0,
		Vector2(projected, 1.0 - lift * 0.024))
	draw_rect(local_leaf, face)
	draw_rect(local_leaf, face.darkened(0.28), false, 1.1)
	_draw_page(local_leaf, turning_leaf_index(after_vertical))
	# Sparse leaves still carry laid lines, which tighten with the rest of the
	# surface as it goes edge-on.
	for i in 9:
		var y := local_leaf.position.y + 28.0 + float(i) * 34.0
		if y < local_leaf.end.y - 24.0:
			draw_line(Vector2(local_leaf.position.x + 12.0, y),
				Vector2(local_leaf.end.x - 12.0, y),
				Color(0.32, 0.24, 0.17, 0.045), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# A curved free edge supplies the bow without distorting the calligraphy.
	var free_x := gutter + width * dir
	var bow := 10.0 * lift * dir
	var edge := PackedVector2Array()
	for i in 9:
		var v := float(i) / 8.0
		edge.append(Vector2(free_x + bow * sin(PI * v), top + h * v))
	draw_polyline(edge, Color(face.lightened(0.18), 0.66), 1.4, true)
	draw_line(Vector2(gutter, top), Vector2(gutter, top + h),
		Color(0, 0, 0, 0.12 + 0.13 * lift), maxf(1.0, width * 0.05))


## Curled outer corners: the whole affordance for turning pages.
func _draw_corners(left: Rect2, right: Rect2) -> void:
	if spread + 1 < data.spread_count():
		var c := right.end
		draw_colored_polygon(PackedVector2Array([
			c, c - Vector2(26, 0), c - Vector2(0, 26)]),
			data.page_color.darkened(0.18))
		draw_line(c - Vector2(26, 0), c - Vector2(0, 26),
			data.page_color.darkened(0.35), 1.0)
	if spread > 0:
		var c2 := Vector2(left.position.x, left.end.y)
		draw_colored_polygon(PackedVector2Array([
			c2, c2 + Vector2(26, 0), c2 - Vector2(0, 26)]),
			data.page_color.darkened(0.18))
		draw_line(c2 + Vector2(26, 0), c2 - Vector2(0, 26),
			data.page_color.darkened(0.35), 1.0)


# ----------------------------------------------------------------- page kinds

## The leaf a page is drawn into, as _draw_open computes it when fully open.
##
## This and page_bottom() below exist so the suite can check that every leaf the
## content generates actually FITS the board it is printed on. Nothing in this
## book clips: Ink.block passes max_lines = -1, there is no clip_children, and
## the shade veil only covers the boards — so a page that overruns is simply
## drawn onto the desk underneath, unlit and unreadable, and the game silently
## loses whatever was on the end of it. The Almanac's ring doctrine lost its
## entire FALSE-versus-DEFECTIVE half that way, which is the only place the game
## explains why a defective instrument is REFERRED rather than DENIED.
##
## KEEP THESE TWO IN STEP WITH _draw_page AND _draw_open. They are deliberately
## adjacent to it for that reason.
func leaf_rect() -> Rect2:
	var full := Rect2(-data.size.x, -data.size.y * 0.5,
		data.size.x * 2.0, data.size.y)
	var pw := full.size.x * 0.5
	return Rect2(full.position + Vector2(6, 6),
		Vector2(pw - 9, full.size.y - 12))


## How far down the leaf a page's content reaches, including its marginalia.
##
## "The generated kinds size themselves" was true of the plates and FALSE of the
## obit rolls, which is the more dangerous half. `KalendarBook` paginates on a
## flat `ENTRIES_PER_PAGE = 6` — a NAME count, not a height budget — so a leaf's
## height depends entirely on how many of those six carry a note. Nothing in
## this game clips its own text, so an overfull leaf would be drawn onto the desk
## and lost. That is the same defect class as the Almanac's ring-doctrine page.
func page_bottom(index: int) -> float:
	if data == null or index >= data.pages.size():
		return 0.0
	var page: BookPage = data.pages[index]
	var r := leaf_rect()
	var w := r.size.x - MARGIN * 2.0
	var y := r.position.y + MARGIN * 0.9
	if not page.heading.is_empty():
		y += Ink.line_height(13) + 9.0
	if not page.subheading.is_empty():
		y += Ink.line_height(11)
	y += 5.0
	# On a roll the prose leads the names; see _draw_page's `body_leads`.
	#
	# `Ink.block` returns `measure.y + size * 0.25`, NOT `measure.y` — the
	# non-body_leads branch below has always had that term and this one was
	# written without it. Two functions that must stay in step have drifted
	# three times in this project and every time it was a few pixels.
	var body_leads := page.kind == &"obits" or page.kind == &"silence"
	if body_leads and not page.body.is_empty():
		y += Ink.measure(page.body, 11, w).y + 11 * 0.25 + 4.0
	if page.kind == &"obits":
		y += _obit_roll_height(w, page)
	if not body_leads and not page.body.is_empty():
		y += Ink.measure(page.body, 11, w).y + 11 * 0.25
	if not page.marginalia.is_empty():
		var note_h := Ink.measure(page.marginalia, 10, w).y + 6.0
		y = maxf(y + 6.0, r.end.y - MARGIN - note_h) + note_h
	return y


## Mirrors `_draw_obit_roll` line for line. KEEP THE TWO IN STEP.
func _obit_roll_height(w: float, page: BookPage) -> float:
	var roll := Lore.obit_roll(page.roll_id)
	if roll == null:
		return Ink.line_height(11)
	var y := 0.0
	if page.entry_count <= 0:
		y += Ink.line_height(10)
		if Lore.data.reign(roll.written_up_to_emperor) != null:
			y += Ink.line_height(11)
		return y + 10.0
	var last := mini(roll.entries.size(), page.entry_from + page.entry_count)
	for i in range(page.entry_from, last):
		var o: Obit = roll.entries[i]
		y += Ink.line_height(11) + Ink.line_height(10)
		if not o.note.is_empty():
			# Ink.block, not Ink.measure. The 9 * 0.25 is 2.25 px off a leaf that
			# clears its folio number by under 5, which is most of the margin this
			# whole function exists to guard.
			y += Ink.measure("  " + o.note, 9, w).y + 9 * 0.25
		y += 3.0
	return y


## Where the folio number sits. Content that reaches this is not off the board
## yet, but it is printed through the page number, which is the first visible
## symptom of a leaf about to overflow.
func folio_baseline() -> float:
	return leaf_rect().end.y - 20.0


func _draw_page(r: Rect2, index: int) -> void:
	if index >= data.pages.size():
		return
	var page: BookPage = data.pages[index]
	var w := r.size.x - MARGIN * 2.0
	var at := r.position + Vector2(MARGIN, MARGIN * 0.9)

	if not page.heading.is_empty():
		at.y += Ink.heading(self, at, page.heading, 13, Ink.CHANCERY, w)
	if not page.subheading.is_empty():
		at.y += Ink.line_fit(self, at, page.subheading, 11, Ink.FADED, w)
	at.y += 5.0

	# On a plate the prose comments on the thing above it, so the body follows the
	# drawing. On a roll the prose is the house speaking about its own roll, so it
	# comes before the names — a list with its preamble printed underneath it is
	# not how anything has ever been bound.
	var body_leads := page.kind == &"obits" or page.kind == &"silence"
	if body_leads and not page.body.is_empty():
		at.y += Ink.block(self, at, page.body, 11, Ink.CHANCERY, w)
		at.y += 4.0

	match page.kind:
		&"matrix": at.y += _draw_matrix_plate(at, w, page)
		&"reigns": at.y += _draw_reign_table(at, w)
		&"styles": at.y += _draw_style_table(at, w)
		&"plate": at.y += _draw_polity_plate(at, w, page)
		&"obits": at.y += _draw_obit_roll(at, w, page)
		&"silence": at.y += _draw_silences(at, w)
		_: pass

	if not body_leads and not page.body.is_empty():
		at.y += Ink.block(self, at, page.body, 11, Ink.CHANCERY, w)

	if not page.marginalia.is_empty():
		# THE HOLE IS SIZED FROM THE NOTE, NOT FROM A GUESS.
		#
		# This reserved a flat 54 px however long the note was, and nothing in the
		# book clips or elides — Ink.block passes max_lines = -1 — so a longer
		# hand simply ran off the bottom board and was drawn on the desk. The
		# senior clerk's correction in the Register is 147 px in that 54 px hole,
		# so half of it, including the sentence naming the point at issue, was
		# painted onto the blotter under the book. The Kalendar's own front
		# matter did it on the first spread the player ever opens.
		var note_h := Ink.measure(page.marginalia, 10, w).y + 6.0
		var foot := Vector2(r.position.x + MARGIN,
			maxf(at.y + 6.0, r.end.y - MARGIN - note_h))
		Ink.margin_note(self, foot, page.marginalia, 10, w, -3.5)

	# Folio number, bottom outer corner.
	Ink.line_right(self, Vector2(r.position.x + MARGIN, r.end.y - 20.0),
		str(index + 1), 9, Ink.FADED, w)


## The plate a player actually compares against. Device drawn at size, legend set
## out in full, and the die's lifespan — which is the field that decides case two
## and is set no larger than any other, because pointing at the answer is not a
## question.
func _draw_matrix_plate(at: Vector2, w: float, page: BookPage) -> float:
	var m := Lore.matrix(page.matrix_id)
	if m == null:
		return Ink.line_fit(self, at, "[ die not recorded ]", 11, Ink.RUBRIC, w)
	var y := 0.0
	var r := minf(w * 0.30, 54.0)
	var centre := at + Vector2(w * 0.5, r + 4.0)

	# The impression as the book shows it: outline of the die's shape, device
	# inside, so shape and device are both comparable at a glance.
	var unit := WaxShape.outline(m.shape, hash(String(m.id)), 0.03, 26)
	draw_colored_polygon(WaxShape.scaled(unit, centre, r),
		m.wax_color.lightened(0.06))
	draw_colored_polygon(WaxShape.scaled(unit, centre, r * 0.94),
		m.wax_color)
	Heraldry.draw_device_incuse(self, m.device, centre, r * 0.55, m.wax_color, 0.8)
	y += r * 2.0 + 12.0

	y += Ink.line_fit(self, at + Vector2(0, y), m.owner_name, 12, Ink.CHANCERY, w)
	var p := Lore.polity(m.polity_id)
	if p != null:
		y += Ink.line_fit(self, at + Vector2(0, y), p.name, 10, Ink.FADED, w)
	y += 4.0
	y += Ink.label(self, at + Vector2(0, y), "legend", 8, Ink.FADED)
	y += Ink.block(self, at + Vector2(0, y), m.legend, 11, Ink.CHANCERY, w)
	y += 3.0
	y += Ink.line_fit(self, at + Vector2(0, y),
		"%s · %s" % [String(m.shape), Heraldry.display_name(m.device)],
		10, Ink.FADED, w)
	y += Ink.line_fit(self, at + Vector2(0, y), m.life_text(), 11,
		Ink.RUBRIC if m.broken_year >= 0 else Ink.CHANCERY, w)
	y += 4.0
	if not m.note.is_empty():
		y += Ink.block(self, at + Vector2(0, y), m.note, 10, Ink.FADED, w)
	return y


## One house's roll of the dead.
##
## The coverage statement is set in the SAME weight as the entries, deliberately.
## Every finding this book supports is a finding about coverage as much as about
## a man — "the roll is written up to 1219 and this instrument is dated 1221" is
## the whole reason a witness list can be honestly unverifiable — so the line that
## states the edge of the roll's knowledge cannot be small print.
func _draw_obit_roll(at: Vector2, w: float, page: BookPage) -> float:
	var roll := Lore.obit_roll(page.roll_id)
	if roll == null:
		return Ink.line_fit(self, at, "[ no roll returned ]", 11, Ink.RUBRIC, w)
	var y := 0.0

	# The reckoning and the edge of the roll's knowledge belong at the HEAD of a
	# section only — the leaf that carries no names. Repeating them above every
	# run of entries would eat the page and stop reading as a bound book.
	if page.entry_count <= 0:
		# Its own reckoning, stated on its own page. The Saint Wend chapter counts
		# from election like the rest of the Church, and a clerk who reduces its
		# obits as an imperial notary would gets a number three years wrong —
		# which is only fair because this line is here.
		y += Ink.block(self, at + Vector2(0, y),
			"reckoned " + Lex.dating_name(roll.reckoning), 10, Ink.RUBRIC, w)
		var reign := Lore.data.reign(roll.written_up_to_emperor)
		if reign != null:
			y += Ink.block(self, at + Vector2(0, y),
				"written up to the %s year of %s"
				% [Lex.ordinal(roll.written_up_to_regnal_year),
					reign.full_name()], 11, Ink.RUBRIC, w)
		y += 4.0
		Ink.rule(self, at + Vector2(0, y), w, Ink.FADED * Color(1, 1, 1, 0.5))
		y += 6.0

	# A head leaf carries no names at all. Clamping the count up to one here put a
	# single stray obit under the coverage statement on every section head.
	if page.entry_count <= 0:
		return y
	var last := mini(roll.entries.size(), page.entry_from + page.entry_count)
	for i in range(page.entry_from, last):
		var o := roll.entries[i]
		y += Ink.line_fit(self, at + Vector2(0, y), o.display(), 11, Ink.CHANCERY, w)
		var r := Lore.data.reign(o.died_emperor)
		# Regnal form, like every other date in the game, so establishing when a
		# man died still costs a trip to the Almanac. Printing the absolute year
		# here would hand the player the one piece of arithmetic this is for.
		y += Ink.line_fit(self, at + Vector2(0, y), "  " + o.obit_line(
			r.full_name() if r != null else String(o.died_emperor)), 10, Ink.FADED, w)
		if not o.note.is_empty():
			y += Ink.block(self, at + Vector2(0, y), "  " + o.note, 9,
				Ink.FADED, w)
		y += 3.0
	return y


## The houses that send nothing, and why. This page is the reason absence is not
## evidence, and it is generated from the same data the check reads so it cannot
## quietly stop matching the polity roster.
func _draw_silences(at: Vector2, w: float) -> float:
	var n := Lore.data.necrology
	if n == null:
		return 0.0
	var y := 0.0
	for house in n.silences:
		var p := Lore.polity(house)
		y += Ink.line_fit(self, at + Vector2(0, y),
			p.name if p != null else String(house), 11, Ink.CHANCERY, w)
		y += Ink.block(self, at + Vector2(0, y), "  " + String(n.silences[house]),
			10, Ink.FADED, w)
		y += 6.0
	return y


func _draw_reign_table(at: Vector2, w: float) -> float:
	var y := 0.0
	y += Ink.line_fit(self, at + Vector2(0, y), "chosen   acceded  crowned  ended",
		9, Ink.FADED, w)
	y += 3.0
	Ink.rule(self, at + Vector2(0, y), w, Ink.FADED * Color(1, 1, 1, 0.5))
	y += 5.0
	for id in Lore.data.reigns:
		var reign: Reign = Lore.data.reigns[id]
		y += Ink.line_fit(self, at + Vector2(0, y), reign.full_name(), 11, Ink.CHANCERY, w)
		var ended := str(reign.end_year) if reign.end_year >= 0 else "reigns"
		var row := "  %s     %s     %s     %s" % [
			str(reign.election_year).rpad(7),
			str(reign.accession_year).rpad(7),
			str(reign.coronation_year).rpad(7),
			ended,
		]
		y += Ink.line_fit(self, at + Vector2(0, y), row, 10, Ink.CHANCERY, w)
		if not reign.epithet.is_empty():
			y += Ink.line_fit(self, at + Vector2(0, y), "  " + reign.epithet, 9, Ink.FADED, w)
		y += 5.0
	return y


## The page that makes case three soluble. It states the three reckonings plainly
## and works one example. It does not say which applies to any particular
## chancery — that is on the charter, in the closing formula, where a scribe
## would have put it.
func _draw_style_table(at: Vector2, w: float) -> float:
	var y := 0.0
	var rows := [
		["Imperial notaries", "count from ACCESSION"],
		["The Church", "counts from ELECTION"],
		["Some chanceries", "count from CORONATION"],
	]
	for row in rows:
		y += Ink.line_fit(self, at + Vector2(0, y), row[0], 11, Ink.CHANCERY, w)
		y += Ink.line_fit(self, at + Vector2(0, y), "    " + row[1], 10, Ink.RUBRIC, w)
		y += 3.0
	y += 6.0
	Ink.rule(self, at + Vector2(0, y), w, Ink.FADED * Color(1, 1, 1, 0.5))
	y += 7.0

	# Worked example, using whichever reign has the widest gap between its
	# epochs, so the arithmetic is never trivial.
	var reign := _widest_gap_reign()
	if reign != null:
		y += Ink.label(self, at + Vector2(0, y), "worked", 8, Ink.FADED)
		y += Ink.block(self, at + Vector2(0, y),
			"The fifth year of %s falls in %d by accession, and in %d by election. "
			% [reign.full_name(),
				RegnalMath.to_absolute(reign, 5, Lex.Dating.ACCESSION),
				RegnalMath.to_absolute(reign, 5, Lex.Dating.ELECTION)]
			+ "Both are true. Neither is the other.",
			10, Ink.CHANCERY, w)
	return y


func _widest_gap_reign() -> Reign:
	var best: Reign = null
	var gap := -1
	for id in Lore.data.reigns:
		var r: Reign = Lore.data.reigns[id]
		var g := r.accession_year - r.election_year
		if g > gap:
			gap = g
			best = r
	return best


func _draw_polity_plate(at: Vector2, w: float, page: BookPage) -> float:
	var p := Lore.polity(page.polity_id)
	if p == null:
		return 0.0
	var y := 0.0
	var r := minf(w * 0.24, 40.0)
	var centre := at + Vector2(w * 0.5, r + 2.0)
	# Shield of the arms.
	var shield := WaxShape.outline(&"shield", hash(String(p.id)), 0.01, 24)
	draw_colored_polygon(WaxShape.scaled(shield, centre, r * 1.25), p.color)
	Heraldry.draw_device(self, p.device, centre, r * 0.72, p.ink())
	y += r * 2.4 + 8.0

	y += Ink.line_fit(self, at + Vector2(0, y), p.name, 12, Ink.CHANCERY, w)
	y += 4.0
	y += Ink.block(self, at + Vector2(0, y), "Succession: " + p.succession, 10,
		Ink.CHANCERY, w)
	y += Ink.line_fit(self, at + Vector2(0, y),
		"Dates " + Lex.dating_name(p.dating_style), 10, Ink.RUBRIC, w)
	if not p.seals_used:
		y += Ink.block(self, at + Vector2(0, y), "Uses no seal.", 10, Ink.RUBRIC, w)
	elif p.matrix_dies_with_holder:
		y += Ink.block(self, at + Vector2(0, y),
			"Matrix broken at the holder's death.", 10, Ink.CHANCERY, w)
	else:
		y += Ink.block(self, at + Vector2(0, y),
			"Seal of the office; the die outlives the man.", 10, Ink.CHANCERY, w)
	y += 5.0
	return y

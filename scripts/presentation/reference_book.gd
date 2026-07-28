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
	_update_hit_size()
	setup(book.start_offset, deg_to_rad(book.start_angle_deg), desk_bounds)


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


func _process(delta: float) -> void:
	super._process(delta)

	# The cover was moving linearly, which is the one thing a hinged board never
	# does. Raw progress is still linear; everything that reads _open_amount now
	# gets it through a curve.
	#
	# ease(x, 0.42) is ease-OUT going forward: the cover swings up off the desk
	# quickly and slows as it lays flat. Run in reverse for closing it becomes
	# ease-in — a slow lean, then it drops shut — which is also what a book does.
	_open_t = move_toward(_open_t, 1.0 if is_open else 0.0, delta * 4.2)
	_open_amount = ease(_open_t, 0.42)
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

func _draw() -> void:
	if data == null:
		return
	var w := data.size.x * (1.0 + _open_amount)
	var full := Rect2(-w * 0.5, -data.size.y * 0.5, w, data.size.y)

	draw_soft_shadow(full)
	draw_rect(full.grow(5.0), data.cover_color.darkened(0.35))
	draw_rect(full.grow(3.0), data.cover_color)

	if _open_amount < 0.02:
		_draw_closed(full)
	else:
		_draw_open(full)
	if review_attention:
		_draw_review_slip(full)


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


func _draw_closed(r: Rect2) -> void:
	# Blind-tooled border and a clasp. Enough to say "book" at a glance from the
	# far side of the desk, buried under a charter.
	draw_rect(r.grow(-14.0), data.cover_color.lightened(0.10), false, 2.0)
	draw_rect(r.grow(-20.0), data.cover_color.darkened(0.25), false, 1.0)

	var at := Vector2(r.position.x + MARGIN, r.position.y + r.size.y * 0.34)
	var w := r.size.x - MARGIN * 2.0
	Ink.line_centre(self, at, data.title.to_upper(), 15,
		data.page_color.lightened(0.2), w)
	Ink.line_centre(self, at + Vector2(0, 26), data.subtitle, 11,
		data.page_color * Color(1, 1, 1, 0.75), w)

	# Clasp on the fore-edge.
	draw_rect(Rect2(r.end.x - 6, r.get_center().y - 22, 14, 44),
		Color(0.72, 0.64, 0.40))
	draw_rect(Rect2(r.end.x - 4, r.get_center().y - 18, 10, 36),
		Color(0.55, 0.48, 0.30))


func _draw_open(r: Rect2) -> void:
	var pw := r.size.x * 0.5
	var left := Rect2(r.position + Vector2(6, 6), Vector2(pw - 9, r.size.y - 12))
	var right := Rect2(Vector2(r.position.x + pw + 3, r.position.y + 6),
		Vector2(pw - 9, r.size.y - 12))

	for pr in [left, right]:
		draw_rect(pr, data.page_color)
		draw_rect(pr, data.page_color.darkened(0.20), false, 1.0)

	# Gutter shadow: pages curve down into the spine.
	for i in 8:
		var t := float(i) / 8.0
		var a := 0.10 * (1.0 - t)
		draw_rect(Rect2(r.position.x + pw - 12.0 * (1.0 - t), r.position.y + 6,
			24.0 * (1.0 - t), r.size.y - 12), Color(0, 0, 0, a))

	if _open_amount < 0.75:
		return  # mid-swing; do not draw text into a half-open book

	_draw_page(left, spread * 2)
	_draw_page(right, spread * 2 + 1)
	_draw_corners(left, right)
	_draw_turning_page(r, pw)


## The turning leaf. A rectangle whose width sweeps across the gutter, drawn over
## whichever page it is covering. Crude, but at the speed it moves it reads.
func _draw_turning_page(r: Rect2, pw: float) -> void:
	if _turn_dir == 0:
		return
	var t := turn_progress()
	var from_x := r.position.x + pw
	var width := pw * (1.0 - absf(2.0 * t - 1.0))
	var x := from_x if _turn_dir > 0 else from_x - width
	if _turn_dir > 0 and t > 0.5:
		x = from_x - width
	elif _turn_dir < 0 and t > 0.5:
		x = from_x
	var leaf := Rect2(x, r.position.y + 6, width, r.size.y - 12)
	draw_rect(leaf, data.page_color.lightened(0.06))
	draw_rect(leaf, data.page_color.darkened(0.28), false, 1.0)
	draw_rect(Rect2(leaf.position, Vector2(minf(10.0, width), leaf.size.y)),
		Color(0, 0, 0, 0.10))


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

func _draw_page(r: Rect2, index: int) -> void:
	if index >= data.pages.size():
		return
	var page: BookPage = data.pages[index]
	var w := r.size.x - MARGIN * 2.0
	var at := r.position + Vector2(MARGIN, MARGIN * 0.9)

	if not page.heading.is_empty():
		at.y += Ink.heading(self, at, page.heading, 13, Ink.CHANCERY, w)
	if not page.subheading.is_empty():
		at.y += Ink.line(self, at, page.subheading, 11, Ink.FADED)
	at.y += 5.0

	match page.kind:
		&"matrix": at.y += _draw_matrix_plate(at, w, page)
		&"reigns": at.y += _draw_reign_table(at, w)
		&"styles": at.y += _draw_style_table(at, w)
		&"plate": at.y += _draw_polity_plate(at, w, page)
		_: pass

	if not page.body.is_empty():
		at.y += Ink.block(self, at, page.body, 11, Ink.CHANCERY, w)

	if not page.marginalia.is_empty():
		var foot := Vector2(r.position.x + MARGIN,
			maxf(at.y + 6.0, r.end.y - MARGIN - 54.0))
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
		return Ink.line(self, at, "[ die not recorded ]", 11, Ink.RUBRIC)
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

	y += Ink.line(self, at + Vector2(0, y), m.owner_name, 12, Ink.CHANCERY)
	var p := Lore.polity(m.polity_id)
	if p != null:
		y += Ink.line(self, at + Vector2(0, y), p.name, 10, Ink.FADED)
	y += 4.0
	y += Ink.label(self, at + Vector2(0, y), "legend", 8, Ink.FADED)
	y += Ink.block(self, at + Vector2(0, y), m.legend, 11, Ink.CHANCERY, w)
	y += 3.0
	y += Ink.line(self, at + Vector2(0, y),
		"%s · %s" % [String(m.shape), Heraldry.display_name(m.device)],
		10, Ink.FADED)
	y += Ink.line(self, at + Vector2(0, y), m.life_text(), 11,
		Ink.RUBRIC if m.broken_year >= 0 else Ink.CHANCERY)
	y += 4.0
	if not m.note.is_empty():
		y += Ink.block(self, at + Vector2(0, y), m.note, 10, Ink.FADED, w)
	return y


func _draw_reign_table(at: Vector2, w: float) -> float:
	var y := 0.0
	y += Ink.line(self, at + Vector2(0, y), "chosen   acceded  crowned  ended",
		9, Ink.FADED)
	y += 3.0
	Ink.rule(self, at + Vector2(0, y), w, Ink.FADED * Color(1, 1, 1, 0.5))
	y += 5.0
	for id in Lore.data.reigns:
		var reign: Reign = Lore.data.reigns[id]
		y += Ink.line(self, at + Vector2(0, y), reign.full_name(), 11, Ink.CHANCERY)
		var ended := str(reign.end_year) if reign.end_year >= 0 else "reigns"
		var row := "  %s     %s     %s     %s" % [
			str(reign.election_year).rpad(7),
			str(reign.accession_year).rpad(7),
			str(reign.coronation_year).rpad(7),
			ended,
		]
		y += Ink.line(self, at + Vector2(0, y), row, 10, Ink.CHANCERY)
		if not reign.epithet.is_empty():
			y += Ink.line(self, at + Vector2(0, y), "  " + reign.epithet, 9, Ink.FADED)
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
		y += Ink.line(self, at + Vector2(0, y), row[0], 11, Ink.CHANCERY)
		y += Ink.line(self, at + Vector2(0, y), "    " + row[1], 10, Ink.RUBRIC)
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

	y += Ink.line(self, at + Vector2(0, y), p.name, 12, Ink.CHANCERY)
	y += 4.0
	y += Ink.line(self, at + Vector2(0, y), "Succession: " + p.succession, 10,
		Ink.CHANCERY)
	y += Ink.line(self, at + Vector2(0, y),
		"Dates " + Lex.dating_name(p.dating_style), 10, Ink.RUBRIC)
	if not p.seals_used:
		y += Ink.line(self, at + Vector2(0, y), "Uses no seal.", 10, Ink.RUBRIC)
	elif p.matrix_dies_with_holder:
		y += Ink.line(self, at + Vector2(0, y),
			"Matrix broken at the holder's death.", 10, Ink.CHANCERY)
	else:
		y += Ink.line(self, at + Vector2(0, y),
			"Seal of the office; the die outlives the man.", 10, Ink.CHANCERY)
	y += 5.0
	return y

class_name CharterView
extends Sheet

## The charter itself: body, date, witness list, and the cord the seal hangs from.
##
## Everything the player needs to rule is on this face, and none of it is
## highlighted. In particular the drawing chancery is buried in the closing
## formula where a real one would be — "Drawn at the chancery of..." — because
## the whole of case three turns on noticing it, and a game that points at the
## clue has not asked a question.

const MARGIN := 26.0

## The rect the rubric date block was last drawn into, in sheet-local space.
## Written by _draw_date; read only by the test that asserts an erasure claiming
## to sit on the year actually does. Empty until the sheet has drawn once.
var date_rect_local := Rect2()
var _lens_fibres: Array[Dictionary] = []
var _lens_ink: Array[Dictionary] = []


func bind(doc: DocumentData, desk_bounds: Rect2) -> void:
	super.bind(doc, desk_bounds)
	_build_lens_microdetail()


func _build_lens_microdetail() -> void:
	_lens_fibres.clear()
	_lens_ink.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(data.id)) if data != null else 1729
	for i in 34:
		_lens_fibres.append({
			"y": rng.randf_range(0.10, 0.82),
			"x": rng.randf_range(0.05, 0.34),
			"length": rng.randf_range(0.28, 0.61),
			"alpha": rng.randf_range(0.025, 0.075),
		})
	for i in 18:
		_lens_ink.append({
			"x": rng.randf_range(0.14, 0.86),
			"y": rng.randf_range(0.31, 0.78),
			"radius": rng.randf_range(0.45, 1.35),
			"alpha": rng.randf_range(0.09, 0.24),
		})


func charter_data() -> CharterData:
	return data as CharterData


## Where the cord is knotted through the foot of the parchment.
func cord_local() -> Vector2:
	return Vector2(-data.size.x * 0.18, data.size.y * 0.5 - 6.0)


func cord_world() -> Vector2:
	return to_global(cord_local())


func _draw_face(r: Rect2) -> void:
	var ch := charter_data()
	if ch == null:
		return
	var w := r.size.x - MARGIN * 2.0
	var at := r.position + Vector2(MARGIN, MARGIN * 0.75)

	at.y += Ink.label(self, at, "charter", 11, Ink.FADED)
	at.y += 2.0
	at.y += Ink.heading(self, at, ch.title, 17, Ink.CHANCERY, w)
	at.y += 6.0

	at.y += Ink.block(self, at, ch.body_text, 14, Ink.CHANCERY, w)
	at.y += 8.0

	at.y += _draw_date(at, w, ch)
	at.y += 10.0

	at.y += _draw_parties(at, w, ch)
	at.y += 8.0

	at.y += _draw_witnesses(at, w, ch)

	_draw_closing(r, ch, at.y)
	_draw_cord()


## The date is set in red, which is what a chancery actually did — and which
## makes it findable in a pile without making it *legible*, since a regnal year
## still has to be reduced before it means anything.
func _draw_date(at: Vector2, w: float, ch: CharterData) -> float:
	var reign := Lore.reign(ch.date_emperor)
	var who := reign.full_name() if reign else String(ch.date_emperor)
	var text := "Given in the %s year of %s." % [
		Lex.ordinal(ch.date_regnal_year), who]
	var h := Ink.block(self, at, text, 16, Ink.RUBRIC, w)
	# WHERE THE DATE ACTUALLY LANDED.
	#
	# Erasure patches are authored as fractions of the sheet, and the date's
	# position depends on how the body text happens to wrap at 14pt — so editing
	# a single word of the arenga silently un-registers the scrape that is
	# supposed to be sitting on the year, and nothing notices. Recording the rect
	# the draw actually used lets a test assert the two agree, which is the only
	# version of that check that cannot itself drift.
	date_rect_local = Rect2(at, Vector2(w, h))
	return h


func _draw_parties(at: Vector2, w: float, ch: CharterData) -> float:
	var y := 0.0
	if not ch.grantor.is_empty():
		y += Ink.line(self, at + Vector2(0, y), "Granted by:  " + ch.grantor, 13,
			Ink.CHANCERY)
	if not ch.claimant.is_empty():
		y += Ink.line(self, at + Vector2(0, y), "To:  " + ch.claimant, 13,
			Ink.CHANCERY)
	if not ch.property.is_empty():
		y += Ink.block(self, at + Vector2(0, y), "Of:  " + ch.property, 13,
			Ink.CHANCERY, w)
	return y


func _draw_witnesses(at: Vector2, w: float, ch: CharterData) -> float:
	if ch.witnesses.is_empty():
		return 0.0
	var y := Ink.label(self, at, "witnesses", 10, Ink.FADED)
	y += 2.0
	for wit in ch.witnesses:
		# The signum crucis a witness actually drew beside his name. A plain '+'
		# rather than a dagger, because the engine's fallback font is not
		# guaranteed to have anything more exotic and a tofu box in a charter
		# would be worse than no mark at all.
		y += Ink.line(self, at + Vector2(8, y), "+  " + wit.display(), 12,
			Ink.CHANCERY, HORIZONTAL_ALIGNMENT_LEFT, w - 8.0)

		# A dead witness is annotated by the chancery, later, in another hand.
		#
		# This has to be ON the parchment. The rules engine already knew these
		# deaths and the ledger already scolded a player for missing one — but
		# the death was rendered nowhere, so "it was there to be found" was a
		# lie, and a lie of exactly the kind this genre cannot survive. It is
		# written in regnal form like every other date, so establishing that a
		# man predeceased his own charter still costs a trip to the Almanac.
		if wit.has_death_record():
			var wr := Lore.reign(wit.died_emperor)
			var note := wit.death_note(wr.full_name() if wr else
				String(wit.died_emperor))
			y += Ink.margin_note(self, at + Vector2(26, y), note, 10,
				w - 26.0, -2.0)
	return y


## Where the closing formula sits, in local space. The lens focuses on this
## rather than on the middle of the sheet, so reading the small hand is a thing
## you do to a specific corner of a specific document.
## Where the lens focuses to read the small hand. Kept at the foot rather than
## tracking the flowed position, because the glass wants a stable target and the
## formula never moves more than a line or two.
func closing_local() -> Vector2:
	return Vector2(-data.size.x * 0.16, data.size.y * 0.5 - MARGIN - 14.0)


func closing_world() -> Vector2:
	return to_global(closing_local())


## Closing formula, pinned to the foot of the sheet. The chancery that drew the
## instrument is named here and nowhere else — and it is written in the smallest
## hand on the page, because that is where a scribe put it and because the whole
## of the third case turns on somebody bothering to read it.
##
## Set deliberately below the threshold of comfortable reading. You can see that
## there is a line of text and you cannot make out which chancery it names. That
## puts the glass on both checks instead of only the seal, and it turns the
## monk's "look at the foot of the page" from a hint into an instruction.
func _draw_closing(r: Rect2, ch: CharterData, flow_y: float) -> void:
	var p := Lore.polity(ch.drawn_by_polity)
	if p == null:
		return
	var w := r.size.x - MARGIN * 2.0
	# Pinned to the foot, but it yields to the body. Hard-pinning collided the
	# moment the witness list grew — and it will grow again, because new cases
	# are written as data and nobody authoring one should have to know how tall
	# this block is.
	var y := maxf(flow_y + 12.0, r.end.y - MARGIN - 26.0)
	y = minf(y, r.end.y - MARGIN - 10.0)
	Ink.block(self, Vector2(r.position.x + MARGIN, y),
		"Drawn at the chancery of %s." % p.name, 7,
		Color(Ink.FADED, 0.62), w, 2)


# ------------------------------------------------------------------- the lens
# Same two-method contract the pendant seal uses, so the glass gained a second
# job without the lens learning anything about charters.

func has_detail() -> bool:
	return data != null


func detail_centre() -> Vector2:
	return closing_world()


func lens_detail_text() -> String:
	var ch := charter_data()
	if ch == null:
		return ""
	var p := Lore.polity(ch.drawn_by_polity)
	return "Drawn at the chancery of %s." % (p.name if p else "—")


## The glass reveals only physical evidence: the closing formula's actual hand,
## ink pooling and parchment fibres. Interpreting the chancery's dating custom
## remains the player's work with the reference books.
func draw_detail(c: CanvasItem, at: Vector2, radius: float) -> void:
	if charter_data() == null:
		return
	var w := radius * 1.62
	var top := at + Vector2(-w * 0.5, -radius * 0.60)

	# Laid lines and short fibres stay fixed per charter. Randomising these in
	# _draw would make the parchment crawl beneath a stationary lens.
	for fibre in _lens_fibres:
		var start := top + Vector2(
			float(fibre.x) * w, float(fibre.y) * radius * 1.16)
		var finish := start + Vector2(float(fibre.length) * w, 0.35)
		c.draw_line(start, finish,
			Color(0.23, 0.14, 0.075, float(fibre.alpha)), 0.65)
	for y in [28.0, 39.0, 50.0, 61.0, 72.0, 83.0, 94.0]:
		c.draw_line(top + Vector2(4.0, y), top + Vector2(w - 3.0, y + 0.8),
			Color(0.42, 0.27, 0.13, 0.035), 0.8)

	# THE WHOLE NAME HAS TO FIT INSIDE A CIRCLE.
	#
	# This laid a flowed block into a fixed rectangle 1.62 radii wide and simply
	# let it run. Nothing clipped it, so the overflow printed across the brass
	# bezel; once the aperture became a real stencil the overflow was cut instead —
	# and the cut fell in the middle of the chancery's name, which is the decisive
	# physical evidence on the whole sheet. Clipping a conclusion out of the
	# player's view is worse than spilling it onto the frame.
	#
	# So the column is sized to the widest chord the text can actually occupy, and
	# the block is measured and centred vertically. A circle of radius r fits a
	# column of half-width x only while |y| <= sqrt(r*r - x*x); at 0.62 radii the
	# corners still have most of the height, which is room enough for the longest
	# polity name in the world file at 13pt.
	var column := radius * 1.24
	var half := column * 0.5
	var body := lens_detail_text()
	var block := Ink.measure(body, 13, column)
	var limit := sqrt(maxf(1.0, pow(radius * 0.965, 2.0) - half * half))
	var text_at := at + Vector2(-half,
		clampf(-block.y * 0.5, -limit, limit - block.y))
	Ink.block(c, text_at, body, 13, Ink.CHANCERY, column)
	# Pooling, feathering and a scribe's terminal flourish make this read as ink
	# on skin rather than a UI label.
	for fleck in _lens_ink:
		c.draw_circle(top + Vector2(
			float(fleck.x) * w, float(fleck.y) * radius * 1.16),
			float(fleck.radius), Color(0.10, 0.065, 0.045, float(fleck.alpha)))
	var flourish_y := text_at.y + 36.0
	c.draw_arc(Vector2(at.x + radius * 0.16, flourish_y), radius * 0.24,
		PI * 0.12, PI * 0.92, 18, Color(Ink.CHANCERY, 0.42), 1.05)
	c.draw_arc(Vector2(at.x + radius * 0.25, flourish_y + 3.0), radius * 0.16,
		PI * 1.05, PI * 1.82, 14, Color(Ink.CHANCERY, 0.28), 0.8)


## The cord: a plaited tag of parchment or silk through the foot of the sheet,
## which the seal hangs from. Drawn here so it stays put when the charter moves;
## the tag itself is a separate object that swings on the end of it.
func _draw_cord() -> void:
	var a := cord_local()
	draw_circle(a, 3.0, Color(0.30, 0.24, 0.18, 0.55))
	draw_circle(a, 1.6, data.tint.darkened(0.5))

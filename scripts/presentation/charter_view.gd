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


## The foot of the page under magnification: which chancery drew it, and what
## that chancery's reckoning does to the date written above. This is the only
## place in the game the two verifications are shown touching each other, and it
## is reached by physically putting a glass on a corner of a document.
func draw_detail(c: CanvasItem, at: Vector2, radius: float) -> void:
	var ch := charter_data()
	if ch == null:
		return
	var p := Lore.polity(ch.drawn_by_polity)
	var reign := Lore.reign(ch.date_emperor)
	var w := radius * 1.62
	var top := at + Vector2(-w * 0.5, -radius * 0.60)

	var y := Ink.label(c, top, "closing formula", 9, Ink.FADED)
	y += 3.0
	y += Ink.block(c, top + Vector2(0, y),
		"Drawn at the chancery of %s." % (p.name if p else "—"), 13,
		Ink.CHANCERY, w)
	y += 6.0

	if p != null:
		y += Ink.block(c, top + Vector2(0, y),
			"That chancery dates its instruments %s."
			% Lex.dating_name(p.dating_style), 11, Ink.RUBRIC, w)
	y += 4.0

	if reign != null and p != null:
		# Reduced the way the drawing chancery meant it, not the way an imperial
		# notary would reach for by habit.
		var year := RegnalMath.to_absolute(reign, ch.date_regnal_year,
			p.dating_style)
		y += Ink.line(c, top + Vector2(0, y), "%s year of %s" % [
			Lex.sentence(Lex.ordinal(ch.date_regnal_year)), reign.full_name()],
			11, Ink.FADED)
		y += Ink.line(c, top + Vector2(0, y),
			"so read:  %d" % year, 13, Ink.CHANCERY)


## The cord: a plaited tag of parchment or silk through the foot of the sheet,
## which the seal hangs from. Drawn here so it stays put when the charter moves;
## the tag itself is a separate object that swings on the end of it.
func _draw_cord() -> void:
	var a := cord_local()
	draw_circle(a, 3.0, Color(0.30, 0.24, 0.18, 0.55))
	draw_circle(a, 1.6, data.tint.darkened(0.5))

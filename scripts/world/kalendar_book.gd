class_name KalendarBook
extends RefCounted

## Build the Kalendar of the Dead as a physical book on the desk.
##
## Generated from data/world/necrology.json rather than authored as a second
## file, for the same reason the Register is generated from the ruling history:
## everything WitnessCheck can say about a man must be readable on the page, and
## two hand-maintained copies of the same rolls would drift apart within a week.
## One source. The book cannot lie about the law because it IS the law's data.
##
## Organised by hand, then by year of death, descending. NOT by calendar day —
## which is how a real necrology is read, and which is unplayable here, because
## no instrument in this game carries a month or a day. A roll keyed on data the
## player cannot obtain from any document is not difficulty, it is a wall.
##
## The lookup verb is therefore: read the man's style off the witness list, decide
## which house would have had him, turn to that hand, and scan its years. No
## index and no search, exactly as the other three books.

## THE SECTION HEAD GETS ITS OWN LEAF.
##
## The first attempt put the coverage statement, the reckoning, the roll's own
## note and then as many names as would fit onto one page — and since the note is
## authored prose of unbounded length, "as many as would fit" is not something a
## builder can know. The fourth name ran off the bottom of the board, which is
## precisely the failure this whole book exists to avoid: an obit WitnessCheck can
## convict on that the player cannot read.
##
## Separating them makes the arithmetic exact. A head leaf holds prose and no
## names; every entry leaf holds the same number. It is also how a bound cartulary
## is actually laid out, which is the usual sign that the mechanical answer and
## the material one agree.
const ENTRIES_PER_PAGE := 6


static func build(necrology: Necrology, lore: LoreData) -> BookData:
	var book := BookData.new()
	book.id = &"kalendar"
	book.title = necrology.title
	book.subtitle = necrology.subtitle
	book.cover_color = necrology.cover_color
	book.page_color = necrology.page_color
	book.size = Vector2(316, 424)

	var pages: Array[BookPage] = []

	var front := BookPage.new()
	front.kind = &"text"
	front.heading = necrology.title
	front.subheading = necrology.subtitle
	front.body = necrology.front_matter
	pages.append(front)

	# A SECOND FRONT LEAF, because the first one did not fit.
	#
	# The front matter was one 680-character block on one board and overran it by
	# 37 px — and nothing in a ReferenceBook clips, so the tail was drawn on the
	# desk underneath the book, unlit. What fell off the end was the paragraph
	# saying that a man absent from a roll is not thereby living, which is the
	# single most important sentence in this book and the entire reason the
	# subsystem is built the way it is.
	#
	# It now has a leaf of its own, with R.V.'s note under it, which is better
	# bookmaking than a fix — the covering rule deserves to be the thing a reader
	# turns to rather than the thing crushed against the foot of a page.
	if not necrology.front_matter_two.is_empty():
		var covering := BookPage.new()
		covering.kind = &"text"
		covering.heading = "What a roll undertakes"
		covering.body = necrology.front_matter_two
		covering.marginalia = necrology.marginalia
		pages.append(covering)
	else:
		front.marginalia = necrology.marginalia

	# A ROLL LONGER THAN A PAGE IS SPLIT ACROSS PAGES.
	#
	# The first draft of this put each house on exactly one page, which is fine
	# for four names and silently drops the fifth off the bottom for eight — and
	# an obit that cannot be read is an obit WitnessCheck can convict on and the
	# player cannot check, which is the one contract this genre may not break.
	#
	# The break is a real one, so the front matter of a continued section says so
	# and the continuation is headed the way a bound book heads a continuation.
	for roll in necrology.rolls:
		# The head leaf: who returned this, whose dead it covers, in what
		# reckoning, and how far it is written up. Every finding of the form "this
		# man cannot be looked up" rests on those four facts, so they get a page.
		var head := BookPage.new()
		head.kind = &"obits"
		head.roll_id = roll.id
		head.heading = roll.hand
		head.subheading = roll.covers
		head.body = roll.note
		head.marginalia = roll.marginalia
		head.entry_from = 0
		head.entry_count = 0
		pages.append(head)

		var cursor := 0
		while cursor < roll.entries.size():
			var p := BookPage.new()
			p.kind = &"obits"
			p.roll_id = roll.id
			p.heading = roll.hand
			p.subheading = "the roll itself" if cursor == 0 else "continued"
			p.entry_from = cursor
			p.entry_count = ENTRIES_PER_PAGE
			pages.append(p)
			cursor += ENTRIES_PER_PAGE

	# The three houses that return nothing are printed on the reverse of the
	# retained chapel extract, after the names the Chancery actually received.
	var silence := BookPage.new()
	silence.kind = &"silence"
	silence.heading = "Houses that return nothing"
	silence.body = "A name that is not here is a name nobody has sent us, and that is all it is."
	pages.append(silence)

	# Pages are shown two at a time and a lone page on the right of the last
	# spread reads as a printing error rather than as the end of the book.
	if pages.size() % 2 == 1:
		var blank := BookPage.new()
		blank.kind = &"text"
		blank.body = ""
		pages.append(blank)

	book.pages = pages
	return book

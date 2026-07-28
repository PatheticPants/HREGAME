class_name RegisterBook
extends RefCounted

## Builds the Register into a physical reference book.
##
## WHY THIS EXISTS
## ---------------
## The Register is meant to be the third source of law, alongside imperial
## statute and regional custom — the campaign's whole premise is that a
## petitioner can quote your own precedent back at you and be right to. The
## seeded entries already carried that weight: `prior_lenz` records the previous
## notary referring a contested reckoning upward and being right.
##
## But it was only ever printed in the end-of-day ledger, after every ruling had
## been made. The single piece of evidence that settles the third case arrived
## strictly too late to help with it. That is not a hard puzzle, it is a missing
## reference — so the Register goes on the desk with the other two books.
##
## It rebuilds after every ruling, which means the day's own entries appear in it
## as they happen, and the monk who quotes your ruling on the widow is quoting
## something the player can physically open and read.

const COVER := Color(0.30, 0.20, 0.26)
const PAGE := Color(0.88, 0.85, 0.76)


static func build(register: Register, lore: LoreData) -> BookData:
	var book := BookData.new()
	book.id = &"register"
	book.title = "The Register"
	book.subtitle = "rulings of this desk"
	book.cover_color = COVER
	book.page_color = PAGE
	book.size = Vector2(320, 430)

	var pages: Array[BookPage] = []
	pages.append(_front_matter(lore))

	# The previous occupant's entries first, then the day's own, in the order
	# they were made — which is how a bound register actually reads.
	var foreign: Array[RulingRecord] = []
	var own: Array[RulingRecord] = []
	for e in register.entries:
		if e.foreign_hand:
			foreign.append(e)
		else:
			own.append(e)

	for e in foreign:
		pages.append(_entry_page(e, lore, false))
	if not own.is_empty():
		var last_day: StringName = &"__none__"
		for i in own.size():
			if own[i].day_id != last_day:
				pages.append(_day_divider(own[i].day_id, lore))
				last_day = own[i].day_id
			pages.append(_entry_page(own[i], lore, i + 1 < own.size()))
	else:
		pages.append(_blank_page())

	book.pages = pages
	return book


static func _front_matter(lore: LoreData) -> BookPage:
	var p := BookPage.new()
	p.kind = &"text"
	p.heading = "The Register"
	p.subheading = "third desk, second floor"
	p.body = "What this office has already decided.\n\n" \
		+ "It is not law. It is what the last man at this desk did when the law " \
		+ "did not say, and what you did after him. A party who has read it will " \
		+ "quote it at you, and will sometimes be right to."
	p.marginalia = "Kept because the Chancery forgets and the parties do not. — R.V."
	return p


static func _day_divider(day_id: StringName, lore: LoreData) -> BookPage:
	var p := BookPage.new()
	p.kind = &"text"
	var day := lore.day_by_id(day_id)
	if day != null:
		p.heading = day.entry_label
		p.body = day.heading + "\n\nEntered as they were ruled."
	else:
		p.heading = "This day"
		p.body = "Entered as they were ruled."
	return p


static func _blank_page() -> BookPage:
	var p := BookPage.new()
	p.kind = &"text"
	p.heading = "This day"
	p.body = "Nothing entered yet."
	return p


static func _entry_page(e: RulingRecord, lore: LoreData, reviewed: bool) -> BookPage:
	var p := BookPage.new()
	p.kind = &"text"
	p.heading = e.case_title
	p.subheading = e.petitioner_name
	var lines := PackedStringArray()
	lines.append("Ruled:  %s" % Lex.verdict_name(e.verdict).to_upper())
	if not e.register_note.is_empty():
		lines.append("")
		lines.append(e.register_note)
	if not e.authority_verdicts.is_empty():
		lines.append("")
		lines.append("Positions recorded:")
		var authorities: Array[int] = []
		for authority in e.authority_verdicts:
			authorities.append(authority)
		authorities.sort()
		for authority in authorities:
			lines.append("%s %s the claim." % [
				Lex.sentence(Lex.authority_name(authority)),
				_verdict_verb(e.authority_verdicts[authority]),
			])
	p.body = "\n".join(lines)
	# The previous notary's entries are in his hand; the player's are in theirs.
	if e.foreign_hand:
		p.marginalia = "— %s" % e.hand_name
	elif reviewed and not e.was_sound:
		if not e.review_headline.is_empty():
			p.marginalia = "Reviewed after the next call: %s — %s" % [
				e.review_headline, e.review_detail]
		else:
			# Compatibility for old/static records written before review evidence
			# was captured at judgment.
			var c := lore.case_by_id(e.case_id)
			if c == null or c.dynamic_precedent:
				return p
			var check := Adjudicator.adjudicate_case(c, lore, null)
			for hint in check.hints():
				if e.finding_codes.has(hint.code):
					p.marginalia = "Reviewed after the next call: %s — %s" % [
						hint.headline, hint.detail]
					break
	return p


static func _verdict_verb(verdict: int) -> String:
	match verdict:
		Lex.Verdict.CONFIRM: return "admitted"
		Lex.Verdict.DENY: return "refused"
		Lex.Verdict.REFER: return "left unresolved"
		_: return "did not rule on"

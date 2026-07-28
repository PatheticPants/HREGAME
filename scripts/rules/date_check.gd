class_name DateCheck
extends Check

## Reduce the charter's regnal date to a year and test it against the packet.
##
## This check reads the date the way the chancery that drew it meant it — using
## that chancery's own reckoning. Whether some *other* authority would read it
## differently is deliberately not this check's business; that belongs to
## AuthorityCheck, and keeping them apart is what stops "the date is wrong" and
## "two laws disagree about the date" from collapsing into the same verdict.

func id() -> StringName:
	return &"date"


func label() -> String:
	return "Date"


func run(ctx: CheckContext) -> Array[Finding]:
	var out: Array[Finding] = []
	var ch := ctx.charter()
	if ch == null:
		return out

	var reign := ctx.reign(ch.date_emperor)
	if reign == null:
		out.append(Finding.make(&"emperor_unknown", Lex.Severity.DEFECT,
			"No such reign is tabled",
			"The Almanac holds no emperor answering to that name. A date that "
			+ "cannot be reduced is not a date.", ch.id))
		return out

	var style := ctx.chancery_style(ch)
	if not RegnalMath.style_applies(reign, style):
		out.append(Finding.make(&"style_inapplicable", Lex.Severity.DEFECT,
			"The reckoning cannot be applied",
			"This chancery dates %s, and no such year is recorded for %s."
			% [Lex.dating_name(style), reign.full_name()], ch.id))
		return out

	if ch.date_regnal_year < 1:
		out.append(Finding.make(&"date_absurd", Lex.Severity.DEFECT,
			"The year is not a year",
			"A regnal year begins at one.", ch.id))
		return out

	var year := RegnalMath.to_absolute(reign, ch.date_regnal_year, style)
	var limit := RegnalMath.max_regnal_year(reign, style, ctx.present_year)

	if year > ctx.present_year:
		out.append(Finding.make(&"date_in_future", Lex.Severity.DEFECT,
			"The charter is not yet written",
			"Read %s, the instrument falls in %d. We stand in %d."
			% [Lex.dating_name(style), year, ctx.present_year], ch.id))
	elif ch.date_regnal_year > limit:
		out.append(Finding.make(&"date_beyond_reign", Lex.Severity.DEFECT,
			"The reign did not last so long",
			"%s reigned %d year%s %s. The instrument claims his %s.\n%s"
			% [reign.full_name(), limit, "" if limit == 1 else "s",
				Lex.dating_name(style), Lex.ordinal(ch.date_regnal_year),
				RegnalMath.describe(reign, ch.date_regnal_year, style)], ch.id))

	out.append_array(_witness_findings(ctx, ch, year))

	# A chancery that does not count from accession is the single most missable
	# fact on the parchment, so it is always surfaced as a hint.
	if style != Lex.Dating.ACCESSION:
		var p := ctx.polity(ch.drawn_by_polity)
		out.append(Finding.hint(&"unusual_reckoning",
			"This chancery does not count from accession",
			"%s dates its instruments %s. Read that way the charter falls in %d; "
			% [p.name if p else "The drawing chancery", Lex.dating_name(style), year]
			+ "read as an imperial notary would read it, it falls in %d."
			% RegnalMath.to_absolute(reign, ch.date_regnal_year, Lex.Dating.ACCESSION),
			ch.id))

	# "The date reduces cleanly" was being suppressed by the presence of any HINT,
	# because hints live in the same array. That silenced the CLEAN finding on
	# exactly the two cases where the arithmetic is the interesting part. Guard
	# on whether anything is actually WRONG, not on whether anything was said.
	var flawed := false
	for f in out:
		if f.severity >= Lex.Severity.DEFECT:
			flawed = true
			break
	if not flawed:
		out.append(Finding.make(&"date_sound", Lex.Severity.CLEAN,
			"The date reduces cleanly",
			RegnalMath.describe(reign, ch.date_regnal_year, style), ch.id))
	return out


## The one cross-fact test in this slice: a man cannot witness a document dated
## after his own death. The fuller witness check — imprisonments, absences,
## men who were demonstrably three duchies away — is later work, and lands as an
## additional Check rather than a change here.
func _witness_findings(ctx: CheckContext, ch: CharterData, year: int) -> Array[Finding]:
	var out: Array[Finding] = []
	for w in ch.witnesses:
		if not w.has_death_record():
			continue
		var wr := ctx.reign(w.died_emperor)
		if wr == null:
			continue
		var died := RegnalMath.to_absolute(wr, w.died_regnal_year, w.died_dating_style)
		if died < year:
			out.append(Finding.make(&"witness_dead", Lex.Severity.DEFECT,
				"A dead man has witnessed",
				"%s is recorded dead in %d. The instrument is dated %d."
				% [w.display(), died, year], ch.id))
		elif died == year:
			out.append(Finding.hint(&"witness_died_that_year",
				"A witness died that same year",
				"%s died in %d, the very year of the grant. Not impossible. "
				% [w.display(), died] + "Worth a second look at the month, if we had one.",
				ch.id))
	return out

class_name ErasureCheck
extends Check

## Has this instrument been altered since it was sealed?
##
## Every other check in the project reads what the parchment says. Seal, date,
## authority, witnesses — all of them take the writing at face value and ask
## whether the world agrees with it. That leaves one whole class of forgery
## untouched, and it happens to be the class that was actually common: not a
## fabricated charter but a GENUINE one improved after the fact. Scrape the year
## off with a knife, write a better one, and every check the game had passed.
##
## The seal is real. The die was alive. The witnesses were in the room. The hand
## is right for the decade. And the instrument is false.
##
## WHY THIS IS A DEFECT AND NOT A LIE ABOUT THE FACTS
## --------------------------------------------------
## The finding is about the ALTERATION, not about whether the new reading is
## plausible. A forger who scrapes a year and writes a perfectly possible one has
## still destroyed the instrument's authority, because an instrument's authority
## is that it is the thing that was sealed. This is the only check here that
## convicts on the document's history rather than on its contents, and it is why
## it belongs beside SealCheck rather than inside DateCheck.
##
## AND WHY AN ERASURE IS NOT AUTOMATICALLY A CRIME
## -----------------------------------------------
## Scribes correct themselves. A rule that convicted on the mere presence of a
## scrape would convict most genuine charters in Europe, and it would teach the
## exact reflex the first case exists to unteach. An honest correction is a NOTE
## and says so plainly. The distinction is drawn where a chancery drew it: on
## whether the altered words are ones the instrument's force depends on.

func id() -> StringName:
	return &"erasure"


func label() -> String:
	return "The skin"


func run(ctx: CheckContext) -> Array[Finding]:
	var out: Array[Finding] = []
	var ch := ctx.charter()
	if ch == null or ch.erasures.is_empty():
		return out

	for e in ch.erasures:
		if e.innocent or not e.dispositive:
			out.append(Finding.hint(&"erasure_innocent",
				"The skin has been scraped and written over",
				"%s has been taken out and set down again. A scribe correcting "
				% _field(e)
				+ "himself before the wax went on, which is ordinary and which "
				+ "the chancery would have done openly.%s"
				% ("" if e.note.is_empty() else "\n" + e.note), ch.id))
			continue

		if e.original_value.is_empty():
			# Nothing came back under the light. Worse than knowing, not better:
			# the office cannot say what the instrument granted, so it cannot say
			# the instrument grants anything.
			out.append(Finding.make(&"erasure_illegible", Lex.Severity.DEFECT,
				"Scraped, and nothing under it",
				"%s stands on a patch of skin taken down to the nap. Whatever "
				% _field(e)
				+ "was written there first is gone, and an instrument that "
				+ "cannot be read as it was sealed cannot be admitted as it "
				+ "stands.", ch.id))
			continue

		# NOTHING HERE MAY ASSERT A FACT THIS CHECK HAS NOT ESTABLISHED.
		#
		# The first version of this sentence read "the wax is the Margrave's, the
		# die was alive, and the witnesses were in the room" — which is true of
		# the one case it was written against and false the moment somebody
		# authors a scraped charter whose seal is also bad. A check that narrates
		# the findings of other checks will eventually narrate them wrongly, and
		# the ledger is the only authoritative voice the player has.
		#
		# The point this finding actually owns is general and needs no help: an
		# instrument's authority is that it is the thing that was sealed.
		out.append(Finding.make(&"erasure_dispositive", Lex.Severity.FATAL,
			"This has been altered since it was sealed",
			"%s has been scraped away and written over. Against the light it "
			% _field(e)
			+ "reads %s.\nWhatever else is sound here, this is not the "
			% e.original_value
			+ "instrument the wax was set on, and the office cannot admit one "
			+ "document in place of another.", ch.id))
	return out


func _field(e: Erasure) -> String:
	return e.altered_field if not e.altered_field.is_empty() else "A clause"

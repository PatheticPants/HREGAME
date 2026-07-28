class_name WitnessCheck
extends Check

## Test the witness list against the rolls of the dead.
##
## THE HOLE THIS CLOSES
## --------------------
## A dead man cannot witness a charter. That test used to live in DateCheck and
## read the death straight off the charter's own witness entry — so the single
## document under suspicion was also the only source for the fact that would have
## condemned it. A forger who declined to write "obiit" defeated the entire check
## by omission, and the game shipped with the hole live: Eckhard von Melle carries
## a death annotation on the Grellwater charter and none at all on the second
## Thurn lion. Same man, same office, two different truths, depending on which
## piece of parchment you happened to be holding.
##
## Death now comes from the Kalendar of the Dead — extracts returned to this
## Chancery by the houses that keep obit rolls. The forger never had it.
##
## WHY THIS IS STILL A JUDGEMENT AND NOT A LOOKUP
## ----------------------------------------------
## A complete imperial register of the dead would be an oracle, and an oracle
## would end the game. Every roll is partial in three ways at once: it covers one
## house, it is written up only so far, and it reckons in its own house's style.
## Three of the seven polities return nothing at all.
##
## So the rule this check obeys above all others is:
##
##     ABSENCE FROM THE ROLLS IS NEVER EVIDENCE OF LIFE.
##
## Silence produces a CLEAN or a NOTE that says out loud what it does not know,
## and it never, under any circumstance, produces a defect. The player is told
## which roll was consulted and where its knowledge stops, so a witness list that
## cannot be verified is a fact about the archive rather than a fact about the
## man — and the decision of what to do about that stays with the notary.
##
## THE ONE THING THE PARCHMENT IS STILL GOOD FOR
## ---------------------------------------------
## Witness.died_* survives, demoted to the parchment's CLAIM. A restoration
## copied from a genuine exemplar carries the exemplar's annotations, so an
## annotation that DISAGREES with the roll is itself a finding — which closes the
## hole from the other side, against a forger who annotates falsely rather than
## one who annotates not at all.

func id() -> StringName:
	return &"witness"


func label() -> String:
	return "Witnesses"


func run(ctx: CheckContext) -> Array[Finding]:
	var out: Array[Finding] = []
	var ch := ctx.charter()
	if ch == null or ch.witnesses.is_empty():
		return out
	var necrology := ctx.necrology
	if necrology == null:
		return out

	# Witness arithmetic against a date that will not reduce is noise. DateCheck
	# has already said the useful thing in that case; adding "and also six men
	# may or may not have been alive in a year that does not exist" helps nobody.
	var reign := ctx.reign(ch.date_emperor)
	if reign == null:
		return out
	var style := ctx.chancery_style(ch)
	if not RegnalMath.style_applies(reign, style) or ch.date_regnal_year < 1:
		return out
	var year := RegnalMath.to_absolute(reign, ch.date_regnal_year, style)

	var dead := 0
	var unverifiable := PackedStringArray()
	var silent := PackedStringArray()
	var reasons := PackedStringArray()
	var seen_reasons := {}

	for w in ch.witnesses:
		var rolls := necrology.rolls_covering(w.house)
		var found: Obit = null
		var found_in: ObitRoll = null
		for r in rolls:
			var o := r.find(w.person_id)
			if o != null:
				found = o
				found_in = r
				break

		if found != null:
			var died := _obit_year(ctx, found, found_in)
			if died == UNRESOLVED:
				continue
			if died < year:
				dead += 1
				out.append(Finding.make(&"witness_dead", Lex.Severity.DEFECT,
					"A dead man has witnessed",
					"%s is entered in %s as dead in %d. The instrument is dated %d."
					% [w.display(), found_in.hand, died, year], ch.id))
			elif died == year:
				out.append(Finding.hint(&"witness_died_that_year",
					"A witness died that same year",
					"%s died in %d, the very year of the grant. Not impossible. "
					% [w.display(), died]
					+ "Worth a second look at the month, if we had one.", ch.id))
			else:
				out.append(Finding.make(&"witness_alive_by_roll",
					Lex.Severity.CLEAN, "The roll has him living",
					"%s is entered in %s under %d, which is after this grant."
					% [w.display(), found_in.hand, died], ch.id))
			out.append_array(_annotation_findings(ctx, ch, w, found, found_in, died))
			continue

		# Not found. Everything below this line is about what we do not know, and
		# none of it may ever be worth more than a NOTE.
		var covering := _covering_roll(ctx, rolls, year)
		if covering != null:
			silent.append(w.display())
			continue
		unverifiable.append(w.display())
		var reason := _why_uncovered(ctx, necrology, w, rolls, year)
		if not reason.is_empty() and not seen_reasons.has(reason):
			seen_reasons[reason] = true
			reasons.append(reason)

	# TWO DEAD MEN IS NOT A COPYIST'S SLIP.
	#
	# One stale name on a witness list is ordinary — lists were copied forward
	# from exemplars for decades, and the whole lesson of the first case is that
	# an anomaly is not a crime. Two is a list somebody assembled out of a book
	# rather than out of a room, and it is a rule the player can state in one
	# sentence after seeing it once.
	if dead >= 2:
		out.append(Finding.make(&"witness_list_impossible", Lex.Severity.FATAL,
			"This list was never in one room",
			"%d of these men were already dead when the instrument is dated. "
			% dead + "One is a copyist. This is a fabrication.", ch.id))

	if not unverifiable.is_empty():
		out.append(Finding.hint(&"necrology_incomplete",
			"These names cannot be looked up",
			"%s. %s" % [_name_list(unverifiable), " ".join(reasons)], ch.id))

	if not silent.is_empty():
		out.append(Finding.make(&"witness_roll_silent", Lex.Severity.CLEAN,
			"The rolls do not name them",
			"%s. The roll is silent, which is not the same as saying he lived."
			% _name_list(silent), ch.id))
	return out


const UNRESOLVED := -99999


## Reduce an obit under ITS OWN ROLL'S reckoning. The Saint Wend chapter counts
## from election like the rest of the Church, so reading its roll as an imperial
## notary would gets a number three years wrong — which is a trap the roll itself
## warns about on its own front page, and therefore fair.
func _obit_year(ctx: CheckContext, o: Obit, roll: ObitRoll) -> int:
	var r := ctx.reign(o.died_emperor)
	if r == null or not RegnalMath.style_applies(r, roll.reckoning):
		return UNRESOLVED
	return RegnalMath.to_absolute(r, o.died_regnal_year, roll.reckoning)


## The roll's own knowledge has an edge, and the edge is the whole point. A roll
## written up only to 1219 cannot speak about a charter of 1221 — its silence
## about a man means nothing at all, and saying so is what stops this check from
## becoming an oracle.
func _covering_roll(ctx: CheckContext, rolls: Array[ObitRoll],
		year: int) -> ObitRoll:
	for r in rolls:
		var reign := ctx.reign(r.written_up_to_emperor)
		if reign == null:
			continue
		var edge := RegnalMath.to_absolute(reign, r.written_up_to_regnal_year,
			r.reckoning)
		if edge >= year:
			return r
	return null


func _why_uncovered(ctx: CheckContext, necrology: Necrology, w: Witness,
		rolls: Array[ObitRoll], year: int) -> String:
	if w.house == &"":
		return "The instrument gives them no house, and a man with no house is in nobody's roll."
	var silence := necrology.silence_for(w.house)
	if not silence.is_empty():
		return silence
	if rolls.is_empty():
		var p := ctx.polity(w.house)
		return "Nothing has ever been returned to us from %s." \
			% (p.name if p != null else "that house")
	# A roll exists and simply stops short of the year in question.
	var best: ObitRoll = rolls[0]
	var reign := ctx.reign(best.written_up_to_emperor)
	if reign == null:
		return "%s has not said how far its roll is written up." % best.hand
	var edge := RegnalMath.to_absolute(reign, best.written_up_to_regnal_year,
		best.reckoning)
	return "%s is written up to %d, and this instrument is dated %d." \
		% [best.hand, edge, year]


## The annotation on the parchment, cross-examined against the roll.
##
## This is the other half of the hole. Removing the parchment as a SOURCE stops a
## forger defeating the check by leaving the obiit off; comparing it against the
## roll stops a forger defeating it by writing an obiit that suits him.
func _annotation_findings(ctx: CheckContext, ch: CharterData, w: Witness,
		o: Obit, roll: ObitRoll, roll_year: int) -> Array[Finding]:
	var out: Array[Finding] = []
	if not w.has_death_record() or roll_year == UNRESOLVED:
		return out
	var r := ctx.reign(w.died_emperor)
	if r == null or not RegnalMath.style_applies(r, w.died_dating_style):
		return out
	var claimed := RegnalMath.to_absolute(r, w.died_regnal_year,
		w.died_dating_style)
	if claimed == roll_year:
		return out
	out.append(Finding.make(&"annotation_disagrees", Lex.Severity.DEFECT,
		"The hand that annotated this did not have the roll",
		"A later hand on the parchment puts %s dead in %d. %s has him in %d."
		% [o.display(), claimed, roll.hand, roll_year], ch.id))
	return out


func _name_list(names: PackedStringArray) -> String:
	if names.size() < 2:
		return names[0] if not names.is_empty() else ""
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]

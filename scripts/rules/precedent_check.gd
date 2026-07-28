class_name PrecedentCheck
extends Check

## The Register is not a fourth sovereign law. It is the office's memory, and a
## party can fairly demand that the desk account for a position it already took.
## This check turns that memory into findings using stable subject/claimant ids.


func id() -> StringName:
	return &"precedent"


func label() -> String:
	return "Precedent"


func run(ctx: CheckContext) -> Array[Finding]:
	var out: Array[Finding] = []
	var ch := ctx.charter()
	if ch == null or ctx.register == null or ch.subject_id == &"":
		return out
	var prior := ctx.register.latest_for_subject(ch.subject_id)
	if prior == null:
		return out

	var same_claimant := prior.claimant_id != &"" \
		and prior.claimant_id == ch.claimant_id
	if same_claimant:
		return _same_claimant(ch, prior, ctx)
	return _competing_claimant(ch, prior, ctx)


func _same_claimant(ch: CharterData, prior: RulingRecord,
		ctx: CheckContext) -> Array[Finding]:
	var out: Array[Finding] = []
	if prior.verdict == Lex.Verdict.CONFIRM:
		out.append(Finding.make(&"title_previously_admitted", Lex.Severity.NOTE,
			"This office has admitted the same title",
			"The Register records %s as confirmed for the same claimant."
			% prior.case_title, ch.id))
		return out

	if ch.supersedes_prior_instrument:
		out.append(Finding.make(&"instrument_cures_prior", Lex.Severity.NOTE,
			"A new instrument answers the old objection",
			"The earlier packet was %s. This instrument was issued afterward "
			% Lex.verdict_name(prior.verdict).to_lower()
			+ "to cure that evidentiary problem; it must stand on its own.",
			ch.id))
		return out

	var positions := {
		Lex.Authority.OFFICE: prior.verdict,
		_drawing_authority(ch, ctx): Lex.Verdict.CONFIRM,
	}
	return _contest_if_split(ch, prior, positions,
		"The claimant returns on the same title without curing the earlier packet.")


func _competing_claimant(ch: CharterData, prior: RulingRecord,
		ctx: CheckContext) -> Array[Finding]:
	# A prior authority split survives a change of claimant, but its substantive
	# positions invert: admitting A is a reason to refuse B, and vice versa.
	if not prior.authority_verdicts.is_empty():
		var inverted := {}
		for authority in prior.authority_verdicts:
			inverted[authority] = _invert(prior.authority_verdicts[authority])
		inverted[Lex.Authority.OFFICE] = _invert(prior.verdict)
		inverted[_drawing_authority(ch, ctx)] = Lex.Verdict.CONFIRM
		return _contest_if_split(ch, prior, inverted,
			"The new claimant asks the desk to undo a title whose competing "
			+ "authority positions are already written in the Register.")

	if prior.verdict == Lex.Verdict.DENY:
		return []  # no recognized competing title remains

	var positions := {
		Lex.Authority.OFFICE: _invert(prior.verdict),
		_drawing_authority(ch, ctx): Lex.Verdict.CONFIRM,
	}
	return _contest_if_split(ch, prior, positions,
		"The instrument is clean, but the Register already took a position on "
		+ "the same property for another claimant.")


func _contest_if_split(ch: CharterData, prior: RulingRecord,
		positions: Dictionary, explanation: String) -> Array[Finding]:
	var out: Array[Finding] = []
	positions.erase(Lex.Authority.NONE)
	var distinct := {}
	for chosen in positions.values():
		distinct[chosen] = true
	if distinct.size() < 2:
		out.append(Finding.make(&"precedent_consistent", Lex.Severity.NOTE,
			"The new packet agrees with the Register",
			"The position entered for %s and the present instrument point the "
			% prior.case_title + "same way.", ch.id))
		return out

	var f := Finding.make(&"precedent_contested", Lex.Severity.CONTESTED,
		"The desk is asked to contradict its own hand",
		explanation + "\n\nEarlier entry: %s — %s."
		% [prior.case_title, Lex.verdict_name(prior.verdict).to_upper()], ch.id)
	f.authority_verdicts = positions
	out.append(f)
	out.append(Finding.hint(&"consult_register",
		"The earlier position is in the Register",
		"Turn to %s. The book records both the ruling and every authority "
		% prior.case_title + "position this desk will now be asked to own.", ch.id))
	return out


func _drawing_authority(ch: CharterData, ctx: CheckContext) -> int:
	var polity := ctx.polity(ch.drawn_by_polity)
	return polity.authority if polity != null else Lex.Authority.IMPERIAL


func _invert(verdict: int) -> int:
	match verdict:
		Lex.Verdict.CONFIRM: return Lex.Verdict.DENY
		Lex.Verdict.DENY: return Lex.Verdict.CONFIRM
		_: return verdict

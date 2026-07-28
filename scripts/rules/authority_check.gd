class_name AuthorityCheck
extends Check

## Ask each body of law, separately, what it makes of the same date.
##
## This is the check the whole game is about. Imperial law counts an emperor's
## years from his accession; the Church counts from his election, which happened
## while his predecessor still lived. Both are correct. Both are ancient. They do
## not produce the same number, and a charter can therefore be impossible and
## unremarkable at once, depending on who is reading it.
##
## When the authorities split, each substantive ruling says whose law governs.
## The office's standing procedure is to Refer, but Confirm and Deny remain
## legally defensible when a named authority sustains them. That is why
## CONTESTED is its own severity and not a defect.


func id() -> StringName:
	return &"authority"


func label() -> String:
	return "Authority"


func run(ctx: CheckContext) -> Array[Finding]:
	var out: Array[Finding] = []
	var ch := ctx.charter()
	if ch == null:
		return out
	var reign := ctx.reign(ch.date_emperor)
	if reign == null:
		return out

	var chancery := ctx.chancery_style(ch)
	var authorities := [Lex.Authority.IMPERIAL, Lex.Authority.CHURCH]
	var polity := ctx.polity(ch.drawn_by_polity)
	if polity != null and polity.authority == Lex.Authority.CUSTOM:
		authorities.append(Lex.Authority.CUSTOM)
	var verdicts := {}
	var years := {}
	var styles := {}

	for a in authorities:
		var style := RegnalMath.style_for_authority(a, chancery)
		if not RegnalMath.style_applies(reign, style):
			continue  # that authority has no opinion it can express here
		styles[a] = style
		years[a] = RegnalMath.to_absolute(reign, ch.date_regnal_year, style)
		var ok := RegnalMath.is_admissible(reign, ch.date_regnal_year, style, ctx.present_year)
		verdicts[a] = Lex.Verdict.CONFIRM if ok else Lex.Verdict.DENY

	if verdicts.size() < 2:
		return out

	var distinct := {}
	for a in verdicts:
		distinct[verdicts[a]] = true
	if distinct.size() < 2:
		return out  # everyone agrees; nothing to refer

	var f := Finding.make(&"reckoning_contested", Lex.Severity.CONTESTED,
		"Two reckonings, two charters",
		_explain(reign, ch, verdicts, years, styles, authorities), ch.id)
	f.authority_verdicts = verdicts
	out.append(f)

	out.append(Finding.hint(&"which_authority",
		"Whose law governs?",
		"Confirmation adopts the Church's reckoning; denial adopts the "
		+ "Empire's. Referral follows the office's procedure without choosing.",
		ch.id))
	return out


func _explain(reign: Reign, ch: CharterData, verdicts: Dictionary,
		years: Dictionary, styles: Dictionary, authorities: Array) -> String:
	var lines := PackedStringArray()
	lines.append("The instrument is dated the %s year of %s."
		% [Lex.ordinal(ch.date_regnal_year), reign.full_name()])
	lines.append("")
	for a in authorities:
		if not verdicts.has(a):
			continue
		var verb := "admits it" if verdicts[a] == Lex.Verdict.CONFIRM else "cannot admit it"
		lines.append("  %s %s  ->  %d,  %s" % [
			Lex.sentence(Lex.authority_name(a)).rpad(16),
			Lex.dating_name(styles[a]).rpad(17),
			years[a],
			verb,
		])
	lines.append("")
	lines.append("%s was chosen King of the Romans in %d and did not accede "
		% [reign.full_name(), reign.election_year]
		+ "until %d. The %d years between are years the Church counts and the "
		% [reign.accession_year, reign.accession_year - reign.election_year]
		+ "Chancery does not.")
	return "\n".join(lines)

class_name SealCheck
extends Check

## Compare the wax hanging off the charter against the Book of Matrices.
##
## The question is never "does this look right". It is: *could any die that
## existed on the day this charter was dated have produced this impression?*
## That phrasing is what ties the two verifications together — you cannot answer
## it without first converting the date, and you cannot trust the date without
## knowing the seal is real. Neither check is soluble alone, which is the whole
## reason there are two of them.

const WILDCARDS := "·.?*_"

## Per-channel tolerance when comparing wax colour. Wax varies batch to batch;
## a whole shade off is another matter.
const COLOR_TOLERANCE := 0.17

## Below this, wear is not worth remarking on.
const WEAR_NOTICEABLE := 0.14


func id() -> StringName:
	return &"seal"


func label() -> String:
	return "Seal"


func run(ctx: CheckContext) -> Array[Finding]:
	var out: Array[Finding] = []
	var ch := ctx.charter()
	if ch == null:
		return out
	for seal in ch.attached_seals():
		out.append_array(_run_seal(ctx, ch, seal))
	return out


func _run_seal(ctx: CheckContext, ch: CharterData,
		seal: SealImpression) -> Array[Finding]:
	var out: Array[Finding] = []
	# A polity that keeps no seals cannot have sealed anything. A rule made
	# entirely of absence, and the easiest one in the game to walk straight past.
	var claimed := ctx.polity(seal.claims_polity)
	if claimed != null and not claimed.seals_used:
		out.append(Finding.make(&"seal_where_none_used", Lex.Severity.FATAL,
			"A seal where none is used",
			"%s keeps no matrices. Its people witness by oath and by named men. "
			% claimed.name + "Wax on a %s instrument is wax somebody added."
			% claimed.short_name, ch.id))
		return out

	var year := _charter_year(ctx, ch)
	var candidates := ctx.matrices_for_owner(seal.claims_owner)

	if candidates.is_empty():
		out.append(Finding.make(&"matrix_unknown", Lex.Severity.FATAL,
			"No such die is recorded",
			"The Book of Matrices holds nothing under \"%s\". " % seal.claims_owner
			+ "An unrecorded die is not evidence of a right; it is evidence of a "
			+ "man with a graver.", ch.id))
		return out

	var visual: Array[SealMatrix] = []
	for m in candidates:
		if _visually_matches(seal, m):
			visual.append(m)

	if visual.is_empty():
		out.append(_mismatch_finding(seal, candidates, ch.id))
		return out

	if year == _UNRESOLVED:
		out.append(Finding.make(&"seal_date_unresolved", Lex.Severity.NOTE,
			"The die cannot be dated",
			"The impression answers to a recorded die, but the charter's date "
			+ "cannot be reduced to a year, so no test of the die's life is "
			+ "possible.", ch.id))
		return out

	var live: Array[SealMatrix] = []
	for m in visual:
		if m.was_live_in(year):
			live.append(m)

	if live.is_empty():
		out.append(_dead_matrix_finding(visual, year, ch.id))
		out.append_array(_supersession_hints(candidates, visual, year, ch.id))
		return out

	if seal.wear > WEAR_NOTICEABLE:
		out.append(Finding.hint(&"wear_but_sound",
			"The impression is worn",
			"Rubbed at the rim and part of the legend gone, which is what "
			+ "damp and a bad chest do to wax. What survives agrees with the "
			+ "die in every particular. Damage is not dishonesty.",
			ch.id))

	var sound := Finding.make(&"seal_sound", Lex.Severity.CLEAN,
		"The seal answers to a live die",
		"%s, %s. Live in %d." % [live[0].owner_name, live[0].life_text(), year],
		ch.id)
	out.append(sound)
	return out


# ---------------------------------------------------------------- comparison

## Field-by-field. The impression and the matrix carry the same four observable
## features precisely so this stays a walk rather than a special case per seal.
func _visually_matches(seal: SealImpression, m: SealMatrix) -> bool:
	if seal.device != m.device:
		return false
	if seal.shape != m.shape:
		return false
	if not _color_close(seal.wax_color, m.wax_color):
		return false
	return legend_compatible(seal.legend, m.legend)


## Worn legends are recorded with a wildcard for each illegible letter, so a
## partly rubbed seal can still be shown to be *compatible* with a die without
## being identical to it. Length must still agree: letters do not vanish, they
## only become unreadable.
static func legend_compatible(worn: String, reference: String) -> bool:
	var a := worn.strip_edges().to_upper()
	var b := reference.strip_edges().to_upper()
	if a.length() != b.length():
		return false
	for i in a.length():
		var c := a[i]
		if WILDCARDS.find(c) >= 0:
			continue
		if c != b[i]:
			return false
	return true


static func _color_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < COLOR_TOLERANCE \
		and absf(a.g - b.g) < COLOR_TOLERANCE \
		and absf(a.b - b.b) < COLOR_TOLERANCE


# ------------------------------------------------------------------ findings

func _mismatch_finding(seal: SealImpression, candidates: Array[SealMatrix],
		subject: StringName) -> Finding:
	# Name the first feature that fails against the closest die, so the ledger
	# can tell the player exactly what they were looking at.
	var best: SealMatrix = candidates[0]
	var best_score := -1
	for m in candidates:
		var s := 0
		if seal.device == m.device:
			s += 2
		if seal.shape == m.shape:
			s += 1
		if legend_compatible(seal.legend, m.legend):
			s += 3
		if s > best_score:
			best_score = s
			best = m

	var code := &"seal_mismatch"
	var head := "The impression does not answer to the die"
	var detail := ""
	if seal.device != best.device:
		code = &"device_mismatch"
		head = "Wrong device"
		detail = "The wax shows %s. Every die recorded for %s bears %s." % [
			_pretty(seal.device), best.owner_name, _pretty(best.device)]
	elif seal.shape != best.shape:
		code = &"shape_mismatch"
		head = "Wrong shape"
		detail = "A %s impression against a %s die. Chanceries do not change "\
			% [seal.shape, best.shape] + "the shape of a seal by accident."
	elif not _color_close(seal.wax_color, best.wax_color):
		code = &"color_mismatch"
		head = "Wrong wax"
		detail = "The tincture is not the house's. Cheap to get wrong, cheap to spot."
	else:
		code = &"legend_mismatch"
		head = "The legend does not agree"
		detail = "Wax reads  %s\nDie reads  %s" % [seal.legend, best.legend]

	return Finding.make(code, Lex.Severity.FATAL, head, detail, subject)


func _dead_matrix_finding(visual: Array[SealMatrix], year: int,
		subject: StringName) -> Finding:
	var m: SealMatrix = visual[0]
	var when := "not yet cut" if year < m.cut_year else "already broken"
	var detail := "The impression answers in every particular to %s's die — %s. "\
		% [m.owner_name, m.life_text()]
	detail += "The charter is dated %d. On that day the die was %s.\n\n" % [year, when]
	if m.broken_year >= 0 and year > m.broken_year:
		detail += "A matrix is defaced before witnesses when its holder dies, so "
		detail += "that no man may seal in a dead man's name. Whatever pressed "
		detail += "this wax, it was not that die."
	else:
		detail += "Wax cannot bear the mark of a graver's work that had not yet "
		detail += "been done."
	return Finding.make(&"matrix_not_live", Lex.Severity.FATAL,
		"The die was not alive on that day", detail, subject)


## When a forger works from an old impression he copies the legend of the wrong
## decade. If the owner recut his die and the impression matches the superseded
## one, say so — it is the accessible tell, findable without any date arithmetic.
func _supersession_hints(candidates: Array[SealMatrix], visual: Array[SealMatrix],
		year: int, subject: StringName) -> Array[Finding]:
	var out: Array[Finding] = []
	var matched: SealMatrix = visual[0]
	for m in candidates:
		if m == matched:
			continue
		if m.cut_year > matched.cut_year:
			out.append(Finding.hint(&"superseded_legend",
				"The legend is of the wrong decade",
				"%s put aside that legend in %d and took a new die reading:\n  %s\n"
				% [m.owner_name, m.cut_year, m.legend]
				+ "A man sealing his own instrument uses the die on his own belt, "
				+ "not the one he gave up %d years before." % maxi(0, year - m.cut_year),
				subject))
	return out


# ------------------------------------------------------------------- helpers

const _UNRESOLVED := -999999


func _charter_year(ctx: CheckContext, ch: CharterData) -> int:
	var reign := ctx.reign(ch.date_emperor)
	if reign == null:
		return _UNRESOLVED
	var style := ctx.chancery_style(ch)
	if not RegnalMath.style_applies(reign, style):
		return _UNRESOLVED
	return RegnalMath.to_absolute(reign, ch.date_regnal_year, style)


static func _pretty(device: StringName) -> String:
	return String(device).replace("_", " ")

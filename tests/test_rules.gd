extends SceneTree

## Headless test of the rules layer. Run from the project root:
##
##     godot --headless --script tests/test_rules.gd
##
## Deliberately does NOT touch the scene tree, the autoloads, or any node. The
## checks take a CheckContext and return findings; that is the entire reason they
## were built that way, and this file is what cashes it in.
##
## The important assertion is the last one: every case's AUTHORED correct_verdict
## must equal the verdict the documents actually produce. When those disagree the
## content is broken, and the failure should arrive here rather than in a
## playtest three weeks later.

var failures := 0
var checks := 0


func _initialize() -> void:
	print("\n=== Hand and Seal — rules ===\n")

	var lore := ContentLoader.load_all()
	for e in lore.errors:
		_fail("content: %s" % e)

	_test_regnal_math(lore)
	_test_legend_matching()
	_test_cases(lore)
	_test_policy()
	_test_witnesses(lore)
	_test_erasures(lore)
	_test_plural_authority(lore)
	_test_precedent(lore)
	_test_campaign_data(lore)

	print("\n%d checks, %d failure(s)\n" % [checks, failures])
	quit(1 if failures > 0 else 0)


# ------------------------------------------------------------------ regnal

func _test_regnal_math(lore: LoreData) -> void:
	_section("regnal arithmetic")
	var aldric := lore.reign(&"aldric_i")
	if aldric == null:
		_fail("no reign 'aldric_i'")
		return

	# Year 1 is the epoch year itself. Off by one here breaks every case.
	_eq(RegnalMath.to_absolute(aldric, 1, Lex.Dating.ACCESSION),
		aldric.accession_year, "year 1 is the accession year")
	_eq(RegnalMath.to_absolute(aldric, 14, Lex.Dating.ACCESSION), 1217,
		"14 Aldric by accession")
	_eq(RegnalMath.to_absolute(aldric, 14, Lex.Dating.ELECTION), 1214,
		"14 Aldric by election")

	# The same phrase, admissible under one law and not the other. This is the
	# entire premise of the game expressed as two booleans.
	_is_true(not RegnalMath.is_admissible(aldric, 14, Lex.Dating.ACCESSION,
		lore.present_year), "14 Aldric is impossible to the Empire")
	_is_true(RegnalMath.is_admissible(aldric, 14, Lex.Dating.ELECTION,
		lore.present_year), "14 Aldric is ordinary to the Church")

	_eq(RegnalMath.max_regnal_year(aldric, Lex.Dating.ACCESSION,
		lore.present_year), 12, "Aldric reigned 12 years by accession")

	var round_trip := RegnalMath.from_absolute(aldric,
		RegnalMath.to_absolute(aldric, 7, Lex.Dating.CORONATION),
		Lex.Dating.CORONATION)
	_eq(round_trip, 7, "absolute conversion round-trips")


# ----------------------------------------------------------------- legends

func _test_legend_matching() -> void:
	_section("worn legends")
	_is_true(SealCheck.legend_compatible("SIGILLVM CIVITATIS MARCHFELDE····",
		"SIGILLVM CIVITATIS MARCHFELDENSIS"), "dots match lost letters")
	_is_true(not SealCheck.legend_compatible("DIETRICVS MARCHIO TVRNENSIS",
		"DIETRICVS DEI GRATIA MARCHIO TVRNENSIS"),
		"a shorter legend is a different legend")
	_is_true(not SealCheck.legend_compatible("SIGILLVM CIVITATIS MARCHFELDENSIX",
		"SIGILLVM CIVITATIS MARCHFELDENSIS"), "a wrong letter is a wrong letter")
	_is_true(SealCheck.legend_compatible("  sigillvm cancellarie imperii  ",
		"SIGILLVM CANCELLARIE IMPERII"), "case and edge whitespace are ignored")


# ------------------------------------------------------------------- cases

func _test_cases(lore: LoreData) -> void:
	_section("cases")
	if lore.cases.is_empty():
		_fail("no cases loaded")
		return

	# THE FINDING SETS GO ON DISK FOR THE PYTHON TO CHECK ITSELF AGAINST.
	#
	# tools/verify_content.py is a deliberately independent second implementation
	# of these rules, and its whole value is that a disagreement between the two
	# is a bug in one of them. It only ever compared the FINAL VERDICT, which is a
	# three-valued summary of a dozen findings — so a CLEAN that should have been
	# a NOTE, or a missing witness finding masked by a FATAL, agreed by luck and
	# the tool said PASS. That is exactly how the date_sound guard drifted for
	# months. Writing the real answer out costs eight lines and closes the class
	# of bug rather than the instance.
	var derived := {}
	for c in lore.cases:
		# A dynamic case has no fixed authored verdict, so there is nothing to
		# assert against — but its BASELINE against an empty Register is still a
		# finding set, and the Python computes exactly that one. Skipping them
		# here left the two most complicated cases in the campaign as the only
		# two nobody was cross-checking, which the comparison found the first
		# time it ran.
		var a := Adjudicator.adjudicate_case(c, lore, null)
		if c.dynamic_precedent:
			print("   note  %s: verdict depends on the Register" % c.id)
		else:
			_eq(a.verdict, c.correct_verdict,
				"%s: documents produce the authored verdict (%s)"
				% [c.id, Lex.verdict_name(c.correct_verdict)])
			if a.reason_code() != c.correct_reason:
				print("      note  %s: authored reason '%s', derived '%s'"
					% [c.id, c.correct_reason, a.reason_code()])
		var codes := PackedStringArray()
		for f in a.findings:
			print("      · %-9s %s" % [_sev(f.severity), f.code])
			codes.append("%s:%s" % [_sev(f.severity), f.code])
		derived[String(c.id)] = codes
	_write_derived(derived)

	# The specific shape of each case, asserted by name. If someone retunes the
	# content these should be updated deliberately, not silently.
	_case_has(lore, &"case_02_grellwater", &"matrix_not_live",
		"the widow's seal fails on the die's lifetime, not its appearance")
	_case_has(lore, &"case_03_kesselholt", &"reckoning_contested",
		"the abbey's date is contested rather than defective")
	_case_lacks(lore, &"case_01_kufergasse", Lex.Severity.FATAL,
		"a worn seal is not a forgery")
	_case_lacks(lore, &"case_01_kufergasse", Lex.Severity.DEFECT,
		"a witness dying that year is not a defect")


## Written where the screenshots go: gitignored, regenerated on every run, and
## consumed by tools/verify_content.py. If it is absent the Python says so and
## keeps going, because it must remain runnable without Godot at all — that
## independence is the entire point of it existing.
func _write_derived(derived: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://.tools/")
	var f := FileAccess.open("res://.tools/derived_findings.json",
		FileAccess.WRITE)
	if f == null:
		print("   note  could not write derived findings for the Python mirror")
		return
	f.store_string(JSON.stringify(derived, "  "))
	f.close()


func _case_has(lore: LoreData, id: StringName, code: StringName, why: String) -> void:
	var c := lore.case_by_id(id)
	if c == null:
		_fail("no case '%s'" % id)
		return
	var a := Adjudicator.adjudicate_case(c, lore, null)
	_is_true(a.codes().has(code), why)


func _case_lacks(lore: LoreData, id: StringName, severity: int, why: String) -> void:
	var c := lore.case_by_id(id)
	if c == null:
		_fail("no case '%s'" % id)
		return
	var a := Adjudicator.adjudicate_case(c, lore, null)
	_is_true(not a.has_severity(severity), why)


# ------------------------------------------------------------------ policy

func _test_policy() -> void:
	_section("verdict policy")
	var p := VerdictPolicy.fallback()

	var fatal: Array[Finding] = [
		Finding.make(&"x", Lex.Severity.FATAL, "forged"),
		Finding.make(&"y", Lex.Severity.CONTESTED, "contested"),
	]
	_eq(p.decide(fatal)["verdict"], Lex.Verdict.DENY,
		"forgery outranks contention")

	var contested: Array[Finding] = [
		Finding.make(&"y", Lex.Severity.CONTESTED, "contested"),
		Finding.make(&"z", Lex.Severity.DEFECT, "defect"),
	]
	_eq(p.decide(contested)["verdict"], Lex.Verdict.REFER,
		"contention outranks defect")

	var clean: Array[Finding] = [Finding.make(&"c", Lex.Severity.CLEAN, "fine")]
	_eq(p.decide(clean)["verdict"], Lex.Verdict.CONFIRM,
		"nothing against means confirm")

	var empty: Array[Finding] = []
	_eq(p.decide(empty)["verdict"], Lex.Verdict.CONFIRM,
		"an empty packet confirms rather than crashing")


## THE HOLE, AND THE FOUR WAYS IT COULD REOPEN.
##
## Witness deaths used to be read off the charter's own witness list, so the one
## document under suspicion was the only source for the fact that would have
## condemned it. Omit the annotation and the check was defeated. These assertions
## exist so that can never quietly become true again — every one of them fails if
## somebody moves the death back onto the parchment, and the first one fails
## loudest, because it is the forgery itself.
func _test_witnesses(lore: LoreData) -> void:
	_section("the rolls of the dead")
	_is_true(lore.necrology != null and not lore.necrology.rolls.is_empty(),
		"the Chancery holds obit rolls returned by other houses")
	if lore.necrology == null:
		return

	var thurn := _first_roll_of(lore, &"thurn")
	_is_true(thurn != null, "the Margrave's chapel returns its dead")
	if thurn == null:
		return

	# 1. A charter that names a man the roll knows to be dead, and says NOTHING
	#    about it, is still caught. This is the whole point.
	var dead := thurn.entries[0]
	for e in thurn.entries:
		if e.person_id == &"dietrich_of_thurn":
			dead = e
	var forged := _packet_witnessed(lore, &"thurn", dead.person_id, "Dietrich",
		&"aldric_i", 14, &"")
	var a := Adjudicator.adjudicate(forged)
	_is_true(a.codes().has(&"witness_dead"),
		"a forger who omits the obiit is caught by the roll anyway")

	# 2. Silence is never evidence of life. A man no roll covers must produce a
	#    NOTE at worst — never a defect, and never prose asserting he lived.
	var stranger := _packet_witnessed(lore, &"", &"nobody_at_all", "A Stranger",
		&"aldric_i", 14, &"")
	var b := Adjudicator.adjudicate(stranger)
	_is_true(not b.codes().has(&"witness_dead"),
		"a man in nobody's roll is not thereby dead")
	var worst := Lex.Severity.CLEAN
	for f in b.findings:
		if f.code.begins_with("witness") or f.code.begins_with("necrology"):
			worst = maxi(worst, f.severity)
	_is_true(worst <= Lex.Severity.NOTE,
		"and an unverifiable witness list is never worse than a note")

	# 3. A roll that stops short of the charter cannot speak about it either.
	_is_true(b.codes().has(&"necrology_incomplete"),
		"the ledger says WHICH roll fell short rather than only that one did")

	# 4. The annotation on the parchment is cross-examined, not believed. This
	#    closes the hole from the other side: against a forger who writes an
	#    obiit that suits him rather than leaving it off.
	var lied := _packet_witnessed(lore, &"thurn", dead.person_id, "Dietrich",
		&"aldric_i", 14, &"kunrad_iv", 6)
	var c := Adjudicator.adjudicate(lied)
	_is_true(c.codes().has(&"annotation_disagrees"),
		"an obiit that disagrees with the roll is itself a finding")


## THE KNIFE, AND THE THREE THINGS THAT MUST STAY TRUE ABOUT IT.
##
## The whole value of this check is that it convicts on the document's HISTORY
## while every other check reads its contents — so the ways it can quietly stop
## working are (a) a scrape stops being decisive, (b) an honest correction starts
## being a crime, which would teach the exact reflex the first case unteaches, and
## (c) something else in the packet starts outranking it.
func _test_erasures(lore: LoreData) -> void:
	_section("the knife")

	var clean := _packet_with_erasures(lore, [])
	_is_true(Adjudicator.adjudicate(clean).codes().is_empty()
			or not Adjudicator.adjudicate(clean).codes().has(&"erasure_dispositive"),
		"an unscraped instrument raises nothing about the skin")

	var altered := Erasure.new()
	altered.altered_field = "The year of the grant"
	altered.original_value = "in the second year of Aldric I"
	altered.dispositive = true
	var forged := _packet_with_erasures(lore, [altered])
	var a := Adjudicator.adjudicate(forged)
	_eq(a.verdict, Lex.Verdict.DENY,
		"a scraped and rewritten disposition is refused, not referred")
	_is_true(a.reason_code() == "erasure_dispositive",
		"and the knife is the decisive finding, ahead of the seal and the date")

	# A scribe correcting himself is universal and honest. This is the same
	# lesson the first case teaches about a rubbed seal, one level up.
	var tidied := Erasure.new()
	tidied.altered_field = "A misspelt place"
	tidied.original_value = "Tannek"
	tidied.innocent = true
	var honest := Adjudicator.adjudicate(_packet_with_erasures(lore, [tidied]))
	_is_true(not honest.codes().has(&"erasure_dispositive"),
		"a scribe's own correction is not a forgery")
	_eq(honest.verdict, Lex.Verdict.CONFIRM,
		"and an honestly corrected instrument still passes")

	# Scraped to the nap with nothing recoverable is a different, lesser finding:
	# the office cannot say what was granted, so it cannot admit what it says.
	var blank := Erasure.new()
	blank.altered_field = "The extent of the wood"
	blank.dispositive = true
	var illegible := Adjudicator.adjudicate(_packet_with_erasures(lore, [blank]))
	_is_true(illegible.codes().has(&"erasure_illegible"),
		"a scrape with nothing under it is a defect rather than a falsity")
	_eq(illegible.verdict, Lex.Verdict.REFER,
		"and a defective instrument is sent up for correction, not refused")


func _packet_with_erasures(lore: LoreData, erasures: Array) -> CheckContext:
	var ch := CharterData.new()
	ch.id = &"test_charter"
	ch.date_emperor = &"kunrad_iv"
	ch.date_regnal_year = 3
	ch.drawn_by_polity = &"marchfeld"
	var typed: Array[Erasure] = []
	for e in erasures:
		typed.append(e)
	ch.erasures = typed
	var ctx := CheckContext.new()
	ctx.documents = [ch]
	ctx.matrices = lore.matrices
	ctx.reigns = lore.reigns
	ctx.polities = lore.polities
	ctx.present_year = lore.present_year
	ctx.necrology = lore.necrology
	return ctx


func _first_roll_of(lore: LoreData, polity: StringName) -> ObitRoll:
	for r in lore.necrology.rolls:
		if r.polity_id == polity:
			return r
	return null


## A minimal one-witness packet, built in code so these assertions do not depend
## on any shipped case continuing to have the shape they need.
func _packet_witnessed(lore: LoreData, house: StringName, person: StringName,
		who: String, emperor: StringName, regnal: int,
		annotated: StringName, annotated_year := 0) -> CheckContext:
	var w := Witness.new()
	w.name = who
	w.person_id = person
	w.house = house
	w.died_emperor = annotated
	w.died_regnal_year = annotated_year
	var ch := CharterData.new()
	ch.id = &"test_charter"
	ch.date_emperor = emperor
	ch.date_regnal_year = regnal
	ch.drawn_by_polity = &"thurn"
	ch.witnesses = [w]
	var ctx := CheckContext.new()
	ctx.documents = [ch]
	ctx.matrices = lore.matrices
	ctx.reigns = lore.reigns
	ctx.polities = lore.polities
	ctx.present_year = lore.present_year
	ctx.necrology = lore.necrology
	return ctx


func _test_plural_authority(lore: LoreData) -> void:
	_section("plural authority")

	var kessel := lore.case_by_id(&"case_03_kesselholt")
	var contested := Adjudicator.adjudicate_case(kessel, lore, null)
	_is_true(contested.is_pure_authority_contest(),
		"Kesselholt is a pure authority contest")
	_is_true(contested.is_defensible(Lex.Verdict.CONFIRM),
		"Church-backed confirmation is legally defensible")
	_is_true(contested.is_defensible(Lex.Verdict.DENY),
		"Empire-backed denial is legally defensible")
	_is_true(contested.is_defensible(Lex.Verdict.REFER),
		"referral follows office procedure")
	_eq(contested.defensible_verdicts(),
		[Lex.Verdict.CONFIRM, Lex.Verdict.DENY, Lex.Verdict.REFER],
		"Kesselholt exposes all three defensible dispositions")
	_eq(contested.supporting_authorities(Lex.Verdict.CONFIRM),
		[Lex.Authority.CHURCH], "the Church sustains confirmation")
	_eq(contested.supporting_authorities(Lex.Verdict.DENY),
		[Lex.Authority.IMPERIAL], "the Empire sustains denial")

	var worn := Adjudicator.adjudicate_case(
		lore.case_by_id(&"case_01_kufergasse"), lore, null)
	_is_true(worn.is_defensible(Lex.Verdict.CONFIRM),
		"the worn but live seal confirms")
	_is_true(not worn.is_defensible(Lex.Verdict.DENY),
		"a clean packet does not make denial defensible")

	var dead_die := Adjudicator.adjudicate_case(
		lore.case_by_id(&"case_02_grellwater"), lore, null)
	_is_true(dead_die.is_defensible(Lex.Verdict.DENY),
		"the dead die sustains denial")
	_is_true(not dead_die.is_defensible(Lex.Verdict.CONFIRM),
		"a fatal seal defect does not sustain confirmation")

	var split := Finding.make(&"split", Lex.Severity.CONTESTED, "split")
	split.authority_verdicts = {
		Lex.Authority.IMPERIAL: Lex.Verdict.DENY,
		Lex.Authority.CHURCH: Lex.Verdict.CONFIRM,
	}
	var fatal := Finding.make(&"fatal", Lex.Severity.FATAL, "fatal")
	var mixed := Adjudication.new()
	mixed.findings = [split, fatal]
	mixed.decisive = split
	mixed.verdict = Lex.Verdict.DENY
	_is_true(not mixed.is_pure_authority_contest(),
		"a factual fatality prevents pluralizing the answer")
	_is_true(not mixed.is_defensible(Lex.Verdict.CONFIRM),
		"authority support cannot excuse a fatal instrument defect")


func _test_precedent(lore: LoreData) -> void:
	_section("precedent")
	var grell := lore.case_by_id(&"case_02_grellwater")
	var regrant := lore.case_by_id(&"case_05_grellwater_regrant")

	var denied_register := Register.new()
	denied_register.add(_prior_record(grell, Lex.Verdict.DENY))
	var after_denial := Adjudicator.adjudicate_case(regrant, lore, denied_register)
	_eq(after_denial.verdict, Lex.Verdict.CONFIRM,
		"a refused old title leaves a clean regrant standing")
	_is_true(not after_denial.is_pure_authority_contest(),
		"denial alone leaves no recognized competitor")

	var admitted_register := Register.new()
	admitted_register.add(_prior_record(grell, Lex.Verdict.CONFIRM))
	var after_admission := Adjudicator.adjudicate_case(
		regrant, lore, admitted_register)
	_eq(after_admission.verdict, Lex.Verdict.REFER,
		"an admitted competing title contests the regrant")
	_eq(after_admission.supporting_authorities(Lex.Verdict.CONFIRM),
		[Lex.Authority.IMPERIAL], "the clean Imperial instrument supports regrant")
	_eq(after_admission.supporting_authorities(Lex.Verdict.DENY),
		[Lex.Authority.OFFICE], "the office's admitted Vesser title supports denial")

	var referred_register := Register.new()
	referred_register.add(_prior_record(grell, Lex.Verdict.REFER))
	var after_referral := Adjudicator.adjudicate_case(
		regrant, lore, referred_register)
	_is_true(after_referral.is_defensible(Lex.Verdict.CONFIRM),
		"the new authority can support confirmation after referral")
	_is_true(after_referral.is_defensible(Lex.Verdict.REFER),
		"the unresolved Register position supports continued referral")
	_is_true(not after_referral.is_defensible(Lex.Verdict.DENY),
		"referral alone does not invent support for denial")

	var kessel := lore.case_by_id(&"case_03_kesselholt")
	var old_positions := Adjudicator.adjudicate_case(kessel, lore, null)
	for prior_verdict in [
			Lex.Verdict.CONFIRM, Lex.Verdict.DENY, Lex.Verdict.REFER]:
		var callback_register := Register.new()
		var prior := _prior_record(kessel, prior_verdict)
		prior.authority_verdicts = old_positions.authority_split()
		callback_register.add(prior)
		var writ := Adjudicator.adjudicate_case(
			lore.case_by_id(&"case_06_kesselholt_writ"), lore,
			callback_register)
		_eq(writ.verdict, Lex.Verdict.REFER,
			"Kesselholt writ is procedurally referred after %s"
			% Lex.verdict_name(prior_verdict).to_lower())
		_eq(writ.supporting_authorities(Lex.Verdict.CONFIRM).has(
			Lex.Authority.IMPERIAL), true,
			"the Empire supports its competing writ")
		_eq(writ.supporting_authorities(Lex.Verdict.DENY).has(
			Lex.Authority.CHURCH), true,
			"the Church's admitted abbey title supports denial")

	var cured_register := Register.new()
	cured_register.add(_prior_record(
		lore.case_by_id(&"case_01_kufergasse"), Lex.Verdict.DENY))
	var cured := Adjudicator.adjudicate_case(
		lore.case_by_id(&"case_07_daughters_portion"), lore, cured_register)
	_eq(cured.verdict, Lex.Verdict.CONFIRM,
		"a superseding instrument is judged on its own merits")
	_is_true(cured.codes().has(&"instrument_cures_prior"),
		"the cured packet explains why precedent does not bind it")

	# Feedback is composed after entries have been added, but it must reason
	# from the history that existed at judgment. The current entry and later
	# entries are not precedent for themselves.
	var second_lion := lore.case_by_id(&"case_04_second_lion")
	var temporal := Register.new()
	var current := _prior_record(second_lion, Lex.Verdict.DENY)
	temporal.add(current)
	temporal.add(_prior_record(second_lion, Lex.Verdict.CONFIRM))
	var as_decided := Adjudicator.adjudicate_case(
		second_lion, lore, temporal.before(current))
	_is_true(not as_decided.codes().has(&"precedent_contested"),
		"a ruling cannot manufacture precedent for its own feedback")


func _test_campaign_data(lore: LoreData) -> void:
	_section("campaign data")
	var thursday := lore.day_by_id(&"day_02")
	_is_true(thursday != null and thursday.entry_label == "THURSDAY",
		"the next-day ledger label comes from day content")
	if thursday == null:
		return

	var kessel := lore.case_by_id(&"case_03_kesselholt")
	var letter_ids := {}
	for verdict in [Lex.Verdict.CONFIRM, Lex.Verdict.DENY, Lex.Verdict.REFER]:
		var history := Register.new()
		history.add(_prior_record(kessel, verdict))
		var letters := thursday.resolve_opening_documents(history)
		_is_true(letters.size() == 1,
			"one Kesselholt letter arrives after %s"
			% Lex.verdict_name(verdict).to_lower())
		if letters.size() == 1:
			letter_ids[letters[0].id] = true
	_eq(letter_ids.size(), 3,
		"all three Kesselholt choices produce distinct correspondence")

	var unresolved_ids := PackedStringArray()
	for c in thursday.resolve_cases(lore, Register.new()):
		unresolved_ids.append(String(c.id))
	_is_true(unresolved_ids.has("case_01_kufergasse")
			and unresolved_ids.has("case_02_grellwater")
			and unresolved_ids.has("case_03_kesselholt"),
		"unheard Tuesday matters return instead of spawning follow-ups")

	var completed := Register.new()
	for id in [&"case_01_kufergasse", &"case_02_grellwater",
			&"case_03_kesselholt"]:
		completed.add(_prior_record(lore.case_by_id(id), Lex.Verdict.REFER))
	var followup_ids := PackedStringArray()
	for c in thursday.resolve_cases(lore, completed):
		followup_ids.append(String(c.id))
	_is_true(followup_ids.has("case_05_grellwater_regrant")
			and followup_ids.has("case_06_kesselholt_writ")
			and followup_ids.has("case_07_daughters_portion"),
		"ruled Tuesday matters unlock their authored Thursday follow-ups")


func _prior_record(c: CaseData, verdict: int) -> RulingRecord:
	var record := RulingRecord.new()
	record.case_id = c.id
	record.day_id = &"day_01"
	record.case_title = c.title
	record.verdict = verdict
	record.lawful_verdict = c.correct_verdict
	var charter := c.charter()
	record.subject_id = charter.subject_id
	record.claimant_id = charter.claimant_id
	return record


# ----------------------------------------------------------------- harness

func _section(title: String) -> void:
	print("-- %s" % title)


func _eq(got, want, why: String) -> void:
	checks += 1
	if got == want:
		print("   ok    %s" % why)
	else:
		_fail("%s  (got %s, wanted %s)" % [why, str(got), str(want)])


func _is_true(cond: bool, why: String) -> void:
	checks += 1
	if cond:
		print("   ok    %s" % why)
	else:
		_fail(why)


func _fail(why: String) -> void:
	failures += 1
	printerr("   FAIL  %s" % why)
	print("   FAIL  %s" % why)


func _sev(s: int) -> String:
	return ["clean", "note", "defect", "contested", "fatal"][clampi(s, 0, 4)]

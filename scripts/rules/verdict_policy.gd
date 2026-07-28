class_name VerdictPolicy
extends Resource

## Turns a heap of findings into a ruling.
##
## Deliberately dumb and deliberately data. The interesting judgement lives in
## the checks (what is wrong) and in the player (what to do about it); this is
## only the office's standing instruction about which kind of wrongness gets
## which stamp. The default doctrine is:
##
##   forgery      -> Deny    a false instrument is refused outright
##   contested    -> Refer   two laws disagree; not a notary's to settle
##   defect       -> Refer   wrong, but perhaps only a scribe's slip
##   otherwise    -> Confirm
##
## Swap the last two and you have a much crueller Chancery. That is a one-line
## edit in a .tres, which is the point.

## Untyped on purpose. A typed Array[VerdictRule] serialises into .tres with a
## class-name annotation that is fiddly to hand-author and easy to get subtly
## wrong; an untyped array round-trips as a plain list. The elements are still
## VerdictRule, and this is the one resource meant to be edited by hand.
@export var rules: Array = []
@export var default_verdict: int = Lex.Verdict.CONFIRM
@export var default_grounds: String = "Nothing in the packet stands against the claim."


func decide(findings: Array[Finding]) -> Dictionary:
	for rule in rules:
		for f in findings:
			if f.severity == rule.severity:
				return {
					"verdict": rule.verdict,
					"finding": f,
					"grounds": rule.grounds,
				}
	return {"verdict": default_verdict, "finding": null, "grounds": default_grounds}


## Built in code as a fallback so the rules can be exercised headlessly even if
## the .tres is missing. data/tuning/verdict_policy.tres is the authority.
static func fallback() -> VerdictPolicy:
	var p := VerdictPolicy.new()
	var r: Array[VerdictRule] = []
	r.append(_rule(Lex.Severity.FATAL, Lex.Verdict.DENY,
		"The instrument is false."))
	r.append(_rule(Lex.Severity.CONTESTED, Lex.Verdict.REFER,
		"Two authorities are in contention. Referred upward."))
	r.append(_rule(Lex.Severity.DEFECT, Lex.Verdict.REFER,
		"The instrument is defective. Referred for correction."))
	p.rules = r
	return p


static func _rule(sev: int, verdict: int, grounds: String) -> VerdictRule:
	var r := VerdictRule.new()
	r.severity = sev
	r.verdict = verdict
	r.grounds = grounds
	return r

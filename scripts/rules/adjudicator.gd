class_name Adjudicator
extends RefCounted

## Runs every check over a packet and applies the policy.
##
## Adding a verification type to the game is: write a Check subclass, append it
## to CHECKS. Nothing else in the project changes — not the policy, not the
## ledger, not any case file. That is the whole payoff of the findings indirection
## and it is worth the two extra classes it cost.

static func checks() -> Array[Check]:
	var list: Array[Check] = []
	list.append(SealCheck.new())
	list.append(DateCheck.new())
	# ORDER IS DOCTRINE. VerdictPolicy walks severity rows and returns the first
	# matching finding in list order, so a dead die stays decisive over a dead
	# witness (the seal is authenticity; the witness list is formality), and a
	# broken date stays decisive over the witness arithmetic derived from it.
	list.append(WitnessCheck.new())
	list.append(AuthorityCheck.new())
	list.append(PrecedentCheck.new())
	# Later: GenealogyCheck, PalaeographyCheck, JurisdictionCheck.
	return list


static func adjudicate(ctx: CheckContext, policy: VerdictPolicy = null) -> Adjudication:
	var p := policy if policy != null else VerdictPolicy.fallback()
	var a := Adjudication.new()

	for c in checks():
		a.findings.append_array(c.run(ctx))

	var decision := p.decide(a.findings)
	a.verdict = decision["verdict"]
	a.decisive = decision["finding"]
	a.grounds = decision["grounds"]
	return a


## Convenience for the session and for the headless test.
static func adjudicate_case(case_data: CaseData, world: LoreData,
		register: Register = null) -> Adjudication:
	var ctx := CheckContext.new()
	ctx.documents = case_data.documents
	ctx.matrices = world.matrices
	ctx.reigns = world.reigns
	ctx.polities = world.polities
	ctx.present_year = world.present_year
	ctx.present_reign = world.present_reign
	ctx.register = register
	ctx.necrology = world.necrology
	return adjudicate(ctx, world.verdict_policy)

class_name Adjudication
extends Resource

## The rules layer's complete answer about one packet.

@export var findings: Array[Finding] = []
@export var verdict: int = Lex.Verdict.NONE
@export var grounds: String = ""

## The finding that actually decided it, if any.
@export var decisive: Finding = null


func reason_code() -> StringName:
	return decisive.code if decisive else &"nothing_against"


func reason_text() -> String:
	if decisive == null:
		return grounds
	return decisive.detail if not decisive.detail.is_empty() else decisive.headline


## Everything the player could have used to get there. The ledger quotes these
## back on a miss, because being told *what you failed to notice* is instruction
## and being told "incorrect" is not.
func hints() -> Array[Finding]:
	var out: Array[Finding] = []
	for f in findings:
		if f.is_hint:
			out.append(f)
	return out


func of_severity(sev: int) -> Array[Finding]:
	var out: Array[Finding] = []
	for f in findings:
		if f.severity == sev:
			out.append(f)
	return out


func has_severity(sev: int) -> bool:
	for f in findings:
		if f.severity == sev:
			return true
	return false


## A procedural verdict is the office's standing instruction. It is not always
## the only legal position the packet can sustain: a pure authority contest may
## make CONFIRM and DENY defensible even though the office directs REFER.
func has_factual_objection() -> bool:
	return has_severity(Lex.Severity.FATAL) or has_severity(Lex.Severity.DEFECT)


func is_pure_authority_contest() -> bool:
	return decisive != null \
		and decisive.severity == Lex.Severity.CONTESTED \
		and not has_factual_objection() \
		and not decisive.authority_verdicts.is_empty()


## authority -> substantive verdict, but only when authority is the decisive
## disagreement and no factual defect independently disposes of the instrument.
func authority_split() -> Dictionary:
	if is_pure_authority_contest():
		return decisive.authority_verdicts.duplicate(true)
	return {}


func supporting_authorities(chosen: int) -> Array[int]:
	var out: Array[int] = []
	for authority in authority_split():
		if authority_split()[authority] == chosen:
			out.append(authority)
	out.sort()
	return out


func opposing_authorities(chosen: int) -> Array[int]:
	var out: Array[int] = []
	for authority in authority_split():
		if authority_split()[authority] != chosen:
			out.append(authority)
	out.sort()
	return out


func follows_office(chosen: int) -> bool:
	return chosen == verdict


func is_defensible(chosen: int) -> bool:
	if follows_office(chosen):
		return true
	return is_pure_authority_contest() and not supporting_authorities(chosen).is_empty()


func defensible_verdicts() -> Array[int]:
	var out: Array[int] = [verdict]
	if is_pure_authority_contest():
		for chosen in decisive.authority_verdicts.values():
			if chosen not in out:
				out.append(chosen)
	out.sort()
	return out


func codes() -> Array[StringName]:
	var out: Array[StringName] = []
	for f in findings:
		out.append(f.code)
	return out

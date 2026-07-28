class_name CaseData
extends Resource

## One petitioner, one packet, one ruling.
##
## The case owns its documents and its expected office disposition. It does NOT
## own its validation: the Adjudicator derives that procedure from the documents
## alone. A pure authority contest may additionally sustain substantive choices.

@export var id: StringName = &""
@export var title: String = ""

@export var petitioner: PetitionerData = null
@export var documents: Array[DocumentData] = []

## Expected office procedure. Kept under the compatibility name used by content.
@export var correct_verdict: int = Lex.Verdict.NONE
## Some follow-up matters deliberately have no context-free answer: the Register
## changes their legal posture. Their branches are verified with constructed
## prior records rather than against one static verdict.
@export var dynamic_precedent := false
@export var correct_reason: StringName = &""
@export_multiline var correct_reason_text: String = ""

## The three branches. One CaseOutcome per verdict the player might reach.
@export var outcomes: Array[CaseOutcome] = []

@export var lines: Array[DialogueLine] = []


func outcome_for(verdict: int) -> CaseOutcome:
	for o in outcomes:
		if o.verdict == verdict:
			return o
	return null


func charter() -> CharterData:
	for d in documents:
		var ch := d as CharterData
		if ch != null:
			return ch
	return null


func sealed_document() -> DocumentData:
	for d in documents:
		if d.takes_seal:
			return d
	return documents[0] if not documents.is_empty() else null


## Best line for a beat, honouring Register conditions and priority.
func line_for(beat: StringName, register: Register) -> DialogueLine:
	var best: DialogueLine = null
	for l in lines:
		if l.beat != beat:
			continue
		if l.requires_case != &"" and register == null:
			continue
		if not l.matches(register.find(l.requires_case) if register else null):
			continue
		if best == null or l.priority > best.priority:
			best = l
	return best


func lines_for(beat: StringName, register: Register) -> Array[DialogueLine]:
	## All eligible lines for a beat, in authored order. Used for multi-line
	## arrival speeches where every eligible line is spoken, not just the best.
	var out: Array[DialogueLine] = []
	for l in lines:
		if l.beat != beat:
			continue
		if not l.matches(register.find(l.requires_case) if register else null):
			continue
		out.append(l)
	return out

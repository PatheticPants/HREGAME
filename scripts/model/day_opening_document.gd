class_name DayOpeningDocument
extends Resource

@export var requires_case: StringName = &""
@export var requires_verdict: int = Lex.Verdict.NONE
@export var document: DocumentData = null


func matches(register: Register) -> bool:
	if requires_case == &"":
		return true
	var prior := register.find(requires_case)
	if prior == null or prior.foreign_hand:
		return false
	return requires_verdict == Lex.Verdict.NONE or prior.verdict == requires_verdict

class_name DayOpeningDocument
extends Resource

@export var requires_case: StringName = &""
@export var requires_verdict: int = Lex.Verdict.NONE
@export var document: DocumentData = null

## WHEN IT ARRIVES.
##
## Empty means at the start of the day, which is how every one of these worked
## before: the room's whole content was decided at dawn and nothing arrived
## after it. A day was a queue of petitioners and nothing else ever happened.
##
## Set it to a case id and the document is delivered the moment that matter is
## finished — mid-day, onto the desk in front of you, while the next man is
## still in the passage. The office is a building with other people in it, and
## the cheapest way to say so is for one of them to interrupt.
@export var after_case: StringName = &""


func arrives_at_dawn() -> bool:
	return after_case == &""


func matches(register: Register) -> bool:
	if requires_case == &"":
		return true
	var prior := register.find(requires_case)
	if prior == null or prior.foreign_hand:
		return false
	return requires_verdict == Lex.Verdict.NONE or prior.verdict == requires_verdict

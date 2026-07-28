class_name DialogueLine
extends Resource

## One spoken line, shown in world space beside the person saying it.
##
## Lines may be conditional on the Register — the record of what the player has
## already ruled. That is the whole reason the Register exists this early: a
## petitioner who can quote your own precedent back at you, correctly, is worth
## more than any number of extra document types.

@export var speaker: String = ""
@export_multiline var text: String = ""

## Which beat of the case this belongs to: arrival, press (when they are asked to
## wait), or the reaction beats after a ruling.
@export var beat: StringName = &"arrival"

## Optional gate. Empty case id means unconditional.
@export var requires_case: StringName = &""
@export var requires_verdict: int = Lex.Verdict.NONE

## -1 = don't care, 0 = only if that ruling was indefensible, 1 = only if the
## earlier packet legally sustained it. This is distinct from following office
## procedure in an authority contest.
@export var requires_soundness: int = -1

## Lines with a higher priority win when several are eligible for the same beat.
@export var priority: int = 0


func matches(prior: RulingRecord) -> bool:
	if requires_case == &"":
		return true
	if prior == null or prior.case_id != requires_case:
		return false
	if requires_verdict != Lex.Verdict.NONE and prior.verdict != requires_verdict:
		return false
	if requires_soundness >= 0:
		var sound := 1 if prior.was_sound else 0
		if sound != requires_soundness:
			return false
	return true

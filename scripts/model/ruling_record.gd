class_name RulingRecord
extends Resource

## One line of the Register: what the notary ruled, and whether it held up.
##
## The Register is the campaign's third reference source, alongside imperial law
## and regional custom — a petitioner may cite the player's own precedent back at
## them, and be right to. Only one day of it exists in this slice, but the record
## is written from the first ruling so that consulting it later is a query, not a
## retrofit.

@export var case_id: StringName = &""
@export var day_id: StringName = &""
@export var case_title: String = ""
@export var petitioner_name: String = ""
@export var subject_id: StringName = &""
@export var claimant_id: StringName = &""

@export var verdict: int = Lex.Verdict.NONE
## The office's procedural instruction, retained under its old serialized name.
## In a pure authority contest this is REFER without making the two substantive
## positions legally false.
@export var lawful_verdict: int = Lex.Verdict.NONE
## Whether the packet legally sustains the chosen verdict, not whether the
## player followed office procedure.
@export var was_sound: bool = false
## Authority enum -> substantive verdict at the time of judgment.
@export var authority_verdicts: Dictionary = {}

@export var reason_code: StringName = &""
@export_multiline var reason_text: String = ""
@export_multiline var register_note: String = ""
@export_multiline var aftermath: String = ""

@export var impression: ImpressionRecord = null

## Authority enum -> signed favour delta from this ruling.
@export var favor: Dictionary = {}

## Findings the Adjudicator raised, kept as codes so the ledger can quote the
## specific defect the player missed rather than a generic "incorrect".
@export var finding_codes: Array[StringName] = []
## The best reviewable observation captured at judgment time. Dynamic precedent
## cannot be reconstructed later without changing the history it was judged
## against, so the senior hand works from this stored evidence.
@export var review_headline: String = ""
@export_multiline var review_detail: String = ""

## Set when the entry was written by someone other than the player. The
## predecessor's hand is in the same book, and some of it is not what it appears.
@export var foreign_hand: bool = false
@export var hand_name: String = ""


func follows_office() -> bool:
	return verdict == lawful_verdict


func is_authority_contested() -> bool:
	if authority_verdicts.is_empty():
		return false
	var distinct := {}
	for chosen in authority_verdicts.values():
		distinct[chosen] = true
	return distinct.size() > 1


func supporting_authorities() -> Array[int]:
	var out: Array[int] = []
	for authority in authority_verdicts:
		if authority_verdicts[authority] == verdict:
			out.append(authority)
	out.sort()
	return out


func opposing_authorities() -> Array[int]:
	var out: Array[int] = []
	for authority in authority_verdicts:
		if authority_verdicts[authority] != verdict:
			out.append(authority)
	out.sort()
	return out

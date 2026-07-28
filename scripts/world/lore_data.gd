class_name LoreData
extends RefCounted

## Everything loaded from data/. One object, passed by reference, never a global
## lookup from inside the rules layer.

var polities: Dictionary = {}   ## StringName -> Polity
var reigns: Dictionary = {}     ## StringName -> Reign
var matrices: Array[SealMatrix] = []

## The rolls of the dead, and a written record of the houses that send none.
var necrology: Necrology = null
var books: Dictionary = {}      ## StringName -> BookData
var cases: Array[CaseData] = []
var days: Array[DayData] = []
var desk_note: DocumentData = null
var practice_documents: Array[DocumentData] = []

var present_year: int = 0
var present_reign: StringName = &""

var chancery_name: String = ""
var notary_name: String = ""
var day_heading: String = ""

## Seconds of actual working time in one candle. The day ends when it burns out,
## so this is the pacing dial for the whole session and it lives in content
## rather than in a script.
var day_seconds: float = 1200.0
var day_burnt_out: String = ""

var verdict_policy: VerdictPolicy = null
var paper_feel: PaperFeel = null
var wax_feel: WaxFeel = null

## Entries already in the Register when the player sits down. Written by whoever
## had this desk before.
var register_seed: Array[RulingRecord] = []

## Anything the loader could not make sense of. Surfaced loudly rather than
## swallowed, because a case that silently fails to load looks like a bug in the
## rules and will cost an hour.
var errors: PackedStringArray = PackedStringArray()


func polity(id: StringName) -> Polity:
	return polities.get(id, null)


func reign(id: StringName) -> Reign:
	return reigns.get(id, null)


func matrix(id: StringName) -> SealMatrix:
	for m in matrices:
		if m.id == id:
			return m
	return null


func book(id: StringName) -> BookData:
	return books.get(id, null)


func case_by_id(id: StringName) -> CaseData:
	for c in cases:
		if c.id == id:
			return c
	return null


func day_by_id(id: StringName) -> DayData:
	for day in days:
		if day.id == id:
			return day
	return null


func matrices_of_polity(id: StringName) -> Array[SealMatrix]:
	var out: Array[SealMatrix] = []
	for m in matrices:
		if m.polity_id == id:
			out.append(m)
	return out


func is_ok() -> bool:
	return errors.is_empty()

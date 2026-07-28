class_name DayData
extends Resource

## One candle and the matters that can consume it.

@export var id: StringName = &""
## The word written on the folded ledger corner and on this day's Register
## divider (for example, THURSDAY). Kept in content so a third day adds no UI
## special case.
@export var entry_label: String = "NEXT DAY"
@export var heading: String = ""
@export var day_seconds := 1200.0
@export_multiline var burnt_out_text: String = ""
## "fixed" calls matters in authored order; "tray" lets the player choose.
@export var selection_mode: StringName = &"fixed"
@export var case_slots: Array[DayCaseSlot] = []
@export var opening_documents: Array[DayOpeningDocument] = []


func resolve_cases(lore: LoreData, register: Register) -> Array[CaseData]:
	var out: Array[CaseData] = []
	for slot in case_slots:
		var c := slot.resolve(lore, register)
		if c != null and c not in out:
			out.append(c)
	return out


## What is on the desk when the shutter opens.
func resolve_opening_documents(register: Register) -> Array[DocumentData]:
	var out: Array[DocumentData] = []
	for conditional in opening_documents:
		if conditional.arrives_at_dawn() and conditional.matches(register) \
				and conditional.document != null:
			out.append(conditional.document)
	return out


## What arrives DURING the day, once a named matter is off the desk.
##
## The conditions are the same ones the dawn documents use — so an arrival can
## depend on what you did to an earlier case, on a different day, exactly as the
## Thursday letters already do. What is new is only the timing.
func resolve_arrivals(register: Register, after: StringName) -> Array[DocumentData]:
	var out: Array[DocumentData] = []
	if after == &"":
		return out
	for conditional in opening_documents:
		if conditional.after_case == after and conditional.matches(register) \
				and conditional.document != null:
			out.append(conditional.document)
	return out

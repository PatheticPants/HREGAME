class_name Reign
extends Resource

## One emperor, with the three dates a chancery might count his years from.
##
## These are separate fields rather than a single "start" because the gap between
## them is the mechanic. A King of the Romans is elected in his predecessor's
## lifetime, accedes when the predecessor dies, and is crowned Emperor at Rome
## some years later. Three epochs, three different meanings for "his ninth year".

@export var id: StringName = &""
@export var name: String = ""
@export var regnal_number: String = ""

@export var election_year: int = 0
@export var accession_year: int = 0
@export var coronation_year: int = 0

## Year of death or deposition. -1 means still reigning.
@export var end_year: int = -1

@export var epithet: String = ""
@export var note: String = ""


func is_reigning() -> bool:
	return end_year < 0


func full_name() -> String:
	if regnal_number.is_empty():
		return name
	return "%s %s" % [name, regnal_number]


## Inclusive absolute-year span of the reign. Callers pass the present year so a
## living emperor's span has an end.
func span(present_year: int) -> Vector2i:
	var last := end_year if end_year >= 0 else present_year
	return Vector2i(accession_year, last)

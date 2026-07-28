class_name Witness
extends Resource

## A name on the charter's witness list.
##
## The witness *check* (cross-referencing against deaths, imprisonments, absences)
## is not in this slice. What is here is the one fact the date check needs: if a
## witness is recorded dead, a charter he attests cannot postdate him. The field
## exists now so the fuller check later is an addition, not a migration.

@export var name: String = ""
@export var title: String = ""

## Regnal death date, if known: emperor id plus year. Empty emperor = unknown,
## which is the normal case and must never be treated as suspicious.
@export var died_emperor: StringName = &""
@export var died_regnal_year: int = 0

## Which chancery's reckoning the death date was recorded in. Deaths recorded by
## a church register and by an imperial one do not mean the same number.
@export var died_dating_style: int = Lex.Dating.ACCESSION

@export var note: String = ""


func has_death_record() -> bool:
	return died_emperor != &"" and died_regnal_year > 0


func display() -> String:
	if title.is_empty():
		return name
	return "%s, %s" % [name, title]


## The chancery's later annotation against a dead witness, as it appears on the
## parchment. Written in regnal form like everything else, so establishing that a
## witness predeceased his own charter costs the player a trip to the Almanac —
## which is the point, and is why the death has to be ON the document rather than
## living only inside the rules engine.
func death_note(reign_name: String) -> String:
	if not has_death_record():
		return ""
	return "obiit in the %s year of %s" % [
		Lex.ordinal(died_regnal_year), reign_name]

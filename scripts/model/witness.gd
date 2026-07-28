class_name Witness
extends Resource

## A name on the charter's witness list.
##
## EVERYTHING IN HERE IS THE PARCHMENT'S CLAIM ABOUT A MAN, NOT A FACT ABOUT HIM.
##
## That distinction used to not exist, and it was the hole under the whole witness
## check: the death annotation was read straight off the charter's own witness
## entry and treated as truth, so the single document under suspicion was also
## the only source for the fact that would have condemned it. Omitting one line
## defeated the check completely — and the game shipped with the hole live, since
## Eckhard von Melle carries a death record on the Grellwater charter and none at
## all on the second Thurn lion.
##
## Death now comes from the Kalendar of the Dead, which the forger never had in
## his hands. What survives here is what a witness list actually is: a name, a
## style, and — sometimes — a later chancery hand's note that the man is gone.
## WitnessCheck cross-examines that note against the roll rather than believing
## it, so annotating falsely is now as detectable as annotating not at all.

@export var name: String = ""
@export var title: String = ""

## Stable identity, matched against the rolls. Never matched by name: two men are
## called Hugo Wend, and a check that convicts on a string comparison will one day
## convict the wrong one. Empty means the office has not identified him, which is
## ordinary and must never be treated as suspicious.
@export var person_id: StringName = &""

## Which house the charter says he belonged to, and therefore which roll would
## have recorded him. FORGER-CONTROLLED, like every other word on the parchment.
## The rules may use it only to WEAKEN certainty — to explain why a man cannot be
## looked up — never to convict. Defaulting it to the charter's own polity would
## simply move the hole rather than close it.
@export var house: StringName = &""

## Regnal death date as the PARCHMENT gives it, if it gives one at all. Empty
## emperor = no annotation, which is the normal case. Retained because a
## restoration copied from a genuine exemplar carries the exemplar's annotations,
## and because an annotation that disagrees with the roll is itself a finding.
@export var died_emperor: StringName = &""
@export var died_regnal_year: int = 0

## Which chancery's reckoning the annotation was written in. Deaths recorded by a
## church register and by an imperial one do not mean the same number.
@export var died_dating_style: int = Lex.Dating.ACCESSION

## Authoring commentary. Deliberately underscored: it is a note to whoever edits
## the case file, and nothing in the game renders it. It read as content for a
## long time because it was named as though it were.
@export var _note: String = ""


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

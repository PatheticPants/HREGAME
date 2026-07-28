class_name Obit
extends Resource

## One dead man, as some house recorded him and returned him to this Chancery.
##
## The point of this class existing at all is that it is NOT on the parchment.
## A witness's death used to be an annotation on the charter's own witness list,
## which meant the one document under suspicion was also the only source for the
## fact that would have condemned it — a forger who simply left the obiit off
## defeated the whole check. The obit lives out here, in a book the forger never
## touched, and the annotation on the parchment is demoted to a claim that this
## can be held against.

## Stable identity. Matching is ALWAYS on this and never on the name: two men
## are called Hugo Wend, and a roll that convicts on a string comparison is a
## roll that will one day kill the wrong man.
@export var person_id: StringName = &""

@export var name: String = ""
@export var title: String = ""

## Regnal death date, expressed in THE ROLL'S OWN reckoning — not the charter's,
## and not the Empire's. Reducing it is the player's job.
@export var died_emperor: StringName = &""
@export var died_regnal_year: int = 0

@export var note: String = ""


func display() -> String:
	if title.is_empty():
		return name
	return "%s, %s" % [name, title]


## How the roll itself puts it, in the same words the parchment uses for its own
## annotation — so a player who has read one recognises the other without being
## told they are the same fact.
func obit_line(reign_name: String) -> String:
	return "obiit in the %s year of %s" % [
		Lex.ordinal(died_regnal_year), reign_name]

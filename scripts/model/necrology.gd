class_name Necrology
extends Resource

## Every death-roll returned to this Chancery, plus a written record of the
## houses that return nothing.
##
## The silences are data, not an absence of data. A check that says "no roll
## covers the Nether March" has to be able to say WHY, and the player has to be
## able to read that same sentence off a page — otherwise the ledger is quoting
## something that was never on the desk, which is the one contract this genre
## cannot break.

@export var title: String = "The Kalendar of the Dead"
@export var subtitle: String = ""
@export var cover_color: Color = Color(0.165, 0.184, 0.161)
@export var page_color: Color = Color(0.894, 0.863, 0.761)
@export_multiline var front_matter: String = ""
@export_multiline var marginalia: String = ""

@export var rolls: Array[ObitRoll] = []

## polity_id -> the reason nothing comes from there.
@export var silences: Dictionary = {}


## Every roll that would have recorded a man of this house. Empty house returns
## nothing at all, deliberately: a witness whose house the charter does not claim
## is a witness nobody has undertaken to record, and guessing his house from the
## charter's own polity would hand the forger the answer.
func rolls_covering(house: StringName) -> Array[ObitRoll]:
	var out: Array[ObitRoll] = []
	if house == &"":
		return out
	for r in rolls:
		if r.covers_house(house):
			out.append(r)
	return out


func silence_for(house: StringName) -> String:
	return String(silences.get(house, ""))


func roll(id: StringName) -> ObitRoll:
	for r in rolls:
		if r.id == id:
			return r
	return null

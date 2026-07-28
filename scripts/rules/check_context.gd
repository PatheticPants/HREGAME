class_name CheckContext
extends RefCounted

## Everything a check is allowed to look at, handed to it explicitly.
##
## No check reaches for a singleton, a node, or the scene tree. That restriction
## is the entire reason the rules can be run headless in a test, and the reason
## adding the Register as a source of law later is a field on this object rather
## than a refactor.

var documents: Array[DocumentData] = []
var matrices: Array[SealMatrix] = []

## id -> Reign / Polity.
var reigns: Dictionary = {}
var polities: Dictionary = {}

## The player's own past rulings. Empty on day one, consulted from day one, so
## that a precedent check is an addition rather than a migration.
var register: Register = null

var present_year: int = 0
var present_reign: StringName = &""


func reign(id: StringName) -> Reign:
	return reigns.get(id, null)


func polity(id: StringName) -> Polity:
	return polities.get(id, null)


func charter() -> CharterData:
	for d in documents:
		var ch := d as CharterData
		if ch != null:
			return ch
	return null


func matrices_for_owner(owner_name: String) -> Array[SealMatrix]:
	var out: Array[SealMatrix] = []
	var needle := owner_name.strip_edges().to_lower()
	for m in matrices:
		if m.owner_name.strip_edges().to_lower() == needle:
			out.append(m)
	return out


## The dating style the chancery that drew a charter would have used.
func chancery_style(ch: CharterData) -> int:
	var p := polity(ch.drawn_by_polity)
	return p.dating_style if p else Lex.Dating.ACCESSION

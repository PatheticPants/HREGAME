class_name Polity
extends Resource

## A named power of the Empire. Capped at seven on purpose — the whole game is
## learnability, and a player has to be able to hold every one of these in memory
## along with its one distinguishing habit.
##
## Each polity carries exactly one mechanical fingerprint beyond its colour:
##   - which event its chancery dates from  (dating_style)
##   - what happens to a seal matrix on the holder's death  (matrix_dies_with_holder)
##   - whether it seals at all  (seals_used)
## Everything else is flavour.

@export var id: StringName = &""
@export var name: String = ""
@export var short_name: String = ""

## Heraldic tincture. Used for the wax, the book plates, and the petitioner's
## placeholder figure, so a player learns the colour before they learn the name.
@export var color: Color = Color.WHITE
@export var device: StringName = &""

@export var succession: String = ""
@export var authority: int = Lex.Authority.IMPERIAL
@export var dating_style: int = Lex.Dating.ACCESSION

## Thurn breaks a dead man's matrix before witnesses; Marchfeld's seal belongs to
## the office and outlives every burgomaster who holds it. Same object, opposite
## rule, and a charter is valid or void depending on which.
@export var matrix_dies_with_holder: bool = true

## The Wends of the Nether March keep no seals. A Wendish charter bearing one is
## suspect on its face — a rule made of absence.
@export var seals_used: bool = true

@export var note: String = ""


func ink() -> Color:
	## Darker relative of the heraldic colour, for rules and lettering.
	return color.darkened(0.45)

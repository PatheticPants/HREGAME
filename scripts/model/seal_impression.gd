class_name SealImpression
extends Resource

## The wax actually hanging off the charter — what the player can see, no more.
##
## Deliberately mirrors SealMatrix field for field. The seal check is then a
## comparison between two objects of the same shape, which is what makes adding a
## new observable feature later (a counterseal, a tag of parchment, a cord colour)
## a one-line change in two files rather than a rewrite.

@export var id: StringName = &""

## Whose seal this *purports* to be. The impression names a person, not a die —
## the player has to work out which of that person's dies could have made it.
@export var claims_owner: String = ""
@export var claims_polity: StringName = &""

@export var device: StringName = &""
@export var legend: String = ""
@export var shape: StringName = &"round"
@export var wax_color: Color = Color(0.55, 0.11, 0.17)

## 0 = crisp, 1 = illegible. Old wax chips and rubs. Wear is not evidence of
## anything; a player who denies every worn seal will be wrong more than they are
## right, which is the lesson case one exists to teach.
@export var wear: float = 0.0

## Stable per-impression randomisation seed for the blob outline, so the same
## seal looks the same every time it is drawn.
@export var shape_seed: int = 0

@export var note: String = ""

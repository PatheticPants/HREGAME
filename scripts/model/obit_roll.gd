class_name ObitRoll
extends Resource

## One house's death-roll, as returned to this Chancery.
##
## THE WHOLE DESIGN IS IN THE LIMITS, NOT THE CONTENTS.
##
## A comprehensive imperial register of the dead would be an oracle: type a name,
## receive a verdict, and the judgement the game is about disappears. What makes
## this a source rather than an answer is that every roll is partial in three
## different ways at once —
##
##   it covers only the men of one house;
##   it is written up only to a certain year, and no further;
##   and it reckons in its own house's style, which is not always the Empire's.
##
## So "he is not in the roll" is worth nothing at all, and the check is obliged to
## say so out loud rather than quietly treating silence as life.

@export var id: StringName = &""

## The hand that returned it, as it heads its own section.
@export var hand: String = ""

## Whose dead this house actually keeps. Rendered verbatim on the page, because
## every finding about coverage has to be readable on the desk.
@export var covers: String = ""

@export var polity_id: StringName = &""

## Lex.Dating.ACCESSION or ELECTION. Every entry in this roll is dated in it.
## The Saint Wend chapter reckons from election like the rest of the Church, so a
## clerk who reduces its obits as an imperial notary would gets a number three
## years wrong. That is a trap, not a contest: the roll states its own reckoning
## on its own front page, which is what makes it fair.
@export var reckoning: int = Lex.Dating.ACCESSION

## How far this roll has been written up, in regnal form — so establishing where
## its knowledge stops costs an Almanac trip like every other date in the game.
@export var written_up_to_emperor: StringName = &""
@export var written_up_to_regnal_year: int = 0

@export var note: String = ""
@export var marginalia: String = ""

@export var entries: Array[Obit] = []


func covers_house(house: StringName) -> bool:
	return house != &"" and house == polity_id


func find(person_id: StringName) -> Obit:
	if person_id == &"":
		return null
	for e in entries:
		if e.person_id == person_id:
			return e
	return null

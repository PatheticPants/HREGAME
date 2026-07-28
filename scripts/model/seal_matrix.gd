class_name SealMatrix
extends Resource

## A known seal die, as recorded in the Book of Matrices on the desk.
##
## This is ground truth: what a genuine impression from this die looks like, and
## the years during which the die existed. Note there is no "is this a forgery"
## field anywhere in the data — a forgery is *derived* by asking whether any live
## matrix could have produced the impression in front of you. Store the answer and
## the rules stop being rules.

@export var id: StringName = &""
@export var owner_name: String = ""
@export var polity_id: StringName = &""

## Observable features. An impression carries the same four, so comparison is a
## field-by-field walk that never needs to know what a seal *is*.
@export var device: StringName = &""
@export var legend: String = ""
@export var shape: StringName = &"round"
@export var wax_color: Color = Color(0.55, 0.11, 0.17)

## The die was cut in this year and defaced in that one. -1 means still in use.
@export var cut_year: int = 0
@export var broken_year: int = -1

@export var note: String = ""


func was_live_in(year: int) -> bool:
	if year < cut_year:
		return false
	if broken_year >= 0 and year > broken_year:
		return false
	return true


func life_text() -> String:
	if broken_year < 0:
		return "cut %d, in use" % cut_year
	return "cut %d, broken %d" % [cut_year, broken_year]

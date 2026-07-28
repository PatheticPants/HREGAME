class_name BookPage
extends Resource

## One page of a physical reference book.
##
## Pages are typed rather than free text so the renderer can draw a matrix plate
## with the actual device on it, or lay out the regnal table in columns, without
## a data author having to describe layout. A new page kind is a new branch in
## reference_book.gd, not a new book.

@export var kind: StringName = &"text"  ## text | matrix | reigns | styles | plate
@export var heading: String = ""
@export var subheading: String = ""
@export_multiline var body: String = ""

## kind == "matrix": which die this plate shows.
@export var matrix_id: StringName = &""

## kind == "plate": a polity's arms and its one distinguishing habit.
@export var polity_id: StringName = &""

## Marginalia in a second hand. The previous notary annotated these books, and
## not everything he wrote was help.
@export_multiline var marginalia: String = ""

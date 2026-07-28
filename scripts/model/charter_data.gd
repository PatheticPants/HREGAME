class_name CharterData
extends DocumentData

## A charter: the thing being ruled on.

@export_multiline var body_text: String = ""

## The date as written on the parchment. A regnal year and an emperor, nothing
## more — turning that into a year is the player's job.
@export var date_emperor: StringName = &""
@export var date_regnal_year: int = 0

## Which chancery drew the document. Determines which epoch its regnal year is
## counted from, and therefore what the date actually says. This is the single
## most important field in the schema and it is easy to miss, which is the point.
@export var drawn_by_polity: StringName = &""

@export var witnesses: Array[Witness] = []

@export var claimant: String = ""
@export var grantor: String = ""
@export var property: String = ""

## Stable legal identity. Prose may change between instruments; these do not.
## They let the Register recognize the same land and distinguish a cured title
## from a competing claimant without case-specific branching.
@export var subject_id: StringName = &""
@export var claimant_id: StringName = &""
@export var supersedes_prior_instrument := false

## The attached wax. Physically a separate object on a cord, legally part of the
## charter — which is why forging one is worth doing.
@export var seal: SealImpression = null

## Places where the skin has been scraped and rewritten. Invisible to every other
## check in the project, because every other check reads what the parchment says
## and this is about what it used to say. See scripts/model/erasure.gd.
@export var erasures: Array[Erasure] = []


func date_phrase(reign_name: String) -> String:
	return "in the %s year of %s" % [Lex.ordinal(date_regnal_year), reign_name]

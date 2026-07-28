class_name Erasure
extends Resource

## A place where the skin has been scraped and written over.
##
## The commonest real medieval forgery was not a fabricated charter. It was a
## GENUINE one with a clause quietly improved: scrape the nap off the vellum with
## a knife, let it dry, write the year you would rather it said. The seal is real,
## the die was alive, the witnesses were in the room, the hand is the right hand
## for the decade — and the instrument is still false.
##
## That is a failure mode nothing else in this game can catch, because every other
## check reads what the parchment says and this one is about what it USED to say.
##
## Detection is physical, and it is the reason the notary has a flame on the desk
## rather than a lamp: scraped skin is thinner than the skin around it, so held up
## against a light it transmits, and the ghost of the removed word comes through.

## Where on the sheet, as fractions of its own size, so a patch stays registered
## whatever a document's dimensions are.
@export var region: Rect2 = Rect2(0.1, 0.1, 0.2, 0.06)

## Which field of the instrument was altered. Prose, in the chancery's own terms:
## "the year", "the name of the grantee", "the extent of the wood".
@export var altered_field: String = ""

## What the flame brings back. Empty means the scrape is legible as a scrape and
## nothing survives of what was under it — which is its own, worse finding.
@export var original_value: String = ""

## A scribe correcting his own slip before the wax went on. Universal, honest,
## and the reason this cannot simply be "scraped means forged": a rule that
## convicts on the presence of an erasure would convict most genuine charters in
## Europe, and it is the same lesson the first case teaches about a worn seal.
@export var innocent: bool = false

## Whether the altered field is one the instrument's force depends on. A tidied
## spelling in the arenga is nothing; a changed year moves land.
@export var dispositive: bool = true

@export var note: String = ""

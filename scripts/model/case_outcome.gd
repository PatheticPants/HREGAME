class_name CaseOutcome
extends Resource

## What follows from ruling a particular way.
##
## Whether a ruling is *lawful* is derived by the rules engine from the documents.
## Whether it is *useful to somebody* cannot be derived — it is politics, and
## politics is authored. So soundness comes from the Adjudicator and favour comes
## from here, and the two are allowed to disagree. They usually do.

@export var verdict: int = Lex.Verdict.NONE

## Authority enum -> signed favour. Positive means that power is pleased.
@export var favor: Dictionary = {}

## The line the Register receives. Written in the notary's own hand, so it is
## terse and slightly defensive, the way real marginalia is.
@export_multiline var register_note: String = ""

## What the petitioner says or does on hearing it.
@export_multiline var reaction: String = ""

## What the day's ledger records once the room is empty. This is where a ruling
## is allowed to turn out to have consequences the notary did not intend.
@export_multiline var aftermath: String = ""

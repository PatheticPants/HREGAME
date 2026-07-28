class_name DocketData
extends DocumentData

## The chancery's own cover slip, filled in by the doorkeeper before the
## petitioner is let through.
##
## This exists to solve a real problem: the petitioner says their piece once, and
## if you then bury the charter under two books you have no way to recall what
## they claimed. The docket is where their words are written down, so the claim
## survives being forgotten. It is also, quietly, the tutorial — everything you
## need to start is on it.

@export var petitioner_name: String = ""
@export var petitioner_style: String = ""
@export_multiline var claim_summary: String = ""
@export var received_note: String = ""

## The doorkeeper's own remark. Sometimes useful, sometimes just a man being
## rude about a widow. Never authoritative.
@export_multiline var doorkeeper_note: String = ""

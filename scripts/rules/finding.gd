class_name Finding
extends Resource

## One observation about a packet, produced by a check.
##
## Checks never decide anything. They report, in this shape, and the verdict
## policy turns a pile of these into a ruling. That indirection is what lets a
## future check (genealogy, palaeography, jurisdiction) be dropped in without
## touching the ruling logic, and lets the ruling logic be retuned in a .tres
## without touching any check.

@export var code: StringName = &""
@export var severity: int = Lex.Severity.CLEAN

## Which body of law is making this observation. NONE means all of them agree.
@export var authority: int = Lex.Authority.NONE

## Document id the finding is about, for highlighting later.
@export var subject: StringName = &""

@export var headline: String = ""
@export_multiline var detail: String = ""

## Only meaningful on CONTESTED findings: authority enum -> the verdict that
## authority would reach on its own. This is how "which authority am I choosing
## to satisfy" becomes a data structure rather than a theme.
@export var authority_verdicts: Dictionary = {}

## Findings the player could have used to reach the truth. Quoted back in the
## ledger when they get it wrong, so a miss teaches rather than scolds.
@export var is_hint: bool = false


static func make(p_code: StringName, p_severity: int, p_headline: String,
		p_detail: String = "", p_subject: StringName = &"") -> Finding:
	var f := Finding.new()
	f.code = p_code
	f.severity = p_severity
	f.headline = p_headline
	f.detail = p_detail
	f.subject = p_subject
	return f


static func hint(p_code: StringName, p_headline: String, p_detail: String = "",
		p_subject: StringName = &"") -> Finding:
	var f := make(p_code, Lex.Severity.NOTE, p_headline, p_detail, p_subject)
	f.is_hint = true
	return f

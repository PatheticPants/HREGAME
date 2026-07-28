class_name Lex
extends RefCounted

## Shared vocabulary for the rules layer.
##
## Everything the law can *say* is an enum here, so no other script invents its
## own string constants. Presentation code may read these; it may not add to them.

enum Verdict { NONE, CONFIRM, DENY, REFER }

## Severity of a single finding. Order matters: the verdict policy walks these
## from most to least severe, so anything inserted must keep the ranking.
enum Severity {
	CLEAN,      ## check ran, nothing to report
	NOTE,       ## an anomaly that is explicable — wear, an old spelling
	DEFECT,     ## the document is wrong, but not necessarily dishonest
	CONTESTED,  ## two authorities disagree; not the notary's to resolve
	FATAL,      ## the document is a forgery or otherwise void
}

## Which body of law is speaking. The point of the game is that these disagree.
enum Authority { NONE, IMPERIAL, CHURCH, CUSTOM, OFFICE }

## Which event a chancery counts regnal years from. See RegnalMath.
enum Dating { ACCESSION, ELECTION, CORONATION }

## Craft grade for a single wax impression. Purely about the player's hands,
## never about whether the ruling was legally right.
enum Grade { FINE, GOOD, THIN, BLOTTED, SMEARED, SHALLOW }


static func verdict_name(v: int) -> String:
	match v:
		Verdict.CONFIRM: return "Confirmed"
		Verdict.DENY: return "Denied"
		Verdict.REFER: return "Referred"
		_: return "Unruled"


static func verdict_from_string(s: String) -> int:
	match s.strip_edges().to_upper():
		"CONFIRM": return Verdict.CONFIRM
		"DENY": return Verdict.DENY
		"REFER": return Verdict.REFER
		_: return Verdict.NONE


static func authority_name(a: int) -> String:
	match a:
		Authority.IMPERIAL: return "the Empire"
		Authority.CHURCH: return "the Church"
		Authority.CUSTOM: return "regional custom"
		Authority.OFFICE: return "this office's precedent"
		_: return "no authority"


static func authority_from_string(s: String) -> int:
	match s.strip_edges().to_lower():
		"imperial": return Authority.IMPERIAL
		"church": return Authority.CHURCH
		"custom": return Authority.CUSTOM
		"office", "precedent": return Authority.OFFICE
		_: return Authority.NONE


static func dating_from_string(s: String) -> int:
	match s.strip_edges().to_lower():
		"election": return Dating.ELECTION
		"coronation": return Dating.CORONATION
		_: return Dating.ACCESSION


static func dating_name(d: int) -> String:
	match d:
		Dating.ELECTION: return "from election"
		Dating.CORONATION: return "from coronation"
		_: return "from accession"


static func grade_name(g: int) -> String:
	match g:
		Grade.FINE: return "fine"
		Grade.GOOD: return "sound"
		Grade.THIN: return "thin"
		Grade.BLOTTED: return "blotted"
		Grade.SMEARED: return "smeared"
		Grade.SHALLOW: return "shallow"
		_: return "unknown"


## Roman-ish ordinal words, for charter body text. Beyond twenty we fall back to
## digits; no charter in this slice needs it, but a data author might try.
const ORDINALS := [
	"", "first", "second", "third", "fourth", "fifth", "sixth", "seventh",
	"eighth", "ninth", "tenth", "eleventh", "twelfth", "thirteenth",
	"fourteenth", "fifteenth", "sixteenth", "seventeenth", "eighteenth",
	"nineteenth", "twentieth",
]


static func ordinal(n: int) -> String:
	if n > 0 and n < ORDINALS.size():
		return ORDINALS[n]
	return str(n)


## Sentence case: raise the first letter and leave everything else alone.
##
## Deliberately NOT String.capitalize(), which title-cases every word and also
## splits snake_case — so "a sound seal" comes back as "A Sound Seal" and
## "regional custom" as "Regional Custom". That is almost never what running
## prose wants, and this game is nearly all running prose.
static func sentence(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)

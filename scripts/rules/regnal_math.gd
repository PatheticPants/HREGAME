class_name RegnalMath
extends RefCounted

## Converting "the ninth year of Emperor Aldric" into a year.
##
## This is not a lookup. A regnal year only becomes a date once you know which
## event that particular chancery counts from, and the Empire's chanceries do not
## agree:
##
##   * Imperial notaries count from ACCESSION — the day the previous emperor died.
##   * The Church counts from ELECTION — the day he was chosen King of the Romans,
##     which happens in his predecessor's lifetime and can precede accession by
##     years.
##   * A few count from CORONATION at Rome, which comes later still.
##
## So one phrase names up to three different years, and a date that is impossible
## under one reckoning is perfectly ordinary under another. Every function here is
## pure and takes the style explicitly; nothing is allowed to assume a default.

static func epoch_for(reign: Reign, style: int) -> int:
	if reign == null:
		return 0
	match style:
		Lex.Dating.ELECTION:
			return reign.election_year
		Lex.Dating.CORONATION:
			return reign.coronation_year
		_:
			return reign.accession_year


## Year 1 is the epoch year itself, hence the -1. Getting this wrong by one is
## the classic palaeographer's error and would quietly break every case.
static func to_absolute(reign: Reign, regnal_year: int, style: int) -> int:
	return epoch_for(reign, style) + regnal_year - 1


static func from_absolute(reign: Reign, absolute_year: int, style: int) -> int:
	return absolute_year - epoch_for(reign, style) + 1


## Highest regnal year the reign can support under this reckoning. A coronation
## epoch that never happened (year 0) makes the style inapplicable, which returns
## 0 rather than a nonsense number.
static func max_regnal_year(reign: Reign, style: int, present_year: int) -> int:
	if reign == null:
		return 0
	var epoch := epoch_for(reign, style)
	if epoch <= 0:
		return 0
	var last := reign.end_year if reign.end_year >= 0 else present_year
	return last - epoch + 1


static func style_applies(reign: Reign, style: int) -> bool:
	return reign != null and epoch_for(reign, style) > 0


## Is this regnal year sayable at all under this reckoning?
static func is_admissible(reign: Reign, regnal_year: int, style: int, present_year: int) -> bool:
	if not style_applies(reign, style):
		return false
	if regnal_year < 1:
		return false
	if regnal_year > max_regnal_year(reign, style, present_year):
		return false
	# A date the scribe could not yet have written.
	return to_absolute(reign, regnal_year, style) <= present_year


static func describe(reign: Reign, regnal_year: int, style: int) -> String:
	if reign == null:
		return "an unrecorded reign"
	return "%s of %s (%s) = %d" % [
		Lex.sentence(Lex.ordinal(regnal_year)),
		reign.full_name(),
		Lex.dating_name(style),
		to_absolute(reign, regnal_year, style),
	]


## Canonical reckoning for each body of law. Custom resolves to whatever the
## drawing chancery itself uses, which is why it is passed in.
static func style_for_authority(authority: int, chancery_style: int) -> int:
	match authority:
		Lex.Authority.CHURCH:
			return Lex.Dating.ELECTION
		Lex.Authority.IMPERIAL:
			return Lex.Dating.ACCESSION
		_:
			return chancery_style

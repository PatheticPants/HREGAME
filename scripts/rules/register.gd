class_name Register
extends RefCounted

## The book of what has already been ruled.
##
## In the campaign this becomes a third source of law: a petitioner may cite the
## player's own precedent back at them, correctly, and the player has to live
## with a position they took three weeks ago for reasons that seemed adequate at
## the time. Only one day of it exists in this slice — but it is written from the
## first ruling and read by the third case's dialogue, which is enough to prove
## the architecture holds.
##
## It also carries the previous notary's entries, which are not all what they
## look like.

var entries: Array[RulingRecord] = []


func add(record: RulingRecord) -> void:
	entries.append(record)


## The history that genuinely existed when `record` was decided. Feedback must
## never re-adjudicate a case against the entry produced by that same decision,
## nor against rulings made later in the day.
func before(record: RulingRecord) -> Register:
	var earlier := Register.new()
	for entry in entries:
		if entry == record:
			break
		earlier.add(entry)
	return earlier


func find(case_id: StringName) -> RulingRecord:
	for e in entries:
		if e.case_id == case_id:
			return e
	return null


func has_ruled(case_id: StringName) -> bool:
	return find(case_id) != null


func has_player_ruling(case_id: StringName) -> bool:
	var entry := find(case_id)
	return entry != null and not entry.foreign_hand


func entries_for_day(day_id: StringName) -> Array[RulingRecord]:
	var out: Array[RulingRecord] = []
	for e in entries:
		if not e.foreign_hand and e.day_id == day_id:
			out.append(e)
	return out


func latest_for_subject(subject_id: StringName) -> RulingRecord:
	for i in range(entries.size() - 1, -1, -1):
		var e := entries[i]
		if not e.foreign_hand and e.subject_id == subject_id:
			return e
	return null


func own_entries() -> Array[RulingRecord]:
	var out: Array[RulingRecord] = []
	for e in entries:
		if not e.foreign_hand:
			out.append(e)
	return out


func sound_count() -> int:
	var n := 0
	for e in own_entries():
		if e.was_sound:
			n += 1
	return n


func ruled_count() -> int:
	return own_entries().size()


func sound_count_for_day(day_id: StringName) -> int:
	var n := 0
	for e in entries_for_day(day_id):
		if e.was_sound:
			n += 1
	return n


## What fraction of a day's rulings the law agreed with. 1.0 for a day with
## nothing in it, because a notary who was never called cannot have been wrong.
##
## SOUNDNESS BUYS CANDLE, AND THIS IS THE ONLY THING IT HAS EVER BOUGHT. It is
## not a score and it is not combined with anything: it scales the stub the
## player carries into tomorrow, and it does that because the clock is the only
## thing in this game the player actually wants. Without it a tightened day
## rewards guessing — bank the time you would have spent in the Kalendar, take
## the odds, and nothing whatever happens to you. See
## SessionController._begin_day.
func sound_fraction_for_day(day_id: StringName) -> float:
	var day_entries := entries_for_day(day_id)
	if day_entries.is_empty():
		return 1.0
	return float(sound_count_for_day(day_id)) / float(day_entries.size())


## authority enum -> accumulated favour across every ruling made today.
func favor_totals() -> Dictionary:
	var totals := {}
	for e in own_entries():
		for a in e.favor:
			totals[a] = int(totals.get(a, 0)) + int(e.favor[a])
	return totals


## Craft, not law. How the player's hands did.
func impression_grades() -> Array[int]:
	var out: Array[int] = []
	for e in own_entries():
		if e.impression != null:
			out.append(e.impression.grade)
	return out


## Placeholder for the campaign's precedent check: given a finding code, has this
## office already tolerated it? Unused this slice, deliberately present, because
## the day it is needed it must not require a schema change.
func precedent_for(reason_code: StringName) -> Array[RulingRecord]:
	var out: Array[RulingRecord] = []
	for e in entries:
		if e.reason_code == reason_code:
			out.append(e)
	return out

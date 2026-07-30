class_name DayCaseSlot
extends Resource

## One place in a day's docket. A consequence case can exist only when its
## predecessor was actually ruled; otherwise the unheard matter itself returns.

@export var case_id: StringName = &""
@export var requires_ruled: StringName = &""

## THE INVERSE GATE, and the only tool that lets a matter chase you.
##
## `requires_ruled` SUBSTITUTES — you get the widow instead of her follow-up.
## `requires_unruled` REMOVES — the slot is there only while this desk has never
## ruled on the named matter, and when it has, it resolves to `fallback_case_id`
## or, left empty, to nothing at all. `LoreData.case_by_id(&"")` returns null and
## `DayData.resolve_cases()` already skips nulls, so an absent slot costs nothing.
##
## That is what a day of arrears is made of: every matter the week never heard,
## and no matter it did.
@export var requires_unruled: StringName = &""
@export var fallback_case_id: StringName = &""


func resolve(lore: LoreData, register: Register) -> CaseData:
	var chosen := case_id
	if requires_ruled != &"" and not _ruled(register, requires_ruled):
		chosen = fallback_case_id
	# elif, not a second if. The two gates share one fallback, so testing them
	# independently would let the second silently overwrite the first and make
	# the pair order-dependent instead of meaningless. Setting both is rejected
	# by the content validator rather than resolved by luck here.
	elif requires_unruled != &"" and _ruled(register, requires_unruled):
		chosen = fallback_case_id
	return lore.case_by_id(chosen)


## An entry in the previous notary's hand is not this desk's ruling, which is
## what has_player_ruling() already means. A null register is a day resolved with
## no history at all, and no history means nothing has been ruled — Adjudicator
## already accepts a null register, and this used to crash on one.
static func _ruled(register: Register, id: StringName) -> bool:
	return register != null and register.has_player_ruling(id)

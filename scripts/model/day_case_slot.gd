class_name DayCaseSlot
extends Resource

## One place in a day's docket. A consequence case can exist only when its
## predecessor was actually ruled; otherwise the unheard matter itself returns.

@export var case_id: StringName = &""
@export var requires_ruled: StringName = &""
@export var fallback_case_id: StringName = &""


func resolve(lore: LoreData, register: Register) -> CaseData:
	var chosen := case_id
	if requires_ruled != &"" and not register.has_player_ruling(requires_ruled):
		chosen = fallback_case_id
	return lore.case_by_id(chosen)

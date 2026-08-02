class_name DocketSlip
extends Draggable

## One named matter protruding from the passage tray. It is not a menu item:
## the player pulls the paper free and lays it in the hearing notch.

const SIZE := Vector2(286, 92)

var case_data: CaseData = null
var slot_index := 0
var selected := false


func bind(c: CaseData, index: int, desk_bounds: Rect2) -> void:
	case_data = c
	slot_index = index
	name = "docket_slip_" + String(c.id)
	hit_size = SIZE
	weight = 0.72
	pickup_sound = &"paper_pickup"
	drop_sound = &"paper_drop"
	slide_sound = &"paper_slide"
	var at: Vector2 = DocketTray.SLOT_CENTERS[
		mini(index, DocketTray.SLOT_CENTERS.size() - 1)]
	setup(at, deg_to_rad(-2.2 + index * 1.35), desk_bounds)


func case_id() -> StringName:
	return case_data.id if case_data != null else &""


func _draw() -> void:
	if case_data == null:
		return
	var r := Rect2(-SIZE * 0.5, SIZE)
	draw_soft_shadow(r, 0.7)
	var paper := Color(0.80, 0.72, 0.56)
	paper = paper.lerp(Color(0.98, 0.79, 0.45), light_level * 0.16)
	draw_rect(r, paper)
	draw_rect(r, paper.darkened(0.34), false, 1.0)
	draw_line(r.position + Vector2(2, 2),
		Vector2(r.end.x - 2, r.position.y + 2), paper.lightened(0.25), 1.0)

	var docket := case_data.documents[0] as DocketData \
		if not case_data.documents.is_empty() else null
	var at := r.position + Vector2(14, 10)
	at.y += Ink.label(self, at, "PASSAGE DOCKET  %02d" % (slot_index + 1),
		8, Ink.FADED)
	at.y += 2
	# The claim block below starts at x+135, so a long title set at full size runs
	# under it and then off the slip. Both of these sit above it vertically, so
	# the width is the slip less its two margins.
	var text_w := SIZE.x - 28.0
	at.y += Ink.line_fit(self, at, case_data.title, 13, Ink.CHANCERY, text_w)
	var petitioner_name := case_data.petitioner.name if case_data.petitioner else ""
	Ink.line_fit(self, at, petitioner_name, 9, Ink.FADED, text_w)
	if docket != null:
		var claim := docket.claim_summary
		if claim.length() > 72:
			claim = claim.substr(0, 69).strip_edges() + "…"
		Ink.block(self, r.position + Vector2(135, 49), claim, 8,
			Color(Ink.CHANCERY, 0.78), 132)

	# The tray sits on the back rail, which is the furthest thing on the desk
	# from wherever the candle usually stands. Choosing who to hear should cost
	# a trip with the light, not be free from the chair.
	draw_shade(r)

	if selected:
		draw_rect(r.grow(-3), Color(Ink.RUBRIC, 0.65), false, 2.0)

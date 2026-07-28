class_name DocketView
extends Sheet

## The chancery's own cover slip, filled in at the door before the petitioner is
## let through.
##
## It exists to solve a real problem the brief's scope creates: a petitioner says
## their piece once, and if you then bury the charter under two open books you
## have no way to recall what was claimed. The docket is where the claim survives
## being forgotten. It is also, quietly, the tutorial — nothing on it is a rule,
## but everything you need in order to start is written down.
##
## The doorkeeper's remark at the bottom is never authoritative. He is sometimes
## helpful and sometimes just a man being unkind about a widow.

const MARGIN := 20.0


func docket_data() -> DocketData:
	return data as DocketData


func _draw_face(r: Rect2) -> void:
	var d := docket_data()
	if d == null:
		return
	var w := r.size.x - MARGIN * 2.0
	var at := r.position + Vector2(MARGIN, MARGIN * 0.7)

	var paper_label := d.title.to_lower() if not d.title.is_empty() else "docket"
	at.y += Ink.label(self, at, paper_label, 10, Ink.FADED)
	at.y += 3.0
	Ink.rule(self, at, w, Ink.FADED * Color(1, 1, 1, 0.5))
	at.y += 7.0

	at.y += Ink.line(self, at, d.petitioner_name, 16, Ink.CHANCERY)
	if not d.petitioner_style.is_empty():
		at.y += Ink.line(self, at, d.petitioner_style, 12, Ink.FADED)
	at.y += 7.0

	at.y += Ink.block(self, at, d.claim_summary, 13, Ink.CHANCERY, w)
	at.y += 6.0

	if not d.received_note.is_empty():
		at.y += Ink.block(self, at, d.received_note, 11, Ink.FADED, w)

	# The doorkeeper writes in the bottom margin, at a slant, in his own ink.
	if not d.doorkeeper_note.is_empty():
		var foot := Vector2(r.position.x + MARGIN, r.end.y - MARGIN - 30.0)
		Ink.margin_note(self, foot, d.doorkeeper_note, 11, w, -2.5,
			Color(0.36, 0.30, 0.22))

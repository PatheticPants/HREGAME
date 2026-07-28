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


## How far down the slip the flowed text reaches, before the doorkeeper's note
## is pinned to the foot.
##
## Kept beside _draw_face and mirroring it exactly, so the suite can check that a
## docket's authored text actually fits the parchment it is printed on. Nothing
## clips a Sheet: Ink.block passes max_lines = -1, so an over-long claim is drawn
## straight off the bottom edge and the doorkeeper's note lands on the blotter.
## The guard below only stops the two colliding; it cannot make room that is not
## there.
##
## KEEP IN STEP WITH _draw_face.
func content_bottom() -> float:
	var d := docket_data()
	if d == null:
		return 0.0
	var r := rect()
	var w := r.size.x - MARGIN * 2.0
	var y := r.position.y + MARGIN * 0.7
	y += Ink.line_height(10) + 3.0 + 7.0
	y += Ink.line_height(16)
	if not d.petitioner_style.is_empty():
		y += Ink.line_height(12)
	y += 7.0
	y += Ink.measure(d.claim_summary, 13, w).y + 13 * 0.25 + 6.0
	if not d.received_note.is_empty():
		y += Ink.measure(d.received_note, 11, w).y + 11 * 0.25
	if not d.doorkeeper_note.is_empty():
		var note_h := Ink.measure(d.doorkeeper_note, 11, w).y
		y = maxf(y + 10.0, r.end.y - MARGIN - note_h) + note_h
	return y


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
	#
	# Pinned to the foot of the sheet, which is right until the flowed text above
	# it is long enough to reach the foot as well — and then two paragraphs are
	# drawn on top of each other and both become unreadable. On the desk memorandum
	# that is R.V.'s instruction about CONFIRM and REFER printed over his
	# instruction about the candle, i.e. the whole tutorial. CharterView._draw_closing
	# already guards its own footer this way; this is the same guard.
	if not d.doorkeeper_note.is_empty():
		# The foot is sized from the note, not from a flat 30 px. The guard above
		# stops the doorkeeper's hand landing on top of the flowed text; it did
		# nothing about the note itself being taller than the space reserved for
		# it, so a three-line note was pinned to a two-line foot and its last
		# line was drawn off the bottom of the parchment onto the desk. Same
		# defect as the reference books' marginalia, in a second file.
		var note_h := Ink.measure(d.doorkeeper_note, 11, w).y
		var foot := Vector2(r.position.x + MARGIN,
			maxf(at.y + 10.0, r.end.y - MARGIN - note_h))
		Ink.margin_note(self, foot, d.doorkeeper_note, 11, w, -2.5,
			Color(0.36, 0.30, 0.22))

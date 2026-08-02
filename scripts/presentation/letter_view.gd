class_name LetterView
extends Sheet

const MARGIN := 24.0


func letter_data() -> LetterData:
	return data as LetterData


func _draw_face(r: Rect2) -> void:
	var letter := letter_data()
	if letter == null:
		return
	var width := r.size.x - MARGIN * 2.0
	var at := r.position + Vector2(MARGIN, MARGIN * 0.7)
	at.y += Ink.label(self, at, "SEALED CORRESPONDENCE", 9, Ink.RUBRIC)
	at.y += 4
	at.y += Ink.heading(self, at, letter.title, 16, Ink.CHANCERY, width)
	at.y += 8
	if not letter.sender.is_empty():
		at.y += Ink.line_fit(self, at, "From:  " + letter.sender, 10, Ink.FADED,
			width)
	if not letter.recipient.is_empty():
		at.y += Ink.line_fit(self, at, "To:  " + letter.recipient, 10, Ink.FADED,
			width)
	at.y += 8
	at.y += Ink.block(self, at, letter.body, 12, Ink.CHANCERY, width)
	at.y += 10
	if not letter.closing.is_empty():
		at.y += Ink.margin_note(self, at, letter.closing, 11, width, -2.0)

	var seal_y := r.end.y - MARGIN - 22
	for i in letter.endorsements.size():
		var x := r.position.x + MARGIN + i * 118.0
		draw_circle(Vector2(x + 12, seal_y), 12,
			Color(0.46, 0.07, 0.09, 0.82))
		Ink.label(self, Vector2(x + 30, seal_y - 6),
			letter.endorsements[i], 8, Ink.FADED)

class_name Ledger
extends Draggable

signal next_day_requested

## The day's ledger. The whole of the feedback, and the whole of the score screen.
##
## It is a book. It lands on the desk with a thud, opens, and writes itself out a
## line at a time in the clerk's hand while a quill scratches. There is no results
## panel, no tally of points, no stars. What you get is a page of prose that says
## what you ruled, what the law said, what it cost, and — in a second hand, in the
## margin — something the previous occupant of this desk wrote that you were not
## meant to read yet.
##
## Three columns of judgement, never combined into one number:
##   soundness  did you follow the law
##   favour     who is pleased with you
##   craft      how your hands did
## They are allowed to disagree. Making them one score would be the single
## fastest way to ruin this game.

const MARGIN := 30.0
const SIZE := Vector2(760, 560)

## Lines are dictionaries so a caller can compose a page without a class per row.
##   kind: text | rule | gap | note | heading
var lines: Array[Dictionary] = []

var revealed := 0.0
var reveal_rate := 7.0
var spread := 0
var allow_next_day := false
var next_day_label := "NEXT DAY"

var _pages: Array[Array] = []
var _last_scratch := -1
var _arrived := 0.0


func _ready() -> void:
	super._ready()
	hit_size = SIZE
	pickup_sound = &"book_close"
	drop_sound = &"ledger_thud"
	slide_sound = &"paper_slide"
	occludes_light = true
	occluder_inset = 0.94
	z_index = 6
	visible = false


func open_with(new_lines: Array[Dictionary], desk_bounds: Rect2, at: Vector2) -> void:
	lines = new_lines
	revealed = 0.0
	spread = 0
	_last_scratch = -1
	_arrived = 0.0
	_paginate()
	visible = true
	setup(at, deg_to_rad(randf_range(-1.5, 1.5)), desk_bounds)
	Audio.play(&"ledger_thud", at)
	Audio.play(&"book_open", at)


func total_lines() -> int:
	return lines.size()


func is_finished() -> bool:
	return revealed >= float(lines.size())


func skip_to_end() -> void:
	revealed = float(lines.size())


func spread_count() -> int:
	return int(ceil(_pages.size() / 2.0))


func on_click(local: Vector2) -> bool:
	if not is_finished():
		skip_to_end()
		return true
	var half := SIZE.x * 0.5
	if local.x > half * 0.55 and spread + 1 < spread_count():
		spread += 1
		Audio.play(&"page_turn", global_position)
		return true
	if local.x < -half * 0.55 and spread > 0:
		spread -= 1
		Audio.play(&"page_turn", global_position)
		return true
	if allow_next_day and spread + 1 == spread_count() \
			and local.x > half - 58.0 and local.y > SIZE.y * 0.5 - 64.0:
		allow_next_day = false
		Audio.play(&"page_turn", global_position)
		next_day_requested.emit()
		return true
	return false


func _process(delta: float) -> void:
	super._process(delta)
	if not visible:
		return
	_arrived = move_toward(_arrived, 1.0, delta * 2.2)
	if revealed < float(lines.size()):
		revealed = minf(float(lines.size()), revealed + delta * reveal_rate)
		var whole := int(revealed)
		if whole != _last_scratch:
			_last_scratch = whole
			# One scratch per line written, skipping the blanks — the sound is
			# the pacing, so it must not fire on a gap.
			if whole > 0 and whole <= lines.size():
				var kind: String = lines[whole - 1].get("kind", "text")
				if kind == "text" or kind == "heading" or kind == "note":
					Audio.play(&"quill_scratch", global_position, -4.0)
	queue_redraw()


# ------------------------------------------------------------------ layout

func _paginate() -> void:
	_pages = []
	var page: Array = []
	var y := 0.0
	var limit := SIZE.y - MARGIN * 2.4
	var width := SIZE.x * 0.5 - MARGIN * 2.0
	for i in lines.size():
		var h := _line_height(lines[i], width)
		if y + h > limit and not page.is_empty():
			_pages.append(page)
			page = []
			y = 0.0
		page.append(i)
		y += h
	if not page.is_empty():
		_pages.append(page)


func _line_height(l: Dictionary, width: float) -> float:
	match String(l.get("kind", "text")):
		"gap": return float(l.get("size", 10))
		"rule": return 9.0
		_:
			var size := int(l.get("size", 12))
			var indent := float(l.get("indent", 0.0))
			return Ink.measure(String(l.get("text", "")), size,
				width - indent).y + size * 0.30


# ----------------------------------------------------------------- drawing

func _draw() -> void:
	var lift := (1.0 - ease(_arrived, 0.3)) * 40.0
	var r := Rect2(-SIZE * 0.5 - Vector2(0, lift), SIZE)

	draw_soft_shadow(r)
	draw_rect(r.grow(8.0), Color(0.20, 0.13, 0.09))
	draw_rect(r.grow(5.0), Color(0.29, 0.19, 0.12))

	var pw := SIZE.x * 0.5
	var left := Rect2(r.position + Vector2(6, 6), Vector2(pw - 9, r.size.y - 12))
	var right := Rect2(Vector2(r.position.x + pw + 3, r.position.y + 6),
		Vector2(pw - 9, r.size.y - 12))
	for pr in [left, right]:
		draw_rect(pr, Color(0.91, 0.87, 0.76))
		draw_rect(pr, Color(0.68, 0.62, 0.50), false, 1.0)
	for i in 8:
		var t := float(i) / 8.0
		draw_rect(Rect2(r.position.x + pw - 11.0 * (1.0 - t), r.position.y + 6,
			22.0 * (1.0 - t), r.size.y - 12), Color(0, 0, 0, 0.09))

	_draw_page(left, spread * 2)
	_draw_page(right, spread * 2 + 1)

	if is_finished() and spread + 1 < spread_count():
		var c := right.end
		draw_colored_polygon(PackedVector2Array([
			c, c - Vector2(28, 0), c - Vector2(0, 28)]), Color(0.83, 0.78, 0.66))
	elif is_finished() and allow_next_day and spread + 1 == spread_count():
		var c := right.end
		draw_colored_polygon(PackedVector2Array([
			c, c - Vector2(54, 0), c - Vector2(0, 54)]), Color(0.74, 0.66, 0.51))
		Ink.label(self, c - Vector2(50, 17), next_day_label.to_upper(), 8,
			Ink.CHANCERY)


func _draw_page(r: Rect2, page_index: int) -> void:
	if page_index >= _pages.size():
		return
	var width := r.size.x - MARGIN * 2.0
	var at := r.position + Vector2(MARGIN, MARGIN * 0.9)

	for i in _pages[page_index]:
		if float(i) >= revealed:
			return
		var l: Dictionary = lines[i]
		var kind := String(l.get("kind", "text"))
		var indent := float(l.get("indent", 0.0))
		var size := int(l.get("size", 12))
		var col: Color = l.get("color", Ink.CHANCERY)
		var text := String(l.get("text", ""))

		# The line currently being written fades in over its own width, so it
		# reads as the nib moving rather than as text appearing.
		var partial := clampf(revealed - float(i), 0.0, 1.0)

		match kind:
			"gap":
				at.y += float(size)
			"rule":
				Ink.rule(self, at + Vector2(indent, 3), width - indent,
					Color(col, 0.4 * partial))
				at.y += 9.0
			"heading":
				at.y += Ink.line(self, at + Vector2(indent, 0), text, size,
					Color(col, partial))
				Ink.rule(self, at + Vector2(indent, -2), width - indent,
					Color(col, 0.35 * partial))
				at.y += 4.0
			"note":
				at.y += Ink.margin_note(self, at + Vector2(indent, 0), text, size,
					width - indent, -3.0, Color(Ink.SECOND_HAND, partial))
			_:
				at.y += Ink.block(self, at + Vector2(indent, 0), text, size,
					Color(col, partial), width - indent)


# ------------------------------------------------------- line-building helpers
# Used by the session to compose the day's page without knowing how it is drawn.

static func text(s: String, size := 12, col := Ink.CHANCERY, indent := 0.0) -> Dictionary:
	return {"kind": "text", "text": s, "size": size, "color": col, "indent": indent}


static func heading(s: String, size := 14, col := Ink.CHANCERY) -> Dictionary:
	return {"kind": "heading", "text": s, "size": size, "color": col}


static func rubric(s: String, size := 12, indent := 0.0) -> Dictionary:
	return text(s, size, Ink.RUBRIC, indent)


static func note(s: String, size := 11) -> Dictionary:
	return {"kind": "note", "text": s, "size": size}


static func gap(px := 10) -> Dictionary:
	return {"kind": "gap", "size": px}


static func rule_line(col := Ink.FADED) -> Dictionary:
	return {"kind": "rule", "color": col}

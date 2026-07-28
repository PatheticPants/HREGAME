extends SceneTree

## TEMPORARY probe: replicate CharterView._draw_face's y-cursor exactly and
## report where the date block actually lands versus the authored erasure.

const MARGIN := 26.0


func _init() -> void:
	var lore := ContentLoader.load_all()
	for c in lore.cases:
		var ch := c.charter()
		if ch == null or ch.erasures.is_empty():
			continue
		_probe(c.id, ch, lore)
	quit()


func _probe(case_id: StringName, ch: CharterData, lore: LoreData) -> void:
	var f := ThemeDB.fallback_font
	var r := Rect2(-ch.size * 0.5, ch.size)
	var w: float = r.size.x - MARGIN * 2.0
	var at := r.position + Vector2(MARGIN, MARGIN * 0.75)
	print("\n================ ", case_id, "  size=", ch.size, " rect=", r,
		"  text width=", w)
	print("cursor start y=", at.y, " x=", at.x)

	at.y += f.get_height(11) * 1.18                     # Ink.label "charter"
	print("  after 'charter' label      y=", at.y)
	at.y += 2.0
	# Ink.heading: line(17) + 17*0.55
	at.y += f.get_height(17) * 1.18 + 17.0 * 0.55
	print("  after title heading        y=", at.y)
	at.y += 6.0

	var body_h: float = f.get_multiline_string_size(ch.body_text,
		HORIZONTAL_ALIGNMENT_LEFT, w, 14).y + 14 * 0.25
	print("  body block height=", body_h, "  -> body spans y ", at.y, " .. ",
		at.y + body_h)
	at.y += body_h
	at.y += 8.0

	# ---- the date, exactly as CharterView._draw_date builds it
	var reign := lore.reign(ch.date_emperor)
	var who: String = reign.full_name() if reign else String(ch.date_emperor)
	var date_text := "Given in the %s year of %s." % [
		Lex.ordinal(ch.date_regnal_year), who]
	var date_top: float = at.y
	var date_size := f.get_multiline_string_size(date_text,
		HORIZONTAL_ALIGNMENT_LEFT, w, 16)
	var date_h: float = date_size.y + 16 * 0.25
	print("  DATE  text=\"", date_text, "\"")
	print("  DATE  top=", date_top, "  bottom=", date_top + date_h,
		"  h=", date_h, "  measured=", date_size)
	print("  DATE  frac y ", (date_top - r.position.y) / r.size.y, " .. ",
		(date_top + date_h - r.position.y) / r.size.y)
	var full_w: float = f.get_string_size(date_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	print("  DATE  glyphs x ", at.x, " .. ", at.x + full_w, "  (run ", full_w, ")")
	# prefix widths, so we can see which words a given x actually covers
	var prefixes := ["Given ", "Given in ", "Given in the ", "Given in the eighth ",
		"Given in the eleventh "]
	for p in prefixes:
		print("      x after \"", p, "\" = ",
			at.x + f.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)

	# ---- the authored patches
	for e in ch.erasures:
		var patch := Rect2(
			r.position + Vector2(e.region.position.x * r.size.x,
				e.region.position.y * r.size.y),
			Vector2(e.region.size.x * r.size.x, e.region.size.y * r.size.y))
		print("  PATCH ", e.altered_field, "  disp=", e.dispositive,
			"  rect=", patch, "  y ", patch.position.y, " .. ", patch.end.y,
			"  x ", patch.position.x, " .. ", patch.end.x)
		var ghost_top: float = patch.position.y + patch.size.y * 0.5 - 7.0
		print("        ghost top y=", ghost_top, "  bottom y=",
			ghost_top + f.get_height(12) * 1.18,
			"  x=", patch.position.x + 3.0,
			"  ghost run=", f.get_string_size(e.original_value,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
		var overlap: float = minf(patch.end.y, date_top + date_h) \
			- maxf(patch.position.y, date_top)
		print("        vertical overlap with the date block: ", overlap,
			" of date h ", date_h)

extends SceneTree

## Continues the probe past the date so the replication can be checked against a
## band somebody else measured independently (the innocent patch on witness 2).

const MARGIN := 26.0


func _init() -> void:
	var lore := ContentLoader.load_all()
	var f := ThemeDB.fallback_font
	for c in lore.cases:
		var ch := c.charter()
		if ch == null or ch.erasures.is_empty():
			continue
		var r := Rect2(-ch.size * 0.5, ch.size)
		var w: float = r.size.x - MARGIN * 2.0
		var at := r.position + Vector2(MARGIN, MARGIN * 0.75)
		at.y += f.get_height(11) * 1.18
		at.y += 2.0
		at.y += f.get_height(17) * 1.18 + 17.0 * 0.55
		at.y += 6.0
		at.y += f.get_multiline_string_size(ch.body_text,
			HORIZONTAL_ALIGNMENT_LEFT, w, 14).y + 14 * 0.25
		at.y += 8.0
		var reign := lore.reign(ch.date_emperor)
		var who: String = reign.full_name() if reign else String(ch.date_emperor)
		var date_text := "Given in the %s year of %s." % [
			Lex.ordinal(ch.date_regnal_year), who]
		at.y += f.get_multiline_string_size(date_text,
			HORIZONTAL_ALIGNMENT_LEFT, w, 16).y + 16 * 0.25
		at.y += 10.0

		# _draw_parties
		var y := 0.0
		if not ch.grantor.is_empty():
			y += f.get_height(13) * 1.18
		if not ch.claimant.is_empty():
			y += f.get_height(13) * 1.18
		if not ch.property.is_empty():
			y += f.get_multiline_string_size("Of:  " + ch.property,
				HORIZONTAL_ALIGNMENT_LEFT, w, 13).y + 13 * 0.25
		at.y += y
		at.y += 8.0
		print("\n==== ", c.id, "  witness block top y=", at.y,
			"  frac=", (at.y - r.position.y) / r.size.y)

		# _draw_witnesses
		var wy := f.get_height(10) * 1.18
		wy += 2.0
		var idx := 0
		for wit in ch.witnesses:
			var top: float = at.y + wy
			wy += f.get_height(12) * 1.18
			print("   witness %d  '%s'  y %s .. %s   frac %s .. %s" % [
				idx, wit.display(), top, at.y + wy,
				(top - r.position.y) / r.size.y,
				(at.y + wy - r.position.y) / r.size.y])
			if wit.has_death_record():
				var wr := lore.reign(wit.died_emperor)
				var note: String = wit.death_note(
					wr.full_name() if wr else String(wit.died_emperor))
				wy += f.get_multiline_string_size(note,
					HORIZONTAL_ALIGNMENT_LEFT, w - 26.0, 10).y + 10 * 0.25 + 4.0
			idx += 1
		for e in ch.erasures:
			print("   PATCH ", e.altered_field, "  local y ",
				r.position.y + e.region.position.y * r.size.y, " .. ",
				r.position.y + e.region.end.y * r.size.y)
	quit()

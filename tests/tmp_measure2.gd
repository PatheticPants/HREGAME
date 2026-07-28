extends SceneTree

func _init() -> void:
	var f := ThemeDB.fallback_font
	var j = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/world.json"))
	var d = j["desk_note"]
	var w := 290.0
	var note: String = d["received_note"]
	# rebuild the wrap the same way draw_multiline_string does, approximately:
	# measure cumulative prefixes to find where the visible area stops.
	var start_y := -67.03 + 6.0
	var foot := 255.0
	var avail: float = foot - start_y
	print("available height for received_note: ", avail)
	print("actual height: ", f.get_multiline_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, w, 11).y)
	var lh: float = f.get_height(11)
	print("line height 11pt: ", lh, "  lines that fit: ", floor(avail / lh), " of ", f.get_multiline_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, w, 11).y / lh)
	# Which paragraph is lost: measure each paragraph
	var paras: PackedStringArray = note.split("\n\n")
	var acc := 0.0
	for p in paras:
		var h: float = f.get_multiline_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, w, 11).y
		print("  para h=", h, " cum=", acc + h, "  visible_until=", avail, " :: ", p.substr(0, 46))
		acc += h + lh
	quit()

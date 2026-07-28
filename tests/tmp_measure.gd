extends SceneTree

func _init() -> void:
	var f := ThemeDB.fallback_font
	var txt := FileAccess.get_file_as_string("res://data/world/world.json")
	var j = JSON.parse_string(txt)
	var d = j["desk_note"]
	var sw: float = float(d["size"][0])
	var sh: float = float(d["size"][1])
	var MARGIN := 20.0
	var r := Rect2(-sw * 0.5, -sh * 0.5, sw, sh)
	var w: float = sw - MARGIN * 2.0
	var y: float = r.position.y + MARGIN * 0.7
	print("sheet rect ", r, "  text width ", w)
	y += f.get_height(10) * 1.18
	y += 3.0 + 7.0
	y += f.get_height(16) * 1.18
	y += f.get_height(12) * 1.18
	y += 7.0
	var claim: String = d["claim_summary"]
	y += f.get_multiline_string_size(claim, HORIZONTAL_ALIGNMENT_LEFT, w, 13).y + 13 * 0.25
	print("after claim_summary y=", y, "  (foot of sheet ", r.end.y, ")")
	y += 6.0
	var note: String = d["received_note"]
	var nh: float = f.get_multiline_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, w, 11).y + 11 * 0.25
	y += nh
	print("received_note height=", nh, "  -> flow y=", y)
	print("OVERFLOW past sheet foot: ", y - r.end.y)
	var foot: float = maxf(y + 10.0, r.end.y - MARGIN - 30.0)
	print("doorkeeper_note top y=", foot, "  = ", foot - r.end.y, " past the foot")
	var dh: float = f.get_multiline_string_size(d["doorkeeper_note"], HORIZONTAL_ALIGNMENT_LEFT, w, 11).y
	print("doorkeeper block height ", dh, " ends at ", foot + dh)
	quit()

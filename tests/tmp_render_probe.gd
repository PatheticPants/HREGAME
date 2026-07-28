extends Node

## Renders ONLY case_08's charter and reports, from PIXELS, where each band of
## ink actually sits in sheet-local coordinates.

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var lore := ContentLoader.load_all()
	var cd: CaseData = null
	for c in lore.cases:
		if String(c.id) == "case_08_mill_on_the_aue":
			cd = c
	var ch := cd.charter()
	var view := CharterView.new()
	add_child(view)
	view.bind(ch, Rect2(0, 0, 2000, 2000))
	view.settle_immediately()
	view.position = Vector2(240, 320)
	view.rotation = 0.0
	view.light_level = 1.0
	view.set_process(false)
	view.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://.tools/probe_charter.png"))

	var dark := []
	var reddish := []
	for py in range(28, 612):
		var d := 0
		var rd := 0
		var lx := 9999
		var rx := -9999
		for px in range(28, 452):
			var col := img.get_pixel(px, py)
			var luma: float = col.r * 0.3 + col.g * 0.6 + col.b * 0.1
			if luma < 0.42:
				d += 1
				lx = mini(lx, px)
				rx = maxi(rx, px)
			if col.r - col.g > 0.16 and col.r - col.b > 0.16 and luma < 0.62:
				rd += 1
		dark.append([py - 320, d, lx - 240, rx - 240])
		reddish.append([py - 320, rd])

	print("--- contiguous DARK-INK bands (sheet-local y), with x extent ---")
	var run_start := 9999
	var last := -9999
	var lo := 9999
	var hi := -9999
	for row in dark:
		if row[1] >= 2:
			if run_start == 9999:
				run_start = row[0]
				lo = 9999
				hi = -9999
			last = row[0]
			lo = mini(lo, row[2])
			hi = maxi(hi, row[3])
		else:
			if run_start != 9999:
				print("  band y %d .. %d   x %d .. %d" % [run_start, last, lo, hi])
				run_start = 9999
	if run_start != 9999:
		print("  band y %d .. %d   x %d .. %d" % [run_start, last, lo, hi])

	print("--- RED (rubric) rows ---")
	var rs := 9999
	var rl := -9999
	for row in reddish:
		if row[1] >= 2:
			if rs == 9999:
				rs = row[0]
			rl = row[0]
		else:
			if rs != 9999:
				print("  red band y %d .. %d" % [rs, rl])
				rs = 9999
	if rs != 9999:
		print("  red band y %d .. %d" % [rs, rl])

	for e in ch.erasures:
		print("PATCH ", e.altered_field, "  sheet-local y ",
			-292.5 + e.region.position.y * 585.0, " .. ",
			-292.5 + e.region.end.y * 585.0,
			"   x ", -215.0 + e.region.position.x * 430.0,
			" .. ", -215.0 + e.region.end.x * 430.0)
	get_tree().quit()

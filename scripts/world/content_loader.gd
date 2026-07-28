class_name ContentLoader
extends RefCounted

## Reads everything under data/ into a LoreData.
##
## JSON rather than .tres for *content*, on purpose:
##
##   * A case is authored by hand in any text editor, with no editor session, no
##     UID bookkeeping, and a diff that reads like prose when it lands in a pull
##     request. Hand-editing a .tres is objectively worse.
##   * No resource UIDs means nothing to desync between the Mac and the Windows
##     machine. This is the single most common cause of a Godot repo that "opens
##     dirty" after a pull.
##   * Every field is validated here, in one place, with the file and key named
##     in the error. A malformed .tres fails somewhere inside the engine.
##
## Tuning stays as .tres, because the whole value of a tuning resource is live
## editing in the inspector while the game runs, and JSON cannot do that.

const DIR_WORLD := "res://data/world/"
const DIR_CASES := "res://data/cases/"
const DIR_DAYS := "res://data/days/"
const DIR_BOOKS := "res://data/world/books/"
const DIR_TUNING := "res://data/tuning/"


static func load_all() -> LoreData:
	var lore := LoreData.new()
	_load_world(lore)
	_load_matrices(lore)
	_load_books(lore)
	_load_register_seed(lore)
	_load_cases(lore)
	_load_days(lore)
	_load_tuning(lore)
	_validate(lore)
	return lore


# ---------------------------------------------------------------------- world

static func _load_world(lore: LoreData) -> void:
	var d = _read_json(DIR_WORLD + "world.json", lore.errors)
	if d == null:
		return

	lore.present_year = _i(d, "present_year")
	lore.present_reign = _sn(d, "present_reign")
	lore.chancery_name = _s(d, "chancery_name", "The Imperial Chancery")
	lore.notary_name = _s(d, "notary_name", "the notary")
	lore.day_heading = _s(d, "day_heading")
	lore.day_seconds = maxf(10.0, _f(d, "day_seconds", 1200.0))
	lore.day_burnt_out = _s(d, "day_burnt_out")

	var desk_note_raw = d.get("desk_note", null)
	if desk_note_raw is Dictionary:
		lore.desk_note = _build_document(desk_note_raw,
			DIR_WORLD + "world.json:desk_note", lore)
	for practice_raw in _arr(d, "practice_documents"):
		var practice_doc := _build_document(practice_raw,
			DIR_WORLD + "world.json:practice_documents", lore)
		if practice_doc != null:
			lore.practice_documents.append(practice_doc)

	for raw in _arr(d, "reigns"):
		var r := Reign.new()
		r.id = _sn(raw, "id")
		r.name = _s(raw, "name")
		r.regnal_number = _s(raw, "regnal_number")
		r.election_year = _i(raw, "election_year")
		r.accession_year = _i(raw, "accession_year")
		r.coronation_year = _i(raw, "coronation_year")
		r.end_year = _i(raw, "end_year", -1)
		r.epithet = _s(raw, "epithet")
		r.note = _s(raw, "note")
		lore.reigns[r.id] = r

	for raw in _arr(d, "polities"):
		var p := Polity.new()
		p.id = _sn(raw, "id")
		p.name = _s(raw, "name")
		p.short_name = _s(raw, "short_name", p.name)
		p.color = _color(raw, "color", Color.WHITE)
		p.device = _sn(raw, "device")
		p.succession = _s(raw, "succession")
		p.authority = Lex.authority_from_string(_s(raw, "authority", "imperial"))
		p.dating_style = Lex.dating_from_string(_s(raw, "dating_style", "accession"))
		p.matrix_dies_with_holder = _b(raw, "matrix_dies_with_holder", true)
		p.seals_used = _b(raw, "seals_used", true)
		p.note = _s(raw, "note")
		lore.polities[p.id] = p


static func _load_matrices(lore: LoreData) -> void:
	var d = _read_json(DIR_WORLD + "matrices.json", lore.errors)
	if d == null:
		return
	for raw in _arr(d, "matrices"):
		var m := SealMatrix.new()
		m.id = _sn(raw, "id")
		m.owner_name = _s(raw, "owner_name")
		m.polity_id = _sn(raw, "polity_id")
		m.device = _sn(raw, "device")
		m.legend = _s(raw, "legend")
		m.shape = _sn(raw, "shape")
		m.wax_color = _color(raw, "wax_color", Color(0.55, 0.11, 0.17))
		m.cut_year = _i(raw, "cut_year")
		m.broken_year = _i(raw, "broken_year", -1)
		m.note = _s(raw, "note")
		lore.matrices.append(m)


static func _load_books(lore: LoreData) -> void:
	if not DirAccess.dir_exists_absolute(DIR_BOOKS):
		lore.errors.append("Missing directory: " + DIR_BOOKS)
		return
	for file in _json_files(DIR_BOOKS):
		var d = _read_json(DIR_BOOKS + file, lore.errors)
		if d == null:
			continue
		var b := BookData.new()
		b.id = _sn(d, "id")
		b.title = _s(d, "title")
		b.subtitle = _s(d, "subtitle")
		b.cover_color = _color(d, "cover_color", Color(0.35, 0.22, 0.16))
		b.page_color = _color(d, "page_color", Color(0.90, 0.86, 0.74))
		b.size = _vec2(d, "size", Vector2(300, 380))
		b.start_offset = _vec2(d, "start_offset", Vector2.ZERO)
		b.start_angle_deg = _f(d, "start_angle_deg")
		var pages: Array[BookPage] = []
		for raw in _arr(d, "pages"):
			var p := BookPage.new()
			p.kind = _sn(raw, "kind")
			p.heading = _s(raw, "heading")
			p.subheading = _s(raw, "subheading")
			p.body = _s(raw, "body")
			p.matrix_id = _sn(raw, "matrix_id")
			p.polity_id = _sn(raw, "polity_id")
			p.marginalia = _s(raw, "marginalia")
			pages.append(p)
		b.pages = pages
		lore.books[b.id] = b


static func _load_register_seed(lore: LoreData) -> void:
	var d = _read_json(DIR_WORLD + "register_seed.json", lore.errors)
	if d == null:
		return
	for raw in _arr(d, "entries"):
		var r := RulingRecord.new()
		r.case_id = _sn(raw, "case_id")
		r.day_id = _sn(raw, "day_id")
		r.case_title = _s(raw, "case_title")
		r.petitioner_name = _s(raw, "petitioner_name")
		r.subject_id = _sn(raw, "subject_id")
		r.claimant_id = _sn(raw, "claimant_id")
		r.verdict = Lex.verdict_from_string(_s(raw, "verdict"))
		r.lawful_verdict = Lex.verdict_from_string(
			_s(raw, "lawful_verdict", _s(raw, "verdict")))
		r.was_sound = _b(raw, "was_sound", true)
		var authority_verdicts: Dictionary = raw.get("authority_verdicts", {})
		for authority_name in authority_verdicts:
			var authority := Lex.authority_from_string(str(authority_name))
			if authority != Lex.Authority.NONE:
				r.authority_verdicts[authority] = Lex.verdict_from_string(
					str(authority_verdicts[authority_name]))
		r.reason_code = _sn(raw, "reason_code")
		r.register_note = _s(raw, "register_note")
		r.foreign_hand = true
		r.hand_name = _s(raw, "hand_name", "an earlier hand")
		lore.register_seed.append(r)


# ---------------------------------------------------------------------- cases

static func _load_cases(lore: LoreData) -> void:
	var order := PackedStringArray()
	var session = _read_json(DIR_CASES + "_order.json", lore.errors)
	if session != null:
		for entry in _arr(session, "order"):
			order.append(str(entry))
	if order.is_empty():
		# No manifest: take every case file in name order. Underscore-prefixed
		# files are manifests and comments, never content.
		for f in _json_files(DIR_CASES):
			if not f.begins_with("_"):
				order.append(f.get_basename())

	for base in order:
		var path := DIR_CASES + base + ".json"
		var d = _read_json(path, lore.errors)
		if d == null:
			continue
		var c := _build_case(d, path, lore)
		if c != null:
			lore.cases.append(c)


static func _build_case(d: Variant, path: String, lore: LoreData) -> CaseData:
	var c := CaseData.new()
	c.id = _sn(d, "id")
	c.title = _s(d, "title")
	if c.id == &"":
		lore.errors.append("%s: case has no id" % path)
		return null

	var pd := PetitionerData.new()
	var praw = d.get("petitioner", {})
	pd.id = _sn(praw, "id", c.id)
	pd.name = _s(praw, "name")
	pd.style = _s(praw, "style")
	pd.polity_id = _sn(praw, "polity_id")
	pd.portrait_path = _s(praw, "portrait_path")
	pd.height = _f(praw, "height", 250.0)
	pd.build = _f(praw, "build", 92.0)
	pd.cloth = _color(praw, "cloth", Color(0.35, 0.32, 0.30))
	pd.restlessness = _f(praw, "restlessness", 0.5)
	c.petitioner = pd

	var docs: Array[DocumentData] = []
	for raw in _arr(d, "documents"):
		var doc := _build_document(raw, path, lore)
		if doc != null:
			docs.append(doc)
	c.documents = docs

	c.correct_verdict = Lex.verdict_from_string(_s(d, "correct_verdict"))
	c.dynamic_precedent = _b(d, "dynamic_precedent", false)
	c.correct_reason = _sn(d, "correct_reason")
	c.correct_reason_text = _s(d, "correct_reason_text")

	var outs: Array[CaseOutcome] = []
	for raw in _arr(d, "outcomes"):
		var o := CaseOutcome.new()
		o.verdict = Lex.verdict_from_string(_s(raw, "verdict"))
		o.register_note = _s(raw, "register_note")
		o.reaction = _s(raw, "reaction")
		o.aftermath = _s(raw, "aftermath")
		var fav := {}
		var fraw = raw.get("favor", {})
		if fraw is Dictionary:
			for key in fraw:
				fav[Lex.authority_from_string(str(key))] = int(fraw[key])
		o.favor = fav
		outs.append(o)
	c.outcomes = outs

	var lines: Array[DialogueLine] = []
	for raw in _arr(d, "lines"):
		var l := DialogueLine.new()
		l.speaker = _s(raw, "speaker", pd.name)
		l.text = _s(raw, "text")
		l.beat = _sn(raw, "beat", &"arrival")
		l.requires_case = _sn(raw, "requires_case")
		l.requires_verdict = Lex.verdict_from_string(_s(raw, "requires_verdict"))
		l.requires_soundness = _i(raw, "requires_soundness", -1)
		l.priority = _i(raw, "priority")
		lines.append(l)
	c.lines = lines

	return c


# ----------------------------------------------------------------------- days

static func _load_days(lore: LoreData) -> void:
	if not DirAccess.dir_exists_absolute(DIR_DAYS):
		# Compatibility for older one-day content.
		var day := DayData.new()
		day.id = &"day_01"
		day.entry_label = "FIRST DAY"
		day.heading = lore.day_heading
		day.day_seconds = lore.day_seconds
		day.burnt_out_text = lore.day_burnt_out
		for c in lore.cases:
			var slot := DayCaseSlot.new()
			slot.case_id = c.id
			day.case_slots.append(slot)
		lore.days.append(day)
		return

	var manifest = _read_json(DIR_DAYS + "_order.json", lore.errors)
	if manifest == null:
		return
	for day_name in _arr(manifest, "order"):
		var path := DIR_DAYS + str(day_name) + ".json"
		var raw = _read_json(path, lore.errors)
		if raw == null:
			continue
		var day := DayData.new()
		day.id = _sn(raw, "id")
		day.entry_label = _s(raw, "entry_label", "NEXT DAY")
		day.heading = _s(raw, "heading")
		day.day_seconds = maxf(10.0, _f(raw, "day_seconds", 1200.0))
		day.burnt_out_text = _s(raw, "burnt_out_text")
		day.selection_mode = _sn(raw, "selection_mode", &"fixed")
		for slot_raw in _arr(raw, "case_slots"):
			var slot := DayCaseSlot.new()
			slot.case_id = _sn(slot_raw, "case_id")
			slot.requires_ruled = _sn(slot_raw, "requires_ruled")
			slot.fallback_case_id = _sn(slot_raw, "fallback_case_id")
			day.case_slots.append(slot)
		for opening_raw in _arr(raw, "opening_documents"):
			var opening := DayOpeningDocument.new()
			opening.requires_case = _sn(opening_raw, "requires_case")
			opening.requires_verdict = Lex.verdict_from_string(
				_s(opening_raw, "requires_verdict"))
			var document_raw = opening_raw.get("document", null)
			if document_raw is Dictionary:
				opening.document = _build_document(document_raw,
					path + ":opening_documents", lore)
			day.opening_documents.append(opening)
		lore.days.append(day)


static func _build_document(raw: Variant, path: String, lore: LoreData) -> DocumentData:
	var kind := _sn(raw, "kind", &"paper")
	var doc: DocumentData

	match kind:
		&"charter":
			var ch := CharterData.new()
			ch.body_text = _s(raw, "body_text")
			ch.date_emperor = _sn(raw, "date_emperor")
			ch.date_regnal_year = _i(raw, "date_regnal_year")
			ch.drawn_by_polity = _sn(raw, "drawn_by_polity")
			ch.claimant = _s(raw, "claimant")
			ch.grantor = _s(raw, "grantor")
			ch.property = _s(raw, "property")
			ch.subject_id = _sn(raw, "subject_id")
			ch.claimant_id = _sn(raw, "claimant_id")
			ch.supersedes_prior_instrument = _b(
				raw, "supersedes_prior_instrument", false)
			var ws: Array[Witness] = []
			for wraw in _arr(raw, "witnesses"):
				var w := Witness.new()
				w.name = _s(wraw, "name")
				w.title = _s(wraw, "title")
				w.died_emperor = _sn(wraw, "died_emperor")
				w.died_regnal_year = _i(wraw, "died_regnal_year")
				w.died_dating_style = Lex.dating_from_string(
					_s(wraw, "died_dating_style", "accession"))
				w.note = _s(wraw, "note")
				ws.append(w)
			ch.witnesses = ws
			var sraw = raw.get("seal", null)
			if sraw is Dictionary:
				var s := SealImpression.new()
				s.id = _sn(sraw, "id")
				s.claims_owner = _s(sraw, "claims_owner")
				s.claims_polity = _sn(sraw, "claims_polity")
				s.device = _sn(sraw, "device")
				s.legend = _s(sraw, "legend")
				s.shape = _sn(sraw, "shape", &"round")
				s.wax_color = _color(sraw, "wax_color", Color(0.55, 0.11, 0.17))
				s.wear = _f(sraw, "wear")
				s.shape_seed = _i(sraw, "shape_seed", 1)
				s.note = _s(sraw, "note")
				ch.seal = s
			doc = ch
		&"docket":
			var dk := DocketData.new()
			dk.petitioner_name = _s(raw, "petitioner_name")
			dk.petitioner_style = _s(raw, "petitioner_style")
			dk.claim_summary = _s(raw, "claim_summary")
			dk.received_note = _s(raw, "received_note")
			dk.doorkeeper_note = _s(raw, "doorkeeper_note")
			doc = dk
		&"letter":
			var letter := LetterData.new()
			letter.sender = _s(raw, "sender")
			letter.recipient = _s(raw, "recipient")
			letter.body = _s(raw, "body")
			letter.closing = _s(raw, "closing")
			for endorsement in _arr(raw, "endorsements"):
				letter.endorsements.append(str(endorsement))
			doc = letter
		_:
			lore.errors.append("%s: unknown document kind '%s'" % [path, kind])
			return null

	doc.id = _sn(raw, "id")
	doc.kind = kind
	doc.title = _s(raw, "title")
	doc.size = _vec2(raw, "size", Vector2(360, 470))
	doc.tint = _color(raw, "tint", Color(0.85, 0.80, 0.68))
	doc.start_offset = _vec2(raw, "start_offset", Vector2.ZERO)
	doc.start_angle_deg = _f(raw, "start_angle_deg")
	doc.takes_seal = _b(raw, "takes_seal", kind == &"charter")
	return doc


# --------------------------------------------------------------------- tuning

static func _load_tuning(lore: LoreData) -> void:
	lore.paper_feel = _load_res(DIR_TUNING + "paper_feel.tres", lore) as PaperFeel
	lore.wax_feel = _load_res(DIR_TUNING + "wax_feel.tres", lore) as WaxFeel
	lore.verdict_policy = _load_res(DIR_TUNING + "verdict_policy.tres", lore) as VerdictPolicy

	# Tuning must never be the reason the game will not start. Fall back to code
	# defaults and say so, rather than crashing on a missing file.
	if lore.paper_feel == null:
		lore.paper_feel = PaperFeel.new()
	if lore.wax_feel == null:
		lore.wax_feel = WaxFeel.new()
	if lore.verdict_policy == null or lore.verdict_policy.rules.is_empty():
		lore.verdict_policy = VerdictPolicy.fallback()


static func _load_res(path: String, lore: LoreData) -> Resource:
	if not ResourceLoader.exists(path):
		lore.errors.append("Missing tuning resource (using code defaults): " + path)
		return null
	return load(path)


# ----------------------------------------------------------------- validation
# Catch content mistakes at load, naming the file and the key. A case that fails
# quietly looks exactly like a bug in the rules engine and costs an afternoon.

static func _validate(lore: LoreData) -> void:
	if lore.present_year <= 0:
		lore.errors.append("world.json: present_year must be set")

	for m in lore.matrices:
		if not lore.polities.has(m.polity_id):
			lore.errors.append("matrices.json: '%s' names unknown polity '%s'"
				% [m.id, m.polity_id])
		if m.broken_year >= 0 and m.broken_year < m.cut_year:
			lore.errors.append("matrices.json: '%s' broken before it was cut" % m.id)

	for c in lore.cases:
		if c.petitioner == null or c.petitioner.portrait_path.is_empty():
			lore.errors.append("case '%s' has no petitioner portrait" % c.id)
		elif not FileAccess.file_exists(c.petitioner.portrait_path):
			lore.errors.append("case '%s': missing petitioner portrait '%s'"
				% [c.id, c.petitioner.portrait_path])
		if c.documents.is_empty():
			lore.errors.append("case '%s' has no documents" % c.id)
		if c.correct_verdict == Lex.Verdict.NONE and not c.dynamic_precedent:
			lore.errors.append("case '%s' has no correct_verdict" % c.id)
		for v in [Lex.Verdict.CONFIRM, Lex.Verdict.DENY, Lex.Verdict.REFER]:
			if c.outcome_for(v) == null:
				lore.errors.append("case '%s' has no outcome for %s"
					% [c.id, Lex.verdict_name(v)])
		var ch := c.charter()
		if ch == null:
			lore.errors.append("case '%s' has no charter" % c.id)
			continue
		if not lore.reigns.has(ch.date_emperor):
			lore.errors.append("case '%s': unknown emperor '%s'"
				% [c.id, ch.date_emperor])
		if not lore.polities.has(ch.drawn_by_polity):
			lore.errors.append("case '%s': unknown drawing polity '%s'"
				% [c.id, ch.drawn_by_polity])

	for day in lore.days:
		if day.id == &"":
			lore.errors.append("a day has no id")
		if day.selection_mode not in [&"fixed", &"tray"]:
			lore.errors.append("day '%s': unknown selection_mode '%s'"
				% [day.id, day.selection_mode])
		for slot in day.case_slots:
			if lore.case_by_id(slot.case_id) == null:
				lore.errors.append("day '%s': unknown case '%s'"
					% [day.id, slot.case_id])
			if slot.requires_ruled != &"" \
					and lore.case_by_id(slot.requires_ruled) == null:
				lore.errors.append("day '%s': unknown prerequisite case '%s'"
					% [day.id, slot.requires_ruled])
			if slot.fallback_case_id != &"" \
					and lore.case_by_id(slot.fallback_case_id) == null:
				lore.errors.append("day '%s': unknown fallback case '%s'"
					% [day.id, slot.fallback_case_id])

	for id in lore.books:
		var b: BookData = lore.books[id]
		for p in b.pages:
			if p.kind == &"matrix" and lore.matrix(p.matrix_id) == null:
				lore.errors.append("book '%s': page names unknown matrix '%s'"
					% [id, p.matrix_id])
			if p.kind == &"plate" and not lore.polities.has(p.polity_id):
				lore.errors.append("book '%s': page names unknown polity '%s'"
					% [id, p.polity_id])


# -------------------------------------------------------------------- helpers

static func _json_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		# Godot appends .remap to data files in an exported build; strip it so
		# the same code path works in editor and in an export.
		var file_name := f.trim_suffix(".remap")
		if file_name.get_extension().to_lower() == "json":
			out.append(file_name)
	out.sort()
	return out


static func _read_json(path: String, errors: PackedStringArray) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("Missing data file: " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		errors.append("%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


static func _arr(d: Variant, key: String) -> Array:
	if d is Dictionary and d.has(key) and d[key] is Array:
		return d[key] as Array
	return []


static func _s(d: Variant, key: String, def: String = "") -> String:
	if d is Dictionary and d.has(key) and d[key] != null:
		return str(d[key])
	return def


static func _sn(d: Variant, key: String, def: StringName = &"") -> StringName:
	var v := _s(d, key)
	return StringName(v) if not v.is_empty() else def


static func _i(d: Variant, key: String, def: int = 0) -> int:
	if d is Dictionary and d.has(key) and (d[key] is float or d[key] is int):
		return int(d[key])
	return def


static func _f(d: Variant, key: String, def: float = 0.0) -> float:
	if d is Dictionary and d.has(key) and (d[key] is float or d[key] is int):
		return float(d[key])
	return def


static func _b(d: Variant, key: String, def: bool = false) -> bool:
	if d is Dictionary and d.has(key) and d[key] is bool:
		return d[key]
	return def


static func _color(d: Variant, key: String, def: Color) -> Color:
	var v := _s(d, key)
	if v.is_empty():
		return def
	if not v.begins_with("#"):
		v = "#" + v
	if not Color.html_is_valid(v):
		return def
	return Color.html(v)


static func _vec2(d: Variant, key: String, def: Vector2) -> Vector2:
	if d is Dictionary and d.has(key) and d[key] is Array and d[key].size() >= 2:
		return Vector2(float(d[key][0]), float(d[key][1]))
	return def

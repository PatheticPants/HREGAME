class_name Sheet
extends Draggable

## A physical piece of parchment. Base for every document on the desk.
##
## Handles the substrate — shadow, body, deckled edge, how the candle warms it —
## and leaves the writing to _draw_face(). A charter and a docket slip are then
## two twenty-line overrides rather than two objects.

var data: DocumentData = null

## Slight per-sheet variation so a stack of parchment does not look printed.
var _grain_seed := 0
var _deckle: PackedFloat32Array = PackedFloat32Array()
var _arrival_from := Vector2.ZERO
var _arrival_t := 1.0


func bind(doc: DocumentData, desk_bounds: Rect2) -> void:
	data = doc
	hit_size = doc.size
	name = "sheet_" + String(doc.id)
	_grain_seed = hash(String(doc.id))
	_build_deckle()
	setup(doc.start_offset, deg_to_rad(doc.start_angle_deg), desk_bounds)
	# Packets are handed down over the far edge of the desk. The physics body is
	# already at its authored resting place; this short presentation offset
	# brings the visible sheet in from the petitioner's side without creating a
	# second drag solver or changing where it will settle.
	var side := -1.0 if (_grain_seed & 1) == 0 else 1.0
	_arrival_from = Vector2(side * 24.0, -105.0)
	_arrival_t = 0.0
	position = solver.position + _arrival_from


func _process(delta: float) -> void:
	super._process(delta)
	if _arrival_t >= 1.0:
		return
	_arrival_t = minf(1.0, _arrival_t + delta / 0.62)
	var arrived := ease(_arrival_t, 0.32)
	position += _arrival_from * (1.0 - arrived)
	rotation += deg_to_rad(side_sign() * 2.5) * (1.0 - arrived)


func side_sign() -> float:
	return -1.0 if (_grain_seed & 1) == 0 else 1.0


func settle_immediately() -> void:
	_arrival_t = 1.0
	position = solver.position
	rotation = solver.angle


## Irregular edge, generated once. Parchment is cut from a skin and never comes
## out square; a perfectly rectangular sheet is the single fastest way to make a
## desk look like a UI.
func _build_deckle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _grain_seed
	_deckle = PackedFloat32Array()
	for i in 24:
		_deckle.append(rng.randf_range(-1.6, 1.6))


func rect() -> Rect2:
	return Rect2(-data.size * 0.5, data.size)


## Where the verdict wax goes. Bottom right of the sheet, clear of the text —
## the same place a chancery would leave room for it.
func wax_slot_local() -> Vector2:
	return Vector2(data.size.x * 0.24, data.size.y * 0.34)


func wax_slot_world() -> Vector2:
	return to_global(wax_slot_local())


func _draw() -> void:
	if data == null:
		return
	var r := rect()
	draw_soft_shadow(r)
	_draw_body(r)
	_draw_face(r)
	# Last, over everything the subclass drew. A page out of the candle's reach
	# loses its writing before it loses its shape, and a new document type cannot
	# forget to do this because it happens above _draw_face rather than inside it.
	draw_shade(r)


func _draw_body(r: Rect2) -> void:
	# Candle warmth, on the same inverse-square curve the renderer uses. Parchment
	# is a warm, slightly translucent material: near the flame it goes distinctly
	# amber and slightly luminous, away from it the pigment drops toward grey.
	# Between this and the contact shadow, carrying the candle across the desk
	# does visible work on every sheet it passes.
	var reach := clampf(light_level, 0.0, 1.0)
	var glow := reach * clampf(light_strength, 0.7, 1.1)
	var base := data.tint.lerp(Color(1.0, 0.82, 0.55), glow * 0.46)
	base = base.darkened((1.0 - reach) * 0.30)

	# A gradient across the sheet itself, brighter on the side facing the flame.
	# A single flat tint per sheet reads as a tinted rectangle; the falloff across
	# the page is what says the light has a position in the room.
	var toward := (light_position - global_position).rotated(-global_rotation)
	if toward.length() > 1.0:
		toward = toward.normalized()
	var near_edge := base.lerp(Color(1.0, 0.86, 0.62), glow * 0.16)
	var far_edge := base.darkened(glow * 0.10 + 0.05)

	draw_rect(r, base)
	_draw_light_gradient(r, toward, near_edge, far_edge, glow)
	_draw_deckle(r, base)

	# Laid lines: the faint horizontal ribbing of a real skin. Almost invisible,
	# does a surprising amount of work.
	var ribs := int(r.size.y / 9.0)
	for i in ribs:
		var y := r.position.y + float(i) * 9.0 + float(_grain_seed % 5)
		draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y),
			Color(0, 0, 0, 0.020), 1.0)

	# Edge: darker at the rim, lighter along the top-left, so the sheet has a
	# side rather than being a coloured rectangle.
	draw_rect(r, base.darkened(0.30), false, 1.0)
	draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1),
		base.lightened(0.32), 1.0)
	draw_line(r.position + Vector2(1, 1), Vector2(r.position.x + 1, r.end.y - 1),
		base.lightened(0.22), 1.0)


## Banded gradient across the page, running from the edge nearest the flame to
## the edge furthest from it. Eight strips is enough that it reads as a smooth
## falloff at this size, and it costs eight draw_rects instead of a shader —
## which matters because gl_compatibility is the target and this runs on every
## sheet, every frame.
func _draw_light_gradient(r: Rect2, toward: Vector2, near_col: Color,
		far_col: Color, glow: float) -> void:
	if glow < 0.02:
		return
	const BANDS := 8
	# Project the page corners onto the light direction so the bands always run
	# along it, whichever way the sheet has been dropped.
	var horizontal := absf(toward.x) >= absf(toward.y)
	for i in BANDS:
		var t := (float(i) + 0.5) / float(BANDS)
		# t == 0 is the near edge, so flip when the flame is the other way.
		var along := t if (toward.x if horizontal else toward.y) < 0.0 else 1.0 - t
		var col := far_col.lerp(near_col, 1.0 - along)
		col.a = 0.30 * glow
		if horizontal:
			draw_rect(Rect2(r.position.x + r.size.x * t - r.size.x / BANDS * 0.5,
				r.position.y, r.size.x / BANDS + 1.0, r.size.y), col)
		else:
			draw_rect(Rect2(r.position.x,
				r.position.y + r.size.y * t - r.size.y / BANDS * 0.5,
				r.size.x, r.size.y / BANDS + 1.0), col)


func _draw_deckle(r: Rect2, base: Color) -> void:
	# Bite small notches out of the rim by overdrawing with the desk-side colour.
	# Cheaper and steadier than building an irregular polygon every frame.
	var notch := Color(0, 0, 0, 0.10)
	for i in _deckle.size():
		var d := _deckle[i]
		var t := float(i) / float(_deckle.size())
		if i % 2 == 0:
			var x := r.position.x + t * r.size.x
			draw_rect(Rect2(x, r.position.y, 6.0, absf(d)), notch)
			draw_rect(Rect2(x, r.end.y - absf(d), 6.0, absf(d)), notch)
		else:
			var y := r.position.y + t * r.size.y
			draw_rect(Rect2(r.position.x, y, absf(d), 6.0), notch)
			draw_rect(Rect2(r.end.x - absf(d), y, absf(d), 6.0), notch)


## Overridden by each document type.
func _draw_face(_r: Rect2) -> void:
	pass

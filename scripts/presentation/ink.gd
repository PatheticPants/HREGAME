class_name Ink
extends RefCounted

## Text drawing helpers shared by papers, books and the ledger.
##
## Godot's draw_string takes a baseline, not a top-left, which is a reliable
## source of off-by-one-line layout bugs. Everything here takes a top-left and
## returns the height it consumed, so callers can stack blocks by adding.
##
## There are two hands in this game. The player's chancery hand is upright and
## dark. The predecessor's is slanted, browner, and appears in the margins of
## books he had no business annotating.

const CHANCERY := Color(0.16, 0.12, 0.09)
const FADED := Color(0.34, 0.27, 0.20)
const RUBRIC := Color(0.52, 0.14, 0.12)      ## red ink, for headings and dates
const SECOND_HAND := Color(0.30, 0.24, 0.34)


static func font() -> Font:
	return ThemeDB.fallback_font


static func line_height(size: int) -> float:
	return font().get_height(size) * 1.18


## One line from a top-left origin. Returns the height used.
static func line(c: CanvasItem, at: Vector2, text: String, size: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> float:
	var f := font()
	c.draw_string(f, at + Vector2(0, f.get_ascent(size)), text, align, width, size, col)
	return line_height(size)


## A wrapped block. Returns the height used, so the next block can start below it.
static func block(c: CanvasItem, at: Vector2, text: String, size: int, col: Color,
		width: float, max_lines := -1) -> float:
	if text.is_empty():
		return 0.0
	var f := font()
	c.draw_multiline_string(f, at + Vector2(0, f.get_ascent(size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, col)
	return f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width,
		size).y + size * 0.25


static func measure(text: String, size: int, width := -1.0) -> Vector2:
	if width > 0.0:
		return font().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
			width, size)
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)


## A heading with a rule under it, the way a chancery clerk would set it out.
static func heading(c: CanvasItem, at: Vector2, text: String, size: int,
		col: Color, width: float) -> float:
	var h := line(c, at, text.to_upper(), size, col)
	c.draw_line(at + Vector2(0, h + 1.0), at + Vector2(width, h + 1.0),
		col * Color(1, 1, 1, 0.45), 1.0)
	return h + size * 0.55


static func rule(c: CanvasItem, at: Vector2, width: float, col: Color,
		thickness := 1.0) -> void:
	c.draw_line(at, at + Vector2(width, 0), col, thickness)


## Marginalia: written at a slant, in another hand, squeezed into whatever room
## the page had left. draw_set_transform lets the whole block lean without
## touching the node's own transform.
static func margin_note(c: CanvasItem, at: Vector2, text: String, size: int,
		width: float, slant_deg := -4.0, col := SECOND_HAND) -> float:
	c.draw_set_transform(at, deg_to_rad(slant_deg), Vector2.ONE)
	var h := block(c, Vector2.ZERO, text, size, col, width)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return h + 4.0


## Small-caps-ish label. The fallback font has no true small caps, so this is
## upper case at a reduced size with a little tracking faked by spaces.
static func label(c: CanvasItem, at: Vector2, text: String, size: int,
		col: Color) -> float:
	var spaced := ""
	for i in text.length():
		spaced += text[i]
		if i < text.length() - 1:
			spaced += " "
	return line(c, at, spaced.to_upper(), size, col)


## Right-aligned single line within a width.
static func line_right(c: CanvasItem, at: Vector2, text: String, size: int,
		col: Color, width: float) -> float:
	return line(c, at, text, size, col, HORIZONTAL_ALIGNMENT_RIGHT, width)


static func line_centre(c: CanvasItem, at: Vector2, text: String, size: int,
		col: Color, width: float) -> float:
	return line(c, at, text, size, col, HORIZONTAL_ALIGNMENT_CENTER, width)


## Letters cut around a seal matrix. The three passes are a tiny highlight, a
## dark cut, and the wax-coloured floor between them: the same physical lighting
## language as Heraldry.draw_device_incuse, applied character by character.
##
## `counter_rotation` lets a magnifying glass cancel its own angle. Character
## origins are pre-rotated by the same amount because draw_set_transform replaces
## rather than composes the caller's drawing transform.
static func circular_incuse(c: CanvasItem, centre: Vector2, text: String,
		radius: float, size: int, wax: Color, depth := 1.0,
		counter_rotation := 0.0,
		light_dir := Vector2(-0.707, -0.707)) -> void:
	var legend := text.strip_edges().to_upper()
	if legend.is_empty():
		return
	var f := font()
	var count := legend.length()
	var step := TAU / float(count)
	var lift := maxf(0.45, float(size) * 0.055) * clampf(depth, 0.2, 1.0)
	# Letters are cut into the same wax as the device, so they must catch the
	# same flame. The offset is rotated into glyph space because each character
	# is drawn on its own tangent.
	var light := light_dir.normalized() if light_dir.length() > 0.01 \
		else Vector2(-0.707, -0.707)
	for i in count:
		var glyph := legend.substr(i, 1)
		var angle := -PI * 0.5 + (float(i) + 0.5) * step
		var desired := centre + Vector2(cos(angle), sin(angle)) * radius
		var origin := desired.rotated(counter_rotation)
		var tangent := angle + PI * 0.5 + counter_rotation
		var glyph_width := f.get_string_size(glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var baseline := Vector2(-glyph_width * 0.5, f.get_ascent(size) * 0.34)
		# Cut into the wax, so lit AWAY from the flame and shadowed toward it —
		# the same rule as the device it surrounds and as any engraved line, and
		# taken from the same place so the legend can never disagree with the
		# device it is cut around. Both were inverted; see Heraldry.
		var toward := light.rotated(-tangent)
		c.draw_set_transform(origin, tangent, Vector2.ONE)
		c.draw_string(f, baseline + Surface.lip_offset(toward, lift), glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(wax.lightened(0.34 * depth), wax.a * 0.78))
		c.draw_string(f, baseline + Surface.trough_offset(toward, lift), glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(wax.darkened(0.52 * depth), wax.a * 0.92))
		c.draw_string(f, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(wax.darkened(0.22 * depth), wax.a))
	c.draw_set_transform(Vector2.ZERO, counter_rotation, Vector2.ONE)

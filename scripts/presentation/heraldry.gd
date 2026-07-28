class_name Heraldry
extends RefCounted

## Procedural heraldic devices, drawn from primitives.
##
## This is the one place placeholder art is worth any effort, because comparing a
## device in the wax against a device in the book IS the gameplay. Flat coloured
## rectangles would make the seal check unplayable. Everything here is deliberately
## crude — recognisable silhouettes, no shading, no assets — but a lion is never
## going to be mistaken for a stag, and that is the entire requirement.
##
## All shapes are authored in a unit square roughly [-1,1] with y pointing down,
## then scaled by the radius passed in.

static func draw_device(c: CanvasItem, device: StringName, at: Vector2, r: float,
		col: Color) -> void:
	match device:
		&"double_eagle": _double_eagle(c, at, r, col)
		&"lion_rampant": _lion_rampant(c, at, r, col)
		&"crossed_keys": _crossed_keys(c, at, r, col)
		&"three_towers": _three_towers(c, at, r, col)
		&"stag": _stag(c, at, r, col)
		&"wolf_head": _wolf_head(c, at, r, col)
		&"knot_ring": _knot_ring(c, at, r, col)
		&"crozier": _crozier(c, at, r, col)
		&"notary_confirm": _notary_confirm(c, at, r, col)
		&"notary_deny": _notary_deny(c, at, r, col)
		&"notary_refer": _notary_refer(c, at, r, col)
		_: _unknown(c, at, r, col)


## A device sunk into wax.
##
## The offset that makes it read as *cut* rather than printed now follows the
## real flame instead of a hardcoded diagonal, so carrying the candle round the
## desk rolls the light across every seal in the room. It also scales with the
## drawn radius — a fixed 1.6px lift is invisible on a device magnified to ninety
## units under the glass, which is exactly where the depth matters most.
static func draw_device_incuse(c: CanvasItem, device: StringName, at: Vector2,
		r: float, wax: Color, depth := 1.0,
		light_dir := Vector2(-0.707, -0.707)) -> void:
	var light := light_dir.normalized() if light_dir.length() > 0.01 \
		else Vector2(-0.707, -0.707)
	var lift := maxf(1.2, r * 0.036) * depth
	# INCUSE MEANS SUNK, AND THIS WAS LIT AS A BOSS.
	#
	# A device pressed INTO wax is a depression. Its far wall faces back toward
	# the flame and catches it; its near wall faces away and is shadowed. So the
	# lit pass belongs AWAY from the light and the dark pass toward it — which is
	# the same rule as an engraved line, and is why both offsets come from
	# Surface rather than being written out again here.
	#
	# This had them the other way round: lightened at +light, darkened at -light,
	# which is the RAISED convention. So every seal in the game — the pendant
	# seals that arrive on charters, the plates in the Book of Matrices, and the
	# impression the player themself strikes — read as a device standing proud of
	# the wax rather than stamped into it, and rolled the wrong way whenever the
	# candle was carried past. It has been wrong since the function was written;
	# wiring the real flame direction in later only made the error move.
	draw_device(c, device, at + Surface.lip_offset(light, lift), r,
		wax.lightened(0.34 * depth))
	draw_device(c, device, at + Surface.trough_offset(light, lift), r,
		wax.darkened(0.50 * depth))
	draw_device(c, device, at, r, wax.darkened(0.20 * depth))


static func display_name(device: StringName) -> String:
	return String(device).replace("_", " ")


# ------------------------------------------------------------------- devices

static func _double_eagle(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	# Body: a tapered diamond. Wings: chevrons. Two heads, turned outward.
	_poly(c, o, r, col, [
		Vector2(0.00, -0.22), Vector2(0.20, 0.05), Vector2(0.13, 0.72),
		Vector2(0.00, 0.86), Vector2(-0.13, 0.72), Vector2(-0.20, 0.05),
	])
	for s in [-1.0, 1.0]:
		_poly(c, o, r, col, [
			Vector2(0.05 * s, -0.14), Vector2(0.82 * s, -0.30),
			Vector2(0.68 * s, 0.06), Vector2(0.86 * s, 0.20),
			Vector2(0.52 * s, 0.30), Vector2(0.14 * s, 0.16),
		])
		c.draw_circle(o + Vector2(0.30 * s, -0.44) * r, 0.15 * r, col)
		_poly(c, o, r, col, [
			Vector2(0.44 * s, -0.50), Vector2(0.72 * s, -0.42),
			Vector2(0.44 * s, -0.34),
		])
	# Tail feathers.
	_poly(c, o, r, col, [
		Vector2(-0.16, 0.78), Vector2(0.16, 0.78),
		Vector2(0.09, 0.98), Vector2(-0.09, 0.98),
	])


static func _lion_rampant(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	# Rearing, facing left, in the usual attitude.
	_poly(c, o, r, col, [
		Vector2(-0.12, -0.34), Vector2(0.16, -0.10), Vector2(0.34, 0.44),
		Vector2(0.42, 0.86), Vector2(0.18, 0.86), Vector2(0.10, 0.50),
		Vector2(-0.14, 0.16), Vector2(-0.30, -0.12),
	])
	c.draw_circle(o + Vector2(-0.34, -0.48) * r, 0.20 * r, col)
	# Mane.
	for i in 7:
		var a := PI * 0.45 + float(i) / 7.0 * PI * 1.15
		c.draw_circle(o + Vector2(-0.34, -0.48) * r
			+ Vector2(cos(a), sin(a)) * 0.26 * r, 0.075 * r, col)
	# Forelegs, thrown forward.
	_limb(c, o, r, col, Vector2(-0.18, -0.24), Vector2(-0.66, -0.30), 0.075)
	_limb(c, o, r, col, Vector2(-0.14, -0.06), Vector2(-0.58, 0.14), 0.070)
	# Hind leg and paw.
	_limb(c, o, r, col, Vector2(0.28, 0.42), Vector2(0.20, 0.92), 0.085)
	# Tail, curled over the back.
	c.draw_arc(o + Vector2(0.46, 0.10) * r, 0.34 * r, PI * 0.15, PI * 1.25,
		18, col, 0.075 * r)


static func _crossed_keys(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	for s in [-1.0, 1.0]:
		var bow := Vector2(0.58 * s, 0.62)
		var tip := Vector2(-0.44 * s, -0.62)
		_limb(c, o, r, col, bow, tip, 0.070)
		c.draw_arc(o + bow * r, 0.20 * r, 0.0, TAU, 22, col, 0.075 * r)
		# Wards at the business end, set square to the shaft.
		var dir := (tip - bow).normalized()
		var perp := Vector2(-dir.y, dir.x)
		for k in [0.16, 0.30]:
			var base: Vector2 = tip - dir * float(k)
			_limb(c, o, r, col, base, base + perp * 0.20 * s, 0.055)


static func _three_towers(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	_tower(c, o, r, col, Vector2(0.00, -0.10), 0.30, 0.94)
	_tower(c, o, r, col, Vector2(-0.56, 0.16), 0.24, 0.70)
	_tower(c, o, r, col, Vector2(0.56, 0.16), 0.24, 0.70)


static func _tower(c: CanvasItem, o: Vector2, r: float, col: Color, at: Vector2,
		w: float, h: float) -> void:
	_poly(c, o, r, col, [
		at + Vector2(-w, 0.0), at + Vector2(w, 0.0),
		at + Vector2(w, h), at + Vector2(-w, h),
	])
	# Crenellations: three merlons across the top.
	for i in 3:
		var x := at.x - w + (float(i) + 0.5) * (2.0 * w / 3.0)
		_poly(c, o, r, col, [
			Vector2(x - w * 0.22, at.y), Vector2(x + w * 0.22, at.y),
			Vector2(x + w * 0.22, at.y - h * 0.20),
			Vector2(x - w * 0.22, at.y - h * 0.20),
		])
	# Door.
	_poly(c, o, r, col.darkened(0.55), [
		at + Vector2(-w * 0.28, h), at + Vector2(w * 0.28, h),
		at + Vector2(w * 0.28, h * 0.52), at + Vector2(-w * 0.28, h * 0.52),
	])


static func _stag(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	_poly(c, o, r, col, [
		Vector2(-0.44, 0.06), Vector2(0.34, -0.04), Vector2(0.48, 0.20),
		Vector2(0.36, 0.42), Vector2(-0.36, 0.44), Vector2(-0.52, 0.24),
	])
	for x in [-0.30, -0.06, 0.16, 0.36]:
		_limb(c, o, r, col, Vector2(x, 0.40), Vector2(x - 0.04, 0.92), 0.055)
	# Neck and head, raised.
	_limb(c, o, r, col, Vector2(-0.38, 0.10), Vector2(-0.62, -0.42), 0.11)
	_poly(c, o, r, col, [
		Vector2(-0.60, -0.36), Vector2(-0.88, -0.52),
		Vector2(-0.84, -0.62), Vector2(-0.56, -0.50),
	])
	# Antlers: two beams, three tines apiece.
	for s in [-1.0, 1.0]:
		var base := Vector2(-0.62, -0.50)
		var tip := base + Vector2(0.10 * s - 0.06, -0.44)
		_limb(c, o, r, col, base, tip, 0.038)
		for k in 3:
			var t := 0.30 + 0.28 * float(k)
			var p := base.lerp(tip, t)
			_limb(c, o, r, col, p, p + Vector2(0.16 * s, -0.12), 0.030)


static func _wolf_head(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	# In profile, facing left, couped at the neck.
	_poly(c, o, r, col, [
		Vector2(-0.92, 0.06), Vector2(-0.52, -0.20), Vector2(-0.20, -0.34),
		Vector2(0.30, -0.30), Vector2(0.52, 0.10), Vector2(0.44, 0.62),
		Vector2(-0.10, 0.56), Vector2(-0.46, 0.34), Vector2(-0.88, 0.22),
	])
	for s in [0.0, 1.0]:
		_poly(c, o, r, col, [
			Vector2(-0.26 + 0.34 * s, -0.32), Vector2(-0.14 + 0.34 * s, -0.74),
			Vector2(0.04 + 0.34 * s, -0.36),
		])
	c.draw_circle(o + Vector2(-0.30, -0.02) * r, 0.065 * r, col.darkened(0.7))
	c.draw_circle(o + Vector2(-0.84, 0.10) * r, 0.055 * r, col.darkened(0.7))
	# Bared teeth.
	for i in 3:
		var x := -0.74 + 0.13 * float(i)
		_poly(c, o, r, col.darkened(0.55), [
			Vector2(x, 0.16), Vector2(x + 0.07, 0.16), Vector2(x + 0.035, 0.30),
		])


static func _knot_ring(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	c.draw_arc(o, 0.72 * r, 0.0, TAU, 40, col, 0.13 * r)
	# Three interlaced loops. No seals in the Nether March, so this device is
	# only ever seen carved or embroidered — never in wax, which is the point.
	for i in 3:
		var a := float(i) / 3.0 * TAU
		var centre := o + Vector2(cos(a), sin(a)) * 0.40 * r
		c.draw_arc(centre, 0.34 * r, 0.0, TAU, 26, col, 0.085 * r)


static func _crozier(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	_limb(c, o, r, col, Vector2(0.10, 0.98), Vector2(0.10, -0.20), 0.085)
	# The crook: an open spiral, tightening.
	var pts := PackedVector2Array()
	for i in 26:
		var t := float(i) / 25.0
		var a := PI * 0.5 + t * PI * 1.75
		var rad := (0.46 - 0.26 * t) * r
		pts.append(o + Vector2(0.10, -0.34) * r + Vector2(cos(a), -sin(a)) * rad)
	for i in pts.size() - 1:
		c.draw_line(pts[i], pts[i + 1], col, 0.085 * r)
	c.draw_circle(o + Vector2(0.10, 0.98) * r, 0.09 * r, col)


# ------------------------------------------------- the notary's three rings
# Not heraldry. These are office marks: the Chancery's own signs for the three
# things a notary is permitted to say. They have to be distinguishable at a
# glance and while sunk in wax, so each is built on a different underlying
# geometry — cross, saltire, chevron — rather than differing in detail.

static func _notary_confirm(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	c.draw_arc(o, 0.84 * r, 0.0, TAU, 34, col, 0.09 * r)
	_limb(c, o, r, col, Vector2(0.0, -0.58), Vector2(0.0, 0.58), 0.085)
	_limb(c, o, r, col, Vector2(-0.58, 0.0), Vector2(0.58, 0.0), 0.085)
	# Potent ends: a bar across each arm, so it does not read as a plain cross.
	for v in [Vector2(0.0, -0.58), Vector2(0.0, 0.58)]:
		_limb(c, o, r, col, v + Vector2(-0.18, 0), v + Vector2(0.18, 0), 0.060)
	for v in [Vector2(-0.58, 0.0), Vector2(0.58, 0.0)]:
		_limb(c, o, r, col, v + Vector2(0, -0.18), v + Vector2(0, 0.18), 0.060)


static func _notary_deny(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	c.draw_arc(o, 0.84 * r, 0.0, TAU, 34, col, 0.09 * r)
	_limb(c, o, r, col, Vector2(-0.52, -0.52), Vector2(0.52, 0.52), 0.10)
	_limb(c, o, r, col, Vector2(0.52, -0.52), Vector2(-0.52, 0.52), 0.10)


static func _notary_refer(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	c.draw_arc(o, 0.84 * r, 0.0, TAU, 34, col, 0.09 * r)
	# A chevron pointing up: sent higher.
	for k in [0.0, 0.36]:
		_limb(c, o, r, col, Vector2(-0.46, 0.18 + k), Vector2(0.0, -0.34 + k), 0.095)
		_limb(c, o, r, col, Vector2(0.0, -0.34 + k), Vector2(0.46, 0.18 + k), 0.095)


static func _unknown(c: CanvasItem, o: Vector2, r: float, col: Color) -> void:
	c.draw_arc(o, 0.66 * r, 0.0, TAU, 30, col, 0.10 * r)
	c.draw_line(o + Vector2(-0.4, -0.4) * r, o + Vector2(0.4, 0.4) * r, col, 0.10 * r)
	c.draw_line(o + Vector2(0.4, -0.4) * r, o + Vector2(-0.4, 0.4) * r, col, 0.10 * r)


# ------------------------------------------------------------------- helpers

static func _poly(c: CanvasItem, o: Vector2, r: float, col: Color,
		unit_points: Array) -> void:
	var pts := PackedVector2Array()
	for v in unit_points:
		pts.append(o + (v as Vector2) * r)
	c.draw_colored_polygon(pts, col)


## A limb or shaft: a thick line with rounded ends, which reads better at small
## sizes than a stroked polygon.
static func _limb(c: CanvasItem, o: Vector2, r: float, col: Color,
		from: Vector2, to: Vector2, width: float) -> void:
	var a := o + from * r
	var b := o + to * r
	c.draw_line(a, b, col, width * r * 2.0)
	c.draw_circle(a, width * r, col)
	c.draw_circle(b, width * r, col)

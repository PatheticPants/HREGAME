class_name WaxPool
extends Node2D

## The wax the player pours and then presses. Parented to the sheet it lands on,
## so it travels with the document afterwards.
##
## THREE RULES
## -----------
##  1. The outline is generated ONCE from a seed and thereafter only scaled and
##     deformed. Randomising the edge inside _draw makes the pool shimmer and
##     instantly reads as an effect rather than as a substance.
##
##  2. Volume spreads by AREA, so radius goes as sqrt(amount). Pouring twice as
##     long makes a pool 1.4x wider, not 2x — which is why over-pouring creeps up
##     on you instead of being obvious, and why the good band is findable by feel.
##
##  3. THE DIE STRIKES WHERE THE RING WAS. Not the middle of the pool. If you
##     press the edge, you get an edge impression: the device runs off the wax,
##     the far side bulges where the metal shoved the material out from under
##     itself, and what you are left with is a half-legible seal that anyone
##     looking at the document can see was struck by a careless hand.
##
## THE SILHOUETTE
## --------------
## The pool is a polygon, textured with one of the authored pixel-wax plates via
## UVs, rather than a texture rect. That costs a few lines and buys three things
## that matter: the edge can be deformed by the press, the impression can be
## clipped exactly to the material, and the shape is real geometry the rest of
## the code can ask questions about.

const WAX_TEXTURES := [
	preload("res://art/props/wax_pool_0.png"),
	preload("res://art/props/wax_pool_1.png"),
	preload("res://art/props/wax_pool_2.png"),
	preload("res://art/props/wax_pool_3.png"),
]

## The texture art is drawn to fill its square, so the polygon is mapped a little
## inside the image to avoid sampling the transparent rim.
const UV_INSET := 0.94

var feel: WaxFeel

var amount := 0.0          ## poured volume
var radius := 0.0          ## current drawn radius, eased toward target
var age := 0.0             ## seconds since the first drop; drives cooling
var color := Color(0.55, 0.11, 0.17)
var opacity := 1.0

var impressed := false
var device: StringName = &""
var ring_rotation := 0.0
var seat_depth := 0.0
var smeared := false
var smear_offset := Vector2.ZERO

## Where the die actually met the wax, in this pool's local space. Set once, at
## the moment the wax gives. Everything about the impression hangs off it.
var press_offset := Vector2.ZERO

## Radius of the die face. The struck region is this circle intersected with the
## wax, which is what produces partial impressions near the rim.
var die_radius := 23.0

## 0..1 while the ring is coming away. Drives the string of wax that follows the
## metal up and then breaks.
var peel := 0.0

## Momentary bulge when a drop lands, decaying. Wax arriving on a page should
## visibly disturb what is already there.
var impact := 0.0

## Where the text of the document starts, in this node's local space. If the
## pool grows past it the ledger notices that the writing was fouled.
var text_guard_radius := 74.0

var _unit: PackedVector2Array = PackedVector2Array()
var _splashes: Array[Vector3] = []   ## x, y, radius
var _rng := RandomNumberGenerator.new()
var _seed := 0
var _spread_velocity := 0.0
var _impact_phase := 0.0

## Set by the desk, like every other lit thing on the table. Wax is glossy, so it
## takes a rim light on the side facing the flame and the highlight travels round
## it as the candle is carried past.
var light_position := Vector2(0, -600)
var light_level := 0.6

var _under: Node2D
var _body: Node2D
var _stamp: Node2D
var _overlay: Node2D


func setup(wax_feel: WaxFeel, wax_color: Color, rng_seed: int) -> void:
	feel = wax_feel
	color = wax_color
	_seed = rng_seed
	_rng.seed = rng_seed
	_unit = WaxShape.outline(&"round", rng_seed, feel.blob_jitter, feel.blob_points)
	# Opacity varies per pour, per the brief: no two impressions identical.
	opacity = clampf(1.0 - _rng.randf_range(0.0, feel.opacity_jitter), 0.55, 1.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# THE WAX OBEYS THE DESK'S STACKING RULE LIKE EVERYTHING ELSE.
	#
	# This was z_index = 1, which with Godot's default z_as_relative put the pool
	# one step above its host sheet — and a CanvasItem at a higher z draws above
	# ALL lower-z siblings regardless of tree order. So a sealed charter's wax
	# floated above every other paper on the desk permanently: slide a docket over
	# a struck seal and the seal stayed on top of it, while the brass spoon (which
	# drops back to z=0 the moment it is set down flat) slid underneath the very
	# wax it had just poured.
	#
	# It needs no z at all. The pool is a CHILD of the sheet, and children always
	# draw after their parent — so it sits on the parchment it was poured onto,
	# travels with it, and is covered by anything the player lays over it. Which
	# is the entire documented contract of this desk: draw order is child order in
	# `surface`, full stop.
	z_index = 0
	_build_layers()
	set_process(true)


## Four layers, because the impression has to be masked by the material and the
## peel string must not be. clip_children on the body makes the wax silhouette
## itself the stencil for everything struck into it — which is exactly what a
## die does to a pool that is smaller than the die.
func _build_layers() -> void:
	_under = Node2D.new()
	_under.name = "beneath"
	_under.draw.connect(_draw_under)
	add_child(_under)

	_body = Node2D.new()
	_body.name = "body"
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Stencils the impression to the material. Verified rendering correctly in
	# gl_compatibility on 4.6: a die that overhangs the pool leaves a device that
	# stops dead at the edge of the wax, which is the whole point of the system.
	_body.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_body.draw.connect(_draw_body)
	add_child(_body)

	_stamp = Node2D.new()
	_stamp.name = "stamp"
	_stamp.draw.connect(_draw_stamp)
	_body.add_child(_stamp)

	_overlay = Node2D.new()
	_overlay.name = "overlay"
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func seed_value() -> int:
	return _seed


func wax_texture() -> Texture2D:
	return WAX_TEXTURES[posmod(_seed, WAX_TEXTURES.size())]


## Record the strike. Called once, when the wax gives under the ring.
func strike(at_local: Vector2, die: StringName, rotation_rad: float,
		face_radius: float) -> void:
	# Clamped so a press that only just caught the rim still leaves *something*
	# rather than an impression floating entirely off the material.
	var reach := radius + face_radius * 0.55
	press_offset = at_local.limit_length(maxf(1.0, reach))
	device = die
	ring_rotation = rotation_rad
	die_radius = face_radius
	impressed = true
	seat_depth = 0.35
	impact = maxf(impact, 0.82)
	_impact_phase = 0.0


## How much of the die actually landed on wax, 0..1. Used for grading, so a press
## hanging half off the pool is recorded as the botch it is.
func strike_coverage() -> float:
	if not impressed or radius <= 0.5:
		return 0.0
	var struck := _struck_polygons()
	if struck.is_empty():
		return 0.0
	var area := 0.0
	for poly in struck:
		area += absf(_polygon_area(poly))
	var full := PI * die_radius * die_radius
	return clampf(area / maxf(1.0, full), 0.0, 1.0)


func add_drop() -> void:
	amount += feel.drop_volume
	impact = 1.0
	_impact_phase = 0.0
	# The arriving volume carries momentum before surface tension reins it in.
	_spread_velocity += maxf(0.45, (target_radius() - radius) * 0.12)
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(0.35, 0.95)
	_splashes.append(Vector3(cos(a) * d, sin(a) * d, _rng.randf_range(0.10, 0.24)))
	if _splashes.size() > 14:
		_splashes.remove_at(0)


func target_radius() -> float:
	# Area, not radius, is proportional to volume.
	return feel.radius_at_unit * sqrt(maxf(0.0, amount))


func is_blotted() -> bool:
	return amount > feel.blot_at


func is_thin() -> bool:
	return amount < feel.good_low


func is_cool() -> bool:
	return age > feel.cool_time


func chill() -> float:
	return clampf(age / maxf(0.01, feel.cool_time), 0.0, 1.0)


func obscures_text() -> bool:
	return radius > text_guard_radius


func _process(delta: float) -> void:
	# Node2D processes from the frame it enters the tree, which is one call
	# before setup() has built the layers or handed over the tuning resource.
	if feel == null or _body == null:
		return
	age += delta
	# The pool rides on a sheet that already knows where the flame is, so it
	# inherits rather than being wired separately into the desk's light loop.
	var host := get_parent() as Draggable
	if host != null:
		light_position = host.light_position
		light_level = host.light_level
	# A critically damped viscous spring. Every drop pushes the rim outward, then
	# surface tension settles it; a direct lerp made the pool inflate like a UI
	# progress disc with no carried momentum.
	var target := target_radius()
	var stiffness := feel.spread_speed * feel.spread_speed * 2.9
	var damping := feel.spread_speed * 3.35
	_spread_velocity += (target - radius) * stiffness * delta
	_spread_velocity *= exp(-damping * delta)
	radius = maxf(0.0, radius + _spread_velocity * delta)
	if absf(target - radius) < 0.02 and absf(_spread_velocity) < 0.02:
		radius = target
		_spread_velocity = 0.0
	_impact_phase += delta * 20.0
	impact = maxf(0.0, impact - delta * 3.4)
	_under.queue_redraw()
	_body.queue_redraw()
	_stamp.queue_redraw()
	_overlay.queue_redraw()


# ------------------------------------------------------------------ geometry

## The pool's current outline. Deformed by the die: material squeezed out from
## under the metal has to go somewhere, so points near the strike are pushed away
## from it and the far rim swells. This is the difference between a stamp that
## sits on top of the wax and one that is in it.
func _outline(scale_factor := 1.0) -> PackedVector2Array:
	var surface_wave := sin(_impact_phase) * impact
	var r := radius * scale_factor * (1.0 + surface_wave * 0.045)
	var points := PackedVector2Array()
	points.resize(_unit.size())
	var displace := seat_depth if impressed else 0.0
	for i in _unit.size():
		var p := _unit[i] * r
		if displace > 0.0:
			var from_press := p - press_offset
			var d := from_press.length()
			# Only the rim within reach of the die moves, and it moves outward
			# along the line from the strike — the same way a thumb pressed into
			# putty raises a lip in front of it.
			var influence := clampf(1.0 - d / maxf(1.0, die_radius * 2.3), 0.0, 1.0)
			if influence > 0.0 and d > 0.01:
				p += from_press / d * influence * displace * die_radius * 0.30
		points[i] = p
	return points


static func _circle(centre: Vector2, r: float, segments := 28) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i in segments:
		var a := float(i) / float(segments) * TAU
		points[i] = centre + Vector2(cos(a), sin(a)) * r
	return points


## Where the die met material: the die face intersected with the wax silhouette.
## Empty if the press missed the pool entirely.
func _struck_polygons() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if radius <= 0.5:
		return out
	var face := _circle(press_offset, die_radius)
	for poly in Geometry2D.intersect_polygons(_outline(), face):
		out.append(poly)
	return out


static func _polygon_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


## UVs mapping the polygon onto the authored wax plate. Computed from the
## undeformed unit outline so the pixel texture does not swim when the rim bulges.
func _uvs_for(points: PackedVector2Array) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	uvs.resize(points.size())
	var r := maxf(1.0, radius)
	for i in points.size():
		uvs[i] = Vector2(0.5, 0.5) + points[i] / (r * 2.0) * UV_INSET
	return uvs


# ------------------------------------------------------------------- drawing

## MOLTEN IS DARKER THAN SET. This had it exactly the wrong way round.
##
## Set wax is pale because it is full of microcrystals that scatter light back
## out of it. Melted, those are gone, it goes clear, and what you see is the
## shaded bottom of the pool through a translucent liquid. docs/GRAPHICS.md
## states this as one of two physics facts that had already been shipped
## backwards once — and names the candle as the place it was fixed. It was never
## applied here, on the seal, which is the object the whole game is named after.
##
## Measured before the change, on the press's own tint Color(0.60, 0.13, 0.16):
## molten came out at luminance 0.280 and fully set at 0.176, so the liquid was
## 59% BRIGHTER than the solid. It now runs 0.172 molten to 0.276 set.
##
## The old version also lerped fresh wax toward a bright orange on the grounds
## that it was "hot enough to glow slightly on its own". Wax pours at about a
## hundred and twenty degrees and does not glow at any temperature it survives.
## What actually distinguishes hot wax is that it is WET, and that cue already
## existed and was already correct — _draw_body's gloss is scaled by (1 - chill)
## and tracks the flame. So the colour was fighting a cue that was already
## right; now they agree, and freshly poured wax reads as dark, wet and
## translucent while set wax reads as pale, dry and opaque.
##
## The gameplay signal survives the inversion unharmed. The pool still changes
## visibly as it goes off — which is what makes the pour and the press two
## decisions rather than one — it simply now changes in the direction real
## sealing wax changes.
func _wax_colour() -> Color:
	var c := Color(color, opacity)
	var cold := chill()
	c = c.darkened((1.0 - cold) * 0.26)
	# Going opaque and chalky as the crystals come out of it.
	return c.lerp(Color(0.78, 0.34, 0.30, c.a), cold * 0.22)


func _draw_under() -> void:
	if radius <= 0.5:
		return
	var col := _wax_colour()

	# Satellite droplets that spattered clear of the pool. Drawn beneath the
	# body so they never act as part of the stencil for the impression.
	for s in _splashes:
		var p := Vector2(s.x, s.y) * radius * 1.28
		_under.draw_circle(p, s.z * radius * 0.62,
			Color(col.darkened(0.16), col.a * 0.85))

	# Where the die overhung the wax it still met parchment. A faint ring pressed
	# into the page is the tell that the strike was off the material — visible
	# only in the gap the wax does not cover, because the wax is drawn over it.
	if impressed and seat_depth > 0.2:
		_under.draw_arc(press_offset, die_radius * 0.97, 0.0, TAU, 30,
			Color(0.28, 0.22, 0.16, 0.20 * seat_depth), 2.0)
		_under.draw_circle(press_offset, die_radius * 0.94,
			Color(0.30, 0.24, 0.17, 0.07 * seat_depth))


## The bead of wax itself.
##
## Rendered rather than blitted. The authored wax plates are lovely, but every
## one of them has a rim and a sunken centre painted into it — which is a
## *centred* impression, baked in, and that is precisely the thing this system
## exists to stop asserting. A plate says "the die landed in the middle" before
## the player has touched the ring. So the pool is drawn from its own geometry
## and the plates are kept for the cooled crumbs on the blotter, where a fixed
## seal shape is exactly right.
func _draw_body() -> void:
	if radius <= 0.5:
		return
	var col := _wax_colour()
	var points := _outline()
	var lit := (light_position - global_position).normalized()
	if lit.length() < 0.5:
		lit = Vector2(-0.6, -0.8)

	# Contact shadow of the bead on the page.
	_body.draw_colored_polygon(_offset_polygon(points, -lit * 2.6 + Vector2(0, 1.2)),
		Color(0.10, 0.02, 0.03, 0.34 * col.a))

	# The body, then a darker skirt where it meets the parchment, then the top
	# surface pulled in from the edge — three passes is enough to read as a
	# domed blob of material rather than a flat sticker.
	_body.draw_colored_polygon(points, col.darkened(0.34))
	_body.draw_colored_polygon(_scaled_polygon(points, 0.93), col)
	_body.draw_colored_polygon(
		_offset_polygon(_scaled_polygon(points, 0.86), lit * radius * 0.045),
		col.lightened(0.05))

	# Rim light along the edge facing the flame. This is the term that makes the
	# wax respond when the candle is carried past it.
	var rim := _offset_polygon(_scaled_polygon(points, 0.97), lit * radius * 0.075)
	_body.draw_colored_polygon(rim, Color(col.lightened(0.30),
		col.a * 0.30 * clampf(light_level, 0.15, 1.0)))
	_body.draw_colored_polygon(_scaled_polygon(points, 0.90), col)

	# A hot pool is wet. The gloss shrinks and dulls as it sets.
	var wet := (1.0 - chill()) * (0.55 + impact * 0.4)
	if wet > 0.02:
		var gloss := _offset_polygon(_scaled_polygon(points, 0.44),
			lit * radius * 0.30)
		_body.draw_colored_polygon(gloss,
			Color(1.0, 0.78, 0.60, 0.20 * wet))

	# The landing ring travels out across the surface and disappears into the
	# meniscus. It follows the same decaying phase that briefly flexes the rim.
	if impact > 0.025:
		var wave_t := clampf(_impact_phase / 6.0, 0.0, 1.0)
		var wave_r := radius * lerpf(0.18, 0.78, wave_t)
		_body.draw_arc(Vector2.ZERO, wave_r, 0.0, TAU, 32,
			Color(col.lightened(0.28), col.a * impact * (1.0 - wave_t) * 0.62),
			maxf(0.8, radius * 0.035))

	# Tiny resin bubbles and inclusions remain registered to this pour's seed.
	# They are strongest while hot and become pits as the wax cools.
	if radius > 12.0:
		for i in 3:
			var a := fposmod(float(_seed) * 0.017 + float(i) * 2.17, TAU)
			var d := radius * (0.24 + float(i) * 0.13)
			var bubble := Vector2(cos(a), sin(a)) * d
			var br := maxf(0.75, radius * (0.021 + i * 0.004))
			_body.draw_circle(bubble + Vector2(0.6, 0.8), br,
				Color(col.darkened(0.55), col.a * 0.48))
			_body.draw_arc(bubble + Vector2(-0.3, -0.3), br * 0.72,
				PI * 1.02, PI * 1.66, 8,
				Color(col.lightened(0.34), col.a * lerpf(0.35, 0.13, chill())), 0.8)


func _draw_stamp() -> void:
	if not impressed or radius <= 0.5:
		return
	var col := _wax_colour()
	var struck := _struck_polygons()
	if struck.is_empty():
		return

	# The sunken field, exactly the shape of the overlap. Off-centre presses get
	# a crescent, not a disc, and that is the whole point.
	for poly in struck:
		_stamp.draw_colored_polygon(poly,
			Color(col.darkened(0.16 + seat_depth * 0.14), col.a))

	# Raised lip where the metal pushed material up around its edge.
	_stamp.draw_arc(press_offset, die_radius * 0.99, 0.0, TAU, 34,
		Color(col.lightened(0.20), col.a * 0.55 * seat_depth),
		maxf(1.5, die_radius * 0.10))
	_stamp.draw_arc(press_offset, die_radius * 0.86, 0.0, TAU, 34,
		Color(col.darkened(0.42), col.a * 0.70 * seat_depth),
		maxf(1.2, die_radius * 0.07))

	# At desk scale the matrix legend is unreadable but visibly present. The
	# glass resolves these strokes into actual circular lettering.
	for i in 24:
		var a := float(i) / 24.0 * TAU + ring_rotation
		var dir := Vector2(cos(a), sin(a))
		_stamp.draw_line(press_offset + dir * die_radius * 0.69,
			press_offset + dir * die_radius * 0.79,
			Color(col.darkened(0.46), col.a * 0.80 * seat_depth),
			maxf(0.7, die_radius * 0.025))

	if smeared:
		# A smear is the same device dragged: the ghost sits back along the
		# direction the hand actually moved.
		_stamp.draw_set_transform(press_offset - smear_offset, ring_rotation,
			Vector2.ONE)
		Heraldry.draw_device(_stamp, device, Vector2.ZERO, die_radius * 0.58,
			Color(col.darkened(0.45), col.a * 0.32))
		_stamp.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The device itself. Everything drawn by this node is stencilled by the wax
	# silhouette above it, so a die hanging over the rim leaves a device that
	# simply stops at the edge of the material.
	# The strike is drawn inside a rotated transform, so the flame direction has
	# to be rotated into that frame or the light would spin with the die.
	var struck_light := (light_position - global_position)
	struck_light = struck_light.normalized() if struck_light.length() > 1.0 \
		else Vector2(-0.65, -0.75)
	_stamp.draw_set_transform(press_offset, ring_rotation, Vector2.ONE)
	Heraldry.draw_device_incuse(_stamp, device, Vector2.ZERO,
		die_radius * 0.58, col, clampf(seat_depth, 0.25, 1.0),
		struck_light.rotated(-ring_rotation))
	_stamp.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_overlay() -> void:
	if peel > 0.001 and radius > 0.5:
		_draw_peel_string(_wax_colour())
	_draw_shade()


## THE SEAL GOES INTO SHADOW WITH THE PAGE IT IS ON.
##
## docs/GRAPHICS.md is explicit that the veil covers the FINISHED FACE of
## anything with readable content — substrate, ink, rubric and seal together —
## and lists four objects that were missed on the first pass, each of which was
## a hole in the claim that the candle controls what can be read. This was the
## fifth, and it is the one the game is named after.
##
## The reason it slipped is structural rather than an oversight. The pool is a
## CHILD of the sheet, and children draw after their parent, so the sheet's own
## veil is laid down and then the pool draws straight over the top of it. A
## sealed charter carried to the dark end of the desk went properly grey
## everywhere except the seal, which stayed at full strength — so the one part
## of the document that records an irreversible decision was also the one part
## the candle had no authority over.
##
## It inherits the host's alpha rather than computing its own, for the same
## reason it inherits light_position and light_level: a board and a charter lying
## beside each other have to go dark together, and a seal has to go dark with the
## page it is stuck to.
func shade_alpha() -> float:
	var host := get_parent() as Draggable
	return host.shade_alpha() if host != null else 0.0


func _draw_shade() -> void:
	if radius <= 0.5:
		return
	var a := shade_alpha()
	if a <= 0.01:
		return
	var points := _outline()
	if points.size() < 3:
		return
	_overlay.draw_colored_polygon(points, Color(Draggable.SHADE_COLOR, a))


## A thread of wax follows the ring up, thins, and snaps near the end of the
## lift. Drawn as a tapering strip rather than a line so it necks properly in the
## middle, which is what makes it read as sticky rather than as a wire. It rises
## from the strike, not from the middle of the pool.
func _draw_peel_string(col: Color) -> void:
	var t := clampf(peel, 0.0, 1.0)
	var broken := t > 0.74
	var reach := feel.peel_stretch * (t if not broken else 0.74) * 2.4
	var root := press_offset
	var head := root + Vector2(-2.0, -reach)
	var segs := 9
	var prev := root
	for i in range(1, segs + 1):
		var f := float(i) / float(segs)
		var p := root.lerp(head, f)
		var thin := 1.0 - 0.85 * sin(f * PI)
		var w := maxf(0.6, die_radius * 0.30 * thin * (1.0 - t * 0.55))
		if broken and f > 0.45:
			break
		_overlay.draw_line(prev, p,
			Color(col.lightened(0.05), col.a * (1.0 - t * 0.4)), w)
		prev = p
	if broken:
		_overlay.draw_circle(head + Vector2(0, -reach * 0.22), die_radius * 0.12,
			Color(col, col.a * (1.0 - (t - 0.74) / 0.26)))


static func _offset_polygon(points: PackedVector2Array,
		by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = points[i] + by
	return out


static func _scaled_polygon(points: PackedVector2Array,
		by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = points[i] * by
	return out


# ------------------------------------------------------------------- the lens
# Same two-method contract the pendant seal and the charter's foot already use.
# Putting the glass on your own work and reading what your hands actually did is
# the moment the press stops being an animation and becomes a thing you have a
# standard about.

func has_detail() -> bool:
	return impressed and radius > 0.5


func detail_centre() -> Vector2:
	return to_global(press_offset)


func draw_detail(c: CanvasItem, at: Vector2, radius_px: float) -> void:
	var col := _wax_colour()
	var r := radius_px * 0.84
	var mapping := r / maxf(1.0, radius)
	var pool_centre := at - press_offset * mapping

	# The actual pour stays registered beneath the strike: an off-rim impression
	# therefore reveals the displaced body of wax instead of being recentered
	# into a falsely perfect museum seal.
	# Same flame as the pendant seals. The player's own impression has to relight
	# when the candle moves, or their work looks painted and the petitioner's
	# looks real.
	var light := (light_position - global_position)
	light = light.normalized() if light.length() > 1.0 else Vector2(-0.65, -0.75)
	WaxShape.draw_magnified_body(c, _unit, pool_centre, r, col, light)
	for poly in _struck_polygons():
		var mapped := PackedVector2Array()
		for p in poly:
			mapped.append(at + (p - press_offset) * mapping)
		c.draw_colored_polygon(mapped, col.darkened(0.27))
		if not mapped.is_empty():
			mapped.append(mapped[0])
			c.draw_polyline(mapped, col.darkened(0.50),
				maxf(1.3, radius_px * 0.018), true)

	var die_r := die_radius * mapping
	c.draw_arc(at, die_r * 0.88, 0.0, TAU, 40,
		Color(col.darkened(0.52), col.a * clampf(strike_coverage(), 0.25, 1.0)), 2.1)
	Heraldry.draw_device_incuse(c, device, at, die_r * 0.56, col,
		clampf(seat_depth, 0.25, 1.0), light)
	var legend := "SIGILLVM • NOTARII •"
	Ink.circular_incuse(c, at, legend, die_r * 0.72, 10, col,
		clampf(seat_depth, 0.25, 1.0), -c.rotation, light)


## Grade the impression once the ring has come away. This is craft, not law: a
## legally correct ruling can still be recorded as a botched seal.
func grade(drift: float) -> ImpressionRecord:
	var rec := ImpressionRecord.new()
	rec.wax_amount = amount
	rec.seat_depth = seat_depth
	rec.drift = drift
	rec.ring_rotation_deg = rad_to_deg(ring_rotation)
	rec.shape_seed = _seed
	rec.obscured_text = obscures_text()

	var coverage := strike_coverage()

	# Ordered worst-first: the most obvious failure is the one the ledger names.
	if smeared:
		rec.grade = Lex.Grade.SMEARED
	elif coverage < 0.55:
		# Struck over the rim. The device is half on the parchment and the seal
		# is not a seal.
		rec.grade = Lex.Grade.SHALLOW
	elif is_blotted():
		rec.grade = Lex.Grade.BLOTTED
	elif is_thin():
		rec.grade = Lex.Grade.THIN
	elif seat_depth < feel.shallow_below:
		rec.grade = Lex.Grade.SHALLOW
	elif amount > feel.good_low * 1.12 and amount < feel.good_high * 0.92 \
			and seat_depth > 0.86 and coverage > 0.93 \
			and drift < feel.smear_distance * 0.35:
		rec.grade = Lex.Grade.FINE
	else:
		rec.grade = Lex.Grade.GOOD
	return rec

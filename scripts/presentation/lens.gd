class_name Lens
extends Draggable

## A glass in a brass ring, on a handle.
##
## The seal's legend is not legible on the desk. You can see that there is
## lettering around the rim and you cannot read a word of it, and the only way to
## read it is to put the glass over the wax. That makes the lens a verb rather
## than decoration, and it makes the seal check a physical act — find the seal in
## the pile, get the glass onto it, keep it there.
##
## Anything can be inspectable: the lens looks for has_detail() and draw_detail()
## by name rather than by base class, so a future document becomes magnifiable by
## adding two methods and nothing else.

const RADIUS := 116.0
const APERTURE_RADIUS := 86.0
const HOME_POSITION := Vector2(665.0, 115.0)
const HOME_ANGLE := -14.0
const CHASSIS := preload("res://art/props/magnifying_glass_chassis.png")
const REFRACTION_SHADER := preload("res://shaders/lens_refraction.gdshader")

# The generated chassis is deliberately kept as one source plate, but the ring
# and handle are drawn as separate regions. That lets the aperture stay broad
# enough to read while the handle is shortened to the desk's established scale.
const RING_SOURCE := Rect2(331, 50, 587, 710)
const HANDLE_SOURCE := Rect2(500, 650, 250, 543)
const RING_TARGET := Rect2(-RADIUS, -RADIUS, RADIUS * 2.0, RADIUS * 2.42)
const HANDLE_TARGET := Rect2(-36.0, 98.0, 72.0, 150.0)

signal focus_confirmed(subject: Node2D)

## Everything the glass might be held over. Set by the desk when it builds.
var subjects: Array[Node2D] = []

var _focus: Node2D = null
var _focus_amount := 0.0
var _focus_dwell := 0.0
## How settled the glass is, 0..1, from its own speed.
##
## KEPT, UNUSED BY THE SHADER, AND HERE IS WHY. The owner's report is right and
## unfixed: the glass magnifies two of the seventeen objects on the desk, because
## only `CharterView` and `SealTag` implement the detail contract and everything
## else — the four books, the dockets, the letters, the tablet — gets nothing.
##
## The obvious fix is the screen-space path that already exists: the shader
## samples `hint_screen_texture` behind a `BackBufferCopy`, so raising the
## magnification enlarges ANY object without it implementing a thing, and cannot
## see through a page because a page on top is what is in the picture. Tried, at
## 0.85..1.30. Two things came out of it, both measured:
##
##   - Over authored evidence it double-draws: the same sentence in the aperture
##     at two sizes, the screen copy ghosting under the redraw. A/B with the
##     magnification forced to zero isolates it. Cross-fading against
##     `_focus_amount` fixes that part cleanly.
##   - At PLAY zoom the aperture goes black. It only looked right in the capture
##     harness's 2.45x poses, which is not a camera the game is ever in — so both
##     frames that appeared to prove it were taken under a condition no player
##     sees. `lens_center_screen` is derived from the canvas transform and
##     `SCREEN_UV` from the framebuffer, and those two stop agreeing somewhere.
##
## A black aperture is a worse defect than a weak one, so the magnification is
## back at its old value and this is the note for whoever finishes it. The other
## route, if the screen path stays stubborn, is a generic `draw_detail` on Sheet
## and ReferenceBook — more code, but deterministic and resolution-independent.
## Frames 60 and 61 are the evidence, at harness zoom and at play zoom.
var _settle := 0.0
var _reported: Dictionary = {}
var _optical_lag := Vector2.ZERO
var _optics_copy: BackBufferCopy
var _optics_quad: Polygon2D
var _optics_material: ShaderMaterial

## THE APERTURE IS A CIRCLE AND THE EVIDENCE MUST BE CUT TO IT.
##
## The magnified subject used to be drawn inline in `_draw`, straight onto the
## lens's own canvas item, with nothing but good manners keeping it inside the
## glass. `CharterView.draw_detail` lays a flowed `Ink.block` into a rectangle
## 1.62 radii wide whose HEIGHT depends on how long the chancery's name happens to
## be — so the longest names ran their last line out over the brass bezel and onto
## the desk. Confirmed in shot 58: "Free City of" is printed across the bottom-left
## of the ring.
##
## Clamping the text would fix that one caller and nothing else. The whole design
## of this lens is that anything can become magnifiable by implementing
## `has_detail`/`draw_detail`, so the guarantee has to live at the aperture: the
## field is a stencil, and whatever a subject draws is cut to the glass.
##
## `CLIP_CHILDREN_ONLY` uses this node's own drawing as the mask without painting
## it. Same mechanism `WaxPool._body` already uses to stencil an impression to the
## wax it was struck into, which is verified working under gl_compatibility.
var _field: Node2D
var _detail: Node2D
## Reflections and the bezel have to survive the restructure ABOVE the evidence:
## children draw after their parent, so anything that must sit on top of the
## magnified image has to become a later sibling rather than a later line.
var _overlay: Node2D


func _ready() -> void:
	super._ready()
	hit_size = Vector2(RADIUS * 2.1, RADIUS * 2.9)
	pickup_sound = &"ring_pickup"
	drop_sound = &"stamp_set"
	slide_sound = &""
	# The aperture must transmit the candle. A solid LightOccluder2D made the
	# glass opaque; segmenting the ring then projected eight long bars across
	# nearby papers. Its short, candle-relative annular contact shadow is drawn
	# directly instead, which is the physically relevant shadow at desk height.
	occludes_light = false
	weight = 1.25
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The one object that is always on top. You hold a glass OVER things; having
	# to dig the lens out from under a charter would be irritating rather than
	# interesting, which is the line between a mechanic and a nuisance.
	z_index = 2
	_build_optics()


func _process(delta: float) -> void:
	super._process(delta)
	var found := _find_subject()
	if found != _focus:
		_focus = found
		_focus_amount = 0.0
		_focus_dwell = 0.0
	# Fade the enlarged image in rather than snapping, so sweeping the glass
	# across a crowded desk does not strobe. A moving glass resolves more slowly
	# than one set down: the high-detail face is something the player focuses,
	# not a decal that turns on at the edge of a hit radius.
	var motion := solver.speed()
	# HOW STILL THE GLASS IS, independent of whether there is anything authored
	# under it. `_focus_amount` cannot do this job: it only rises when one of the
	# two objects that implement the detail contract is in range, so keying the
	# magnification to it would have left the glass weakest over everything else
	# on the desk — which is the complaint.
	_settle = move_toward(_settle, 1.0 if motion < 60.0 else 0.0, delta * 3.2)
	var focus_rate := 6.2 if motion < 90.0 else 2.8
	_focus_amount = move_toward(_focus_amount, 1.0 if _focus != null else 0.0,
		delta * focus_rate)
	var lag_target := -solver.velocity.rotated(-global_rotation) * 0.014
	if not is_held:
		lag_target *= 0.28
	lag_target = lag_target.limit_length(6.0)
	_optical_lag = _optical_lag.lerp(lag_target,
		1.0 - pow(0.0012, delta))
	# Dwell used to accumulate only while the glass was HELD — but the enlarged
	# image draws whenever a subject is under the lens, held or not, so laying the
	# glass down on a seal looks exactly like inspecting it and reads perfectly.
	# A player who set the glass down to look at it comfortably had done the
	# intended thing and never satisfied the check: in the practice leaf, where
	# the only exit is the inspect_impression beat, that ended the game silently
	# and with everything on screen looking correct. The model was right and only
	# the grip was wrong, which is the worst way for a game to say no.
	#
	# `_reported` still dedupes per subject instance, so a glass left lying on a
	# seal reports exactly once and cannot spam the petitioner's reactions.
	var readable := _focus != null and _focus_amount > 0.78 and motion < 125.0
	if readable:
		_focus_dwell += delta
	else:
		_focus_dwell = 0.0
	if _focus != null and _focus_dwell >= 0.55:
		var subject_id := _focus.get_instance_id()
		if not _reported.has(subject_id):
			_reported[subject_id] = true
			focus_confirmed.emit(_focus)

	# The children hold the evidence and the brass, and Draggable only ever
	# redraws `self` and the hover node.
	if _field != null:
		_detail.queue_redraw()
		_overlay.queue_redraw()

	if _optics_material != null:
		var viewport_size := get_viewport_rect().size
		var centre_px := get_global_transform_with_canvas().origin
		_optics_material.set_shader_parameter("lens_center_screen",
			centre_px / viewport_size)
		# THE GLASS MAGNIFIES WHATEVER IS UNDER IT, ALWAYS, AND THAT IS THE WHOLE
		# JOB. It used to be 0.048..0.070 — a five per cent bulge — so it proved
		# there was glass in the aperture and did nothing else. Everything on this
		# desk that was not a seal, a closing formula or your own impression got
		# no enlargement at all: two of the seventeen objects on the desk, counted.
		# The books, the dockets, the letters, the tablet, all of it, nothing.
		#
		# This samples the composited screen, so it enlarges EVERY object without
		# any of them implementing anything — and it cannot see through a page,
		# because a page that is on top is what is in the picture.
		#
		# It sharpens as the glass settles: a moving glass is a glance, a still one
		# is a reading. `body` in the shader falls to zero at the rim, so the edge
		# stays true and only the middle swells, which is what a ground lens does.
		# HELD AT THE OLD VALUE ON PURPOSE, AND IT IS STILL WRONG. See the note on
		# `_settle`: raising this to a real magnification blacks the aperture out
		# at play zoom, so the honest state is the weak-but-safe one until the
		# screen-space path is understood rather than half-fixed.
		_optics_material.set_shader_parameter("magnification",
			lerpf(0.048, 0.070, _focus_amount))
		# `active` WAS THE GATE AND WAS WIRED TO THE CONSTANT 1.0.
		#
		# The uniform exists to switch the optics off, and every frame of the
		# game's life it was told they were on — so a glass shrunk into a
		# pigeonhole, or lying under the ledger at day's end, still ran a
		# backbuffer copy and a full-aperture refraction of whatever happened to
		# be behind it. A stowed lens refracting the rack is also just wrong.
		var working := 0.0 if (stowed or not visible) else 1.0
		_optics_material.set_shader_parameter("active", working)
		# And stop paying for the backbuffer copy at all when it cannot be seen.
		# COPY_MODE_DISABLED is the switch; the node stays put so nothing has to
		# be rebuilt when the glass comes back out of the hole.
		if _optics_copy != null:
			_optics_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED \
				if working <= 0.0 else BackBufferCopy.COPY_MODE_RECT


## A petitioner reacts to an inspection once, not every time the glass wobbles
## off the rim and back. Instance IDs make that rule work for any future
## inspectable object without teaching the lens what a seal is.
func begin_case() -> void:
	_reported.clear()
	_focus = null
	_focus_amount = 0.0
	_focus_dwell = 0.0
	_optical_lag = Vector2.ZERO


## What is under the glass — and it has to be UNDER it, not merely near it.
##
## This used to take the nearest `detail_centre()` within a radius and nothing
## else: no check that the subject was visible, and none that anything was lying
## on top of it. So the glass read a charter through a letter covering it, and
## snapped to a pendant seal a hand's width away while sitting on the closing
## formula. The owner reported it as the glass "seeing through pages and doing
## all sorts of wacky things", which is exactly what eight lines of pure
## proximity produce on a desk where everything overlaps.
##
## Two rules now, both borrowed from the desk's own hit test: the topmost
## candidate wins rather than the nearest, and a candidate covered at that point
## by something drawn above it is not a candidate at all.
func _find_subject() -> Node2D:
	var reach := RADIUS * 0.85
	var best: Node2D = null
	var best_order := -(1 << 30)
	for s in subjects:
		if s == null or not is_instance_valid(s) or s == self:
			continue
		if not s.visible:
			continue
		if not s.has_method("has_detail") or not s.call("has_detail"):
			continue
		var centre: Vector2 = s.call("detail_centre") if s.has_method("detail_centre") \
			else s.global_position
		if centre.distance_to(global_position) >= reach:
			continue
		if _is_buried(s):
			continue
		# Draw order, the same key the renderer sorts by: z first, then position
		# in the tree. Nearest is the wrong question when two things overlap —
		# what the player can SEE is the one on top.
		var order := s.z_index * 100000 + _draw_index(s)
		if order >= best_order:
			best_order = order
			best = s
	return best


## Where this node falls in the order things are painted in. Siblings of the
## glass are compared by child index; a subject parented to another object (the
## poured pool rides on its sheet) inherits its parent's place.
func _draw_index(who: Node2D) -> int:
	var top: Node = who
	while top != null and top.get_parent() != get_parent():
		top = top.get_parent()
	return (top as Node2D).get_index() if top is Node2D else -1


## Is something opaque lying over this subject, right where the glass is?
##
## Only siblings that draw ABOVE it count, and only if the glass's own centre is
## inside them — a paper overlapping the far corner of a charter does not hide
## the bit being looked at.
func _is_buried(subject: Node2D) -> bool:
	var deck := get_parent()
	if deck == null:
		return false
	var subject_order := subject.z_index * 100000 + _draw_index(subject)
	for i in deck.get_child_count():
		var other := deck.get_child(i) as Draggable
		if other == null or other == self or other == subject:
			continue
		if not other.visible or other.stowed:
			continue
		if other.z_index * 100000 + i <= subject_order:
			continue
		if other.contains_point(global_position):
			return true
	return false


## The old rectangular hit box made empty corners around the circular bezel win
## over papers the player could plainly see. The authored silhouette is a circle
## plus a handle, and the hand should agree with the pixels.
func contains_point(world: Vector2) -> bool:
	if not visible or not draggable_enabled:
		return false
	var local := to_local(world)
	if local.length() <= RADIUS + 7.0:
		return true
	return Rect2(-31.0, RADIUS * 0.70, 62.0, 145.0).has_point(local)


## The shared hover affordance outlines hit_size. That is right for a sheet and
## wrong for a circle-plus-handle: at inspection zoom it exposed the invisible
## rectangular grab area around an otherwise convincing prop.
func _draw_hover() -> void:
	if _hover_amount <= 0.01:
		return
	var a := _hover_amount * 0.42 * clampf(0.45 + light_level, 0.45, 1.15)
	for i in 4:
		var grow := 2.0 + float(i) * 3.5
		var fade := a * (1.0 - float(i) / 4.0) * 0.7
		var col := Color(1.0, 0.84, 0.58, fade)
		_hover_node.draw_arc(Vector2.ZERO, RADIUS + grow,
			0.0, TAU, 42, col, 2.6)
		_hover_node.draw_line(Vector2(0, RADIUS + grow * 0.25),
			Vector2(0, RADIUS + 142.0 + grow), col, 20.0 + grow, true)


func _build_optics() -> void:
	_optics_copy = BackBufferCopy.new()
	_optics_copy.name = "lens_backbuffer"
	_optics_copy.copy_mode = BackBufferCopy.COPY_MODE_RECT
	_optics_copy.rect = Rect2(-Vector2.ONE * (APERTURE_RADIUS + 5.0),
		Vector2.ONE * (APERTURE_RADIUS + 5.0) * 2.0)
	_optics_copy.z_index = -1
	add_child(_optics_copy)

	_optics_quad = Polygon2D.new()
	_optics_quad.name = "optical_aperture"
	var r := APERTURE_RADIUS
	_optics_quad.polygon = PackedVector2Array([
		Vector2(-r, -r), Vector2(r, -r),
		Vector2(r, r), Vector2(-r, r),
	])
	_optics_quad.uv = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
	])
	_optics_quad.color = Color.WHITE
	# WITHOUT A TEXTURE, POLYGON2D SENDS NO UVs — AND THE SHADER DISCARDS ON UV.
	#
	# The `uv` array above is only written into the draw command when the polygon
	# has a valid texture. With none, the fragment shader receives a constant UV,
	# so `p = (UV - 0.5) * 2` is constant, `length(p)` is a constant greater than
	# one, and `if (radius > 1.0) discard;` killed every single fragment. The
	# refraction, the rim aberration and the aperture mask have therefore never
	# rendered once in the life of this prop: hiding the quad was pixel-identical
	# to showing it, and every existing lens assertion passed with the material
	# completely dead.
	#
	# One white texel, and it must be exactly 1x1: Polygon2D divides the `uv`
	# array by the texture's size, so a 2x2 would silently halve the UV range and
	# put the aperture back outside the unit circle.
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	_optics_quad.texture = ImageTexture.create_from_image(white)
	_optics_quad.z_index = -1
	_optics_quad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_optics_material = ShaderMaterial.new()
	_optics_material.shader = REFRACTION_SHADER
	_optics_quad.material = _optics_material
	add_child(_optics_quad)

	# Order below is draw order. The parent lays down glass and caustic; the field
	# cuts the evidence to the aperture; the overlay puts reflections and brass
	# back on top of it.
	_field = Node2D.new()
	_field.name = "optical_field"
	_field.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_field.draw.connect(_draw_field_mask)
	add_child(_field)

	_detail = Node2D.new()
	_detail.name = "magnified_evidence"
	_detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail.draw.connect(_draw_magnified_evidence)
	_field.add_child(_detail)

	_overlay = Node2D.new()
	_overlay.name = "glass_and_brass"
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


## The stencil. Drawn, never seen: CLIP_CHILDREN_ONLY spends this circle as a mask
## for `_detail` and paints none of it. Slightly inside the glass tint so a
## subject cannot land a pixel on the join between glass and brass.
func _draw_field_mask() -> void:
	_field.draw_circle(Vector2.ZERO, APERTURE_RADIUS * 0.965, Color.WHITE)


func _draw_magnified_evidence() -> void:
	if _focus == null or _focus_amount <= 0.02:
		return
	if not is_instance_valid(_focus) or not _focus.has_method("draw_detail"):
		return
	var lit := Surface.lit(light_level, light_strength)
	var toward := Surface.toward(self, light_position)
	# Focus settles over the last few percent rather than growing from a dot: the
	# image belongs to the glass from first contact and gently resolves.
	var resolve_scale := lerpf(0.955, 1.0, _focus_amount)
	var focus_at := Vector2.ZERO
	if _focus.has_method("detail_centre"):
		var subject_centre: Vector2 = _focus.call("detail_centre")
		# A real lens does not teleport an off-axis detail to its centre. Retaining
		# a little of the subject's offset supplies optical parallax while the
		# magnification still keeps the important mark readable.
		focus_at = to_local(subject_centre) * 0.16
		focus_at = focus_at.limit_length(APERTURE_RADIUS * 0.12)
	_detail.draw_circle(focus_at + toward * APERTURE_RADIUS * 0.08,
		APERTURE_RADIUS * 0.72,
		Color(1.0, 0.76, 0.48, 0.018 + lit * 0.035))
	# Quantised lag: the image has a fraction of optical inertia while the glass
	# moves, then returns exactly to the evidence when set down.
	var lag := Vector2(round(_optical_lag.x), round(_optical_lag.y))
	_detail.draw_set_transform(focus_at + lag, -rotation,
		Vector2.ONE * resolve_scale)
	_focus.call("draw_detail", _detail, Vector2.ZERO, APERTURE_RADIUS * 0.94)
	_detail.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# THE GLASS MAY NOT CHEAT THE CANDLE.
	#
	# draw_detail takes a light DIRECTION for its shading and never once read
	# light_level, so a seal in the far corner of the desk — correctly an
	# illegible smudge to the naked eye, which shot 44 exists to prove — became
	# fully readable the moment the glass was laid on it. Device, incuse legend
	# and wear chips, all of it, with the flame across the room. That let the hero
	# prop of the whole optics pass defeat the one mechanic the game is built on.
	#
	# This is the fifth object to escape the shade veil, and it escaped for a
	# structural reason rather than by oversight: draw_shade is applied inside
	# each object's own _draw(), and the lens calls draw_detail from somewhere
	# else entirely, so the veil was never on the path. Applying the SUBJECT's
	# own shade here puts the enlarged image back under the same rule as the
	# thing it is an image of — and does it once, for every present and future
	# implementer of draw_detail, rather than in each of them.
	#
	# It dims rather than disappears. You can still see that there is wax there
	# and that it has a device on it; you cannot read the legend until you bring
	# the light. A verb that answers with "not from here" is still answering.
	var subject := _focus as Draggable
	if subject != null:
		var veil := subject.shade_alpha()
		if veil > 0.01:
			_detail.draw_circle(Vector2.ZERO, APERTURE_RADIUS * 0.965,
				Color(Draggable.SHADE_COLOR, veil))


func _draw_overlay() -> void:
	var lit := Surface.lit(light_level, light_strength)
	var toward := Surface.toward(self, light_position)
	_draw_glass_reflections(toward, lit)
	_draw_authored_bezel(toward, lit)


func _draw() -> void:
	_draw_lens_shadow()
	var lit := Surface.lit(light_level, light_strength)
	var toward := Surface.toward(self, light_position)
	_draw_authored_handle(toward, lit)

	# The glass itself: dark edge refraction, a warm body, and an almost-clear
	# centre. A flat translucent disc looked like a UI panel placed on the desk.
	# Clear glass transmits almost all of the scene. The older 24% brown disc
	# made inspection darker than looking with the naked eye and buried exactly
	# the seal detail the tool exists to reveal.
	draw_circle(Vector2.ZERO, APERTURE_RADIUS * 1.035,
		Color(0.075, 0.055, 0.035, 0.12))
	draw_circle(Vector2.ZERO, APERTURE_RADIUS,
		Color(0.86, 0.82, 0.72, 0.070 + lit * 0.025))
	draw_circle(Vector2.ZERO, APERTURE_RADIUS * 0.94,
		Color(0.98, 0.97, 0.91, 0.018 + lit * 0.012))
	_draw_caustic(toward, lit)

	# A LENS SHOWS YOU ONE IMAGE, NOT TWO.
	#
	# The refracted screen copy underneath keeps transmitting the document at its
	# ordinary size while the resolved evidence is drawn over it at reading size,
	# so a focused glass showed the witness list twice — once small and once large,
	# interleaved, both in the same ink. Shot 58 had "Drawn at the chancery of"
	# lying across "Stoss, of the lesser" and "Lamp, sworn measurer". Physically a
	# magnifier does not do this, and as an evidence instrument it is worse than
	# useless: the one place in the game where the player is deliberately reading
	# small print is the one place the type was doubled.
	#
	# The field fills as it resolves. Not to opacity — some transmission has to
	# survive or the glass becomes a porthole with a card in it — but far enough
	# that the enlarged hand is unambiguously the thing being read.
	if _focus_amount > 0.01:
		var settle := ease(clampf(_focus_amount, 0.0, 1.0), 0.55)
		draw_circle(Vector2.ZERO, APERTURE_RADIUS * 0.965,
			Color(0.88, 0.83, 0.70, 0.60 * settle))
		# Warmed by the FLAME, and only by the flame. Left ungated this painted a
		# salmon disc into the cold-morning frame, where the rest of the room has
		# gone flat and neutral and the candle is a dead stub — the one surface
		# still insisting on firelight. `_chassis_tint` below already makes this
		# distinction for the brass; the field has to make it too.
		if not ambient_daylight:
			draw_circle(Vector2.ZERO, APERTURE_RADIUS * 0.965,
				Color(1.0, 0.80, 0.50, (0.05 + lit * 0.10) * settle))
		else:
			draw_circle(Vector2.ZERO, APERTURE_RADIUS * 0.965,
				Color(0.80, 0.86, 0.96, 0.10 * settle))

	# The magnified evidence is `_detail`, cut to the aperture by `_field`, and the
	# reflections and brass are `_overlay` above it. Both are children, so they
	# draw after this function returns. See the note beside their declarations.


func _chassis_tint(lit: float) -> Color:
	if ambient_daylight:
		return Color(0.78, 0.84, 0.95)
	return Color(0.56, 0.53, 0.55).lerp(
		Color(1.0, 0.91, 0.73), 0.42 + lit * 0.45)


func _draw_authored_bezel(toward: Vector2, lit: float) -> void:
	_overlay.draw_texture_rect_region(CHASSIS, RING_TARGET, RING_SOURCE,
		_chassis_tint(lit))
	var light_angle := toward.angle()
	# The authored plate supplies form and wear; these moving fragments let the
	# one carried flame remain the authority over its brass.
	_overlay.draw_arc(Vector2.ZERO, RADIUS * 0.965,
		light_angle - 0.82, light_angle + 0.52, 24,
		Color(1.0, 0.88, 0.56, 0.10 + lit * 0.46), 2.4)
	_overlay.draw_arc(Vector2.ZERO, RADIUS * 0.985,
		light_angle + PI - 0.58, light_angle + PI + 0.48, 20,
		Color(0.08, 0.045, 0.025, 0.38), 2.8)
	_overlay.draw_arc(Vector2.ZERO, APERTURE_RADIUS * 1.03,
		light_angle - 0.56, light_angle + 0.34, 18,
		Color(1.0, 0.91, 0.68, 0.12 + lit * 0.28), 1.5)


func _draw_glass_reflections(toward: Vector2, lit: float) -> void:
	# Reflections cross the enlarged object, which is what makes them read as
	# belonging to a sheet of glass rather than to the wax below. They move with
	# the carried flame instead of being painted forever into the upper left.
	var a := toward.angle()
	var offset := toward * APERTURE_RADIUS * 0.045
	_overlay.draw_arc(offset, APERTURE_RADIUS * 0.79, a - 0.56, a + 0.17, 20,
		Color(1, 1, 1, 0.12 + lit * 0.16), 6.0)
	_overlay.draw_arc(offset * 1.5, APERTURE_RADIUS * 0.61, a - 0.43, a - 0.04, 14,
		Color(1, 1, 1, 0.07 + lit * 0.11), 3.2)
	_overlay.draw_arc(-offset, APERTURE_RADIUS * 0.86, a + PI - 0.39, a + PI + 0.19, 16,
		Color(0.34, 0.22, 0.09, 0.060), 4.4)
	# Two tiny seed bubbles in old crown glass. They catch the same light and
	# keep the otherwise perfect disc from reading as a digital mask.
	for p: Vector2 in [Vector2(-0.31, 0.18), Vector2(0.28, -0.36)]:
		var at: Vector2 = p * APERTURE_RADIUS
		_overlay.draw_circle(at + toward * 1.2, 2.1,
			Color(1, 1, 1, 0.08 + lit * 0.08))
		_overlay.draw_circle(at - toward * 0.8, 1.1,
			Color(0.16, 0.11, 0.07, 0.12))


func _draw_authored_handle(toward: Vector2, lit: float) -> void:
	draw_texture_rect_region(CHASSIS, HANDLE_TARGET, HANDLE_SOURCE,
		_chassis_tint(lit))
	var x := clampf(toward.x * 4.0, -7.0, 7.0)
	draw_line(Vector2(x, 151.0), Vector2(x * 0.45, 218.0),
		Color(0.77, 0.49, 0.24, 0.08 + lit * 0.24), 1.4)


func _draw_lens_shadow() -> void:
	var off := shadow_offset()
	var a := (0.045 + 0.13 * sqrt(clampf(light_level, 0.0, 1.0))) \
		* clampf(light_strength, 0.65, 1.1)
	# Annular contact shadow: the previous stack of filled circles made the clear
	# aperture cast the same shadow as solid brass.
	for i in range(3, 0, -1):
		var grow := float(i) * 1.8
		draw_arc(off, (RADIUS + APERTURE_RADIUS) * 0.5,
			0.0, TAU, 52, Color(0, 0, 0, a / float(i + 1)),
			RADIUS - APERTURE_RADIUS + grow, true)
		draw_line(Vector2(0, 105) + off, Vector2(0, 235) + off,
			Color(0, 0, 0, a / float(i + 1)), 22.0 + grow, true)


func _draw_caustic(toward: Vector2, lit: float) -> void:
	if lit <= 0.04 or ambient_daylight:
		return
	# The brightest transmitted patch sits opposite the flame. It crosses the
	# paper rather than the wax detail and dies immediately when the glass leaves
	# the useful light.
	var at := -toward * APERTURE_RADIUS * 0.54
	draw_set_transform(at, toward.angle(), Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, APERTURE_RADIUS * 0.25,
		-0.62, 0.74, 14, Color(1.0, 0.77, 0.43, 0.025 + lit * 0.065), 5.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

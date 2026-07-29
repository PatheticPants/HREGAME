class_name Draggable
extends Node2D

## Anything on the desk that can be picked up.
##
## Owns a DragSolver and the shadow, and nothing else. Subclasses draw their own
## faces and never touch the physics — which is why a book, a candle and a
## charter all handle identically despite drawing nothing in common.

signal picked_up(who: Draggable)
signal dropped(who: Draggable)

@export var hit_size := Vector2(360, 470)
@export var draggable_enabled := true

## Sounds are named per object so a ring clinks and a sheet rustles without any
## branching at the call site.
@export var pickup_sound: StringName = &"paper_pickup"
@export var drop_sound: StringName = &"paper_drop"
@export var slide_sound: StringName = &"paper_slide"

## Set by the desk every frame. Shadows fall away from the flame, which means
## moving the candle relights the entire desk — cheap, and the single detail
## that does the most for how the scene reads.
var light_position := Vector2(0, -400)

## Flicker, shared by everything in the room. Modulates shadow density so the
## whole desk pulses together rather than each object shimmering on its own.
var light_strength := 1.0

## How much of the flame actually reaches THIS object, 0..1, on the same
## inverse-square curve the renderer uses. A sheet at the far corner of the desk
## has almost no shadow because there is almost no light on it — that is the
## difference between shadows that track the candle and shadows that look real.
var light_level := 1.0

## Solid things interrupt the candle. Paper does not: a sheet is a tenth of a
## millimetre thick, and giving it an occluder throws a hard wedge of darkness
## across the desk that instantly reads as a bug. Papers get a contact shadow
## instead; books, tools and rings get both.
@export var occludes_light := false

## Occluder silhouette, as a fraction of hit_size. Hit rectangles are generous
## on purpose so small objects are easy to grab; their shadows must not be.
@export var occluder_inset := 0.86

## Round objects — rings, the lens, the candle dish — cast round shadows.
@export var occluder_round := false

## True once the flame is out and the room is lit by the shutter instead. Cold
## morning is uniform and directional, so nothing is in shadow relative to
## anything else and the whole falloff below has to switch off — otherwise the
## ledger, which is read only after the candle has died, arrives veiled.
var ambient_daylight := false

## How heavy this thing is in the hand, relative to a sheet of parchment. Above
## 1 follows tightly and settles fast; below 1 lags, drifts and overshoots.
@export var weight := 1.0

## How many objects sit beneath this one. Drives shadow throw, so a sheet at the
## top of a pile visibly floats above one at the bottom.
var stack_depth := 0

var solver := DragSolver.new()
var is_held := false

## Cursor is over this object and it is the topmost thing under it. Drives a
## small warm lift so the player can tell what their hand would close on — the
## only concession to an interface anywhere in the game, and it is made of light
## rather than of an outline or a cursor change.
var hovered := false

## Sitting in a pigeonhole on the back rack. Stowed objects are shrunk, pushed
## out of the way, and not part of the working pile.
var stowed := false

## What fraction of its normal size an object is drawn at once racked. Books need
## to shrink further than a docket slip does to fit the same hole.
@export var stow_scale := 0.46

var _visual_scale := 1.0
var _stow_amount := 0.0
var _hover_amount := 0.0
var _stow_anchor := Vector2.ZERO
var _stow_landed := false
var _feel: PaperFeel
var _light_occluder: LightOccluder2D
var _occluder_size := Vector2.ZERO
var _hover_node: Node2D
## The desk surface foreshortens when the clerk looks up, but objects with height
## do not become paper-thin with it. The parent plane still moves their contact
## points in perspective; this local compensation preserves most of each prop's
## apparent height and adds a small far-to-near scale gradient.
var _projection_plane_y := 1.0
var _projection_depth_scale := 1.0
var _projection_relief := 0.72
## Extra height supplied by authored actions that are not direct dragging:
## papers gathered by a petitioner, a tool being handed across the desk, and
## similar beats. Kept separate from the solver so an action can lift an object
## without pretending the mouse is holding it.
var presentation_lift := 0.0


func _ready() -> void:
	_feel = Lore.paper_feel()
	solver.place(position, rotation)
	_light_occluder = LightOccluder2D.new()
	_light_occluder.name = "moving_shadow"
	_light_occluder.occluder_light_mask = 1
	add_child(_light_occluder)
	_sync_light_occluder()

	_hover_node = Node2D.new()
	_hover_node.name = "hover_glow"
	_hover_node.draw.connect(_draw_hover)
	add_child(_hover_node)

	set_process(true)


func setup(start_position: Vector2, start_angle: float, desk_bounds: Rect2) -> void:
	solver.bounds = desk_bounds
	solver.place(start_position, start_angle)
	position = start_position
	rotation = start_angle


func _process(delta: float) -> void:
	_feel = Lore.paper_feel()
	solver.weight = weight
	_sync_light_occluder()

	if is_held:
		solver.clamp_target(_feel)
	solver.advance(delta, _feel)
	if stowed and not is_held:
		_hold_in_slot(delta)

	position = solver.position
	rotation = solver.angle

	# A small lift on pickup. Deliberately subtle — the shadow does the heavy
	# lifting for "this is off the pile"; scale alone reads as a zoom.
	var want := _feel.pickup_scale if is_held else 1.0
	# Racking shrinks the object into its hole. Eased rather than snapped so a
	# book visibly slides in and settles.
	_stow_amount = move_toward(_stow_amount, 1.0 if stowed else 0.0, delta * 4.6)
	want *= lerpf(1.0, stow_scale, ease(_stow_amount, 0.4))
	want *= 1.0 + maxf(0.0, presentation_lift)
	_visual_scale = move_toward(_visual_scale, want, _feel.pickup_scale_speed * delta)
	var apparent_y := lerpf(_projection_plane_y, 1.0, _projection_relief)
	var local_y := apparent_y / maxf(0.1, _projection_plane_y)
	scale = Vector2(_projection_depth_scale,
		_projection_depth_scale * local_y) * _visual_scale

	_hover_amount = move_toward(_hover_amount,
		1.0 if (hovered and not is_held) else 0.0, delta * 7.0)

	_update_slide_audio()
	queue_redraw()
	if _hover_node != null:
		_hover_node.queue_redraw()


## Called by Desk during the work-to-audience tilt. `plane_y` belongs to the
## parent contact surface; `depth_scale` is the modest perspective size change
## between the far and near edges. Work view passes ones and is bit-exact.
func set_projection_context(plane_y: float, depth_scale: float,
		relief := 0.72) -> void:
	_projection_plane_y = clampf(plane_y, 0.1, 1.0)
	_projection_depth_scale = maxf(0.1, depth_scale)
	_projection_relief = clampf(relief, 0.0, 1.0)


## A real occlusion polygon travels with every prop that has height. PointLight2D
## uses it for the long moving shadow; draw_soft_shadow supplies the tight contact
## shadow that keeps everything, paper included, attached to the desk.
func _sync_light_occluder() -> void:
	if _light_occluder == null:
		return
	_light_occluder.visible = occludes_light
	if not occludes_light or _occluder_size.is_equal_approx(hit_size):
		return
	_occluder_size = hit_size
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = light_occluder_polygon()
	_light_occluder.occluder = polygon


## The silhouette that interrupts the candle. Subclasses whose hit box is not
## their physical shape override this: the spoon's bowl is at the far end of its
## handle, an open book has a gutter, and the glass's long handle must not turn
## its circular aperture into a tall oval shadow.
func light_occluder_polygon() -> PackedVector2Array:
	var half := hit_size * 0.5 * occluder_inset
	if occluder_round:
		var points := PackedVector2Array()
		for i in 14:
			var a := float(i) / 14.0 * TAU
			points.append(Vector2(cos(a) * half.x, sin(a) * half.y))
		return points
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])


## A clipped-corner block for boards, tablets and other built objects. The
## renderer's shadow now follows the silhouette instead of projecting the
## generous rectangular grab area onto half the desk.
func bevelled_light_occluder(cut := 8.0) -> PackedVector2Array:
	var half := hit_size * 0.5 * occluder_inset
	var c := minf(cut, minf(half.x, half.y) * 0.42)
	return PackedVector2Array([
		Vector2(-half.x + c, -half.y), Vector2(half.x - c, -half.y),
		Vector2(half.x, -half.y + c), Vector2(half.x, half.y - c),
		Vector2(half.x - c, half.y), Vector2(-half.x + c, half.y),
		Vector2(-half.x, half.y - c), Vector2(-half.x, -half.y + c),
	])


func _update_slide_audio() -> void:
	if slide_sound == &"":
		return
	var s := solver.speed()
	var lo := _feel.slide_audible_speed
	var hi := _feel.slide_full_speed
	var amount := clampf((s - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
	# Only the object actually in hand drives the slide bed; a dozen sheets all
	# settling at once would wash it out.
	if not is_held:
		amount *= 0.35
	Audio.set_loop(slide_sound, amount)


# ------------------------------------------------------------------ handling

func grab(cursor: Vector2) -> void:
	if not draggable_enabled:
		return
	# Taking something out of the rack is the same gesture as picking it up off
	# the desk. There is no separate "retrieve" verb to learn.
	unstow()
	is_held = true
	solver.grab(cursor)
	if pickup_sound != &"":
		Audio.play(pickup_sound, global_position)
	picked_up.emit(self)


func move_to(cursor: Vector2) -> void:
	solver.target = cursor


func drop() -> void:
	if not is_held:
		return
	is_held = false
	solver.release()
	if drop_sound != &"":
		Audio.play(drop_sound, global_position)
	Audio.set_loop(slide_sound, 0.0)
	dropped.emit(self)


## Hit testing is done by the desk against an explicit, ordered list rather than
## by physics picking, so "the topmost object always wins" is a rule we control
## outright. Digging a buried charter out of a pile is a mechanic here; it cannot
## be at the mercy of another subsystem's sort order.
func contains_point(world: Vector2) -> bool:
	# AN OBJECT YOU CANNOT SEE CANNOT BE CLICKED.
	#
	# The Ledger lives in `surface` from construction with visible = false for
	# the whole working day, carries z_index = 6, and has the largest hit
	# rectangle on the desk. It sat later in child order than the lens, the
	# rings, the spoon and the candle — so a click anywhere in the middle of the
	# desk that hit one of those was answered by an invisible book, and the
	# player picked up nothing they could see.
	if not visible or not draggable_enabled:
		return false
	return Rect2(-hit_size * 0.5, hit_size).has_point(to_local(world))


func centre_world() -> Vector2:
	return global_position


## Slide into a pigeonhole.
func stow_into(at: Vector2, angle: float) -> void:
	stowed = true
	_stow_anchor = at
	_stow_landed = false
	solver.rest_angle = angle
	solver.sleeping = false
	solver.velocity = Vector2.ZERO
	solver.angular_velocity = 0.0
	Audio.play(&"stow_in", global_position)


## A racked object is CONSTRAINED, not free. Letting the ordinary spring carry it
## home looked right for half a second and then stopped short — release damping
## kills the velocity long before the object reaches the hole, so books settled
## near their slot instead of in it and drifted a little further out every time
## they were put away. Eased directly instead, and put to sleep on arrival.
func _hold_in_slot(delta: float) -> void:
	# 1 - pow(retention, delta), not rate * delta. The linear form is
	# frame-rate dependent — it closes about twice as fast at 10 fps as at 60 —
	# which is precisely the bug DragSolver's fixed timestep exists to prevent,
	# and it had crept back into the one motion every rack interaction depends on.
	var k := 1.0 - pow(0.0004, delta)
	solver.position = solver.position.lerp(_stow_anchor, k)
	solver.angle = lerp_angle(solver.angle, solver.rest_angle, k)
	solver.velocity = Vector2.ZERO
	solver.angular_velocity = 0.0
	if solver.position.distance_to(_stow_anchor) < 0.4:
		solver.position = _stow_anchor
		solver.angle = solver.rest_angle
		solver.sleeping = true
		# The END of the action. Sliding something into a hole had a start (the
		# scrape) and a middle (the slide) and then simply stopped existing,
		# which is the classic missing third phase: the player never hears the
		# thing arrive.
		if not _stow_landed:
			_stow_landed = true
			Audio.play(&"stamp_set", global_position, -6.0)
	else:
		solver.sleeping = false


func unstow() -> void:
	if not stowed:
		return
	stowed = false
	Audio.play(&"stow_out", global_position)


## Warm edge light while the cursor is over it.
##
## Drawn by a child node rather than by each subclass, because children draw
## after their parent — so every object gets the affordance on top of its own
## face for free, and a new prop cannot forget to implement it.
##
## This is the only interface element in the game and it is deliberately made of
## light rather than of an outline or a cursor swap: it reads as the object
## catching the candle, which is a thing that already happens here.
func _draw_hover() -> void:
	if _hover_amount <= 0.01:
		return
	var rect := Rect2(-hit_size * 0.5, hit_size)
	# Drawn just OUTSIDE the silhouette. Inside, a warm line on warm parchment is
	# invisible; outside, it sits on the dark desk where it reads immediately.
	var a := _hover_amount * 0.42 * clampf(0.45 + light_level, 0.45, 1.15)
	for i in 4:
		var r := rect.grow(2.0 + float(i) * 3.5)
		var fade := a * (1.0 - float(i) / 4.0) * 0.7
		if occluder_round:
			_hover_node.draw_arc(r.get_center(),
				maxf(r.size.x, r.size.y) * 0.44, 0.0, TAU, 30,
				Color(1.0, 0.84, 0.58, fade), 3.0)
		else:
			_hover_node.draw_rect(r, Color(1.0, 0.84, 0.58, fade), false, 3.0)


## A press and release in nearly the same place, which the desk distinguishes
## from a drag. Books open on it, pages turn on it. Return true to say it was
## used, so the desk knows not to treat it as a plain drop.
func on_click(_local_point: Vector2) -> bool:
	return false


# ------------------------------------------------------------------- shadows

## How deep into shadow this object's FACE is, 0..1.
##
## The substrate already warmed and cooled with the flame — but the writing on it
## did not, so a charter across the desk from the only light in the room drew its
## text at full contrast and was exactly as readable as one under the wick. The
## candle changed the colour of the desk and never once changed what could be
## READ off it, which quietly cost the game its central claim: that the readable
## desk contracts as the day goes and carrying the flame stops being optional.
##
## The fix is one veil drawn over the finished face — substrate, ink, rubric and
## seal together — because that is what a page out of the light actually does.
## One draw call, after everything else, and it cannot be forgotten by a new
## document type that only overrides _draw_face().
func shade_alpha() -> float:
	if ambient_daylight:
		return 0.0
	var lit := clampf(light_level * clampf(light_strength, 0.7, 1.1), 0.0, 1.0)
	# smoothstep rather than a linear ramp: within about a hand's width of the
	# flame there should be no veil at all, and the fall to near-illegible should
	# happen across the middle of the desk rather than at its far rim.
	return (1.0 - smoothstep(0.0, 0.55, lit)) * SHADE_MAX


## Never quite black. A sheet you cannot see at all is a lost sheet, and digging
## for a buried charter has to stay a mechanic rather than becoming a chore.
const SHADE_MAX := 0.50
## Cold, so shadow separates from the warm light instead of reading as grey wash.
const SHADE_COLOR := Color(0.045, 0.042, 0.075)


## Veil the finished face. Called by whatever drew one, last.
func draw_shade(over: Rect2, corner_ratio := 0.0) -> void:
	var a := shade_alpha()
	if a <= 0.01:
		return
	if corner_ratio > 0.0:
		draw_circle(over.get_center(),
			maxf(over.size.x, over.size.y) * 0.5 * corner_ratio,
			Color(SHADE_COLOR, a))
	else:
		draw_rect(over, Color(SHADE_COLOR, a))


func shadow_offset() -> Vector2:
	var throw := _feel.shadow_base_throw + stack_depth * _feel.shadow_throw_per_layer
	if is_held:
		throw += _feel.pickup_shadow_lift
	throw += maxf(0.0, presentation_lift) * 74.0
	var away := global_position - light_position
	if away.length() < 1.0:
		away = Vector2(0.4, 1.0)
	# Falloff with distance from the flame: a sheet right under the candle casts
	# a short hard shadow, one at the far corner a long soft one.
	var reach := clampf(away.length() / 620.0, 0.30, 1.70)
	return (away.normalized() * throw * reach).rotated(-global_rotation)


## Fake blur by stacking a few offset rectangles, largest and faintest first.
## Cheaper than a shader, entirely good enough for this art, and the layer count
## is a tuning knob rather than a magic number.
##
## The important term is `light_level`. A contact shadow is cast light, so an
## object sitting in the dark half of the desk has almost none, and carrying the
## candle toward it makes its shadow arrive — darkening, shortening and swinging
## round as the flame passes. Without that term every object on the desk has the
## same shadow density regardless of where the light is, which is exactly what
## makes 2D lighting look painted on.
func draw_soft_shadow(rect: Rect2, corner_ratio := 0.0) -> void:
	var off := shadow_offset()
	var layers := maxi(1, _feel.shadow_layers)
	var spread := 3.0 + off.length() * 0.55
	# Held objects keep a floor of shadow: they are directly under the player's
	# attention and should never look unmoored, even lifted in a dark corner.
	var floor_level := 0.30 if is_held else 0.10
	var lit := clampf(maxf(light_level, floor_level), 0.0, 1.0)
	var strength := (0.22 + 0.95 * sqrt(lit)) * clampf(light_strength, 0.6, 1.1)
	for i in range(layers, 0, -1):
		var t := float(i) / float(layers)
		var grow := t * spread
		var a := _feel.shadow_alpha * strength \
			* (1.0 - t * 0.68) * (2.2 / float(layers))
		var r := Rect2(rect.position + off - Vector2(grow, grow),
			rect.size + Vector2(grow, grow) * 2.0)
		if corner_ratio > 0.0:
			draw_circle(r.get_center(), maxf(r.size.x, r.size.y) * 0.5 * corner_ratio,
				Color(0, 0, 0, a))
		else:
			draw_rect(r, Color(0, 0, 0, a))

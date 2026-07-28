class_name Candle
extends Draggable

## The only light in the room, and an object you pick up and put somewhere else.
##
## WHY IT MOVES
## ------------
## A fixed light is a lighting *setting*. A light you carry is a decision. The
## desk is deliberately too small, the room is dark, and the charter you need to
## read is not always where the flame is — so moving the candle is the same class
## of act as moving a book, and it costs the same desk space. Everything that
## follows from that (shadows swinging round, parchment warming as it approaches,
## the far corner going black) is free once the light is genuinely mobile.
##
## THE LIGHT RIG
## -------------
## Three lights, all driven by one flicker value so they never beat against each
## other:
##
##   core    tiny, near-white, very steep falloff. The flame's own glare.
##   key     the working light. Casts every shadow on the desk.
##   fill    huge, dim, deep amber, no shadows. Light bouncing off the desk and
##           back onto the walls, which is what stops the room reading as a
##           spotlight in a void.
##
## Falloff is generated rather than painted: a true inverse-square curve, so the
## light is fierce within a hand's width of the wick and gone by the far edge of
## the desk. A linear gradient (which is what a hand-painted radial usually is)
## reads as a flat disc of brightness with a visible rim, and no amount of energy
## tuning fixes it.
##
## FLICKER
## -------
## Three bands of coherent noise — slow draught, ordinary instability, brief
## oxygen-starved gutters — modulating energy, reach, colour temperature AND the
## flame's position together. The position wander is the important one: it is what
## makes every shadow on the desk swim very slightly, and it is the single
## strongest cue that the light is fire rather than a lamp.

const CANDLE_TEXTURE := preload("res://art/props/candle_holder.png")
const SPRITE_SIZE := 142.0
# Registered to the black wick in the authored 192px plate. The previous point
# sat down-right on the white candle body, which made both the flame and the
# growing spent-wax pool look as if they were sliding off the stub.
const WICK := Vector2(-16.0, -28.0)

## Reach of each light in desk units at full flicker. The key light is sized so a
## charter at arm's length is readable and the far corner of the desk is not.
const CORE_REACH := 118.0
const KEY_REACH := 690.0
const FILL_REACH := 1500.0

## THE DAY'S CLOCK
## ---------------
## 0 is a fresh candle, 1 is a puddle and a dead wick. When it reaches 1 the
## working day is over — that is the only clock in the game and it is a physical
## object sitting on the desk rather than a number in a corner.
##
## It burns ONLY while the player is actually working. Not while a petitioner is
## talking, not during arrivals or departures, not while the ledger is open. The
## clock runs on your deliberation and on nothing else, which is the only version
## of this that is fair.
##
## The important consequence is that the light CONTRACTS as it goes. A dying
## candle does not simply dim — its pool of usable light pulls in around the
## wick, so the desk you can actually read shrinks hour by hour and the carrying
## you were doing for convenience at the start becomes necessary at the end.
var burn := 0.0

## Below this much candle left, it starts to gutter in earnest.
const GUTTERING_FROM := 0.86

## THE STUB, IN THE AUTHORED PLATE'S OWN COORDINATES.
##
## art/props/candle_holder.png is a plan view: a hammered brass saucer with a
## short candle standing in it, drawn with just enough cheat that you can see the
## cylinder and its drips. That cheat is the style anchor, and the melt has to
## extend it rather than paint over it — which is exactly what the first version
## did. It flooded a jagged pale star across the whole stub and obliterated the
## best-looking thing on the desk.
const STUB := Vector2(-15.0, -14.0)
const STUB_RADIUS := 17.0
const SAUCER_RADIUS := 31.0

var _time := 0.0
var _flicker := 1.0
var _flame_drift := Vector2.ZERO
var _spent := false
var _warned := false

## Outlines generated once and then only scaled. Regenerating a wax silhouette
## per frame makes it crawl, which reads as static rather than as wax — the same
## rule WaxShape's own docstring states, and the candle was breaking it by
## rebuilding a RandomNumberGenerator inside _draw.
var _flood_shape: PackedVector2Array = PackedVector2Array()
var _cup_shape: PackedVector2Array = PackedVector2Array()

## A DRIP IS AN EVENT. A melt that is only a continuously interpolated parameter
## has nothing to watch; it is a number wearing wax. A bead that swells on the
## lip, hangs, breaks and runs gives the candle discrete beats — something
## happens, at intervals, without the player doing anything, which is most of
## what "atmosphere" means in a room where you are reading.
var _bead_angle := 0.0
var _bead := 0.0          ## 0 none, 0..1 swelling, 1..2 running
var _next_drip := 9.0
## Set runnels down the side of the stub: angle, length, thickness. They stay.
var _runnels: Array[Vector3] = []
var _engagement_pulse := 0.0
var _engaged := false
## 1 while the day's clock is stopped. Damps the flicker bands and the flame's
## own wander toward nothing, so a still flame means still time.
var _rested := 1.0
var _rest_amount := 1.0
var _wax_seed := 0
var _low_noise := FastNoiseLite.new()
var _mid_noise := FastNoiseLite.new()
var _high_noise := FastNoiseLite.new()
var _core_light: PointLight2D
var _key_light: PointLight2D
var _bounce_light: PointLight2D
var _plane_y := 1.0


func _ready() -> void:
	super._ready()
	hit_size = Vector2(SPRITE_SIZE * 0.72, SPRITE_SIZE * 0.78)
	# Carried, not fixed. Picking it up is how you light what you are reading.
	draggable_enabled = true
	pickup_sound = &"ring_pickup"
	drop_sound = &"stamp_set"
	slide_sound = &""
	# A candle in a saucer has height, but the flame sits inside its own body —
	# occluding with it would put the light source inside the shadow caster.
	occludes_light = false
	# Brass dish, tallow, and a live flame you do not want to swing about.
	weight = 0.55
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# One step above the flat stack. The candle still lives in ordinary child
	# order and can be picked up and buried by a book, but a sheet of parchment
	# will not slide over a lit flame — which looked like a glowing patch of desk
	# with no source, and would also be a fire.
	z_index = 1

	# The puddle a candle dies in should be this candle's puddle. The seed was
	# declared for exactly this and then never wired, so every day melted into a
	# pixel-identical pool.
	_wax_seed = randi()
	# The same generator that makes the pendant seals and the poured pool. The
	# candle's wax and the sealing wax should be the same substance, and until now
	# the candle was drawing its own twenty-two-lobe polygon with per-lobe random
	# radii — which at any size reads as a crumpled paper star rather than as
	# something that flowed.
	_flood_shape = WaxShape.outline(&"round", _wax_seed, 0.11, 34)
	_cup_shape = WaxShape.outline(&"round", _wax_seed ^ 0x9e37, 0.07, 26)
	_next_drip = randf_range(7.0, 15.0)
	_low_noise.seed = randi()
	_mid_noise.seed = randi()
	_high_noise.seed = randi()
	_low_noise.frequency = 0.55
	_mid_noise.frequency = 1.25
	_high_noise.frequency = 2.8
	_build_lights()


# ------------------------------------------------------------------- the rig

## Inverse-square falloff, generated. `sharpness` is the k in 1/(1+k·t²), so a
## large k is a fierce little pool of light and a small k is a broad wash. The
## curve is rescaled to reach exactly zero at the texture edge, otherwise the
## light ends on a visible circular rim.
static func _falloff(sharpness: float) -> GradientTexture2D:
	const STOPS := 24
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	var edge := 1.0 / (1.0 + sharpness)
	for i in STOPS:
		var t := float(i) / float(STOPS - 1)
		var a := (1.0 / (1.0 + sharpness * t * t) - edge) / (1.0 - edge)
		offsets.append(t)
		colors.append(Color(1, 1, 1, maxf(0.0, a)))
	var gradient := Gradient.new()
	# Offsets first: resizing the offset list pads colours with white, so the
	# colour assignment has to come second or it is silently truncated.
	gradient.offsets = offsets
	gradient.colors = colors

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _make_light(light_name: String, sharpness: float, reach: float,
		energy: float, color: Color, shadows: bool) -> PointLight2D:
	var light := PointLight2D.new()
	light.name = light_name
	light.texture = _falloff(sharpness)
	# The generated texture is 256px across, so its unscaled radius is 128.
	light.texture_scale = reach / 128.0
	light.energy = energy
	light.color = color
	light.shadow_enabled = shadows
	if shadows:
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF13
		light.shadow_filter_smooth = 3.2
		# Shadows are never black in a real room: the fill light and the ambient
		# both reach into them. A pure black shadow is the fastest way to make a
		# 2D light read as a stencil.
		light.shadow_color = Color(0.03, 0.017, 0.011, 0.62)
	light.range_item_cull_mask = 1
	light.shadow_item_cull_mask = 1
	add_child(light)
	return light


func _build_lights() -> void:
	# Added widest-first so the near lights composite on top.
	_bounce_light = _make_light("candle_bounce", 5.0, FILL_REACH, 0.34,
		Color(0.98, 0.44, 0.17), false)
	_key_light = _make_light("candle_key", 20.0, KEY_REACH, 1.30,
		Color(1.0, 0.60, 0.29), true)
	_core_light = _make_light("candle_core", 52.0, CORE_REACH, 1.05,
		Color(1.0, 0.88, 0.66), false)
	_update_light_nodes()


# --------------------------------------------------------------------- burning

## Advance the day. Returns true on the single frame the candle dies.
func burn_for(delta: float, day_seconds: float) -> bool:
	if _spent or day_seconds <= 0.0:
		return false
	burn = minf(1.0, burn + delta / day_seconds)
	if burn >= GUTTERING_FROM and not _warned:
		_warned = true
		Audio.play(&"candle_gutter", global_position)
	if burn >= 1.0:
		_spent = true
		Audio.play(&"candle_out", global_position)
		return true
	return false


func is_spent() -> bool:
	return _spent


func burn_remaining() -> float:
	return 1.0 - burn


## Put out deliberately, at the end of a day the player finished on their own
## terms rather than on the candle's.
func snuff() -> void:
	if _spent:
		return
	_spent = true
	burn = 1.0
	Audio.play(&"candle_out", global_position)


func reset_day() -> void:
	burn = 0.0
	_spent = false
	_warned = false
	_engaged = false
	_engagement_pulse = 0.0
	_rested = 1.0
	_rest_amount = 1.0
	# A NEW CANDLE IS A NEW CANDLE. The runnels down the side are a whole day's
	# history and they must not survive into Thursday morning; the second day is
	# supposed to open with a fresh one in the dish.
	_runnels.clear()
	_bead = 0.0
	_next_drip = randf_range(7.0, 15.0)
	_time = 0.0


## How much of its original output survives. Deliberately not linear: a candle
## holds most of its light for most of its life and then goes quickly, which is
## also the pacing this wants — a long steady evening and a bad last hour.
func _output() -> float:
	if _spent:
		return 0.0
	return lerpf(1.0, 0.30, ease(clampf(burn, 0.0, 1.0), 2.2))


# ------------------------------------------------------------------- flicker

func _process(delta: float) -> void:
	super._process(delta)
	_time += delta

	var low := _low_noise.get_noise_1d(_time * 1.15)
	var mid := _mid_noise.get_noise_1d(_time * 2.2 + 91.0)
	var high := _high_noise.get_noise_1d(_time * 4.8 - 53.0)
	_engagement_pulse = move_toward(_engagement_pulse, 0.0, delta * 1.0)
	# A gutter is a brief starve, not a symmetric dip — it only ever darkens.
	var gutter := maxf(0.0, -high - 0.42)
	# A candle drowning in its own wax guts far harder than a fresh one, so the
	# last stretch of the day is visibly, audibly unsteady without a single
	# number appearing anywhere on screen.
	var unrest := 1.0 + smoothstep(GUTTERING_FROM, 1.0, burn) * 3.2
	# A STILL FLAME IS A STOPPED CLOCK.
	#
	# Eased rather than switched, over about three quarters of a second, so the
	# room visibly settles when the last ruling is made and visibly comes back to
	# life on the first thing the player touches. Never fully frozen: a flame that
	# stops dead reads as a paused game rather than as a quiet one.
	_rest_amount = move_toward(_rest_amount, _rested, delta * 1.4)
	var live := lerpf(1.0, 0.22, _rest_amount)

	_flicker = clampf(0.90 + (low * 0.085 + mid * 0.045
		- gutter * 0.42 * unrest) * live, 0.30, 1.10)
	_flicker = minf(1.22, _flicker + _engagement_pulse * 0.22)
	if _spent:
		_flicker = 0.0

	# The luminous centre is bent sideways by draught and lifts away from the
	# wick as it stretches. Every shadow on the desk is cast from this point, so
	# this wander is what makes the whole room breathe.
	_flame_drift = Vector2(low * 3.6 + mid * 1.6,
		-absf(mid) * 1.1 - gutter * 2.4 + high * 0.8) * live \
		- Vector2(0.0, _engagement_pulse * 4.5)

	_tick_drip(delta)
	_update_light_nodes()
	queue_redraw()


## Beads form on the lip, hang, and go. More often as the cup widens and the wall
## thins, which is also true of candles, and which means the object gets busier
## as the day gets worse — the melt accelerates exactly when the player is most
## aware of the clock.
func _tick_drip(delta: float) -> void:
	if _spent:
		_bead = 0.0
		return
	if _bead > 0.0:
		# Swelling is slow; the run is quick. A drip that falls at the same rate
		# it grew is a slider, not a drip.
		_bead += delta * (0.85 if _bead < 1.0 else 2.6)
		if _bead >= 2.0:
			_bead = 0.0
			# It sets where it stopped, and it stays there for the rest of the day.
			_runnels.append(Vector3(_bead_angle,
				randf_range(0.55, 1.0), randf_range(2.6, 4.6)))
			if _runnels.size() > 8:
				_runnels.remove_at(0)
			Audio.play(&"wax_drip", global_position, -18.0)
		return
	_next_drip -= delta * lerpf(0.6, 2.4, burn)
	if _next_drip <= 0.0:
		_next_drip = randf_range(6.0, 16.0)
		# Down the side the flame is leaning away from, because that is the side
		# whose wall the heat has thinned.
		_bead_angle = atan2(_flame_drift.y, _flame_drift.x) + PI \
			+ randf_range(-0.7, 0.7)
		_bead = 0.001


func _update_light_nodes() -> void:
	var at := flame_local()
	# A dying candle does not merely dim, it CONTRACTS. Reach is scaled harder
	# than energy so the pool of usable light pulls in around the wick as the day
	# goes — the readable desk shrinks, and carrying the flame stops being a
	# convenience and becomes the only way to work.
	var out := _output()
	var reach := lerpf(0.46, 1.0, out)

	if _core_light != null:
		_core_light.position = at
		_core_light.energy = 1.05 * _flicker * out
		_core_light.texture_scale = (CORE_REACH / 128.0) \
			* lerpf(0.90, 1.06, _flicker) * lerpf(0.62, 1.0, out)
	if _key_light != null:
		_key_light.position = at
		# Energy and reach move together: a stronger flame lights further, so the
		# shadow edges visibly lengthen and shorten rather than just dimming.
		_key_light.energy = 1.30 * _flicker * lerpf(0.55, 1.0, out)
		_key_light.texture_scale = (KEY_REACH / 128.0) \
			* lerpf(0.92, 1.05, _flicker) * reach
		# Cooler and redder as it guts, warmer and yellower at full burn. A spent
		# wick is also a redder one, so late light is noticeably meaner.
		_key_light.color = Color(1.0,
			lerpf(0.48, 0.63, _flicker) * lerpf(0.80, 1.0, out),
			lerpf(0.17, 0.33, _flicker) * lerpf(0.66, 1.0, out))
	if _bounce_light != null:
		_bounce_light.position = at
		_bounce_light.energy = (0.30 + _flicker * 0.07) * lerpf(0.40, 1.0, out)
	_apply_light_transform()


## Lights are children of a node that gets scaled twice — once by the pickup pop,
## once by the desk's foreshortening. Undo both on the light nodes so the pool of
## light stays a circle in world space instead of squashing into a stripe.
func _apply_light_transform() -> void:
	var sx := 1.0 / maxf(0.01, scale.x)
	var sy := 1.0 / maxf(0.01, scale.y * _plane_y)
	var s := Vector2(sx, sy)
	for light in [_core_light, _key_light, _bounce_light]:
		if light != null:
			light.scale = s


func set_projection_scale(plane_y: float) -> void:
	_plane_y = maxf(0.1, plane_y)
	_apply_light_transform()


# -------------------------------------------------------------------- queries

func wick_local() -> Vector2:
	return WICK


func flame_local() -> Vector2:
	# THE FLAME DESCENDS. In plan view a shortening candle cannot show its column,
	# but the light source still physically drops toward the desk — and that is
	# readable, because every shadow in the room is cast from this point. It used
	# to sink three and a half units over a whole working day, which is nothing.
	# Sixteen is a visible slump, and it makes the late-day light feel like it is
	# coming from inside a dish rather than from above one.
	return WICK + _flame_drift + Vector2(0.0, ease(burn, 0.85) * 16.0)


func flame_world() -> Vector2:
	return to_global(flame_local())


func light_intensity() -> float:
	return _flicker


## The clock has stopped: nobody is at the desk, or the ruling is made.
##
## The flame steadies. That is the whole cue and it needs no words: every shadow
## on this desk swims because the flame wanders, so a flame that stands still
## stops the room breathing, and the player learns "a still flame is my time not
## being spent" from the first transition without being told.
func mark_work_rested() -> void:
	_engaged = false
	_rested = 1.0
	queue_redraw()


func mark_work_engaged() -> void:
	_rested = 0.0
	_engaged = true
	_engagement_pulse = 1.0
	# Let the ordinary pickup transient clear first so this singular cue is not
	# buried beneath the rustle that caused it.
	var sound_position := global_position
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		Audio.play(&"candle_catch", sound_position))
	queue_redraw()


## How strongly this flame reaches a point, 0..1. The same inverse-square curve
## the key light's texture uses, so what an object *thinks* it is lit by agrees
## with what the renderer actually does to it. Contact shadows, parchment warmth
## and the petitioner's face all read from this.
func illumination_at(world_point: Vector2) -> float:
	if _spent:
		return 0.0
	var reach := KEY_REACH * _flicker * lerpf(0.46, 1.0, _output())
	var d := flame_world().distance_to(world_point) / maxf(1.0, reach)
	return clampf(1.0 / (1.0 + 20.0 * d * d), 0.0, 1.0) * _flicker


## Kept for older callers; the falloff now matches the renderer.
func light_at(world_point: Vector2) -> float:
	return illumination_at(world_point)


func light_color() -> Color:
	return _key_light.color if _key_light != null else Color(1.0, 0.6, 0.3)


# -------------------------------------------------------------------- drawing

func _draw() -> void:
	var rect := Rect2(-Vector2.ONE * SPRITE_SIZE * 0.5,
		Vector2.ONE * SPRITE_SIZE)
	draw_soft_shadow(Rect2(-Vector2(53, 47), Vector2(106, 94)), 1.0)
	draw_texture_rect(CANDLE_TEXTURE, rect, false)
	_draw_spent_wax()
	if _engaged or _rest_amount < 0.98:
		# The first bead remains in the saucer for the rest of the day. Starting
		# the clock therefore has a persistent physical trace, not only a flash.
		# It also reports the clock's CURRENT state: wet and warm while the day is
		# being spent, matte and cool while it is not.
		var bead := WICK + Vector2(21.0, 15.0)
		var wet := 1.0 - _rest_amount
		draw_circle(bead + Vector2(1.5, 2.0), 5.2, Color(0, 0, 0, 0.30))
		draw_circle(bead, 4.8,
			Color(0.86, 0.80, 0.66).lerp(Color(0.98, 0.87, 0.62), wet))
		if wet > 0.05:
			draw_circle(bead + Vector2(-1.3, -1.4), 1.6 + wet * 0.7,
				Color(1.0, 0.95, 0.80, 0.30 + 0.45 * wet))
	if not _spent:
		_draw_flame()
	else:
		_draw_dead_wick()


## WHAT A CANDLE DOES, SEEN FROM ABOVE.
##
## It cannot show a shortening column, so it has to show the two things that are
## actually visible in plan: the CUP of molten wax at the top opening wider and
## wider until the whole face of the stub is liquid, and the set flood creeping
## out across the saucer beneath it.
##
## The version this replaces did neither. It drew one jagged twenty-two-sided
## star in a flat cream that was lighter than the brass — so it read as crumpled
## paper — and it drew that star over the entire stub, wiping out the authored
## art at every burn level past about a third. Three straight thick lines stood
## in for runs and looked like sticking plasters. Nothing was translucent,
## nothing was glossy, and nothing moved.
##
## Wax is worth this much code because the whole game is wax.
func _draw_spent_wax() -> void:
	var grow := ease(clampf(burn, 0.0, 1.0), 0.72)
	var lit := clampf(0.55 + _flicker * 0.45, 0.0, 1.2)

	# Set wax is warm and OPAQUE and sits below the brass in value. Molten wax is
	# brighter, more saturated and slightly transparent, because light is coming
	# through it from the flame directly above.
	# MOLTEN WAX IS DARKER THAN SET WAX. Set wax is pale because it is full of
	# microcrystals that scatter light; melted, it goes clear and you see the
	# shadowed bottom of the cup through it. Drawing the liquid brighter than the
	# solid — which is the intuitive way round and the way this first went — makes
	# the whole candle read as a poached egg, and it is why the object looked
	# flat: there was no dark anywhere on it.
	var set_wax := Color(0.80, 0.72, 0.55).lerp(Color(0.98, 0.84, 0.60),
		0.30 + 0.18 * _flicker)
	var molten := Color(0.62, 0.40, 0.17)

	if burn > 0.02:
		_draw_flood(grow, set_wax)
	_draw_runnels(set_wax)
	_draw_cup(grow, set_wax, molten, lit)
	if _bead > 0.0:
		_draw_bead(set_wax, molten)


## The spilt wax in the dish. Low, wide, and set: this is the part that has
## already cooled, so it gets no gloss and no glow.
func _draw_flood(grow: float, set_wax: Color) -> void:
	var centre := STUB + Vector2(1.0, 5.0)
	# Stays inside the saucer. The brass is authored art and the best-looking
	# surface on the desk; the flood is supposed to gather in it, not bury it.
	var r := lerpf(15.0, 26.0, grow)
	# Squashed, because the saucer is seen at the same shallow angle the stub is.
	draw_colored_polygon(
		WaxShape.scaled(_flood_shape, centre + Vector2(0.8, 1.6), r * 1.05, 0.80),
		Color(0.16, 0.11, 0.06, 0.34))
	draw_colored_polygon(WaxShape.scaled(_flood_shape, centre, r, 0.80),
		set_wax.darkened(0.26))
	draw_colored_polygon(WaxShape.scaled(_flood_shape, centre + Vector2(-0.6, -1.2),
		r * 0.90, 0.80), set_wax)
	# Surface tension leaves a raised lip all the way round, and the lip is the
	# only part of a set pool that catches anything.
	var lip := WaxShape.scaled(_flood_shape, centre + Vector2(-0.9, -1.8),
		r * 0.90, 0.80)
	lip.append(lip[0])
	draw_polyline(lip, Color(set_wax.lightened(0.30), 0.40), 1.4, true)


## Beads that have already run and set. They stay for the rest of the day, so by
## evening the stub has a history down one side of it.
func _draw_runnels(set_wax: Color) -> void:
	for run in _runnels:
		var dir := Vector2(cos(run.x), sin(run.x) * 0.72)
		var from := STUB + dir * STUB_RADIUS * 0.72
		var to := STUB + dir * (STUB_RADIUS * 0.72 + run.y * 13.0)
		draw_line(from, to, set_wax.darkened(0.34), run.z + 1.4, true)
		draw_line(from, to, set_wax, run.z * 0.62, true)
		# The blunt end where it stopped and set.
		draw_circle(to, run.z * 0.60, set_wax.darkened(0.10))
		draw_circle(to + Vector2(-0.6, -0.8), run.z * 0.34,
			set_wax.lightened(0.22))


## THE CUP. The one thing a plan view can show properly, and the cue that says
## this candle is burning right now rather than merely standing there.
##
## It opens around the wick and widens all day until the whole face of the stub
## is liquid. Under the flame the wax is thin enough to transmit, so the middle
## of the cup glows from inside rather than being lit from outside — which is the
## single most characteristic thing about a lit candle and was entirely absent.
func _draw_cup(grow: float, set_wax: Color, molten: Color, lit: float) -> void:
	var wick := WICK + Vector2(0.0, ease(burn, 0.85) * 16.0)
	# Never the whole stub. A wall of set wax survives all day — that wall IS the
	# candle, and a cup that eats it entirely by mid-afternoon leaves nothing to
	# read the hour against.
	var r := lerpf(5.5, STUB_RADIUS * 0.74, grow)
	if _spent:
		# Cold. It skins over and goes matte within a minute of the wick dying.
		draw_colored_polygon(WaxShape.scaled(_cup_shape, wick, r, 0.78),
			set_wax.darkened(0.16))
		draw_colored_polygon(WaxShape.scaled(_cup_shape, wick + Vector2(0, -0.8),
			r * 0.84, 0.78), set_wax.darkened(0.04))
		return

	# The lip: wax that has climbed the wall, gone pale again and stayed there.
	# It is the brightest thing on the stub, which is what makes the liquid inside
	# read as a hollow rather than as a lump.
	draw_colored_polygon(WaxShape.scaled(_cup_shape, wick, r * 1.10, 0.78),
		set_wax)
	# The wall dropping away into the cup. One dark ring does more for depth here
	# than any amount of gradient inside the pool.
	draw_colored_polygon(WaxShape.scaled(_cup_shape, wick + Vector2(0, 0.5),
		r * 1.02, 0.78), set_wax.darkened(0.48))
	# The liquid: clear, so you are looking at the shaded bottom of the cup.
	draw_colored_polygon(WaxShape.scaled(_cup_shape, wick, r, 0.78),
		Color(molten.darkened(0.22), 0.95))
	draw_colored_polygon(WaxShape.scaled(_cup_shape, wick + Vector2(0, -0.5),
		r * 0.80, 0.78), molten)
	# TRANSMITTED LIGHT, and only at the very middle. Wax glows where it is thin
	# and directly under the flame, not across a whole dish.
	draw_circle(wick + Vector2(0, 0.8), r * 0.42,
		Color(1.0, 0.62, 0.22, 0.22 * lit))
	draw_circle(wick + Vector2(0, 0.6), r * 0.24,
		Color(1.0, 0.82, 0.44, 0.30 * lit))
	# One small moving specular, opposite the way the flame is leaning. A liquid
	# surface that does not move its highlight is a painted one.
	var gloss := wick - _flame_drift.normalized() * r * 0.42 \
		if _flame_drift.length() > 0.01 else wick + Vector2(-r * 0.35, -r * 0.35)
	draw_circle(gloss, maxf(0.8, r * 0.13),
		Color(1.0, 0.94, 0.76, 0.42 + 0.24 * _flicker))


## A drip in progress: it swells on the lip, hangs heavy, then goes.
func _draw_bead(set_wax: Color, molten: Color) -> void:
	var dir := Vector2(cos(_bead_angle), sin(_bead_angle) * 0.72)
	var swell := minf(_bead, 1.0)
	var run := clampf(_bead - 1.0, 0.0, 1.0)
	var at := STUB + dir * (STUB_RADIUS * 0.72 + run * 13.0)
	# Heavier as it hangs, then stretched by the fall.
	var size := lerpf(1.2, 4.2, ease(swell, 0.6)) * lerpf(1.0, 0.72, run)
	draw_circle(at + Vector2(0.6, 1.0), size * 1.05, Color(0.14, 0.09, 0.05, 0.30))
	draw_circle(at, size, molten.lerp(set_wax, run * 0.7))
	draw_circle(at + Vector2(-0.5, -0.7), size * 0.42,
		Color(1.0, 0.93, 0.74, 0.55 * (1.0 - run * 0.6)))
	if run > 0.02:
		# The thread it leaves behind, thinning as it goes.
		var from := STUB + dir * STUB_RADIUS * 0.72
		draw_line(from, at, Color(molten.lerp(set_wax, 0.4),
			0.70 * (1.0 - run * 0.5)), maxf(0.8, size * 0.42), true)


## When it goes out there is still something to look at: a black wick, a thread
## of smoke, and a saucer full of set wax.
func _draw_dead_wick() -> void:
	var flame := flame_local()
	# The same drowned, hooked, soot-headed wick that was burning a second ago —
	# not a fresh upright thread. Death should not tidy it up.
	_draw_wick(flame)
	# A last ember at the tip, cooling over a few seconds. This is the one moment
	# in the day when the room has no light of its own, and watching the very last
	# of it go out is worth three draw calls.
	var ember := clampf(1.0 - _time * 0.35, 0.0, 1.0)
	if ember > 0.01:
		draw_circle(flame + Vector2(0, -5), 1.4 + ember,
			Color(1.0, 0.42, 0.12, 0.55 * ember))
	# Smoke, drifting and thinning. Stops entirely after a while.
	var since := clampf(_time * 0.12, 0.0, 1.0)
	for i in 5:
		var t := float(i) / 5.0
		var rise := 8.0 + t * 34.0
		var sway := sin(_time * 1.4 - t * 2.6) * (3.0 + t * 7.0)
		draw_circle(flame + Vector2(sway, -rise), 2.0 + t * 4.5,
			Color(0.62, 0.60, 0.58, 0.10 * (1.0 - t) * (1.0 - since)))


## The wick, which is the part of a candle that visibly ages.
##
## Fresh it is a short pale thread. By the middle of the day it has charred back
## to a black stalk; by the end it is long, bent over into the cup, and carrying
## a mushroom of soot that makes the flame gutter — which is the physical reason
## the last hour is unsteady, and it was previously asserted only by a noise
## curve. Drawn under the flame, so the flame's own glare eats most of it and
## what survives reads as a dark core.
func _draw_wick(flame: Vector2) -> void:
	var age := clampf(burn, 0.0, 1.0)
	var base := flame + Vector2(0.0, 3.2)
	# It leans the way the flame leans, and further as it lengthens.
	var lean := _flame_drift.x * 0.22 + age * 2.6
	var tip := base + Vector2(lean, -lerpf(3.0, 7.5, age))
	var char_col := Color(0.10, 0.075, 0.06).lerp(Color(0.05, 0.04, 0.04), age)
	draw_line(base, tip, char_col, lerpf(1.6, 2.4, age), true)
	if age > 0.45:
		# The hook. A long wick falls over into its own cup.
		var hook := tip + Vector2(lean * 1.5 + 2.2 * age, 1.1 * age)
		draw_line(tip, hook, char_col, lerpf(1.4, 2.2, age), true)
		# The mushroom: unburnt carbon, and the reason it guts.
		draw_circle(hook, lerpf(0.4, 1.9, (age - 0.45) / 0.55),
			Color(0.07, 0.055, 0.05))


func _draw_flame() -> void:
	var flame := flame_local()
	_draw_wick(flame)
	var lean := _flame_drift - Vector2(0, absf(_flame_drift.y) * 0.35)
	# A wick sitting in a pool of its own wax carries a smaller, meaner flame.
	var pulse := lerpf(0.84, 1.10, _flicker) * lerpf(0.58, 1.0, _output())

	# Only the tight glare belongs to the drawn flame. Room-scale illumination is
	# the PointLight2D's job — painting it here as well is what produces those
	# visible concentric rings.
	draw_circle(flame, 11.0 * pulse,
		Color(1.0, 0.44, 0.11, 0.035 + _flicker * 0.016))
	draw_set_transform(flame, atan2(lean.x, -8.0),
		Vector2.ONE * lerpf(0.55, 1.0, _output()))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.4, 3.6),
		Vector2(-3.7, -4.0),
		Vector2(0.0, -10.0 - _flicker * 2.0),
		Vector2(4.4, -3.2),
		Vector2(5.0, 3.7),
	]), Color(1.0, 0.50, 0.12, 0.94))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.8, 2.7),
		Vector2(-1.8, -3.0),
		Vector2(0.2, -7.5),
		Vector2(2.7, -2.2),
		Vector2(2.7, 2.8),
	]), Color(1.0, 0.84, 0.36, 0.98))

	# THE DARK CONE. The single most recognisable thing about a real flame and it
	# was missing: directly above the wick sits a pocket of unburnt vapour that has
	# not reached the oxygen yet, and it is DARKER than the luminous sheath around
	# it. Without it a flame is a bright lozenge; with it, it has an inside.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1.5, 2.4),
		Vector2(-1.0, -0.6),
		Vector2(0.1, -2.6),
		Vector2(1.2, -0.4),
		Vector2(1.5, 2.5),
	]), Color(0.72, 0.30, 0.06, 0.55))

	# The blue base, where the gas burns hottest and cleanest against the wick.
	# Small, and it should never be obvious — but a flame whose foot is the same
	# colour as its tip is a paper flame.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.4, 3.4),
		Vector2(-1.6, 0.8),
		Vector2(0.0, 0.2),
		Vector2(1.8, 0.9),
		Vector2(2.4, 3.4),
	]), Color(0.46, 0.66, 1.0, 0.34 + 0.14 * _flicker))
	draw_circle(Vector2(0.1, 1.4), 1.5, Color(0.82, 0.91, 1.0, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# SMOKE BELONGS TO GUTTERING, NOT ONLY TO DEATH. A candle that is drowning in
	# its own wax with a mushroomed wick smokes — that is what guttering IS — and
	# this rig only ever produced smoke after the flame had already gone out, so
	# the one visual warning that the day is nearly over arrived after it ended.
	if burn > GUTTERING_FROM:
		var soot := smoothstep(GUTTERING_FROM, 1.0, burn)
		for i in 4:
			var t := float(i) / 4.0
			var rise := 11.0 + t * 26.0
			var sway := sin(_time * 2.1 - t * 2.2) * (2.0 + t * 6.0) \
				+ _flame_drift.x * 1.4
			draw_circle(flame + Vector2(sway, -rise), 1.6 + t * 3.4,
				Color(0.55, 0.50, 0.47,
					0.13 * soot * (1.0 - t) * maxf(0.0, 1.0 - _flicker)))

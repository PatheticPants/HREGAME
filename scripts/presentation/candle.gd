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

var _time := 0.0
var _flicker := 1.0
var _flame_drift := Vector2.ZERO
var _spent := false
var _warned := false
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

	_update_light_nodes()
	queue_redraw()


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
	# The wick settles into the pool as the column beneath it goes.
	return WICK + _flame_drift + Vector2(0.0, burn * 3.5)


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


## Seen from directly above, a candle burning down does not get shorter — it
## drowns. Wax floods out around the stub and creeps across the saucer, and the
## bright ring of the collar widens as the column inside it sinks. That, plus a
## light that keeps pulling in, is the whole read.
func _draw_spent_wax() -> void:
	if burn <= 0.01:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _wax_seed
	var centre := WICK + Vector2(1.0, 4.0)
	var grow := ease(clampf(burn, 0.0, 1.0), 0.72)
	var pale := Color(0.90, 0.85, 0.71)
	var warm := clampf(light_level + 0.35, 0.35, 1.15)
	pale = pale.lerp(Color(1.0, 0.86, 0.62), 0.30 * warm)

	# Irregular flood, generated once from a fixed seed so it does not crawl.
	var points := PackedVector2Array()
	var lobes := 22
	for i in lobes:
		var a := float(i) / float(lobes) * TAU
		var r := lerpf(13.0, 33.0, grow) * (0.86 + rng.randf() * 0.28)
		points.append(centre + Vector2(cos(a) * r, sin(a) * r * 0.82))
	draw_colored_polygon(points, Color(pale.darkened(0.30), 0.92))
	var inner := PackedVector2Array()
	for i in points.size():
		inner.append(centre + (points[i] - centre) * 0.84)
	draw_colored_polygon(inner, Color(pale, 0.95))

	# Runs that have set solid over the rim of the dish.
	if grow > 0.45:
		for i in 3:
			var a := 0.7 + float(i) * 2.1
			var from := centre + Vector2(cos(a), sin(a) * 0.8) * 26.0
			var to := centre + Vector2(cos(a), sin(a) * 0.8) * lerpf(26.0, 44.0, grow)
			draw_line(from, to, Color(pale.darkened(0.12), 0.85),
				lerpf(3.0, 6.5, grow))

	# The collar the wick sits in, widening as the column sinks into it.
	draw_circle(centre + Vector2(-1, -2), lerpf(7.0, 12.0, grow),
		Color(pale.darkened(0.42), 0.9))


## When it goes out there is still something to look at: a black wick, a thread
## of smoke, and a saucer full of set wax.
func _draw_dead_wick() -> void:
	var flame := flame_local()
	draw_line(flame + Vector2(0, 4), flame + Vector2(0, -5),
		Color(0.09, 0.07, 0.06), 2.4)
	draw_circle(flame + Vector2(0, -5), 1.8, Color(0.06, 0.05, 0.05))
	# Smoke, drifting and thinning. Stops entirely after a while.
	var since := clampf(_time * 0.12, 0.0, 1.0)
	for i in 5:
		var t := float(i) / 5.0
		var rise := 8.0 + t * 34.0
		var sway := sin(_time * 1.4 - t * 2.6) * (3.0 + t * 7.0)
		draw_circle(flame + Vector2(sway, -rise), 2.0 + t * 4.5,
			Color(0.62, 0.60, 0.58, 0.10 * (1.0 - t) * (1.0 - since)))


func _draw_flame() -> void:
	var flame := flame_local()
	var lean := _flame_drift - Vector2(0, absf(_flame_drift.y) * 0.35)
	# A wick sitting in a pool of its own wax carries a smaller, meaner flame.
	var pulse := lerpf(0.84, 1.10, _flicker) * lerpf(0.58, 1.0, _output())

	# Only the tight glare belongs to the drawn flame. Room-scale illumination is
	# the PointLight2D's job — painting it here as well is what produces those
	# visible concentric rings.
	draw_circle(flame, 15.0 * pulse,
		Color(1.0, 0.44, 0.11, 0.05 + _flicker * 0.022))
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
	draw_circle(Vector2(0.1, 0.6), 2.0, Color(0.82, 0.91, 1.0, 0.92))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

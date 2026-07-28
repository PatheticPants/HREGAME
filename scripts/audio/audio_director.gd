extends Node

## Autoload. Every sound in the game goes through here, addressed by event name.
##
## Presentation code says Audio.play(&"paper_pickup", pos) and never names a file,
## a bus, or a pitch. Swapping the placeholder synths for real recordings is then
## a matter of dropping files into audio/ with the same names — no call site
## changes. Retrofitting this later is the miserable job the brief warned about,
## so it exists before anything makes a noise.
##
## Two kinds of sound:
##   one-shots  — fire and forget, pooled players, randomised pitch and gain
##   sustained  — loops whose volume is driven continuously (paper sliding,
##                wax pouring, room tone)

const POOL_SIZE := 16
const AUDIO_DIR := "res://audio/"

## Per-event playback shaping. Everything not listed here uses the defaults.
## Pitch jitter is what stops repeated events (a stack of papers picked up one
## after another) from sounding like a machine gun of the same sample.
const EVENTS := {
	&"paper_pickup":  {"gain": -6.0, "pitch": 1.06, "jitter": 0.13},
	&"paper_drop":    {"gain": -5.0, "pitch": 1.00, "jitter": 0.10},
	&"paper_slide":   {"gain": -19.0, "pitch": 1.00, "jitter": 0.04, "loop": true},
	&"page_turn":     {"gain": -7.0, "pitch": 1.00, "jitter": 0.11},
	&"book_open":     {"gain": -7.0, "pitch": 1.00, "jitter": 0.06},
	&"book_close":    {"gain": -6.0, "pitch": 1.00, "jitter": 0.06},
	&"spoon_clink":   {"gain": -10.0, "pitch": 1.00, "jitter": 0.09},
	&"wax_melt":      {"gain": -19.0, "pitch": 1.00, "jitter": 0.02, "loop": true},
	&"wax_ready":     {"gain": -11.0, "pitch": 1.00, "jitter": 0.06},
	&"wax_drip":      {"gain": -9.0, "pitch": 1.10, "jitter": 0.18},
	&"wax_pour":      {"gain": -17.0, "pitch": 1.00, "jitter": 0.03, "loop": true},
	&"wax_sizzle":    {"gain": -20.0, "pitch": 1.00, "jitter": 0.08},
	&"ring_pickup":   {"gain": -13.0, "pitch": 1.00, "jitter": 0.09},
	&"ring_press":    {"gain": -8.0, "pitch": 1.00, "jitter": 0.05, "loop": true},
	&"ring_seat":     {"gain": -3.0, "pitch": 1.00, "jitter": 0.05},
	&"ring_lift":     {"gain": -6.0, "pitch": 1.00, "jitter": 0.07},
	&"door_knock":    {"gain": -4.0, "pitch": 1.00, "jitter": 0.03},
	&"door_open":     {"gain": -8.0, "pitch": 1.00, "jitter": 0.05},
	&"door_close":    {"gain": -6.0, "pitch": 1.00, "jitter": 0.05},
	&"cloth_shift":   {"gain": -16.0, "pitch": 1.00, "jitter": 0.14},
	&"quill_scratch": {"gain": -11.0, "pitch": 1.00, "jitter": 0.10},
	&"ledger_thud":   {"gain": -4.0, "pitch": 1.00, "jitter": 0.04},
	&"candle_light":  {"gain": -10.0, "pitch": 1.00, "jitter": 0.06},
	&"candle_catch":  {"gain": -8.0, "pitch": 1.00, "jitter": 0.04},
	&"stamp_set":     {"gain": -10.0, "pitch": 1.00, "jitter": 0.10},
	&"view_shift":    {"gain": -15.0, "pitch": 1.00, "jitter": 0.05},
	&"footfall":      {"gain": -17.0, "pitch": 1.00, "jitter": 0.11},
	&"stylus_scratch": {"gain": -18.0, "pitch": 1.00, "jitter": 0.05, "loop": true},
	&"wax_smooth":    {"gain": -14.0, "pitch": 1.00, "jitter": 0.12},
	&"candle_gutter": {"gain": -12.0, "pitch": 1.00, "jitter": 0.05},
	&"candle_out":    {"gain": -7.0, "pitch": 1.00, "jitter": 0.03},
	&"stow_in":       {"gain": -8.0, "pitch": 1.00, "jitter": 0.09},
	&"stow_out":      {"gain": -10.0, "pitch": 1.02, "jitter": 0.10},
	&"room_tone":     {"gain": -30.0, "pitch": 1.00, "jitter": 0.00, "loop": true},
}

var _streams: Dictionary = {}          ## StringName -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _loops: Dictionary = {}            ## StringName -> AudioStreamPlayer
var _loop_targets: Dictionary = {}     ## StringName -> target linear volume 0..1
var _missing: Dictionary = {}

@export var master_gain_db: float = 0.0
@export var muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func _load_streams() -> void:
	for event in EVENTS:
		var path := "%s%s.wav" % [AUDIO_DIR, event]
		if not ResourceLoader.exists(path):
			_missing[event] = true
			continue
		var res := load(path)
		# Looping is a property of the imported stream, not the player, so it has
		# to be set here rather than at the call site. The stream is duplicated
		# first so the on-disk import is not mutated for one-shot users.
		if res is AudioStreamWAV and bool(_cfg(event).get("loop", false)):
			var wav: AudioStreamWAV = (res as AudioStreamWAV).duplicate()
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = wav.data.size() / 2  # 16-bit mono: two bytes a frame
			_streams[event] = wav
		else:
			_streams[event] = res


func _cfg(event: StringName) -> Dictionary:
	return EVENTS.get(event, {"gain": -6.0, "pitch": 1.0, "jitter": 0.08})


# ------------------------------------------------------------------ one-shots

## Fire a sound. `position` is accepted and currently unused — the desk is a
## single close-up space and stereo panning on it reads as a mistake — but the
## signature is right so positional audio can be switched on without touching
## fifty call sites.
func play(event: StringName, _position: Vector2 = Vector2.ZERO, gain_offset := 0.0) -> void:
	if muted:
		return
	if bool(_cfg(event).get("loop", false)):
		if not _loop_misuse.has(event):
			_loop_misuse[event] = true
			push_warning("[audio] '%s' is sustained; drive it with set_loop(), "
				% event + "not play(), or it will occupy a one-shot voice forever.")
		return
	var stream = _streams.get(event, null)
	if stream == null:
		_warn_once(event)
		return
	var cfg := _cfg(event)
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = float(cfg.get("gain", -6.0)) + gain_offset + master_gain_db
	var jitter := float(cfg.get("jitter", 0.08))
	p.pitch_scale = maxf(0.05, float(cfg.get("pitch", 1.0)) + randf_range(-jitter, jitter))
	p.play()


## Same, but never overlaps itself — for events that can be triggered every frame
## by a continuous condition (a drip landing, a page corner catching).
func play_throttled(event: StringName, min_gap := 0.06) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var last := float(_throttle.get(event, -999.0))
	if now - last < min_gap:
		return
	_throttle[event] = now
	play(event)


var _throttle: Dictionary = {}
var _loop_misuse: Dictionary = {}


# ------------------------------------------------------------------ sustained

## Set the target volume (0..1) of a looping event. Ramped in _process so a
## sheet that stops moving fades its slide out rather than cutting it.
func set_loop(event: StringName, amount: float) -> void:
	_loop_targets[event] = clampf(amount, 0.0, 1.0)
	if amount <= 0.0:
		return
	if not _loops.has(event):
		var stream = _streams.get(event, null)
		if stream == null:
			_warn_once(event)
			return
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.stream = stream
		p.volume_db = -60.0
		add_child(p)
		p.play()
		_loops[event] = p


func _process(delta: float) -> void:
	for event in _loops:
		var p: AudioStreamPlayer = _loops[event]
		var target := float(_loop_targets.get(event, 0.0))
		if muted:
			target = 0.0
		var cfg := _cfg(event)
		# -60 dB is our silence floor; ramp in dB so the fade sounds linear.
		var want := -60.0 if target <= 0.001 else \
			float(cfg.get("gain", -12.0)) + master_gain_db + linear_to_db(target)
		p.volume_db = move_toward(p.volume_db, want, 140.0 * delta)


func stop_all_loops() -> void:
	for event in _loops.keys():
		_loop_targets[event] = 0.0


# --------------------------------------------------------------------- niceties

func _warn_once(event: StringName) -> void:
	if _missing.has(event):
		return
	_missing[event] = true
	push_warning("[audio] no stream for '%s' — run tools/make_placeholder_audio.py"
		% event)


## Named after what happens, not what it sounds like, so a designer reading the
## call site learns something. Used by the press sequence, which fires several
## distinct beats within half a second and must be legible in code.
func beat(event: StringName, gain_offset := 0.0) -> void:
	play(event, Vector2.ZERO, gain_offset)

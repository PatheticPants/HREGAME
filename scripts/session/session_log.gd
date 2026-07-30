class_name SessionLog
extends Object

## An instrument, not a feature. One JSONL line per player action, off by default.
##
##     Godot_v4.6.3-stable_win64_console.exe --path . --session-log
##     Godot_v4.6.3-stable_win64_console.exe --path . --session-log=.tools/my_run.jsonl
##
## WHY THIS EXISTS
## ---------------
## Every question anybody has asked about this game's pacing across four sessions
## has been answered by reading source and looking at still frames. Nobody has
## ever measured a working day. The one number the design's central claim rests
## on — how much candle is left when the last petitioner sits down — is not
## derivable from any constant in the project, because the candle burns on
## DELIBERATION and deliberation is the one thing only a player produces.
##
## So this records the two clocks side by side on every line:
##
##   `t`      wall-clock seconds since the log opened. Advances always.
##   `burn_s` candle-seconds consumed. Advances ONLY while the player is
##            deliberating over a matter somebody is waiting on.
##
## The gap between them is the whole answer. Anything that shows up as `t`
## advancing while `burn_s` stands still is time the game gives away for free —
## arrivals, departures, dialogue before the first touch, the ledger, choosing
## from the tray. Anything that moves both is time the player is being charged
## for. No other instrument in this project can tell those two apart.
##
## NOT A TELEMETRY SERVICE. No network, no session id of any kind, no UI, and
## it does nothing whatsoever unless the flag is on — `enabled()` is false and
## every `act()` call returns on its first line. It is safe to leave the call
## sites in permanently, which is the point: an instrument you have to re-add is
## an instrument nobody uses.

const DEFAULT_PATH := "res://.tools/session_log.jsonl"
const FLAG := "--session-log"

static var _file: FileAccess = null
static var _checked := false
static var _on := false
static var _origin_ms := 0

## Context carried on every line so a log is readable without reconstructing
## state. Written by the session, read by nobody else.
static var day_id: StringName = &""
static var day_seconds := 0.0
static var case_id: StringName = &""
static var stage := ""


## Is the flag on? Resolved once. Accepts the flag before or after a `--`
## separator, bare or with an `=path`, because Godot routes those three forms to
## two different arrays and a flag that works only one way is a flag that gets
## reported as broken.
static func enabled() -> bool:
	if _checked:
		return _on
	_checked = true
	var path := ""
	var asked := false
	var argv := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in argv:
		if arg == FLAG:
			asked = true
		elif arg.begins_with(FLAG + "="):
			asked = true
			path = arg.substr(FLAG.length() + 1)
	if not asked:
		return false
	if path.is_empty():
		path = DEFAULT_PATH
	# Appended, not truncated: comparing this morning's run against last night's
	# is the entire use, and a logger that eats the previous run is a logger that
	# answers one question and destroys the evidence for the next.
	_file = FileAccess.open(path, FileAccess.READ_WRITE)
	if _file == null:
		_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("[session-log] cannot open '%s': %s"
			% [path, error_string(FileAccess.get_open_error())])
		return false
	_file.seek_end()
	_on = true
	_origin_ms = Time.get_ticks_msec()
	# WHERE THIS RUN STARTS IN THE FILE, which is a fact, unlike a counter.
	#
	# This carried a `run` number incremented here. A static resets every process
	# start and this line executes once per process, so it said 1 forever —
	# measured, by launching twice and reading both `run_begins` lines. The byte
	# offset is the honest version and it is strictly more useful: it says where
	# to cut the file to get just this run.
	act(&"run_begins", {
		"from_byte": _file.get_position(),
		"at": Time.get_datetime_string_from_system(false, true),
		"path": path,
	})
	return true


## Write one action. `detail` is merged into the line, so a caller adds whatever
## is specific to its act and nothing more.
##
## The candle is passed rather than looked up, because this file must not know
## what a Desk is — the rules layer's no-nodes discipline is worth extending to
## the instrument that measures it.
static func act(what: StringName, detail: Dictionary = {},
		candle: Candle = null) -> void:
	if not enabled():
		return
	if _file == null:
		return
	var line := {
		"t": snappedf(float(Time.get_ticks_msec() - _origin_ms) / 1000.0, 0.001),
		"act": String(what),
	}
	if candle != null:
		line["burn"] = snappedf(candle.burn, 0.0001)
		line["left"] = snappedf(candle.burn_remaining(), 0.0001)
		# The number the whole exercise is for: candle-seconds actually spent.
		# `burn` alone is not comparable across days, because Thursday's candle is
		# shorter than Tuesday's by whatever Tuesday left in the dish.
		line["burn_s"] = snappedf(candle.burn * day_seconds, 0.01)
	if day_id != &"":
		line["day"] = String(day_id)
	if case_id != &"":
		line["case"] = String(case_id)
	if not stage.is_empty():
		line["stage"] = stage
	for k in detail:
		line[k] = detail[k]
	_file.store_line(JSON.stringify(line))
	# Flushed every line. A crash mid-day is exactly the run worth reading, and
	# the write rate here is a few hundred lines an hour.
	_file.flush()


## Names for the session's stage enum, so a log line says SPEAKING rather than 6
## and stays readable after somebody inserts a stage in the middle.
const STAGE_NAMES := ["IDLE", "PRACTICE", "PRACTICE_REVIEW", "CHOOSING", "KNOCK",
	"ENTERING", "SPEAKING", "WORKING", "REACTING", "DEPARTING", "CLOSING",
	"LEDGER", "OVER"]


static func stage_name(value: int) -> String:
	return STAGE_NAMES[value] if value >= 0 and value < STAGE_NAMES.size() \
		else str(value)


## What the player just put a hand on, in words. `get_class()` returns the
## engine's base class for a script that has no class_name, so this reads the
## script's own global name and falls back to the node name.
static func describe(who: Object) -> String:
	if who == null:
		return "nothing"
	var script := who.get_script() as Script
	if script != null:
		var global := script.get_global_name()
		if global != &"":
			return String(global)
	if who is Node:
		return (who as Node).name
	return who.get_class()

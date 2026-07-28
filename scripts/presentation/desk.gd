class_name Desk
extends Node2D

## The room, the desk, and the hand.
##
## Owns input, stacking and construction. It does not know what a case is — the
## SessionController tells it what to lay out and when to sweep it away. It does
## not know what the law is either; that is three folders away in scripts/rules.
##
## STACKING
## --------
## Draw order is child order in `surface`, full stop. Picking anything up moves
## it to the end of the child list and it stays there. There is no z_index
## juggling and no sorting pass, because the moment ordering becomes derived from
## something other than "what did the player touch last", digging a buried
## charter out of a pile stops being predictable — and digging is a mechanic here.
##
## Hit testing walks that same list backwards and takes the first object whose
## rectangle contains the point. Topmost always wins. Godot's physics picking has
## its own opinions about order and we do not want a negotiation.

const DESK_RECT := Rect2(-880, -250, 1760, 660)
const CLICK_SLOP := 6.0
const ROOM_RECT := Rect2(-960, -920, 1920, 1080)
const ROOM_TEXTURE := preload("res://art/environment/chancery_audience_room.png")

## What the room looks like with the candle out.
##
## Low and slightly blue, so warm candlelight separates from it instead of just
## being brighter — and never black, because the far corners have to stay just
## readable enough that hunting for a buried charter is a mechanic rather than a
## chore.
## How far the far wall travels with the camera during a view change. The camera
## itself moves 370 units; moving the distant plate a fifth of that leaves it
## with visibly less apparent travel than the desk, which is parallax.
const PARALLAX_FAR := 74.0

const NIGHT_AMBIENT := Color(0.235, 0.225, 0.275)

## And what it looks like once the day is over. The candle dies and a cold grey
## morning comes up through the shutter to replace it: the ledger stays readable,
## and the warm-to-cold turn is the visual full stop on the day.
const MORNING_AMBIENT := Color(0.62, 0.64, 0.70)

## Where the shutter is. Once the candle is out, shadows come from daylight
## instead: far away, so it is directional rather than radial, and near enough
## to uniform in strength that nothing on the desk is favoured over anything
## else. That is the exact opposite of a candle, which is the point — the room
## stops having a bright middle and becomes flatly, plainly legible.
const WINDOW_DIRECTION := Vector2(-0.55, -1.0)
const WINDOW_DISTANCE := 2600.0
const WINDOW_LEVEL := 0.30

signal investigation_performed(beat: StringName)
## The first physical act of work on a case. The session uses this to start the
## candle rather than guessing from a dialogue state: listening is free, but
## handling evidence while somebody speaks is still deliberation.
signal case_work_engaged(who: Draggable)
signal docket_selected(case_id: StringName)

var surface: Node2D
var fixtures: Node2D
var work_plane: Node2D
var petitioner: PetitionerView
var press: PressController
var session: SessionController

var candle: Candle
var wax_spoon: WaxSpoon
var lens: Lens
var tablet: WaxTablet
var stylus: Stylus
var ledger: Ledger
var desk_note: DocketView
var ring_stand: RingStand
var ledge: DeskLedge
var register_book: ReferenceBook
var kalendar_book: ReferenceBook
var dust: Dust
## The main scene's view controller, if there is one. Null in the test harnesses.
var view: ViewController
var docket_tray: DocketTray
var docket_slips: Array[DocketSlip] = []
var rings: Array[SignetRing] = []
var books: Array[ReferenceBook] = []

## Documents belonging to the case currently on the desk.
var case_papers: Array[Draggable] = []
var day_papers: Array[Draggable] = []
var current_charter: CharterView = null

var _held: Draggable = null
var _press_origin := Vector2.ZERO
var _dragged := false
var _cursor := Vector2.ZERO
var _cursor_prev := Vector2.ZERO
var _cursor_speed := 0.0
var _sweeping: Array[Draggable] = []
var _sweep_timer := 0.0
var _wax_memories: Array[Dictionary] = []
var _door_open_amount := 0.0
var _door_target := 0.0
var _ambient: CanvasModulate
var _ambient_target := NIGHT_AMBIENT
var _door_home_y := -683.0
var _door: AudienceDoor
var _desk_visual: DeskPlaneView
var _view_amount := 0.0
var _backlit_reported := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Ambient is what the room would look like with the candle blown out: a
	# little moonlight through a shutter and nothing else. It has to be low, or
	# the flame has no contrast to work with and every light in the rig ends up
	# reading as a decal laid over an already-lit desk. Slightly blue, so warm
	# candlelight separates from it instead of just being brighter.
	#
	# It cannot be black either. At zero the far corners become unreadable and
	# hunting for a buried charter stops being a mechanic and becomes a chore.
	_ambient = CanvasModulate.new()
	_ambient.name = "candle_ambient"
	_ambient.color = NIGHT_AMBIENT
	_ambient_target = NIGHT_AMBIENT
	add_child(_ambient)

	_door = AudienceDoor.new()
	_door.name = "audience_door"
	_door.position = Vector2(-895, -683)
	_door_home_y = _door.position.y
	_door.settled.connect(_on_door_settled)
	add_child(_door)

	petitioner = PetitionerView.new()
	petitioner.name = "petitioner"
	# Bottom-aligned with the far desk edge: straight-on room above, top-down
	# work surface below, with no portrait spilling onto the player's plane.
	petitioner.position = Vector2(-40, DESK_RECT.position.y - 2.0)
	add_child(petitioner)

	# The entire handled plane shares one projection transform. Keeping the
	# texture and every prop beneath the same parent prevents objects from
	# sliding across the desk while the camera tilts.
	work_plane = Node2D.new()
	work_plane.name = "work_plane"
	add_child(work_plane)

	_desk_visual = DeskPlaneView.new()
	_desk_visual.name = "desk_surface"
	work_plane.add_child(_desk_visual)
	_desk_visual.bind(self)

	fixtures = Node2D.new()
	fixtures.name = "fixtures"
	work_plane.add_child(fixtures)

	surface = Node2D.new()
	surface.name = "surface"
	work_plane.add_child(surface)

	press = PressController.new()
	press.name = "press"
	add_child(press)

	# Added after the work plane, so the air is in front of the desk and the
	# papers rather than behind them. See scripts/presentation/dust.gd.
	dust = Dust.new()
	dust.name = "dust"
	add_child(dust)

	_build_fixtures()
	dust.candle = candle
	press.impression_finished.connect(_remember_impression)

	session = SessionController.new()
	session.name = "session"
	add_child(session)
	session.bind(self)

	# The desk does not own the camera and must not: the ViewController is a
	# sibling in the main scene, and the tests build a desk with no camera at all.
	# This is a nullable convenience so the session can lift the notary's head
	# when somebody knocks, and it is checked at every call site.
	view = get_parent().get_node_or_null("view_controller") as ViewController

	set_process(true)
	Audio.set_loop(&"room_tone", 1.0)
	set_view_amount(0.0)
	session.begin()


# ---------------------------------------------------------------- construction

func _build_fixtures() -> void:
	# Drawn before `surface`, so a racked object sits inside its hole rather than
	# behind the carcass.
	ledge = DeskLedge.new()
	ledge.name = "ledge"
	fixtures.add_child(ledge)

	docket_tray = DocketTray.new()
	docket_tray.name = "docket_tray"
	fixtures.add_child(docket_tray)
	docket_tray.show_for(0)

	ring_stand = RingStand.new()
	ring_stand.position = Vector2(-770, 60)
	fixtures.add_child(ring_stand)

	for i in 3:
		var ring := SignetRing.new()
		surface.add_child(ring)
		var verdict: int = [Lex.Verdict.CONFIRM, Lex.Verdict.DENY, Lex.Verdict.REFER][i]
		ring.bind(verdict, DESK_RECT, ring_stand.slot_position(i))
		rings.append(ring)

	# The candle lives in the ordinary stack, not among the fixtures, because it
	# is something the player picks up. In `fixtures` it drew beneath every sheet
	# and vanished the moment it was carried under a book.
	candle = Candle.new()
	surface.add_child(candle)
	candle.setup(Vector2(752, -115), deg_to_rad(1.0), DESK_RECT)

	wax_spoon = WaxSpoon.new()
	surface.add_child(wax_spoon)
	wax_spoon.setup(Vector2(555, -105), deg_to_rad(-3.0), DESK_RECT)
	press.candle = candle
	press.spoon = wax_spoon

	lens = Lens.new()
	surface.add_child(lens)
	lens.setup(Vector2(700, 250), deg_to_rad(-14.0), DESK_RECT)
	lens.focus_confirmed.connect(_on_lens_focus_confirmed)

	# The tablet begins racked, which does two jobs at once: it keeps a big
	# object off an already-full desk until it is wanted, and it is the first
	# thing a player ever sees come out of a pigeonhole.
	tablet = WaxTablet.new()
	surface.add_child(tablet)
	tablet.setup(ledge.slot_position(1), 0.0, DESK_RECT)
	_try_rack(tablet)

	stylus = Stylus.new()
	surface.add_child(stylus)
	stylus.setup(Vector2(-548, 352), deg_to_rad(9.0), DESK_RECT)

	_build_desk_note()
	_build_book(&"matrix_book", Vector2(-430, 210))
	_build_book(&"almanac", Vector2(400, 235))
	_build_kalendar_book()
	_build_register_book()

	ledger = Ledger.new()
	surface.add_child(ledger)

	Audio.play(&"candle_light", candle.global_position)


func _build_desk_note() -> void:
	var note := Lore.data.desk_note as DocketData
	if note == null:
		return
	desk_note = DocketView.new()
	surface.add_child(desk_note)
	desk_note.bind(note, DESK_RECT)
	desk_note.settle_immediately()


## The Kalendar of the Dead. Generated from the same necrology the rules read, so
## every death WitnessCheck can raise is a page the player can physically open.
##
## It starts racked, like the Register. That is now three of four pigeonholes
## occupied before the first knock — the tablet, the Kalendar and the Register —
## with the Almanac and the Book of Matrices loose on a desk that already cannot
## hold two open books and a charter. That squeeze is deliberate and it is the
## point of the rack existing; it is recorded here so the next person to add a
## book knows they are spending the last hole.
func _build_kalendar_book() -> void:
	if Lore.data.necrology == null:
		return
	kalendar_book = ReferenceBook.new()
	surface.add_child(kalendar_book)
	kalendar_book.bind(
		KalendarBook.build(Lore.data.necrology, Lore.data), DESK_RECT)
	kalendar_book.consulted.connect(_on_book_consulted)
	books.append(kalendar_book)
	_park_in_rack(kalendar_book, 2)


## The Register is a book like the other two, but its pages are generated from
## the ruling history rather than authored — so it grows during the day and the
## precedent a petitioner cites is something the player can physically open.
##
## It starts racked. The desk is already full, and a player who never opens it
## has simply not consulted a source, which is a decision rather than a
## deprivation.
func _build_register_book() -> void:
	register_book = ReferenceBook.new()
	surface.add_child(register_book)
	register_book.bind(RegisterBook.build(session_register(), Lore.data), DESK_RECT)
	register_book.consulted.connect(_on_book_consulted)
	books.append(register_book)
	# IT HAS TO BE STANDING AT THE HOLE BEFORE IT CAN GO IN.
	#
	# RegisterBook.build() never set start_offset, so bind() placed the book at
	# desk-local (0,0) and _try_rack asked the ledge which hole catches a drop at
	# the dead centre of the blotter. The answer is none, so this book has been
	# starting in the middle of the desk — precisely where lay_out_packet drops
	# every charter, and underneath it, because the packet is added afterwards.
	# The comment above and the README have both claimed it starts racked since
	# the day it was written. The tablet works only because desk.gd sets its
	# position to a slot first; do the same here.
	_park_in_rack(register_book, 3)


## The Register's live contents. The session owns it, but the desk builds the
## book before the session exists, so this tolerates being asked early.
func session_register() -> Register:
	return session.register if session != null else Register.new()


## Rebuild the Register's pages after a ruling, preserving whether it was open
## and roughly where the reader had got to.
func refresh_register_book() -> void:
	if register_book == null or not is_instance_valid(register_book):
		return
	var was_open := register_book.is_open
	var was_spread := register_book.spread
	var here := register_book.position
	var stowed := register_book.stowed
	register_book.bind(RegisterBook.build(session_register(), Lore.data), DESK_RECT)
	register_book.solver.place(here, register_book.rotation)
	register_book.position = here
	register_book.stowed = stowed
	register_book.is_open = was_open
	register_book.spread = mini(was_spread,
		maxi(0, register_book.data.spread_count() - 1))


## A senior correction is correspondence, not an invisible data mutation. Pull
## the Register out of its pigeonhole, leave it closed at the corrected spread,
## and let the protruding review slip tell the player why it has come back.
func reveal_register_review() -> void:
	if register_book == null or not is_instance_valid(register_book):
		return
	if ledge != null:
		ledge.release(register_book)
	register_book.unstow()
	register_book.close_for_storage()
	register_book.mark_review_attention()
	var here := Vector2(-510.0, 185.0)
	var angle := deg_to_rad(-3.0)
	register_book.solver.place(here, angle)
	register_book.position = here
	register_book.rotation = angle
	bring_to_front(register_book)
	Audio.play(&"paper_drop", register_book.global_position, -3.0)


func _build_book(id: StringName, fallback_at: Vector2) -> void:
	var data := Lore.book(id)
	if data == null:
		push_warning("[desk] no book data for '%s'" % id)
		return
	if data.start_offset == Vector2.ZERO:
		data.start_offset = fallback_at
	var b := ReferenceBook.new()
	surface.add_child(b)
	b.bind(data, DESK_RECT)
	b.consulted.connect(_on_book_consulted)
	books.append(b)


## Lay out one case's packet. Called by the session; the desk has no idea what a
## case means beyond "these documents, now".
func lay_out_packet(documents: Array[DocumentData]) -> void:
	case_papers.clear()
	current_charter = null
	_backlit_reported = false
	lens.begin_case()

	for doc in documents:
		var node := _make_document_view(doc)
		if node == null:
			continue
		surface.add_child(node)
		node.bind(doc, DESK_RECT)
		Audio.play(&"paper_drop", node.global_position, -5.0)
		case_papers.append(node)
		if doc is CharterData:
			current_charter = node as CharterView

	# The seal comes in on the end of a cord, so it has to be built after the
	# charter it hangs from.
	if current_charter != null:
		var ch := current_charter.charter_data()
		if ch.seal != null:
			var tag := SealTag.new()
			surface.add_child(tag)
			tag.bind(ch.seal, current_charter, DESK_RECT)
			case_papers.append(tag)

	_refresh_lens_subjects()
	press.reset_for_new_case(current_charter)


func _make_document_view(doc: DocumentData) -> Sheet:
	if doc is CharterData:
		return CharterView.new()
	if doc is LetterData:
		return LetterView.new()
	if doc is DocketData:
		return DocketView.new()
	push_warning("[desk] no physical view for document kind '%s'" % doc.kind)
	return null


## Letters and other morning papers stay on the desk across every hearing in the
## day. They are pressure and context, never silently consumed as case evidence.
func lay_out_day_documents(documents: Array[DocumentData]) -> void:
	for old in day_papers:
		if is_instance_valid(old):
			if ledge != null:
				ledge.release(old)
			old.queue_free()
	day_papers.clear()
	for doc in documents:
		var node := _make_document_view(doc)
		if node == null:
			continue
		surface.add_child(node)
		node.bind(doc, DESK_RECT)
		node.settle_immediately()
		day_papers.append(node)
		Audio.play(&"paper_drop", node.global_position, -5.0)


## Day 2's queue is furniture, not a menu. Each case is a physical slip at the
## far lip and begins only when it is dragged into the hearing notch.
func show_docket_tray(day_cases: Array[CaseData]) -> void:
	for slip in docket_slips:
		if is_instance_valid(slip):
			slip.queue_free()
	docket_slips.clear()
	docket_tray.show_for(day_cases.size())
	for i in day_cases.size():
		var slip := DocketSlip.new()
		surface.add_child(slip)
		slip.bind(day_cases[i], i, DESK_RECT)
		docket_slips.append(slip)
	unlock_docket_tray()


func hide_docket_tray() -> void:
	for slip in docket_slips:
		if is_instance_valid(slip):
			slip.queue_free()
	docket_slips.clear()
	docket_tray.show_for(0)


func lock_docket_tray() -> void:
	for slip in docket_slips:
		slip.draggable_enabled = false


func unlock_docket_tray() -> void:
	for slip in docket_slips:
		slip.draggable_enabled = true


func remove_docket(case_id: StringName) -> void:
	for i in range(docket_slips.size() - 1, -1, -1):
		var slip := docket_slips[i]
		if slip.case_id() != case_id:
			continue
		docket_slips.remove_at(i)
		if is_instance_valid(slip):
			slip.selected = true
			slip.draggable_enabled = false
			slip.queue_free()
		break
	docket_tray.show_for(docket_slips.size())


## Investigation has a social surface. Petitioners watch which book the notary
## reaches for and whether the glass lingers over their wax, then the session
## decides whether this particular person has something authored to say.
func _on_lens_focus_confirmed(subject: Node2D) -> void:
	if subject is SealTag:
		investigation_performed.emit(&"inspect_seal")
	elif subject is CharterView:
		investigation_performed.emit(&"inspect_closing")
	elif subject is WaxPool:
		investigation_performed.emit(&"inspect_impression")


func _on_book_consulted(book_id: StringName) -> void:
	investigation_performed.emit(StringName("consult_" + String(book_id)))


## Lifting a charter into the candle is as conspicuous as reaching for the glass,
## and rather more so — a notary holding your parchment up against the flame is
## doing exactly one thing, and everybody in the room knows what it is. Fired
## once per case, like every other beat.
func _check_backlight() -> void:
	if current_charter == null or not is_instance_valid(current_charter):
		return
	if not current_charter.is_backlit():
		_backlit_reported = false
		return
	if _backlit_reported:
		return
	_backlit_reported = true
	investigation_performed.emit(&"hold_to_light")


## The petitioner gathers the papers up and takes them away. Implemented by
## handing each sheet a velocity and letting the same solver that dragged it
## carry it off — no separate animation path, so it looks like the same object.
func sweep_packet_away() -> void:
	var to := petitioner.global_position + Vector2(0, -60)
	var local_target := surface.to_local(to)
	for d in case_papers:
		if d == null or not is_instance_valid(d):
			continue
		d.draggable_enabled = false
		d.solver.bounds = Rect2()
		d.solver.sleeping = false
		d.solver.velocity = (local_target - d.position).normalized() \
			* randf_range(900.0, 1300.0)
		d.solver.angular_velocity = randf_range(-4.0, 4.0)
		_sweeping.append(d)
	_sweep_timer = 0.0
	# paper_slide is a sustained loop. Playing it as a one-shot leaves a looping
	# stream trapped forever in the one-shot pool; the moving sheets already
	# drive the slide bed themselves.
	Audio.play(&"paper_drop", to, -3.0)
	case_papers.clear()
	current_charter = null


func _finish_sweep() -> void:
	for d in _sweeping:
		if is_instance_valid(d):
			d.queue_free()
	_sweeping.clear()
	_refresh_lens_subjects()


func _refresh_lens_subjects() -> void:
	var subs: Array[Node2D] = []
	for i in surface.get_child_count():
		var c := surface.get_child(i) as Node2D
		if c == null:
			continue
		if c.has_method("has_detail"):
			subs.append(c)
		# Wax the player has poured rides on its sheet, one level down, so a
		# flat scan of the surface would never find it — and looking at your own
		# impression through the glass is half the reason to care about the press.
		for j in c.get_child_count():
			var pool := c.get_child(j) as WaxPool
			if pool != null:
				subs.append(pool)
	lens.subjects = subs


## A few crumbs shear off when the ring lifts. They stay on the blotter after
## the document leaves, so the room quietly accumulates the history of the day:
## not a score, just physical evidence that three irreversible things happened.
func _remember_impression(verdict: int, record: ImpressionRecord) -> void:
	if current_charter == null or record == null:
		return
	var device: StringName = &"notary_refer"
	match verdict:
		Lex.Verdict.CONFIRM: device = &"notary_confirm"
		Lex.Verdict.DENY: device = &"notary_deny"

	var rng := RandomNumberGenerator.new()
	rng.seed = record.shape_seed ^ (verdict * 7919)
	var crumbs: Array[Vector3] = []
	var count := 3
	if record.grade == Lex.Grade.BLOTTED or record.grade == Lex.Grade.SMEARED:
		count = 6
	for i in count:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(9.0, 27.0)
		crumbs.append(Vector3(cos(angle) * distance, sin(angle) * distance,
			rng.randf_range(1.4, 3.4)))

	# Where the wax actually was, not where the chancery would have preferred it.
	# If the notary sealed across the witness list, the blotter remembers that.
	var where := current_charter.wax_slot_world()
	if press.pool != null and is_instance_valid(press.pool):
		where = press.pool.global_position

	# The new impression is now something the glass can be held over.
	_refresh_lens_subjects()

	_wax_memories.append({
		"at": work_plane.to_local(where),
		"plate": record.shape_seed,
		"device": device,
		"grade": record.grade,
		"rotation": deg_to_rad(record.ring_rotation_deg),
		"crumbs": crumbs,
	})


# ---------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# In the audience view the desk is deliberately non-interactive. A click
		# advances the person in front of us instead of grabbing a foreshortened
		# document from the bottom of the frame.
		if _view_amount > 0.06:
			if event.pressed:
				petitioner.on_click()
			return
		if event.pressed:
			_begin_press()
		else:
			_end_press()


func _begin_press() -> void:
	var p := surface.get_local_mouse_position()
	_press_origin = p
	_dragged = false
	var target := _pick(p)
	if target == null:
		_click_empty()
		return
	# The permanent memorandum describes the office; rearranging it is not
	# handling the live matter. Everything evidentiary or instrumental still
	# starts working time, including references and political correspondence.
	if not target is DocketSlip and target != desk_note:
		case_work_engaged.emit(target)
	_held = target
	bring_to_front(target)
	target.grab(p)


func _end_press() -> void:
	if _held == null:
		return
	var was := _held
	var local := was.to_local(get_global_mouse_position())
	was.drop()
	_held = null
	if _dragged and was is DocketSlip:
		_try_hear_docket(was as DocketSlip)
		return
	# A press and release in nearly the same place is a click, not a drag. Books
	# open on it; everything else ignores it and is simply put back down.
	if not _dragged:
		was.on_click(local)
		return
	_try_rack(was)


func _try_hear_docket(slip: DocketSlip) -> void:
	if docket_tray == null or slip == null or slip.selected:
		return
	docket_tray.armed = false
	docket_tray.queue_redraw()
	if not docket_tray.accepts(slip.position):
		return
	var id := slip.case_id()
	if id == &"":
		return
	slip.selected = true
	slip.draggable_enabled = false
	docket_selected.emit(id)


## Start something already shelved. Only for construction: the player never puts
## anything away except by carrying it, and this exists solely so a build-time
## "it begins in the rack" is not silently a lie about where the object is.
func _park_in_rack(who: Draggable, slot: int) -> void:
	if ledge == null or who == null:
		return
	var at := ledge.slot_position(slot)
	who.solver.place(at, 0.0)
	who.position = at
	_try_rack(who)


## Let go over a pigeonhole and the thing goes in it. Nothing else puts anything
## away, and nothing ever puts itself away.
func _try_rack(who: Draggable) -> void:
	if ledge == null or who == null or not is_instance_valid(who):
		return
	ledge.armed_slot = -1
	var slot := ledge.slot_for_drop(who.position, who)
	if slot < 0:
		ledge.release(who)
		return
	ledge.take(slot, who)
	# Books close when they are shelved. An open book in a pigeonhole is not a
	# thing, and it would also keep its huge open hit box.
	if who is ReferenceBook:
		(who as ReferenceBook).close_for_storage()
	# Sit it on the floor of the hole rather than centring it, so anything
	# taller than the rack rises out of the top the way a book in a rack does
	# instead of hanging through the bottom of it.
	var visual_height := who.hit_size.y * who.stow_scale
	var lift := maxf(0.0, visual_height - DeskLedge.SLOT_SIZE.y) * 0.5
	who.stow_into(ledge.slot_position(slot) - Vector2(0.0, lift),
		deg_to_rad(randf_range(-2.5, 2.5)))


func _click_empty() -> void:
	if ledger.visible and not ledger.is_finished():
		ledger.skip_to_end()
		return
	petitioner.on_click()


## Topmost first. The list is the truth about what is on top of what.
func _pick(point: Vector2) -> Draggable:
	var world := surface.to_global(point)
	for i in range(surface.get_child_count() - 1, -1, -1):
		var d := surface.get_child(i) as Draggable
		if d != null and d.contains_point(world):
			return d
	return null


func bring_to_front(d: Draggable) -> void:
	if d.get_parent() == surface:
		surface.move_child(d, -1)
	_refresh_lens_subjects()


## Is the player holding something? Anything the game does to the view on its own
## initiative has to ask this first, because looking up drops what is in hand.
func hands_full() -> bool:
	return _held != null


func cancel_hand_for_view() -> void:
	if _held == null:
		return
	_held.drop()
	_held = null
	_dragged = false


func set_view_amount(value: float) -> void:
	_view_amount = clampf(value, 0.0, 1.0)
	if _view_amount > 0.06:
		cancel_hand_for_view()

	# Pivot the desk surface around its far edge. Contact points still recede
	# together, while handled props receive their own relief compensation below
	# so books, seals and tools retain height instead of becoming flat stickers.
	var plane_y := lerpf(1.0, 0.62, _view_amount)
	if work_plane != null:
		work_plane.scale = Vector2(1.0, plane_y)
		work_plane.position = Vector2(0,
			DESK_RECT.position.y * (1.0 - plane_y))
	if surface != null:
		for child in surface.get_children():
			var d := child as Draggable
			if d == null:
				continue
			var depth := clampf(inverse_lerp(
				DESK_RECT.position.y, DESK_RECT.end.y, d.position.y), 0.0, 1.0)
			var full_depth_scale := lerpf(0.90, 1.06, depth)
			d.set_projection_context(plane_y,
				lerpf(1.0, full_depth_scale, _view_amount))
	if petitioner != null:
		petitioner.scale = Vector2.ONE * lerpf(1.0, 1.075, _view_amount)
		# The person stands between the desk and the wall, so they shift by an
		# amount between the two.
		petitioner.position.y = petitioner_home_y() - _view_amount * PARALLAX_FAR * 0.34
	if candle != null:
		candle.set_projection_scale(plane_y)

	# PARALLAX. The wall is across the room and the desk is under your hands, so
	# when the head comes up they cannot move together. Shifting the far plate
	# with the camera reduces its apparent travel, which is the whole reason a
	# 2D scene reads as having depth during a viewpoint change — without it the
	# tilt is a pan of a flat picture, however well eased.
	if _door != null:
		_door.position.y = _door_home_y - _view_amount * PARALLAX_FAR
	queue_redraw()


# --------------------------------------------------------------------- process

func _process(delta: float) -> void:
	_cursor = surface.get_local_mouse_position()
	_cursor_speed = (_cursor - _cursor_prev).length() / maxf(delta, 0.0001)
	_cursor_prev = _cursor
	if _door != null:
		_door.advance(delta)
		_door_open_amount = _door.open_amount
		# The creak tracks the swing the way the melt tracks the flame: a loop
		# whose volume is the physical rate, silent the instant the leaf stops.
		Audio.set_loop(&"door_creak", _door.swing_rate())

	if _held != null:
		_held.move_to(_cursor)
		if _press_origin.distance_to(_cursor) > CLICK_SLOP:
			_dragged = true

	# Arm whichever hole would catch what is in hand, so the rack answers before
	# the player commits rather than after.
	if ledge != null:
		var armed := -1
		if _held != null and _dragged:
			armed = ledge.slot_for_drop(_held.position, _held)
		if armed != ledge.armed_slot:
			if armed >= 0:
				Audio.play_throttled(&"stow_out", 0.22)
			ledge.armed_slot = armed
	if docket_tray != null:
		var hearing_armed := _held is DocketSlip and _dragged \
			and docket_tray.accepts(_held.position)
		if hearing_armed != docket_tray.armed:
			docket_tray.armed = hearing_armed
			docket_tray.queue_redraw()

	if _ambient != null and not _ambient.color.is_equal_approx(_ambient_target):
		# Roughly six seconds from candlelight to morning.
		_ambient.color = _ambient.color.lerp(_ambient_target,
			clampf(delta * 0.42, 0.0, 1.0))

	_update_hover()
	_update_lighting()
	_check_backlight()
	_update_stack_depths()
	press.tick(delta, _held, _cursor, _cursor_speed)
	if tablet != null:
		tablet.tick(delta, _held, _cursor_speed)

	if not _sweeping.is_empty():
		_tick_sweep(delta)

	if _desk_visual != null:
		_desk_visual.queue_redraw()
	queue_redraw()


## The day is over. Bring the morning up slowly through the shutter — slowly
## enough that the player watches the warm light leave rather than being cut to
## a new lighting state.
func begin_morning() -> void:
	_ambient_target = MORNING_AMBIENT


func reset_for_next_day() -> void:
	if ledge != null:
		ledge.release(ledger)
	ledger.unstow()
	ledger.visible = false
	press.enabled = false
	candle.reset_day()
	_ambient_target = NIGHT_AMBIENT
	_work_reset_tools()
	Audio.play(&"candle_light", candle.global_position)


func _work_reset_tools() -> void:
	cancel_hand_for_view()
	lens.begin_case()
	press.reset_for_new_case(null)


func is_morning() -> bool:
	return _ambient_target == MORNING_AMBIENT


## Opening and closing are requests. The loud sound belongs to the arrival, which
## the door itself reports — see AudienceDoor.settled and _on_door_settled. What
## fires here is only the small immediate acknowledgement that a hand has touched
## it: a latch lifting, a bolt going home. Input still gets an instant answer;
## the swing and the thud land when the leaf is actually there.
func open_door() -> void:
	_door_target = 1.0
	if _door != null:
		_door.swing_to(1.0)
	Audio.play(&"door_latch", _door_world())


func close_door() -> void:
	_door_target = 0.0
	if _door != null:
		_door.swing_to(0.0)
	# Pulling it to has a start as well as an end. Opening had one and closing did
	# not, so half the door's cycle began in silence.
	Audio.play(&"door_latch", _door_world(), -6.0)


## Is the leaf actually where it was told to go? Callers that sequence beats
## around the door must ask this rather than assuming the request was the event.
func door_is_settled() -> bool:
	return _door == null or _door.is_settled()


## Somebody is on the other side. The leaf jumps against the latch and stays shut.
func knock_at_door() -> void:
	if _door != null:
		_door.knock()
	Audio.play(&"door_knock", _door_world())


func _door_world() -> Vector2:
	return _door.global_position if _door != null else global_position


func _on_door_settled(opening: bool) -> void:
	Audio.play(&"door_open" if opening else &"door_close", _door_world())


## Freed on a clock rather than on arrival. Damping means a sheet that was
## launched at an awkward angle can coast to a halt short of the petitioner and
## sit there forever, so "have they got there yet" is the wrong question — the
## papers only have to be off the desk and out of the way.
func _tick_sweep(delta: float) -> void:
	_sweep_timer += delta
	if _sweep_timer > 1.5:
		_finish_sweep()


## Every shadow on the desk is thrown by the candle flame, and the candle is a
## thing the player carries. One place computes where the light is, how hard it
## is burning this instant, and how much of it reaches each individual object —
## so a sheet dragged toward the flame darkens its own shadow on the way, and the
## whole desk relights when the candle is set down somewhere else.
func _update_lighting() -> void:
	if candle == null:
		return
	var flame := candle.flame_world()
	var strength := candle.light_intensity()
	var spent := candle.is_spent()
	if spent:
		# Daylight. One direction for the whole room, one strength for
		# everything in it, and no flicker.
		flame = global_position + WINDOW_DIRECTION.normalized() * WINDOW_DISTANCE
		strength = 1.0
	for i in surface.get_child_count():
		var d := surface.get_child(i) as Draggable
		if d == null or d == candle:
			continue  # the candle does not stand in its own light
		d.light_position = flame
		d.light_strength = strength
		d.ambient_daylight = spent
		d.light_level = WINDOW_LEVEL if spent \
			else candle.illumination_at(d.global_position)
	petitioner.light_position = flame
	petitioner.light_strength = strength
	petitioner.light_level = WINDOW_LEVEL if spent \
		else candle.illumination_at(petitioner.global_position)
	ring_stand.light_position = flame
	ring_stand.light_level = WINDOW_LEVEL if spent \
		else candle.illumination_at(ring_stand.global_position)
	# Which hollow is empty because its ring is in the player's hand. The word is
	# cut into the block, so lifting the ring is precisely when it stops being
	# readable — and precisely when knowing what you have picked up matters most.
	ring_stand.lifted_slot = -1
	for i in rings.size():
		if rings[i].is_held:
			ring_stand.lifted_slot = i
			break
	ring_stand.queue_redraw()
	if ledge != null:
		ledge.light_position = flame
		ledge.light_level = WINDOW_LEVEL if spent \
			else candle.illumination_at(ledge.global_position)
		ledge.queue_redraw()


## Exactly one object can be hovered — the same one _pick would grab — so the
## glow is a truthful preview of what the hand would close on rather than a
## general "this is clickable" wash over everything under the cursor.
func _update_hover() -> void:
	var target: Draggable = null
	if _held == null and _view_amount <= 0.06:
		target = _pick(_cursor)
	for i in surface.get_child_count():
		var d := surface.get_child(i) as Draggable
		if d != null:
			d.hovered = d == target


func _update_stack_depths() -> void:
	for i in surface.get_child_count():
		var d := surface.get_child(i) as Draggable
		if d != null:
			d.stack_depth = i


# --------------------------------------------------------------------- backdrop

func _draw() -> void:
	_draw_room()


func petitioner_home_y() -> float:
	return DESK_RECT.position.y - 2.0


func _draw_room() -> void:
	# This plate extends above and below both camera endpoints. It is never
	# stretched during the tilt; only the camera reveals a different crop.
	# Shifted with the camera so the far wall has less apparent travel than the
	# desk under your hands. See PARALLAX_FAR.
	draw_texture_rect(ROOM_TEXTURE,
		Rect2(ROOM_RECT.position - Vector2(0.0, _view_amount * PARALLAX_FAR),
			ROOM_RECT.size), false)

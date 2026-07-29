extends Node

var _desk: Desk
var _main: Node


func _ready() -> void:
	call_deferred("_run")


func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_main = packed.instantiate()
	add_child(_main)
	await get_tree().process_frame
	_desk = _main.get_node("desk") as Desk
	await _settle(40)
	if _desk.session.stage == SessionController.Stage.PRACTICE:
		_desk.sweep_packet_away()
		_desk.session._begin_day(0)
	_desk.session.set_process(false)
	_desk.lay_out_packet(Lore.data.cases[0].documents)
	await _settle(60)

	var charter: Draggable = null
	for d in _desk.case_papers:
		if d is CharterView:
			charter = d
			break
	print("A: charter=", charter.name)
	_desk._held = charter
	_desk._dragged = true
	charter.grab(charter.position)
	await _settle(2)
	_desk.sweep_packet_away()
	for step in 10:
		await _settle(20)
		print("  f+", (step + 1) * 20, " valid=", is_instance_valid(charter),
			" held==null=", (_desk._held == null), " sweeping=", _desk._sweeping.size())
		if not is_instance_valid(charter):
			break
	print("A: FINAL held==null ", _desk._held == null,
		" is_instance_valid(_held) ", is_instance_valid(_desk._held))

	print("A: does work AFTER desk.gd:946 still run?")
	var ring: Draggable = _desk.rings[0]
	print("  ring.hovered before: ", ring.hovered)
	_desk.begin_morning()
	var m0: float = _desk._morning_amount
	var amb0: Color = _desk._ambient.color
	await _settle(60)
	print("  _morning_amount ", m0, " -> ", _desk._morning_amount, "  (lerp is BEFORE 946)")
	print("  ambient ", amb0, " -> ", _desk._ambient.color, "  (BEFORE 946)")
	print("  ring.hovered after (update_hover is AFTER 946): ", ring.hovered)
	print("  candle remaining (candle ticks itself): ", _desk.candle.remaining())
	get_tree().quit()

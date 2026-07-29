extends Node

## TEMPORARY review probe #3. Deleted after use.

const OUT := "res://.tools/"

var _desk: Desk
var _main: Node
var _lens: Lens
var _mat: ShaderMaterial


func _ready() -> void:
	call_deferred("_run")


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

	var view := _main.get_node_or_null("view_controller")
	if view != null:
		view.set_process(false)
		view.set_process_input(false)
	var camera := _main.get_node("camera") as Camera2D
	var sheet := _desk.current_charter
	var over := _desk.surface.to_local(sheet.closing_world())
	# Put the flame beside the glass exactly as the real capture does.
	_desk.bring_to_front(_desk.candle)
	_desk.candle.solver.place(over + Vector2(166.0, -112.0), _desk.candle.rotation)
	_desk.candle.position = over + Vector2(166.0, -112.0)
	await _settle(14)
	_desk.bring_to_front(_desk.lens)
	_desk.lens.solver.place(over, deg_to_rad(-5.0))
	_desk.lens.position = over
	await _settle(44)
	camera.position = _desk.lens.global_position
	camera.zoom = Vector2(2.45, 2.45)
	await _settle(12)

	_lens = _desk.lens
	_lens.set_process(false)
	var quad: Polygon2D = _lens._optics_quad
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	quad.texture = ImageTexture.create_from_image(img)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/_probe_committed.gdshader")
	quad.material = _mat
	_push_centre()
	_mat.set_shader_parameter("active", 1.0)
	_mat.set_shader_parameter("fringe_pixels", 0.42)

	# --- Q1: is the BackBufferCopy node load-bearing under gl_compatibility?
	_mat.set_shader_parameter("magnification", 0.90)
	await _settle(6)
	await _shot("bbc_on_mag090")
	_lens._optics_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	await _settle(6)
	await _shot("bbc_off_mag090")
	_lens._optics_copy.copy_mode = BackBufferCopy.COPY_MODE_RECT
	await _settle(6)

	# --- Q2: the chromatic fringe, at the committed magnification.
	_mat.set_shader_parameter("magnification", 0.070)
	_mat.set_shader_parameter("fringe_pixels", 0.42)
	await _settle(6)
	await _shot("fringe_042")
	_mat.set_shader_parameter("fringe_pixels", 0.0)
	await _settle(6)
	await _shot("fringe_000")
	_mat.set_shader_parameter("fringe_pixels", 3.0)
	await _settle(6)
	await _shot("fringe_300")
	_mat.set_shader_parameter("fringe_pixels", 0.42)

	# --- Q3/Q4: circularity and resolution.
	_mat.set_shader_parameter("magnification", 0.90)
	await _settle(6)
	await _shot("res_%dx%d" % _win())
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1080),
			Vector2i(1920, 1200), Vector2i(1000, 1000)]:
		get_window().size = size
		await _settle(20)
		_push_centre()
		await _settle(6)
		print("   window ", size, "  visible_rect ",
			get_viewport().get_visible_rect().size,
			"  centre_uniform ", _mat.get_shader_parameter("lens_center_screen"))
		await _shot("res_%dx%d" % [size.x, size.y])
	get_window().size = Vector2i(1600, 900)
	await _settle(20)

	get_tree().quit()


func _win() -> Array:
	var s := get_window().size
	return [s.x, s.y]


func _push_centre() -> void:
	_mat.set_shader_parameter("lens_center_screen",
		_lens.get_global_transform_with_canvas().origin
			/ get_viewport().get_visible_rect().size)


func _settle(frames: int) -> void:
	for i in frames:
		if _desk != null and not _desk.is_processing():
			_desk._update_lighting()
		await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + "probe3_" + label + ".png"))
	print("   probe3 shot  ", label, "  ", image.get_size())

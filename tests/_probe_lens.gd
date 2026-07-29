extends Node

## TEMPORARY review probe. Deleted after use.

const OUT := "res://.tools/"

var _desk: Desk
var _main: Node
var _tag := ""


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var size := get_viewport().get_visible_rect().size
	_tag = "%dx%d" % [int(size.x), int(size.y)]
	print("PROBE viewport ", size)
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
	_desk.bring_to_front(_desk.lens)
	_desk.lens.solver.place(over, deg_to_rad(-5.0))
	_desk.lens.position = over
	await _settle(44)

	camera.position = _desk.lens.global_position
	camera.zoom = Vector2(2.45, 2.45)
	await _settle(12)

	var lens := _desk.lens
	print("PROBE lens canvas origin ", lens.get_global_transform_with_canvas().origin)
	print("PROBE lens_center_screen ",
		lens._optics_material.get_shader_parameter("lens_center_screen"))
	print("PROBE lens scale ", lens.scale, " rot ", lens.rotation)

	await _shot("a_stock")

	# Freeze the lens so the probe owns the shader parameters.
	lens.set_process(false)
	var quad: Polygon2D = lens._optics_quad
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/_probe_committed.gdshader")
	quad.material = mat
	var centre := lens.get_global_transform_with_canvas().origin \
		/ get_viewport().get_visible_rect().size
	mat.set_shader_parameter("lens_center_screen", centre)
	mat.set_shader_parameter("active", 1.0)
	mat.set_shader_parameter("fringe_pixels", 0.42)

	mat.set_shader_parameter("magnification", 0.070)
	await _settle(4)
	await _shot("b_mag070")

	mat.set_shader_parameter("magnification", 0.0)
	await _settle(4)
	await _shot("c_mag000")

	quad.visible = false
	await _settle(4)
	await _shot("d_quad_hidden")
	quad.visible = true

	mat.set_shader_parameter("magnification", 0.90)
	await _settle(4)
	await _shot("e_mag090")

	# Fringe on / off at the same magnification: the aberration claim.
	mat.set_shader_parameter("magnification", 0.070)
	mat.set_shader_parameter("fringe_pixels", 0.42)
	await _settle(4)
	await _shot("f_fringe042")
	mat.set_shader_parameter("fringe_pixels", 0.0)
	await _settle(4)
	await _shot("g_fringe000")
	mat.set_shader_parameter("fringe_pixels", 8.0)
	await _settle(4)
	await _shot("h_fringe800")
	mat.set_shader_parameter("fringe_pixels", 0.42)

	# active = 0 should switch the optics off entirely.
	mat.set_shader_parameter("active", 0.0)
	await _settle(4)
	await _shot("i_active000")
	mat.set_shader_parameter("active", 1.0)

	# The BackBufferCopy node removed: does the screen read still work?
	lens._optics_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	mat.set_shader_parameter("magnification", 0.90)
	await _settle(6)
	await _shot("j_mag090_nobbc")
	lens._optics_copy.copy_mode = BackBufferCopy.COPY_MODE_RECT

	# Wide shot at desk zoom, big magnification, to see the whole prop.
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 590)
	await _settle(8)
	await _shot("k_wide_mag090")
	mat.set_shader_parameter("magnification", 0.070)
	await _settle(4)
	await _shot("l_wide_mag070")

	get_tree().quit()


func _settle(frames: int) -> void:
	for i in frames:
		if _desk != null and not _desk.is_processing():
			_desk._update_lighting()
		await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT + "probe_" + _tag + "_" + label + ".png"
	image.save_png(ProjectSettings.globalize_path(path))
	print("   probe shot  ", label)

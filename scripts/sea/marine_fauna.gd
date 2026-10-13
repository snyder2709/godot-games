class_name MarineFauna
extends Node3D

signal crab_clicked(crab_pos: Vector3)
signal dolphin_clicked(pos: Vector3)
signal dolphin_jumped(pos: Vector3)

const SEA_MIN_X := -16.5
const SEA_MAX_X := 16.5
const SEA_MIN_Z := -13.5
const SEA_MAX_Z := 6.5

class DolphinData extends RefCounted:
	var node: Node3D
	var start_pos: Vector3
	var end_pos: Vector3
	var t: float = 1.0
	var active: bool = false
	var delay: float = 0.0
	var spin: float = 0.0

var _island_crab: Node3D
var _crab_anim: AnimationPlayer
var _crab_bounce: float = 0.0

var dolphins: Array[DolphinData] = []
var _kenney_colormap: Texture2D


func init_fauna(colormap: Texture2D) -> void:
	_kenney_colormap = colormap
	_build_island_crab()
	_build_dolphins()


func _build_island_crab() -> void:
	_island_crab = Node3D.new()
	_island_crab.position = Vector3(-9.2, 0.32, -5.6)
	add_child(_island_crab)
	var crab_inst := _instantiate_model("res://assets/models/animal-crab.glb", _island_crab, Vector3.ZERO, Vector3(0.0, 35.0, 0.0), Vector3.ONE * 0.38, true)
	_crab_anim = _play_glb_anim(crab_inst, [&"idle", &"walk"])


func _build_dolphins() -> void:
	# Используем готовую 3D-модель дельфина с плавательной скелетной анимацией
	for i in range(2):
		var dnode := Node3D.new()
		dnode.visible = false
		add_child(dnode)
		var d_model := _instantiate_model(
			"res://assets/models/dolphin.glb",
			dnode,
			Vector3.ZERO,
			Vector3(-90.0, 0.0, 0.0),
			Vector3.ONE * 0.009
		)
		_play_glb_anim(d_model, [&"Take 001", &"Armature", &"swim", &"idle"])

		var dd := DolphinData.new()
		dd.node = dnode
		dd.delay = 1.2 + float(i) * 3.0
		dd.active = false
		dolphins.append(dd)


func update_fauna(delta: float, world_time: float, water_surface: WaterSurface, _girl_pos: Vector3) -> void:
	# Анимация прыжка крабика
	if _crab_bounce > 0.0:
		_crab_bounce = maxf(0.0, _crab_bounce - delta * 3.5)
	if _island_crab != null:
		_island_crab.position.y = 0.32 + sin(_crab_bounce * PI) * 0.65
		var crab_sy := 0.45 * (1.0 + sin(_crab_bounce * PI) * 0.5)
		var crab_sxz := 0.45 * (1.0 - sin(_crab_bounce * PI) * 0.25)
		_island_crab.scale = Vector3(crab_sxz, crab_sy, crab_sxz)

	# Обновление прыжков дельфинов
	for d in dolphins:
		if not d.active:
			d.delay -= delta
			if d.delay <= 0.0:
				_start_dolphin_jump(d, water_surface)
			continue

		var prev_t := d.t
		d.t += delta * 0.74

		if prev_t < 0.06 and d.t >= 0.06:
			dolphin_jumped.emit(d.start_pos)

		if d.t >= 1.0:
			dolphin_jumped.emit(d.end_pos)
			d.active = false
			d.node.visible = false
			d.delay = randf_range(3.2, 5.8)
		else:
			var s := d.start_pos
			var e := d.end_pos
			var pos := s.lerp(e, d.t)
			pos.y = sin(d.t * PI) * 2.85 - 0.25

			var jump_dir := (e - s).normalized()
			d.node.look_at_from_position(pos, pos + jump_dir, Vector3.UP)
			d.node.rotate_object_local(Vector3.RIGHT, (d.t - 0.5) * 1.5)

			if d.spin > 0.0:
				d.spin = maxf(0.0, d.spin - delta * 1.6)
				d.node.rotate_object_local(Vector3.FORWARD, delta * 14.0)


func _start_dolphin_jump(d: DolphinData, water_surface: WaterSurface) -> void:
	var from_left := randf() < 0.5
	var sx := randf_range(-8.5, -3.0) if from_left else randf_range(3.0, 8.5)
	var sz := randf_range(-7.5, 0.5)
	var s := Vector3(sx, 0.0, sz)
	var jump_len := randf_range(5.2, 6.8)
	var e := s + Vector3(jump_len if from_left else -jump_len, 0.0, randf_range(-1.2, 1.2))

	if water_surface != null:
		s = water_surface.push_out_of_islands(s, 2.0)
		e = water_surface.push_out_of_islands(e, 2.0)

	d.start_pos = s
	d.end_pos = e
	d.t = 0.0
	d.spin = 0.0
	d.active = true
	d.node.visible = true
	d.node.position = s


func check_touch(camera: Camera3D, screen_pt: Vector2) -> bool:
	# Тап по крабику
	if _island_crab != null and camera.is_position_in_frustum(_island_crab.global_position):
		var crab_screen := camera.unproject_position(_island_crab.global_position + Vector3(0.0, 0.3, 0.0))
		if screen_pt.distance_to(crab_screen) <= 75.0:
			_crab_bounce = 1.0
			if _crab_anim != null and _crab_anim.has_animation(&"dance"):
				_crab_anim.play(&"dance")
			crab_clicked.emit(_island_crab.global_position)
			return true

	# Тап по прыгающим дельфинам в воздухе
	for d in dolphins:
		if d.active and camera.is_position_in_frustum(d.node.global_position):
			var d_screen := camera.unproject_position(d.node.global_position)
			if screen_pt.distance_to(d_screen) <= 85.0:
				d.spin = 1.0
				dolphin_clicked.emit(d.node.global_position)
				return true

	return false


func _play_glb_anim(node: Node3D, preferred_names: Array[StringName]) -> AnimationPlayer:
	if node == null:
		return null
	for child in node.find_children("*", "AnimationPlayer", true, false):
		var ap: AnimationPlayer = child
		var list := ap.get_animation_list()
		for pref in preferred_names:
			for anim_name in list:
				if StringName(anim_name.to_lower()) == pref or anim_name.to_lower().contains(String(pref).to_lower()):
					var anim := ap.get_animation(anim_name)
					if anim:
						anim.loop_mode = Animation.LOOP_LINEAR
					ap.play(anim_name)
					return ap
		if list.size() > 0:
			var first_anim := ap.get_animation(list[0])
			if first_anim:
				first_anim.loop_mode = Animation.LOOP_LINEAR
			ap.play(list[0])
			return ap
	return null


func _instantiate_model(res_path: String, parent: Node3D, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, sc := Vector3.ONE, apply_kenney_tex: bool = false) -> Node3D:
	if not ResourceLoader.exists(res_path):
		return null
	var packed = load(res_path)
	if packed is PackedScene:
		var inst: Node3D = packed.instantiate()
		inst.position = pos
		inst.rotation_degrees = rot_deg
		inst.scale = sc
		for cam in inst.find_children("*", "Camera3D", true, false):
			cam.queue_free()
		for lgt in inst.find_children("*", "Light3D", true, false):
			lgt.queue_free()
		if apply_kenney_tex and _kenney_colormap != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = _kenney_colormap
			mat.roughness = 0.45
			for child in inst.find_children("*", "MeshInstance3D", true, false):
				var mi: MeshInstance3D = child
				mi.material_override = mat
		parent.add_child(inst)
		return inst
	return null

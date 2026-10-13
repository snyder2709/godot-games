class_name DadActor
extends Node3D

enum State { WAITING, DIVING, UNDERWATER, EMERGING }

signal dad_clicked()
signal dad_splashed()
signal dad_dived()
signal dad_emerged(hat_idx: int)
signal bubble_tick(pos: Vector3)

const SEA_MIN_X := -16.5
const SEA_MAX_X := 16.5
const SEA_MIN_Z := -13.5
const SEA_MAX_Z := 6.5

var dad_state: int = State.WAITING
var dad_pos := Vector3(0.0, 0.0, -2.0)
var dad_next_pos := Vector3(0.0, 0.0, -2.0)
var dad_timer: float = 0.0
var dad_hat_idx: int = 0
var bubble_trail_pos := Vector3.ZERO
var _glug_cooldown: float = 0.0

var _dad_visual: Node3D
var _dad_left_arm: Node3D
var _dad_right_arm: Node3D
var _dad_hats: Array[Node3D] = []
var _kenney_colormap: Texture2D


func init_actor(colormap: Texture2D) -> void:
	_kenney_colormap = colormap
	position = dad_pos
	_build_visuals()


func is_waiting() -> bool:
	return dad_state == State.WAITING


func get_state() -> int:
	return dad_state


func get_pos() -> Vector3:
	return dad_pos


func splash_dad() -> void:
	if dad_state != State.WAITING:
		return
	dad_state = State.DIVING
	dad_timer = 0.40
	dad_splashed.emit()


func check_touch(camera: Camera3D, screen_pt: Vector2) -> bool:
	if dad_state == State.WAITING and camera.is_position_in_frustum(global_position):
		var dad_screen := camera.unproject_position(global_position + Vector3(0, 0.6, 0))
		if screen_pt.distance_to(dad_screen) <= 105.0:
			dad_clicked.emit()
			return true
	return false


func update_actor(delta: float, world_time: float, water_surface: WaterSurface, camera_pos: Vector3, girl_pos: Vector3) -> void:
	if _dad_left_arm != null and _dad_right_arm != null:
		_dad_left_arm.rotation.z = sin(world_time * 6.2) * 0.45 - 0.25
		_dad_right_arm.rotation.z = -sin(world_time * 6.2) * 0.45 + 0.25

	var dad_wave_y: float = water_surface.get_wave_height(dad_pos.x, dad_pos.z, world_time) if water_surface else 0.0

	match dad_state:
		State.WAITING:
			visible = true
			position = Vector3(dad_pos.x, dad_wave_y, dad_pos.z)
			_dad_visual.scale = _dad_visual.scale.lerp(Vector3.ONE, delta * 8.0)
			var look_to_cam := (camera_pos - dad_pos).normalized()
			_dad_visual.rotation.y = lerp_angle(_dad_visual.rotation.y, atan2(look_to_cam.x, look_to_cam.z), delta * 6.0)

		State.DIVING:
			dad_timer -= delta
			var t := clampf(dad_timer / 0.40, 0.0, 1.0)
			position = Vector3(dad_pos.x, dad_wave_y + (1.0 - t) * -2.4, dad_pos.z)
			_dad_visual.scale = Vector3.ONE * t
			_dad_visual.rotation.y += delta * 12.0
			if dad_timer <= 0.0:
				visible = false
				dad_state = State.UNDERWATER
				dad_timer = 1.55
				bubble_trail_pos = dad_pos
				dad_dived.emit()

				var found := false
				for attempt in range(40):
					var cand := Vector3(
						randf_range(SEA_MIN_X + 2.5, SEA_MAX_X - 2.5),
						0.0,
						randf_range(SEA_MIN_Z + 2.5, SEA_MAX_Z - 1.5)
					)
					var d_girl := cand.distance_to(girl_pos)
					if d_girl >= 5.0 and d_girl <= 14.5 and water_surface.is_valid_spawn(dad_pos, cand, 2.1):
						dad_next_pos = cand
						found = true
						break
				if not found:
					dad_next_pos = water_surface.push_out_of_islands(Vector3(0.0, 0.0, 0.0), 2.2)

		State.UNDERWATER:
			dad_timer -= delta
			var progress := 1.0 - clampf(dad_timer / 1.55, 0.0, 1.0)
			bubble_trail_pos = water_surface.push_out_of_islands(dad_pos.lerp(dad_next_pos, progress), 1.4)

			_glug_cooldown -= delta
			if _glug_cooldown <= 0.0:
				_glug_cooldown = 0.15
				bubble_tick.emit(bubble_trail_pos)

			if dad_timer <= 0.0:
				dad_pos = water_surface.push_out_of_islands(dad_next_pos, 2.0)
				dad_state = State.EMERGING
				dad_timer = 0.40
				visible = true

				dad_hat_idx = (dad_hat_idx + 1) % (_dad_hats.size() + 1)
				for i in range(_dad_hats.size()):
					_dad_hats[i].visible = (i + 1 == dad_hat_idx)

				dad_emerged.emit(dad_hat_idx)

		State.EMERGING:
			dad_timer -= delta
			var t := 1.0 - clampf(dad_timer / 0.40, 0.0, 1.0)
			position = Vector3(dad_pos.x, dad_wave_y + sin(t * PI) * 0.85, dad_pos.z)
			_dad_visual.scale = Vector3.ONE * clampf(t * 1.2, 0.1, 1.12)
			if dad_timer <= 0.0:
				_dad_visual.scale = Vector3.ONE
				dad_state = State.WAITING


func _build_visuals() -> void:
	_dad_visual = Node3D.new()
	add_child(_dad_visual)

	var skin_mat := _make_toon_mat(Color("#FFD3B6"), 0.38)
	var hair_mat := _make_toon_mat(Color("#4E342E"), 0.48)
	var vest_mat := _make_toon_mat(Color("#00CEC9"), 0.35)

	# Пенный круг вокруг Папы в воде
	var foam_ring := TorusMesh.new()
	foam_ring.inner_radius = 0.65
	foam_ring.outer_radius = 0.95
	_add_mesh(_dad_visual, foam_ring, _make_unshaded_mat(Color(1, 1, 1, 0.55)), Vector3(0.0, 0.05, 0.0))

	# Торс и плечи в купальной майке
	var shoulders := CapsuleMesh.new()
	shoulders.radius = 0.45
	shoulders.height = 1.35
	_add_mesh(_dad_visual, shoulders, skin_mat, Vector3(0.0, 0.28, 0.0), Vector3(0, 0, 90))
	_add_mesh(_dad_visual, shoulders, vest_mat, Vector3(0.0, -0.06, 0.0), Vector3(0, 0, 90))

	# Руки папы, радостно машущие из воды
	_dad_left_arm = Node3D.new()
	_dad_left_arm.position = Vector3(-0.60, 0.42, 0.0)
	_dad_visual.add_child(_dad_left_arm)

	_dad_right_arm = Node3D.new()
	_dad_right_arm.position = Vector3(0.60, 0.42, 0.0)
	_dad_visual.add_child(_dad_right_arm)

	var arm_caps := CapsuleMesh.new()
	arm_caps.radius = 0.14
	arm_caps.height = 0.80
	var palm_sph := SphereMesh.new()
	palm_sph.radius = 0.16
	palm_sph.height = 0.32

	_add_mesh(_dad_left_arm, arm_caps, skin_mat, Vector3(-0.25, 0.32, 0.0), Vector3(0, 0, 32))
	_add_mesh(_dad_left_arm, palm_sph, skin_mat, Vector3(-0.44, 0.62, 0.0))

	_add_mesh(_dad_right_arm, arm_caps, skin_mat, Vector3(0.25, 0.32, 0.0), Vector3(0, 0, -32))
	_add_mesh(_dad_right_arm, palm_sph, skin_mat, Vector3(0.44, 0.62, 0.0))

	# Голова папы
	var head := Node3D.new()
	head.position = Vector3(0.0, 1.05, 0.0)
	_dad_visual.add_child(head)

	var head_sph := SphereMesh.new()
	head_sph.radius = 0.48
	head_sph.height = 0.96
	head_sph.radial_segments = 28
	head_sph.rings = 14
	_add_mesh(head, head_sph, skin_mat)

	var ear_sph := SphereMesh.new()
	ear_sph.radius = 0.12
	ear_sph.height = 0.24
	_add_mesh(head, ear_sph, skin_mat, Vector3(-0.46, 0.0, 0.0))
	_add_mesh(head, ear_sph, skin_mat, Vector3(0.46, 0.0, 0.0))

	var hair_top := SphereMesh.new()
	hair_top.radius = 0.49
	hair_top.height = 0.80
	_add_mesh(head, hair_top, hair_mat, Vector3(0.0, 0.16, -0.06))

	# Мультяшная борода папы
	var beard_main := SphereMesh.new()
	beard_main.radius = 0.44
	beard_main.height = 0.65
	_add_mesh(head, beard_main, hair_mat, Vector3(0.0, -0.20, 0.12), Vector3.ZERO, Vector3(1.06, 0.96, 1.04))

	var mustache := CapsuleMesh.new()
	mustache.radius = 0.08
	mustache.height = 0.48
	_add_mesh(head, mustache, hair_mat, Vector3(0.0, -0.08, 0.44), Vector3(0, 0, 90))

	var white_eye := SphereMesh.new()
	white_eye.radius = 0.10
	white_eye.height = 0.20
	var pupil := SphereMesh.new()
	pupil.radius = 0.055
	pupil.height = 0.11
	var white_mat := _make_toon_mat(Color.WHITE, 0.15)
	var dark_mat := _make_toon_mat(Color("#2D3436"), 0.15)

	for side in [-1.0, 1.0]:
		_add_mesh(head, white_eye, white_mat, Vector3(side * 0.18, 0.08, 0.40))
		_add_mesh(head, pupil, dark_mat, Vector3(side * 0.18, 0.08, 0.47))

	var nose := SphereMesh.new()
	nose.radius = 0.09
	nose.height = 0.18
	_add_mesh(head, nose, _make_toon_mat(Color("#FFBEA3"), 0.4), Vector3(0.0, -0.01, 0.49))

	var mouth := SphereMesh.new()
	mouth.radius = 0.14
	mouth.height = 0.18
	_add_mesh(head, mouth, _make_toon_mat(Color("#FF5252"), 0.28), Vector3(0.0, -0.19, 0.44), Vector3.ZERO, Vector3(1.15, 0.85, 0.75))

	# Очки для плавания на лбу
	var goggle_ring := TorusMesh.new()
	goggle_ring.inner_radius = 0.08
	goggle_ring.outer_radius = 0.14
	var goggle_mat := _make_toon_mat(Color("#FF9F43"), 0.2)
	_add_mesh(head, goggle_ring, goggle_mat, Vector3(-0.18, 0.28, 0.38), Vector3(75, 0, 0))
	_add_mesh(head, goggle_ring, goggle_mat, Vector3(0.18, 0.28, 0.38), Vector3(75, 0, 0))

	# Сюрпризы на голове
	var hats_root := Node3D.new()
	hats_root.position = Vector3(0.0, 0.52, 0.0)
	head.add_child(hats_root)

	# 1. Резиновая уточка
	var hat_duck := Node3D.new()
	hat_duck.visible = false
	hats_root.add_child(hat_duck)
	_instantiate_model("res://assets/models/duck.glb", hat_duck, Vector3(0.0, -0.04, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.32)
	_dad_hats.append(hat_duck)

	# 2. Сундучок
	var hat_chest := Node3D.new()
	hat_chest.visible = false
	hats_root.add_child(hat_chest)
	_instantiate_model("res://assets/models/chest.glb", hat_chest, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, Vector3.ONE * 0.28, true)
	_dad_hats.append(hat_chest)

	# 3. Крабик
	var hat_crab := Node3D.new()
	hat_crab.visible = false
	hats_root.add_child(hat_crab)
	var cr_inst := _instantiate_model("res://assets/models/animal-crab.glb", hat_crab, Vector3(0.0, 0.04, 0.0), Vector3.ZERO, Vector3.ONE * 0.24, true)
	_play_glb_anim(cr_inst, ["dance", "idle"])
	_dad_hats.append(hat_crab)

	# 4. Рыбка
	var hat_fish := Node3D.new()
	hat_fish.visible = false
	hats_root.add_child(hat_fish)
	var fi_inst := _instantiate_model("res://assets/models/animal-fish.glb", hat_fish, Vector3(0.0, 0.04, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.22, true)
	_play_glb_anim(fi_inst, ["dance", "idle"])
	_dad_hats.append(hat_fish)

	# 5. Буёк
	var hat_buoy := Node3D.new()
	hat_buoy.visible = false
	hats_root.add_child(hat_buoy)
	_instantiate_model("res://assets/models/buoy.glb", hat_buoy, Vector3(0.0, -0.06, 0.0), Vector3.ZERO, Vector3.ONE * 0.22, true)
	_dad_hats.append(hat_buoy)


func _make_toon_mat(col: Color, rough: float = 0.35) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.rim_enabled = true
	mat.rim = 0.35
	mat.rim_tint = 0.25
	return mat


func _make_unshaded_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = sc
	parent.add_child(mi)
	return mi


func _play_glb_anim(node: Node3D, preferred_names: Array[String]) -> AnimationPlayer:
	if node == null:
		return null
	for child in node.find_children("*", "AnimationPlayer", true, false):
		var ap: AnimationPlayer = child
		var list := ap.get_animation_list()
		for pref in preferred_names:
			for anim_name in list:
				if anim_name.to_lower().contains(pref.to_lower()):
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

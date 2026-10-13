class_name GirlController
extends Node3D

signal girl_clicked()
signal water_sprayed(nozzle_pos: Vector3, forward_dir: Vector3)
signal water_hit_dad()
signal foam_spawned(pos: Vector3)

const SEA_MIN_X := -16.5
const SEA_MAX_X := 16.5
const SEA_MIN_Z := -13.5
const SEA_MAX_Z := 6.5

var girl_pos := Vector3(0.0, 0.0, 3.2)
var girl_target := Vector3(0.0, 0.0, 3.2)
var girl_vel := Vector3.ZERO
var girl_yaw: float = PI
var wheel_angle: float = 0.0
var wheel_spin_boost: float = 0.0
var girl_bounce: float = 0.0
var swim_to_dad: bool = false
var _foam_cooldown: float = 0.0

class WaterJetData extends RefCounted:
	var node: MeshInstance3D
	var vel: Vector3 = Vector3.ZERO
	var life: float = 0.0

var _jet_pool: Array[MeshInstance3D] = []
var _active_jets: Array[WaterJetData] = []
var _sphere_mesh_small: SphereMesh

var _girl_visual: Node3D
var _wheel_pivot: Node3D
var _girl_head: Node3D
var _girl_left_arm: Node3D
var _girl_right_arm: Node3D


func init_controller() -> void:
	position = girl_pos
	_sphere_mesh_small = SphereMesh.new()
	_sphere_mesh_small.radius = 0.13
	_sphere_mesh_small.height = 0.26
	_sphere_mesh_small.radial_segments = 12
	_sphere_mesh_small.rings = 6

	var jet_mat := _make_unshaded_mat(Color("#48DBFB"))
	for i in range(16):
		var mi := MeshInstance3D.new()
		mi.mesh = _sphere_mesh_small
		mi.material_override = jet_mat
		mi.visible = false
		add_child(mi)
		_jet_pool.append(mi)

	_build_visuals()


func navigate_to(target: Vector3, is_dad: bool = false) -> void:
	girl_target = target
	swim_to_dad = is_dad


func stop_navigation() -> void:
	girl_target = girl_pos
	swim_to_dad = false
	girl_vel = Vector3.ZERO


func bounce_back(new_pos: Vector3, new_vel: Vector3) -> void:
	girl_pos = new_pos
	girl_vel = new_vel
	girl_target = new_pos + new_vel.normalized() * 0.85
	swim_to_dad = false
	girl_bounce = 1.0


func fire_water_jet() -> void:
	wheel_spin_boost = 1.0
	girl_bounce = 0.85

	var forward := Vector3(sin(girl_yaw), 0.0, cos(girl_yaw))
	var nozzle_pos := girl_pos + forward * 0.95 + Vector3(0.0, 0.38, 0.0)

	for i in range(8):
		var spread := Vector3(randf_range(-0.15, 0.15), randf_range(-0.08, 0.12), randf_range(-0.15, 0.15))
		var v := (forward + spread).normalized() * randf_range(6.5, 9.2)
		v.y += randf_range(2.8, 4.4)

		var mi: MeshInstance3D = null
		for item in _jet_pool:
			if not item.visible:
				mi = item
				break

		if mi == null and _active_jets.size() > 0:
			var oldest: WaterJetData = _active_jets[0]
			mi = oldest.node
			_active_jets.remove_at(0)

		if mi != null:
			mi.position = nozzle_pos
			mi.scale = Vector3.ONE * randf_range(0.8, 1.3)
			mi.visible = true

			var data := WaterJetData.new()
			data.node = mi
			data.vel = v
			data.life = 0.95
			_active_jets.append(data)

	water_sprayed.emit(nozzle_pos, forward)


func check_touch(camera: Camera3D, screen_pt: Vector2) -> bool:
	if camera.is_position_in_frustum(global_position):
		var girl_screen := camera.unproject_position(global_position + Vector3(0, 0.5, 0))
		if screen_pt.distance_to(girl_screen) <= 85.0:
			girl_bounce = 0.85
			wheel_spin_boost = 1.0
			fire_water_jet()
			girl_clicked.emit()
			return true
	return false


func update_controller(delta: float, world_time: float, water_surface: WaterSurface, dad_pos: Vector3, is_dad_waiting: bool, beach_ball: BeachBall = null, buoy_manager: BuoyManager = null) -> void:

	if wheel_spin_boost > 0.0:
		wheel_spin_boost = maxf(0.0, wheel_spin_boost - delta * 2.2)
		wheel_angle += delta * 15.0 * wheel_spin_boost

	if girl_bounce > 0.0:
		girl_bounce = maxf(0.0, girl_bounce - delta * 3.0)

	if swim_to_dad and is_dad_waiting:
		girl_target = dad_pos

	var to_target := girl_target - girl_pos
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > 0.15:
		var dir := to_target / dist
		if water_surface != null:
			for isl in water_surface.islands:
				var ipos := isl.pos
				var safe_r := isl.radius + 1.60
				var to_isl := ipos - girl_pos
				to_isl.y = 0.0
				var d_isl := to_isl.length()
				if d_isl < safe_r + 1.4 and d_isl > 0.01:
					var n_isl := to_isl / d_isl
					var into := dir.dot(n_isl)
					if into > 0.0:
						var tang1 := Vector3(-n_isl.z, 0.0, n_isl.x)
						var tang2 := Vector3(n_isl.z, 0.0, -n_isl.x)
						var best_tang := tang1 if tang1.dot(dir) >= tang2.dot(dir) else tang2
						dir = (dir - n_isl * into + best_tang * 0.65).normalized()

		if buoy_manager != null:
			for b in buoy_manager.buoys:
				var bpos := b.pos
				var safe_r := b.radius + 0.85
				var to_b := bpos - girl_pos
				to_b.y = 0.0
				var d_b := to_b.length()
				if d_b < safe_r + 1.2 and d_b > 0.01:
					var n_b := to_b / d_b
					var into_b := dir.dot(n_b)
					if into_b > 0.0:
						var tang1 := Vector3(-n_b.z, 0.0, n_b.x)
						var tang2 := Vector3(n_b.z, 0.0, -n_b.x)
						var best_tang := tang1 if tang1.dot(dir) >= tang2.dot(dir) else tang2
						dir = (dir - n_b * into_b + best_tang * 0.70).normalized()

		var target_yaw := atan2(dir.x, dir.z)
		var yaw_diff := wrapf(target_yaw - girl_yaw, -PI, PI)
		girl_yaw = lerp_angle(girl_yaw, target_yaw, delta * 6.5)

		var max_spd := 7.6 if swim_to_dad else 6.2
		var speed := clampf(dist * 2.8, 2.6, max_spd)
		girl_vel = girl_vel.lerp(dir * speed, delta * 6.0)

		if _wheel_pivot != null:
			_wheel_pivot.rotation.y = clampf(yaw_diff * 1.6, -1.2, 1.2) + wheel_angle

		_foam_cooldown -= delta
		if _foam_cooldown <= 0.0:
			_foam_cooldown = 0.16
			foam_spawned.emit(girl_pos - dir * 0.95 + Vector3(randf_range(-0.25, 0.25), 0.08, randf_range(-0.25, 0.25)))
	else:
		girl_vel = girl_vel.lerp(Vector3.ZERO, delta * 5.0)
		if _wheel_pivot != null:
			_wheel_pivot.rotation.y = wheel_angle

	# Применяем физическую скорость к позиции девочки в любом состоянии
	girl_pos += girl_vel * delta
	girl_pos.x = clampf(girl_pos.x, SEA_MIN_X, SEA_MAX_X)
	girl_pos.z = clampf(girl_pos.z, SEA_MIN_Z, SEA_MAX_Z)

	# Коллизия с островами
	if water_surface != null:
		var prev_pos := girl_pos
		girl_pos = water_surface.push_out_of_islands(girl_pos, 1.45)
		if girl_pos.distance_to(prev_pos) > 0.0005:
			for isl in water_surface.islands:
				var ipos := isl.pos
				var away := girl_pos - ipos
				away.y = 0.0
				if away.length() <= isl.radius + 1.50 and away.length() > 0.001:
					var n_out := away.normalized()
					var vn := girl_vel.dot(n_out)
					if vn < 0.0:
						girl_vel -= n_out * vn
			if girl_pos.distance_to(girl_target) < 0.65:
				girl_vel = Vector3.ZERO
				girl_target = girl_pos

	var girl_wave_y: float = water_surface.get_wave_height(girl_pos.x, girl_pos.z, world_time) if water_surface else 0.0
	position = Vector3(
		girl_pos.x,
		girl_wave_y + girl_bounce * 0.42,
		girl_pos.z
	)
	if _girl_visual != null:
		_girl_visual.rotation.y = girl_yaw
		_girl_visual.rotation.z = sin(world_time * 3.0) * 0.07
		_girl_visual.rotation.x = cos(world_time * 2.6) * 0.06

	_update_water_jets(delta, dad_pos, is_dad_waiting, beach_ball)


func _update_water_jets(delta: float, dad_pos: Vector3, is_dad_waiting: bool, beach_ball: BeachBall = null) -> void:
	for i in range(_active_jets.size() - 1, -1, -1):
		var jet: WaterJetData = _active_jets[i]
		jet.life -= delta
		var pnode: MeshInstance3D = jet.node
		if jet.life <= 0.0:
			pnode.visible = false
			_active_jets.remove_at(i)
		else:
			jet.vel.y -= 11.0 * delta
			pnode.position += jet.vel * delta
			if is_dad_waiting and pnode.position.distance_to(dad_pos) <= 2.2:
				pnode.visible = false
				_active_jets.remove_at(i)
				water_hit_dad.emit()
				break
			if beach_ball != null and beach_ball.check_water_jet_hit(pnode.position, jet.vel):
				pnode.visible = false
				_active_jets.remove_at(i)
				break




func _build_visuals() -> void:
	_girl_visual = Node3D.new()
	_girl_visual.rotation.y = girl_yaw
	add_child(_girl_visual)

	# 1. ГЛЯНЦЕВЫЙ ЖЁЛТЫЙ СПАСАТЕЛЬНЫЙ КРУГ
	var ring_torus := TorusMesh.new()
	ring_torus.inner_radius = 0.42
	ring_torus.outer_radius = 0.88
	ring_torus.rings = 48
	ring_torus.ring_segments = 28
	var yellow_mat := _make_toon_mat(Color("#FFD32A"), 0.12)
	_add_mesh(_girl_visual, ring_torus, yellow_mat, Vector3(0.0, 0.14, 0.0))

	# Оранжевые ручки
	var handle_torus := TorusMesh.new()
	handle_torus.inner_radius = 0.07
	handle_torus.outer_radius = 0.16
	var orange_mat := _make_toon_mat(Color("#FF9F43"), 0.25)
	_add_mesh(_girl_visual, handle_torus, orange_mat, Vector3(-0.64, 0.36, -0.08), Vector3(0, 0, 25))
	_add_mesh(_girl_visual, handle_torus, orange_mat, Vector3(0.64, 0.36, -0.08), Vector3(0, 0, -25))

	# 2. РУЛЬ С КНОПКОЙ И СОПЛОМ
	var col_mount := Node3D.new()
	col_mount.position = Vector3(0.0, 0.36, 0.58)
	col_mount.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
	_girl_visual.add_child(col_mount)

	var dashboard := SphereMesh.new()
	dashboard.radius = 0.18
	dashboard.height = 0.24
	_add_mesh(col_mount, dashboard, orange_mat, Vector3.ZERO)

	var stem := CylinderMesh.new()
	stem.top_radius = 0.06
	stem.bottom_radius = 0.08
	stem.height = 0.32
	_add_mesh(col_mount, stem, _make_toon_mat(Color("#0984E3"), 0.2), Vector3(0.0, 0.16, 0.0))

	_wheel_pivot = Node3D.new()
	_wheel_pivot.position = Vector3(0.0, 0.32, 0.0)
	col_mount.add_child(_wheel_pivot)

	var wheel_torus := TorusMesh.new()
	wheel_torus.inner_radius = 0.22
	wheel_torus.outer_radius = 0.32
	wheel_torus.rings = 36
	wheel_torus.ring_segments = 20
	_add_mesh(_wheel_pivot, wheel_torus, _make_toon_mat(Color("#0984E3"), 0.15), Vector3.ZERO)

	var spoke := CapsuleMesh.new()
	spoke.radius = 0.035
	spoke.height = 0.52
	var light_blue := _make_toon_mat(Color("#48DBFB"), 0.2)
	_add_mesh(_wheel_pivot, spoke, light_blue, Vector3.ZERO, Vector3(0, 0, 90))
	_add_mesh(_wheel_pivot, spoke, light_blue, Vector3.ZERO, Vector3(90, 0, 0))

	# Кнопка
	var horn_btn := SphereMesh.new()
	horn_btn.radius = 0.11
	horn_btn.height = 0.18
	_add_mesh(_wheel_pivot, horn_btn, _make_toon_mat(Color("#FF3F34"), 0.15), Vector3(0.0, 0.04, 0.0))

	# Сопло
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = 0.04
	nozzle.bottom_radius = 0.06
	nozzle.height = 0.16
	_add_mesh(_girl_visual, nozzle, _make_toon_mat(Color("#00CEC9"), 0.2), Vector3(0.0, 0.25, 0.88), Vector3(90.0, 0.0, 0.0))

	# 3. МИЛАЯ СВЕТЛОВОЛОСАЯ ДЕВОЧКА
	var skin_mat := _make_toon_mat(Color("#FFE0CC"), 0.36)
	var suit_mat := _make_toon_mat(Color("#FF6B81"), 0.32)
	var hair_mat := _make_toon_mat(Color("#FDE073"), 0.32)
	var brow_mat := _make_toon_mat(Color("#D4A038"), 0.38)
	var hat_mat := _make_toon_mat(Color("#FFFDF2"), 0.45)

	var torso := CapsuleMesh.new()
	torso.radius = 0.30
	torso.height = 0.72
	_add_mesh(_girl_visual, torso, suit_mat, Vector3(0.0, 0.36, -0.04))

	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.09
	arm_mesh.height = 0.50
	_girl_left_arm = _add_mesh(_girl_visual, arm_mesh, skin_mat, Vector3(-0.25, 0.48, 0.24), Vector3(68.0, -20.0, 0.0))
	_girl_right_arm = _add_mesh(_girl_visual, arm_mesh, skin_mat, Vector3(0.25, 0.48, 0.24), Vector3(68.0, 20.0, 0.0))

	var hand_sph := SphereMesh.new()
	hand_sph.radius = 0.10
	hand_sph.height = 0.20
	_add_mesh(_girl_visual, hand_sph, skin_mat, Vector3(-0.22, 0.55, 0.44))
	_add_mesh(_girl_visual, hand_sph, skin_mat, Vector3(0.22, 0.55, 0.44))

	_girl_head = Node3D.new()
	_girl_head.position = Vector3(0.0, 0.92, -0.04)
	_girl_visual.add_child(_girl_head)

	var head_sph := SphereMesh.new()
	head_sph.radius = 0.38
	head_sph.height = 0.76
	head_sph.radial_segments = 28
	head_sph.rings = 14
	_add_mesh(_girl_head, head_sph, skin_mat)

	var ear_sph := SphereMesh.new()
	ear_sph.radius = 0.08
	ear_sph.height = 0.16
	_add_mesh(_girl_head, ear_sph, skin_mat, Vector3(-0.36, -0.02, 0.02))
	_add_mesh(_girl_head, ear_sph, skin_mat, Vector3(0.36, -0.02, 0.02))

	# Личико
	var white_mat := _make_toon_mat(Color.WHITE, 0.12)
	var iris_mat := _make_toon_mat(Color("#0984E3"), 0.15)
	var pupil_mat := _make_toon_mat(Color("#1E272E"), 0.10)
	var spark_mat := _make_unshaded_mat(Color.WHITE)
	var cheek_mat := _make_toon_mat(Color("#FF8FA3"), 0.35)
	var nose_mat := _make_toon_mat(Color("#FFCCB3"), 0.35)
	var mouth_mat := _make_toon_mat(Color("#D63031"), 0.28)
	var tongue_mat := _make_toon_mat(Color("#FF7675"), 0.30)

	var sclera_mesh := SphereMesh.new()
	sclera_mesh.radius = 0.088
	sclera_mesh.height = 0.176
	var iris_mesh := SphereMesh.new()
	iris_mesh.radius = 0.062
	iris_mesh.height = 0.124
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.040
	pupil_mesh.height = 0.080
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.020
	spark_mesh.height = 0.040
	var brow_mesh := CapsuleMesh.new()
	brow_mesh.radius = 0.018
	brow_mesh.height = 0.12
	var cheek_mesh := SphereMesh.new()
	cheek_mesh.radius = 0.075
	cheek_mesh.height = 0.12

	for side in [-1.0, 1.0]:
		_add_mesh(_girl_head, sclera_mesh, white_mat, Vector3(side * 0.138, 0.03, 0.315), Vector3.ZERO, Vector3(1.0, 1.08, 0.65))
		_add_mesh(_girl_head, iris_mesh, iris_mat, Vector3(side * 0.138, 0.03, 0.352), Vector3.ZERO, Vector3(1.0, 1.05, 0.65))
		_add_mesh(_girl_head, pupil_mesh, pupil_mat, Vector3(side * 0.138, 0.03, 0.372), Vector3.ZERO, Vector3(1.0, 1.05, 0.65))
		_add_mesh(_girl_head, spark_mesh, spark_mat, Vector3(side * 0.118, 0.064, 0.392))
		_add_mesh(_girl_head, brow_mesh, brow_mat, Vector3(side * 0.138, 0.140, 0.340), Vector3(0.0, 0.0, 90.0 - side * 12.0))
		_add_mesh(_girl_head, cheek_mesh, cheek_mat, Vector3(side * 0.228, -0.055, 0.300), Vector3.ZERO, Vector3(1.15, 0.85, 0.65))

	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.055
	nose_mesh.height = 0.11
	_add_mesh(_girl_head, nose_mesh, nose_mat, Vector3(0.0, -0.030, 0.378))

	var smile_mesh := SphereMesh.new()
	smile_mesh.radius = 0.095
	smile_mesh.height = 0.13
	_add_mesh(_girl_head, smile_mesh, mouth_mat, Vector3(0.0, -0.14, 0.345), Vector3.ZERO, Vector3(1.25, 0.82, 0.55))

	var tongue_mesh := SphereMesh.new()
	tongue_mesh.radius = 0.052
	tongue_mesh.height = 0.07
	_add_mesh(_girl_head, tongue_mesh, tongue_mat, Vector3(0.0, -0.165, 0.365), Vector3.ZERO, Vector3(1.15, 0.65, 0.60))

	# Золотистые волосы
	var hair_cap := SphereMesh.new()
	hair_cap.radius = 0.395
	hair_cap.height = 0.75
	_add_mesh(_girl_head, hair_cap, hair_mat, Vector3(0.0, 0.06, -0.05))

	var bang_center := CapsuleMesh.new()
	bang_center.radius = 0.085
	bang_center.height = 0.30
	_add_mesh(_girl_head, bang_center, hair_mat, Vector3(0.0, 0.20, 0.30), Vector3(12.0, 0.0, 90.0))

	for side in [-1.0, 1.0]:
		var pt_pivot := Node3D.new()
		pt_pivot.position = Vector3(side * 0.38, 0.05, -0.12)
		_girl_head.add_child(pt_pivot)

		var bow_sph := SphereMesh.new()
		bow_sph.radius = 0.11
		bow_sph.height = 0.19
		_add_mesh(pt_pivot, bow_sph, suit_mat, Vector3(0.0, 0.05, 0.0))

		var tail_caps := CapsuleMesh.new()
		tail_caps.radius = 0.15
		tail_caps.height = 0.45
		_add_mesh(pt_pivot, tail_caps, hair_mat, Vector3(side * 0.13, -0.06, -0.05), Vector3(18.0, 0.0, -side * 40.0))

	# Панамка
	var brim := CylinderMesh.new()
	brim.top_radius = 0.52
	brim.bottom_radius = 0.58
	brim.height = 0.06
	brim.radial_segments = 28
	_add_mesh(_girl_head, brim, hat_mat, Vector3(0.0, 0.30, -0.04), Vector3(-18.0, 0.0, 0.0))

	var crown_hat := SphereMesh.new()
	crown_hat.radius = 0.36
	crown_hat.height = 0.44
	_add_mesh(_girl_head, crown_hat, hat_mat, Vector3(0.0, 0.36, -0.06), Vector3(-18.0, 0.0, 0.0))


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

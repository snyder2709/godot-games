class_name BeachBall
extends Node3D

signal ball_kicked(pos: Vector3)
signal ball_splashed(pos: Vector3)
signal ball_bumped(pos: Vector3)
signal dad_passed_ball(pos: Vector3)

const BALL_RADIUS := 0.52
const SEA_MIN_X := -12.5
const SEA_MAX_X := 15.0
const SEA_MIN_Z := -12.0
const SEA_MAX_Z := 5.5

var ball_pos := Vector3(1.8, 0.2, -1.2)
var ball_vel := Vector3.ZERO
var ball_rot_vel := Vector3.ZERO

var _ball_visual: Node3D
var _squash_tween: Tween
var _was_airborne := false


func init_ball() -> void:
	_build_visuals()
	position = ball_pos


func _build_visuals() -> void:
	_ball_visual = Node3D.new()
	add_child(_ball_visual)

	# 1. Белая основа мяча
	var base_sphere := SphereMesh.new()
	base_sphere.radius = BALL_RADIUS
	base_sphere.height = BALL_RADIUS * 2.0
	base_sphere.radial_segments = 24
	base_sphere.rings = 14
	var white_mat := _make_mat(Color("#FFFFFF"))
	_add_mesh(_ball_visual, base_sphere, white_mat, Vector3.ZERO)

	# 2. Яркие цветные дольки (красный, синий, жёлтый)
	var colors := [Color("#FF4757"), Color("#1E90FF"), Color("#FFA502")]
	for i in range(3):
		var slice := SphereMesh.new()
		slice.radius = BALL_RADIUS * 1.01
		slice.height = BALL_RADIUS * 2.02
		slice.radial_segments = 16
		slice.rings = 10
		slice.is_hemisphere = false
		var slice_mat := _make_mat(colors[i])
		var node := _add_mesh(_ball_visual, slice, slice_mat, Vector3.ZERO)
		node.rotation_degrees.y = i * 120.0
		node.scale = Vector3(0.55, 1.0, 1.0)

	# 3. Белые круглые полюса (колпачки сверху и снизу)
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.16
	pole_mesh.bottom_radius = 0.16
	pole_mesh.height = 0.08
	var pole_mat := _make_mat(Color("#F1F2F6"))
	_add_mesh(_ball_visual, pole_mesh, pole_mat, Vector3(0.0, BALL_RADIUS - 0.02, 0.0))
	_add_mesh(_ball_visual, pole_mesh, pole_mat, Vector3(0.0, -BALL_RADIUS + 0.02, 0.0))


func _make_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.12
	mat.metallic = 0.04
	mat.albedo_color = col
	return mat


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func update_ball(delta: float, world_time: float, water_surface: WaterSurface, dad_pos: Vector3, is_dad_waiting: bool) -> void:
	var wave_y := water_surface.get_wave_height(ball_pos.x, ball_pos.z, world_time) if water_surface else 0.0
	var is_in_water := ball_pos.y <= wave_y + 0.08

	if is_in_water:
		# Плавание на воде: плавучесть и сопротивление
		var depth := wave_y - ball_pos.y
		ball_vel.y += depth * 32.0 * delta + 8.5 * delta
		ball_vel.y *= maxf(0.0, 1.0 - 5.5 * delta)
		ball_vel.x *= maxf(0.0, 1.0 - 2.2 * delta)
		ball_vel.z *= maxf(0.0, 1.0 - 2.2 * delta)

		if _was_airborne and ball_vel.y < -0.8:
			_apply_squash()
			ball_splashed.emit(ball_pos)
			ball_vel.y = -ball_vel.y * 0.42
		_was_airborne = false
	else:
		# Полёт в воздухе: гравитация
		ball_vel.y -= 13.5 * delta
		_was_airborne = true

	ball_pos += ball_vel * delta

	# Границы акватории
	if ball_pos.x < SEA_MIN_X:
		ball_pos.x = SEA_MIN_X
		ball_vel.x = absf(ball_vel.x) * 0.8
	elif ball_pos.x > SEA_MAX_X:
		ball_pos.x = SEA_MAX_X
		ball_vel.x = -absf(ball_vel.x) * 0.8

	if ball_pos.z < SEA_MIN_Z:
		ball_pos.z = SEA_MIN_Z
		ball_vel.z = absf(ball_vel.z) * 0.8
	elif ball_pos.z > SEA_MAX_Z:
		ball_pos.z = SEA_MAX_Z
		ball_vel.z = -absf(ball_vel.z) * 0.8

	# Отталкивание от островков
	if water_surface:
		for isl in water_surface.islands:
			var to_isl := ball_pos - isl.pos
			to_isl.y = 0.0
			var min_d := isl.radius + BALL_RADIUS + 0.15
			var d := to_isl.length()
			if d < min_d and d > 0.001:
				var n := to_isl / d
				ball_pos = isl.pos + n * min_d
				ball_vel = ball_vel.bounce(n) * 0.75

	# Интерактивный пас от Папы
	if is_dad_waiting:
		var to_dad := ball_pos - dad_pos
		to_dad.y = 0.0
		if to_dad.length() <= 1.85 and to_dad.length() > 0.001:
			var away := to_dad.normalized()
			ball_vel = away * 5.2 + Vector3(0.0, 3.8, 0.0)
			_apply_squash()
			dad_passed_ball.emit(ball_pos)

	# Вращение мяча при движении
	if _ball_visual:
		_ball_visual.rotate_x(ball_vel.z * delta * 2.8)
		_ball_visual.rotate_z(-ball_vel.x * delta * 2.8)
		_ball_visual.rotate_y(ball_rot_vel.y * delta)
		ball_rot_vel.y *= maxf(0.0, 1.0 - 1.5 * delta)

	position = ball_pos


func check_touch(camera: Camera3D, screen_pt: Vector2) -> bool:
	if not camera.is_position_in_frustum(global_position):
		return false
	var screen_pos := camera.unproject_position(global_position)
	if screen_pt.distance_to(screen_pos) <= 85.0:
		kick(Vector3(randf_range(-2.8, 2.8), 5.6, randf_range(-2.8, 2.8)))
		ball_kicked.emit(ball_pos)
		return true
	return false


func kick(impulse: Vector3) -> void:
	ball_vel = impulse
	ball_rot_vel.y = randf_range(-9.0, 9.0)
	_apply_squash()


func check_girl_collision(girl_pos: Vector3, girl_vel: Vector3) -> void:
	var to_ball := ball_pos - girl_pos
	to_ball.y = 0.0
	var dist := to_ball.length()
	var min_dist := BALL_RADIUS + 1.15
	if dist < min_dist and dist > 0.001:
		var n := to_ball / dist
		ball_pos = girl_pos + n * min_dist
		var push_speed := maxf(girl_vel.length() * 1.3, 3.6)
		ball_vel = n * push_speed + Vector3(0.0, 2.6, 0.0)
		ball_rot_vel.y = randf_range(-6.0, 6.0)
		_apply_squash()
		ball_bumped.emit(ball_pos)


func check_water_jet_hit(jet_pos: Vector3, jet_vel: Vector3) -> bool:
	if ball_pos.distance_to(jet_pos) <= BALL_RADIUS + 0.4:
		ball_vel += jet_vel * 0.35 + Vector3(0.0, 1.8, 0.0)
		ball_rot_vel.y += randf_range(-5.0, 5.0)
		_apply_squash()
		ball_bumped.emit(ball_pos)
		return true
	return false


func _apply_squash() -> void:
	if not _ball_visual:
		return
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()

	_squash_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(_ball_visual, "scale", Vector3(1.35, 0.68, 1.35), 0.08)
	_squash_tween.tween_property(_ball_visual, "scale", Vector3(0.88, 1.25, 0.88), 0.12)
	_squash_tween.tween_property(_ball_visual, "scale", Vector3.ONE, 0.22)


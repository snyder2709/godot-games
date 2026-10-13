class_name MarineTreasures
extends Node3D

signal pearl_revealed(pos: Vector3)
signal starfish_clicked(pos: Vector3)
signal lighthouse_clicked(pos: Vector3)

# 1. Ракушка с жемчужиной
var _clam_node: Node3D
var _clam_top: Node3D
var _pearl: MeshInstance3D
var _clam_open_timer: float = 0.0
var _clam_is_open := false

# 2. Морская звёздочка
var _starfish: Node3D
var _starfish_bounce: float = 0.0

# 3. Маяк и световой луч
var _lantern_beam: Node3D
var _lantern_light: OmniLight3D
var _is_night_mode := false


func init_treasures() -> void:
	_build_clam()
	_build_starfish()
	_build_lighthouse_beam()


func _build_clam() -> void:
	_clam_node = Node3D.new()
	_clam_node.position = Vector3(-10.0, 0.36, -5.4)
	add_child(_clam_node)

	var shell_mat := _make_mat(Color("#FFAAA6"), 0.25)
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.36
	shell_mesh.height = 0.18
	shell_mesh.radial_segments = 16
	shell_mesh.rings = 8

	# Нижняя створка
	var bot_shell := MeshInstance3D.new()
	bot_shell.mesh = shell_mesh
	bot_shell.material_override = shell_mat
	_clam_node.add_child(bot_shell)

	# Верхняя створка на шарнире
	_clam_top = Node3D.new()
	_clam_top.position = Vector3(0.0, 0.05, -0.28)
	_clam_node.add_child(_clam_top)

	var top_shell := MeshInstance3D.new()
	top_shell.mesh = shell_mesh
	top_shell.material_override = shell_mat
	top_shell.position = Vector3(0.0, 0.0, 0.28)
	_clam_top.add_child(top_shell)

	# Светящаяся жемчужина
	var pearl_mesh := SphereMesh.new()
	pearl_mesh.radius = 0.16
	pearl_mesh.height = 0.32
	pearl_mesh.radial_segments = 16
	pearl_mesh.rings = 10
	var pearl_mat := StandardMaterial3D.new()
	pearl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pearl_mat.albedo_color = Color("#FFF9E6")

	_pearl = MeshInstance3D.new()
	_pearl.mesh = pearl_mesh
	_pearl.material_override = pearl_mat
	_pearl.position = Vector3(0.0, 0.08, 0.0)
	_clam_node.add_child(_pearl)


func _build_starfish() -> void:
	_starfish = Node3D.new()
	_starfish.position = Vector3(10.2, 0.38, -4.8)
	add_child(_starfish)

	var star_mat := _make_mat(Color("#FF6B6B"), 0.30)
	var center_mesh := SphereMesh.new()
	center_mesh.radius = 0.18
	center_mesh.height = 0.12
	var center := MeshInstance3D.new()
	center.mesh = center_mesh
	center.material_override = star_mat
	_starfish.add_child(center)

	# 5 лучиков звёздочки
	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.07
	arm_mesh.height = 0.38
	for i in range(5):
		var arm := MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.material_override = star_mat
		var angle := i * (TAU / 5.0)
		arm.position = Vector3(sin(angle) * 0.22, 0.0, cos(angle) * 0.22)
		arm.rotation_degrees = Vector3(90.0, -rad_to_deg(angle), 0.0)
		_starfish.add_child(arm)

	# Глазки звёздочки
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color("#2D3436")
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.035
	eye_mesh.height = 0.07

	var e1 := MeshInstance3D.new()
	e1.mesh = eye_mesh
	e1.material_override = eye_mat
	e1.position = Vector3(-0.06, 0.08, 0.08)
	_starfish.add_child(e1)

	var e2 := MeshInstance3D.new()
	e2.mesh = eye_mesh
	e2.material_override = eye_mat
	e2.position = Vector3(0.06, 0.08, 0.08)
	_starfish.add_child(e2)


func _build_lighthouse_beam() -> void:
	_lantern_beam = Node3D.new()
	_lantern_beam.position = Vector3(-10.68, 2.55, -6.65)
	add_child(_lantern_beam)

	# Световой конус луча маяка
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.15
	beam_mesh.bottom_radius = 1.85
	beam_mesh.height = 8.5
	var beam_mat := StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(1.0, 0.95, 0.6, 0.22)

	var bmi := MeshInstance3D.new()
	bmi.mesh = beam_mesh
	bmi.material_override = beam_mat
	bmi.position = Vector3(0.0, 0.0, 4.25)
	bmi.rotation_degrees.x = 90.0
	_lantern_beam.add_child(bmi)


func set_night_mode(is_night: bool) -> void:
	_is_night_mode = is_night
	if _lantern_beam:
		var mi: MeshInstance3D = _lantern_beam.get_child(0) as MeshInstance3D
		if mi and mi.material_override is StandardMaterial3D:
			var mat := mi.material_override as StandardMaterial3D
			mat.albedo_color.a = 0.45 if is_night else 0.15


func update_treasures(delta: float, world_time: float) -> void:
	# 1. Вращение луча маяка
	if _lantern_beam:
		_lantern_beam.rotation.y += delta * (1.8 if _is_night_mode else 1.1)

	# 2. Анимация створки ракушки и жемчужины
	if _clam_open_timer > 0.0:
		_clam_open_timer = maxf(0.0, _clam_open_timer - delta)
		var t := 1.0 - clampf(_clam_open_timer / 1.8, 0.0, 1.0)
		var open_angle := sin(clampf(t * 1.5, 0.0, 1.0) * PI * 0.5) * -65.0
		if _clam_open_timer < 0.35:
			open_angle *= (_clam_open_timer / 0.35)
		if _clam_top:
			_clam_top.rotation_degrees.x = open_angle
		if _pearl:
			_pearl.position.y = 0.08 + sin(clampf(t * 1.5, 0.0, 1.0) * PI * 0.5) * 0.42
			_pearl.rotation.y += delta * 5.0
	else:
		_clam_is_open = false
		if _clam_top:
			_clam_top.rotation_degrees.x = 0.0
		if _pearl:
			_pearl.position.y = 0.08

	# 3. Анимация прыжка звёздочки
	if _starfish_bounce > 0.0:
		_starfish_bounce = maxf(0.0, _starfish_bounce - delta * 3.2)
		var progress := 1.0 - _starfish_bounce
		if _starfish:
			_starfish.position.y = 0.38 + sin(progress * PI) * 0.95
			_starfish.rotation.y = progress * TAU * 1.5
			var sy := 1.0 + sin(progress * PI) * 0.45
			var sxz := 1.0 - sin(progress * PI) * 0.22
			_starfish.scale = Vector3(sxz, sy, sxz)
	else:
		if _starfish:
			_starfish.position.y = 0.38
			_starfish.scale = Vector3.ONE


func check_touch(camera: Camera3D, screen_pt: Vector2) -> bool:
	# Проверка тапа по маяку
	if _lantern_beam and camera.is_position_in_frustum(_lantern_beam.global_position):
		var tower_screen := camera.unproject_position(_lantern_beam.global_position)
		if screen_pt.distance_to(tower_screen) <= 75.0:
			lighthouse_clicked.emit(_lantern_beam.global_position)
			return true

	# Проверка тапа по ракушке
	if _clam_node and camera.is_position_in_frustum(_clam_node.global_position):
		var clam_screen := camera.unproject_position(_clam_node.global_position + Vector3(0.0, 0.2, 0.0))
		if screen_pt.distance_to(clam_screen) <= 70.0:
			_clam_open_timer = 1.8
			_clam_is_open = true
			pearl_revealed.emit(_clam_node.global_position + Vector3(0.0, 0.3, 0.0))
			return true

	# Проверка тапа по морской звёздочке
	if _starfish and camera.is_position_in_frustum(_starfish.global_position):
		var star_screen := camera.unproject_position(_starfish.global_position + Vector3(0.0, 0.2, 0.0))
		if screen_pt.distance_to(star_screen) <= 70.0:
			_starfish_bounce = 1.0
			starfish_clicked.emit(_starfish.global_position)
			return true

	return false


func _make_mat(col: Color, roughness: float = 0.3) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = roughness
	mat.albedo_color = col
	return mat

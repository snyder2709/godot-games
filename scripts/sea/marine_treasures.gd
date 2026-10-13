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

# 3. Настоящий морской маяк с полосатой башней и световым лучом
var _lighthouse_root: Node3D
var _lantern_beam: Node3D
var _lantern_light: OmniLight3D
var _lighthouse_bounce: float = 0.0
var _is_night_mode := false


func init_treasures() -> void:
	_build_clam()
	_build_starfish()
	_build_lighthouse()


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


func _build_lighthouse() -> void:
	_lighthouse_root = Node3D.new()
	_lighthouse_root.position = Vector3(-10.68, 0.45, -6.65)
	add_child(_lighthouse_root)

	var stone_mat := _make_mat(Color("#57606F"), 0.45)
	var white_mat := _make_mat(Color("#F1F2F6"), 0.35)
	var red_mat := _make_mat(Color("#FF4757"), 0.35)
	var dark_mat := _make_mat(Color("#2F3542"), 0.40)

	# 1. Круглый каменный фундамент
	_add_cylinder(_lighthouse_root, 0.76, 0.76, 0.28, stone_mat, Vector3(0.0, 0.14, 0.0))

	# 2. Полосатый корпус башни (4 конические секции: белая, красная, белая, красная)
	_add_cylinder(_lighthouse_root, 0.58, 0.68, 0.60, white_mat, Vector3(0.0, 0.58, 0.0))
	_add_cylinder(_lighthouse_root, 0.48, 0.58, 0.60, red_mat, Vector3(0.0, 1.18, 0.0))
	_add_cylinder(_lighthouse_root, 0.38, 0.48, 0.60, white_mat, Vector3(0.0, 1.78, 0.0))
	_add_cylinder(_lighthouse_root, 0.32, 0.38, 0.42, red_mat, Vector3(0.0, 2.29, 0.0))

	# 3. Смотровая площадка (балкон и ограждение)
	_add_cylinder(_lighthouse_root, 0.52, 0.52, 0.08, dark_mat, Vector3(0.0, 2.54, 0.0))
	var rail_mesh := TorusMesh.new()
	rail_mesh.inner_radius = 0.46
	rail_mesh.outer_radius = 0.52
	var rmi := MeshInstance3D.new()
	rmi.mesh = rail_mesh
	rmi.material_override = dark_mat
	rmi.position = Vector3(0.0, 2.64, 0.0)
	_lighthouse_root.add_child(rmi)

	# 4. Фонарное помещение (стеклянная кабина)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass_mat.albedo_color = Color(1.0, 0.95, 0.7, 0.45)
	_add_cylinder(_lighthouse_root, 0.28, 0.28, 0.50, glass_mat, Vector3(0.0, 2.82, 0.0))

	# Внутренняя светящаяся лампа
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.14
	lamp_mesh.height = 0.28
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color("#FFF9E6")
	var lmi := MeshInstance3D.new()
	lmi.mesh = lamp_mesh
	lmi.material_override = lamp_mat
	lmi.position = Vector3(0.0, 2.82, 0.0)
	_lighthouse_root.add_child(lmi)

	# Источник света фонаря
	_lantern_light = OmniLight3D.new()
	_lantern_light.position = Vector3(0.0, 2.82, 0.0)
	_lantern_light.omni_range = 9.0
	_lantern_light.light_color = Color("#FFF9E6")
	_lantern_light.light_energy = 0.5
	_lighthouse_root.add_child(_lantern_light)

	# 5. Конический купол крыши и шпиль
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 0.38
	roof_mesh.height = 0.40
	var rfmi := MeshInstance3D.new()
	rfmi.mesh = roof_mesh
	rfmi.material_override = red_mat
	rfmi.position = Vector3(0.0, 3.25, 0.0)
	_lighthouse_root.add_child(rfmi)

	var spire_mesh := SphereMesh.new()
	spire_mesh.radius = 0.07
	spire_mesh.height = 0.14
	var spire_mat := _make_mat(Color("#FFD32A"), 0.2)
	var spmi := MeshInstance3D.new()
	spmi.mesh = spire_mesh
	spmi.material_override = spire_mat
	spmi.position = Vector3(0.0, 3.48, 0.0)
	_lighthouse_root.add_child(spmi)

	# 6. Вращающийся луч света
	_lantern_beam = Node3D.new()
	_lantern_beam.position = Vector3(0.0, 2.82, 0.0)
	_lighthouse_root.add_child(_lantern_beam)

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 2.20
	beam_mesh.bottom_radius = 0.12
	beam_mesh.height = 9.0
	var beam_mat := StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(1.0, 0.95, 0.6, 0.22)

	var bmi := MeshInstance3D.new()
	bmi.mesh = beam_mesh
	bmi.material_override = beam_mat
	bmi.position = Vector3(0.0, 0.0, 4.5)
	bmi.rotation_degrees.x = 90.0
	_lantern_beam.add_child(bmi)


func _add_cylinder(parent: Node3D, top_r: float, bot_r: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = 18
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func set_night_mode(is_night: bool) -> void:
	_is_night_mode = is_night
	if _lantern_beam and _lantern_beam.get_child_count() > 0:
		var mi: MeshInstance3D = _lantern_beam.get_child(0) as MeshInstance3D
		if mi and mi.material_override is StandardMaterial3D:
			var mat := mi.material_override as StandardMaterial3D
			mat.albedo_color.a = 0.50 if is_night else 0.16
	if _lantern_light:
		_lantern_light.light_energy = 1.35 if is_night else 0.45


func update_treasures(delta: float, world_time: float) -> void:
	# 1. Вращение луча маяка и реакция на тап
	if _lighthouse_bounce > 0.0:
		_lighthouse_bounce = maxf(0.0, _lighthouse_bounce - delta * 3.5)
		var progress := 1.0 - _lighthouse_bounce
		var sy := 1.0 + sin(progress * PI) * 0.25
		var sxz := 1.0 - sin(progress * PI) * 0.12
		if _lighthouse_root:
			_lighthouse_root.scale = Vector3(sxz, sy, sxz)
	elif _lighthouse_root != null:
		_lighthouse_root.scale = Vector3.ONE

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
	if _lighthouse_root and camera.is_position_in_frustum(_lighthouse_root.global_position):
		var tower_screen := camera.unproject_position(_lighthouse_root.global_position + Vector3(0.0, 1.8, 0.0))
		if screen_pt.distance_to(tower_screen) <= 85.0:
			_lighthouse_bounce = 1.0
			lighthouse_clicked.emit(_lighthouse_root.global_position + Vector3(0.0, 3.2, 0.0))
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

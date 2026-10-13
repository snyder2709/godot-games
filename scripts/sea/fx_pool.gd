class_name FXPool
extends Node3D

const MAX_PARTICLES := 32

var _sphere_mesh: SphereMesh
var _pool: Array[MeshInstance3D] = []
var _active_particles: Array[Dictionary] = []
var _shared_mat: StandardMaterial3D


func _ready() -> void:
	_sphere_mesh = SphereMesh.new()
	_sphere_mesh.radius = 0.13
	_sphere_mesh.height = 0.26
	_sphere_mesh.radial_segments = 12
	_sphere_mesh.rings = 6

	# Предварительное выделение пула мешей для полного исключения new/queue_free в геймплее
	for i in range(MAX_PARTICLES):
		var mi := MeshInstance3D.new()
		mi.mesh = _sphere_mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		_pool.append(mi)


func spawn_splash(origin: Vector3, count: int, col: Color) -> void:
	for i in range(count):
		var a := randf() * TAU
		var h_speed := randf_range(1.4, 4.2)
		var v_speed := randf_range(3.8, 6.8)
		spawn_particle(
			origin + Vector3(0.0, 0.25, 0.0),
			Vector3(cos(a) * h_speed, v_speed, sin(a) * h_speed),
			col,
			randf_range(0.35, 0.55),
			true,
			randf_range(0.85, 1.35)
		)


func spawn_particle(pos: Vector3, vel: Vector3, col: Color, life: float, gravity: bool, base_scale: float = 1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = null
	# Ищем свободный элемент в пуле
	for item in _pool:
		if not item.visible:
			mi = item
			break

	# Если пул заполнен, переиспользуем самый старый
	if mi == null and _active_particles.size() > 0:
		var oldest: Dictionary = _active_particles[0]
		mi = oldest["node"]
		_active_particles.remove_at(0)

	if mi == null:
		return null

	mi.position = pos
	mi.scale = Vector3.ONE * base_scale
	mi.visible = true
	var mat: StandardMaterial3D = mi.material_override
	if mat:
		mat.albedo_color = col

	_active_particles.append({
		"node": mi,
		"vel": vel,
		"life": life,
		"max_life": life,
		"gravity": gravity,
		"base_scale": base_scale
	})
	return mi


func _process(delta: float) -> void:
	for i in range(_active_particles.size() - 1, -1, -1):
		var p: Dictionary = _active_particles[i]
		p["life"] -= delta
		var pnode: MeshInstance3D = p["node"]
		if p["life"] <= 0.0:
			pnode.visible = false
			_active_particles.remove_at(i)
		else:
			if p["gravity"]:
				p["vel"].y -= 13.5 * delta
			pnode.position += p["vel"] * delta
			var ratio: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
			pnode.scale = Vector3.ONE * (ratio * float(p["base_scale"]))

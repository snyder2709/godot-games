class_name FXPool
extends Node3D

signal bubble_popped(pos: Vector3)

const MAX_PARTICLES := 32
const MAX_RIPPLES := 16
const MAX_BUBBLES := 12

class ParticleData extends RefCounted:
	var node: MeshInstance3D
	var vel: Vector3
	var life: float
	var max_life: float
	var gravity: bool
	var base_scale: float

class RippleData extends RefCounted:
	var node: MeshInstance3D
	var pos: Vector3
	var life: float
	var max_life: float
	var start_scale: float
	var target_scale: float
	var base_color: Color

class SeaBubbleData extends RefCounted:
	var node: MeshInstance3D
	var pos: Vector3
	var vel: Vector3
	var life: float
	var max_life: float
	var phase: float
	var base_radius: float

var _sphere_mesh: SphereMesh
var _torus_mesh: TorusMesh
var _bubble_mesh: SphereMesh

var _particle_pool: Array[MeshInstance3D] = []
var _active_particles: Array[ParticleData] = []

var _ripple_pool: Array[MeshInstance3D] = []
var _active_ripples: Array[RippleData] = []

var _bubble_pool: Array[MeshInstance3D] = []
var _active_bubbles: Array[SeaBubbleData] = []


func _ready() -> void:
	_init_particles()
	_init_ripples()
	_init_bubbles()


func _init_particles() -> void:
	_sphere_mesh = SphereMesh.new()
	_sphere_mesh.radius = 0.13
	_sphere_mesh.height = 0.26
	_sphere_mesh.radial_segments = 12
	_sphere_mesh.rings = 6

	for i in range(MAX_PARTICLES):
		var mi := MeshInstance3D.new()
		mi.mesh = _sphere_mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		_particle_pool.append(mi)


func _init_ripples() -> void:
	_torus_mesh = TorusMesh.new()
	_torus_mesh.inner_radius = 0.82
	_torus_mesh.outer_radius = 1.0
	_torus_mesh.rings = 24
	_torus_mesh.ring_segments = 12

	for i in range(MAX_RIPPLES):
		var mi := MeshInstance3D.new()
		mi.mesh = _torus_mesh
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.7)
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		_ripple_pool.append(mi)


func _init_bubbles() -> void:
	_bubble_mesh = SphereMesh.new()
	_bubble_mesh.radius = 0.22
	_bubble_mesh.height = 0.44
	_bubble_mesh.radial_segments = 14
	_bubble_mesh.rings = 8

	for i in range(MAX_BUBBLES):
		var mi := MeshInstance3D.new()
		mi.mesh = _bubble_mesh
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.88, 0.96, 1.0, 0.65)
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		_bubble_pool.append(mi)


func spawn_splash(origin: Vector3, count: int, col: Color) -> void:
	spawn_ripple(Vector3(origin.x, 0.05, origin.z), 0.2, 1.6, Color(1.0, 1.0, 1.0, 0.75), 0.5)
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
	for item in _particle_pool:
		if not item.visible:
			mi = item
			break

	if mi == null and _active_particles.size() > 0:
		var oldest := _active_particles[0]
		mi = oldest.node
		_active_particles.remove_at(0)

	if mi == null:
		return null

	mi.position = pos
	mi.scale = Vector3.ONE * base_scale
	mi.visible = true
	var mat: StandardMaterial3D = mi.material_override
	if mat:
		mat.albedo_color = col

	var pdata := ParticleData.new()
	pdata.node = mi
	pdata.vel = vel
	pdata.life = life
	pdata.max_life = life
	pdata.gravity = gravity
	pdata.base_scale = base_scale
	_active_particles.append(pdata)
	return mi


func spawn_ripple(pos: Vector3, start_sc: float = 0.25, target_sc: float = 1.8, col: Color = Color(1.0, 1.0, 1.0, 0.7), duration: float = 0.55) -> void:
	var mi: MeshInstance3D = null
	for item in _ripple_pool:
		if not item.visible:
			mi = item
			break

	if mi == null and _active_ripples.size() > 0:
		var oldest := _active_ripples[0]
		mi = oldest.node
		_active_ripples.remove_at(0)

	if mi == null:
		return

	mi.position = pos
	mi.scale = Vector3(start_sc, 0.4, start_sc)
	mi.visible = true

	var rd := RippleData.new()
	rd.node = mi
	rd.pos = pos
	rd.life = duration
	rd.max_life = duration
	rd.start_scale = start_sc
	rd.target_scale = target_sc
	rd.base_color = col
	_active_ripples.append(rd)


func spawn_floating_bubble(pos: Vector3, vel: Vector3 = Vector3(0.0, 1.2, 0.0), radius: float = 0.24, duration: float = 4.5) -> void:
	var mi: MeshInstance3D = null
	for item in _bubble_pool:
		if not item.visible:
			mi = item
			break

	if mi == null and _active_bubbles.size() > 0:
		var oldest := _active_bubbles[0]
		mi = oldest.node
		_active_bubbles.remove_at(0)

	if mi == null:
		return

	mi.position = pos
	mi.scale = Vector3.ONE * (radius / 0.22)
	mi.visible = true

	var bd := SeaBubbleData.new()
	bd.node = mi
	bd.pos = pos
	bd.vel = vel
	bd.life = duration
	bd.max_life = duration
	bd.phase = randf() * TAU
	bd.base_radius = radius
	_active_bubbles.append(bd)


func check_bubble_touch(camera: Camera3D, screen_pt: Vector2) -> bool:
	for i in range(_active_bubbles.size() - 1, -1, -1):
		var b := _active_bubbles[i]
		if camera.is_position_in_frustum(b.node.global_position):
			var b_screen := camera.unproject_position(b.node.global_position)
			if screen_pt.distance_to(b_screen) <= 65.0:
				var pop_pos := b.node.global_position
				b.node.visible = false
				_active_bubbles.remove_at(i)
				spawn_splash(pop_pos, 7, Color("#81D4FA"))
				bubble_popped.emit(pop_pos)
				return true
	return false


func _process(delta: float) -> void:
	_update_particles(delta)
	_update_ripples(delta)
	_update_bubbles(delta)


func _update_particles(delta: float) -> void:
	for i in range(_active_particles.size() - 1, -1, -1):
		var p := _active_particles[i]
		p.life -= delta
		var pnode := p.node
		if p.life <= 0.0:
			pnode.visible = false
			_active_particles.remove_at(i)
		else:
			if p.gravity:
				p.vel.y -= 13.5 * delta
			pnode.position += p.vel * delta
			var ratio := clampf(p.life / p.max_life, 0.0, 1.0)
			pnode.scale = Vector3.ONE * (ratio * p.base_scale)


func _update_ripples(delta: float) -> void:
	for i in range(_active_ripples.size() - 1, -1, -1):
		var r := _active_ripples[i]
		r.life -= delta
		var rnode := r.node
		if r.life <= 0.0:
			rnode.visible = false
			_active_ripples.remove_at(i)
		else:
			var progress := 1.0 - clampf(r.life / r.max_life, 0.0, 1.0)
			var sc := lerpf(r.start_scale, r.target_scale, sqrt(progress))
			rnode.scale = Vector3(sc, 0.35, sc)
			var mat: StandardMaterial3D = rnode.material_override
			if mat:
				var a := (1.0 - progress) * r.base_color.a
				mat.albedo_color = Color(r.base_color.r, r.base_color.g, r.base_color.b, a)


func _update_bubbles(delta: float) -> void:
	for i in range(_active_bubbles.size() - 1, -1, -1):
		var b := _active_bubbles[i]
		b.life -= delta
		if b.life <= 0.0:
			b.node.visible = false
			_active_bubbles.remove_at(i)
		else:
			b.phase += delta * 3.2
			b.pos += b.vel * delta
			b.pos.x += sin(b.phase) * 0.45 * delta
			b.pos.z += cos(b.phase * 0.8) * 0.35 * delta
			b.node.position = b.pos
			var sc := (b.base_radius / 0.22) * (1.0 + sin(b.phase * 2.0) * 0.08)
			b.node.scale = Vector3(sc, sc * 1.08, sc)

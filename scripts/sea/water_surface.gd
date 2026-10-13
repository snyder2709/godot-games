class_name WaterSurface
extends Node3D

signal duck_clicked(duck_pos: Vector3)

const SEA_MIN_X := -16.5
const SEA_MAX_X := 16.5
const SEA_MIN_Z := -13.5
const SEA_MAX_Z := 6.5

class IslandData extends RefCounted:
	var pos: Vector3
	var radius: float

var islands: Array[IslandData] = []
var _floating_duck: Node3D
var _duck_bounce: float = 0.0
var _target_ring: MeshInstance3D
var _target_ring_timer: float = 0.0
var _water_shader_mat: ShaderMaterial
var _kenney_colormap: Texture2D


func init_surface(colormap: Texture2D) -> void:
	_kenney_colormap = colormap
	_init_shader()
	_build_sea_mesh()
	_build_islands()
	_build_floating_duck()
	_build_target_ring()


func get_wave_height(x: float, z: float, time: float) -> float:
	var w1 := sin(x * 0.8 + time * 2.0) * cos(z * 0.7 + time * 1.6) * 0.12
	var w2 := sin((x + z) * 1.3 - time * 2.4) * 0.06
	return w1 + w2


func push_out_of_islands(pt: Vector3, actor_radius: float) -> Vector3:
	var res := Vector3(pt.x, 0.0, pt.z)
	for _pass in range(2):
		for isl in islands:
			var ipos := isl.pos
			var min_dist := isl.radius + actor_radius
			var diff := res - ipos
			diff.y = 0.0
			var d := diff.length()
			if d < min_dist:
				if d < 0.001:
					diff = Vector3(0.0, 0.0, 1.0)
					d = 1.0
				res = ipos + (diff / d) * min_dist
	res.x = clampf(res.x, SEA_MIN_X, SEA_MAX_X)
	res.z = clampf(res.z, SEA_MIN_Z, SEA_MAX_Z)
	return res


func is_valid_spawn(from_pt: Vector3, cand: Vector3, margin: float) -> bool:
	var p2 := Vector2(cand.x, cand.z)
	var p1 := Vector2(from_pt.x, from_pt.z)
	var seg := p2 - p1
	var seg_len_sq := seg.length_squared()
	for isl in islands:
		var ipos := isl.pos
		var center := Vector2(ipos.x, ipos.z)
		var safe_r := isl.radius + margin
		if p2.distance_to(center) < safe_r:
			return false
		if seg_len_sq > 0.01:
			var t := clampf((center - p1).dot(seg) / seg_len_sq, 0.0, 1.0)
			var closest := p1 + seg * t
			if closest.distance_to(center) < isl.radius + 0.85:
				return false
	return true


func show_target_ring(pos: Vector3, duration: float = 0.55) -> void:
	if _target_ring:
		_target_ring.position = Vector3(pos.x, 0.10, pos.z)
		_target_ring_timer = duration
		_target_ring.visible = true


func hide_target_ring() -> void:
	if _target_ring:
		_target_ring_timer = 0.0
		_target_ring.visible = false


func check_duck_touch(camera: Camera3D, screen_pt: Vector2) -> bool:
	if _floating_duck == null or not camera.is_position_in_frustum(_floating_duck.global_position):
		return false
	var duck_screen := camera.unproject_position(_floating_duck.global_position)
	if screen_pt.distance_to(duck_screen) <= 70.0:
		_duck_bounce = 1.0
		duck_clicked.emit(_floating_duck.global_position)
		return true
	return false


func update_surface(delta: float, world_time: float) -> void:
	if _duck_bounce > 0.0:
		_duck_bounce = maxf(0.0, _duck_bounce - delta * 3.0)

	if _floating_duck != null:
		var dx := _floating_duck.position.x
		var dz := _floating_duck.position.z
		_floating_duck.position.y = get_wave_height(dx, dz, world_time) + _duck_bounce * 0.55
		_floating_duck.rotation.y += delta * (6.0 if _duck_bounce > 0.0 else 0.5)

	if _target_ring != null:
		if _target_ring_timer > 0.0:
			_target_ring_timer = maxf(0.0, _target_ring_timer - delta)
			_target_ring.visible = true
			var s := 1.0 + (0.6 - _target_ring_timer) * 1.5
			_target_ring.scale = Vector3(s, 1.0, s)
		else:
			_target_ring.visible = false


func _init_shader() -> void:
	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.76, 0.90, 1.0);
uniform vec4 deep_color : source_color = vec4(0.03, 0.44, 0.82, 1.0);
uniform vec4 foam_color : source_color = vec4(0.96, 0.99, 1.0, 1.0);

varying float v_wave_h;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w1 = sin(world_pos.x * 0.8 + TIME * 2.0) * cos(world_pos.z * 0.7 + TIME * 1.6) * 0.12;
	float w2 = sin((world_pos.x + world_pos.z) * 1.3 - TIME * 2.4) * 0.06;
	float h = w1 + w2;
	VERTEX.y += h;
	v_wave_h = h;

	float d_dx = cos(world_pos.x * 0.8 + TIME * 2.0) * 0.8 * cos(world_pos.z * 0.7 + TIME * 1.6) * 0.12
	           + cos((world_pos.x + world_pos.z) * 1.3 - TIME * 2.4) * 1.3 * 0.06;
	float d_dz = -sin(world_pos.x * 0.8 + TIME * 2.0) * sin(world_pos.z * 0.7 + TIME * 1.6) * 0.7 * 0.12
	           + cos((world_pos.x + world_pos.z) * 1.3 - TIME * 2.4) * 1.3 * 0.06;
	NORMAL = normalize(vec3(-d_dx, 1.0, -d_dz));
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 water_col = mix(shallow_color.rgb, deep_color.rgb, clamp(fresnel * 0.75 + 0.25, 0.0, 1.0));
	float crest_foam = smoothstep(0.10, 0.18, v_wave_h);
	ALBEDO = mix(water_col, foam_color.rgb, crest_foam * 0.55);
	ROUGHNESS = 0.15;
	SPECULAR = 0.55;
}
"""
	_water_shader_mat = ShaderMaterial.new()
	_water_shader_mat.shader = water_shader


func _build_sea_mesh() -> void:
	var sea_plane := PlaneMesh.new()
	sea_plane.size = Vector2(90.0, 90.0)
	sea_plane.subdivide_width = 36
	sea_plane.subdivide_depth = 36
	var mi := MeshInstance3D.new()
	mi.mesh = sea_plane
	mi.material_override = _water_shader_mat
	add_child(mi)


func _build_islands() -> void:
	_create_island(Vector3(-10.8, -0.05, -6.5), 3.4, true)
	_create_island(Vector3(11.0, -0.05, -6.0), 3.5, false)
	_create_island(Vector3(-0.4, -0.05, -11.8), 3.0, false)


func _create_island(pos: Vector3, radius: float, with_tower: bool) -> void:
	var isl_data := IslandData.new()
	isl_data.pos = Vector3(pos.x, 0.0, pos.z)
	isl_data.radius = radius + 0.25
	islands.append(isl_data)

	var isl := Node3D.new()
	isl.position = pos
	add_child(isl)

	var sand_dome := SphereMesh.new()
	sand_dome.radius = radius
	sand_dome.height = radius * 0.65
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color("#F6D365")
	sand_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	sand_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	var smi := MeshInstance3D.new()
	smi.mesh = sand_dome
	smi.material_override = sand_mat
	smi.position = Vector3(0.0, 0.12, 0.0)
	isl.add_child(smi)

	var shore_foam := TorusMesh.new()
	shore_foam.inner_radius = radius * 0.92
	shore_foam.outer_radius = radius * 1.08
	var foam_mat := StandardMaterial3D.new()
	foam_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fmi := MeshInstance3D.new()
	fmi.mesh = shore_foam
	fmi.material_override = foam_mat
	fmi.position = Vector3(0.0, 0.06, 0.0)
	isl.add_child(fmi)

	var patch_scale := (radius * 0.78) / 3.87
	_instantiate_model("res://assets/models/patch-sand-foliage.glb", isl, Vector3(0.0, 0.38, 0.0), Vector3.ZERO, Vector3.ONE * patch_scale, true)
	_instantiate_model("res://assets/models/palm-detailed-bend.glb", isl, Vector3(-radius * 0.28, 0.45, 0.12), Vector3(0.0, 35.0, 0.0), Vector3.ONE * 0.82, true)
	_instantiate_model("res://assets/models/palm-detailed-straight.glb", isl, Vector3(radius * 0.26, 0.45, -0.22), Vector3(0.0, -60.0, 0.0), Vector3.ONE * 0.78, true)
	_instantiate_model("res://assets/models/rocks-sand-a.glb", isl, Vector3(radius * 0.35, 0.22, radius * 0.22), Vector3(0.0, 120.0, 0.0), Vector3.ONE * 0.42, true)

	if with_tower:
		_instantiate_model("res://assets/models/tower-complete-small.glb", isl, Vector3(0.12, 0.52, -0.15), Vector3(0.0, 25.0, 0.0), Vector3.ONE * 0.65, true)
		_instantiate_model("res://assets/models/chest.glb", isl, Vector3(-0.65, 0.52, 0.72), Vector3(0.0, 15.0, 0.0), Vector3.ONE * 0.85, true)
		var boat_offset := Vector3(radius * 0.88, 0.06, radius * 0.42)
		_instantiate_model("res://assets/models/boat-row-small.glb", isl, boat_offset, Vector3(0.0, 45.0, 0.0), Vector3.ONE * 0.90, true)
		var boat_data := IslandData.new()
		boat_data.pos = Vector3(pos.x + boat_offset.x, 0.0, pos.z + boat_offset.z)
		boat_data.radius = 1.25
		islands.append(boat_data)


func _build_floating_duck() -> void:
	_floating_duck = Node3D.new()
	_floating_duck.position = Vector3(-3.8, 0.0, 1.4)
	add_child(_floating_duck)
	_instantiate_model("res://assets/models/duck.glb", _floating_duck, Vector3(0.0, -0.08, 0.0), Vector3(0.0, 45.0, 0.0), Vector3.ONE * 0.45)


func _build_target_ring() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.38
	ring_mesh.outer_radius = 0.54
	_target_ring = MeshInstance3D.new()
	_target_ring.mesh = ring_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#FFF200")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_ring.material_override = mat
	_target_ring.visible = false
	add_child(_target_ring)


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

extends Node3D

enum DadState { WAITING, DIVING, UNDERWATER, EMERGING }

const SEA_MIN_X := -16.5
const SEA_MAX_X := 16.5
const SEA_MIN_Z := -13.5
const SEA_MAX_Z := 6.5

var world_time: float = 0.0

# 3D Камера (вид от 3-го лица за спиной)
var _camera: Camera3D
var _ui_canvas: Node2D
var _cam_pos := Vector3(0.0, 5.4, 10.2)
var _cam_look := Vector3(0.0, 0.4, -1.5)

# Шейдеры и текстуры палитры Kenney
var _water_shader_mat: ShaderMaterial
var _kenney_colormap: Texture2D

# Острова и коллизии
var islands: Array[Dictionary] = []

# Главная героиня: Маленькая девочка в спасательном круге с рулём (Kenney character-girl.glb)
var _girl_root: Node3D
var _girl_visual: Node3D
var _girl_anim: AnimationPlayer
var _wheel_pivot: Node3D
var girl_pos := Vector3(0.0, 0.0, 3.2)
var girl_target := Vector3(0.0, 0.0, 3.2)
var girl_vel := Vector3.ZERO
var girl_yaw: float = PI
var wheel_angle: float = 0.0
var wheel_spin_boost: float = 0.0
var girl_bounce: float = 0.0
var swim_to_dad: bool = false
var _foam_cooldown: float = 0.0

# 3D Кольцо-цель на воде
var _target_ring: MeshInstance3D
var _target_ring_timer: float = 0.0

# Папа в воде (Kenney character-dad.glb)
var _dad_root: Node3D
var _dad_visual: Node3D
var _dad_anim: AnimationPlayer
var _dad_hats: Array[Node3D] = []
var dad_pos := Vector3(0.0, 0.0, -2.0)
var dad_next_pos := Vector3(0.0, 0.0, -2.0)
var dad_state: int = DadState.WAITING
var dad_timer: float = 0.0
var dad_hat_idx: int = 0
var bubble_trail_pos := Vector3.ZERO
var _glug_cooldown: float = 0.0

# Морские буйки-бамперы (Kenney buoy.glb, buoy-flag.glb)
var buoys: Array[Dictionary] = []

# Крабик на пляже (Kenney animal-crab.glb)
var _island_crab: Node3D
var _crab_anim: AnimationPlayer
var _crab_bounce: float = 0.0

# Стайки 3D-рыбок (Kenney animal-fish.glb)
var fishes: Array[Dictionary] = []

# Окружение: Корабли, Птицы, Уточка, Облака
var boats: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var clouds: Array[Node3D] = []
var _floating_duck: Node3D
var _duck_bounce: float = 0.0

# Водяная пушка / струи брызг
var water_jets: Array[Dictionary] = []

# 3D Партиклы
var fx_particles: Array[Dictionary] = []
var _sphere_mesh_small: SphereMesh

# Аудиоплееры
var _splash_player: AudioStreamPlayer
var _laugh_player: AudioStreamPlayer
var _squeak_player: AudioStreamPlayer
var _horn_player: AudioStreamPlayer
var _slide_player: AudioStreamPlayer
var _glug_player: AudioStreamPlayer
var _bell_player: AudioStreamPlayer
var _boing_player: AudioStreamPlayer
var _tap_player: AudioStreamPlayer
var _sea_ambient: AudioStreamPlayer


func _ready() -> void:
	randomize()

	# Инициализация звуков
	_splash_player = _make_player(SoundGen.get_splash_stream(), 6)
	_laugh_player = _make_player(SoundGen.get_laugh_stream(), 3)
	_squeak_player = _make_player(SoundGen.get_squeak_stream(), 4)
	_horn_player = _make_player(SoundGen.get_boat_horn_stream(), 3)
	_slide_player = _make_player(SoundGen.get_slide_up_stream(), 4)
	_glug_player = _make_player(SoundGen.get_glug_stream(), 4)

	if ResourceLoader.exists("res://assets/bell.ogg"):
		_bell_player = _make_player(load("res://assets/bell.ogg"), 4)
	else:
		_bell_player = _make_player(SoundGen.get_toy_stream(), 4)

	if ResourceLoader.exists("res://assets/boing.ogg"):
		_boing_player = _make_player(load("res://assets/boing.ogg"), 4)
	else:
		_boing_player = _make_player(SoundGen.get_squeak_stream(), 4)

	if ResourceLoader.exists("res://assets/tap.ogg"):
		_tap_player = _make_player(load("res://assets/tap.ogg"), 4)
	else:
		_tap_player = _make_player(SoundGen.get_pop_stream(), 4)

	# Фоновый морской прибой (тихий ambient)
	if ResourceLoader.exists("res://assets/sea_ambient.wav"):
		_sea_ambient = AudioStreamPlayer.new()
		_sea_ambient.stream = load("res://assets/sea_ambient.wav")
		if _sea_ambient.stream is AudioStreamWAV:
			(_sea_ambient.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_sea_ambient.volume_db = -16.0
		add_child(_sea_ambient)
		_sea_ambient.play()

	if ResourceLoader.exists("res://assets/models/Textures/colormap.png"):
		_kenney_colormap = load("res://assets/models/Textures/colormap.png")

	_sphere_mesh_small = SphereMesh.new()
	_sphere_mesh_small.radius = 0.14
	_sphere_mesh_small.height = 0.28
	_sphere_mesh_small.radial_segments = 14
	_sphere_mesh_small.rings = 7

	_init_shaders()
	_setup_environment_and_camera()
	_build_shader_sea_and_islands()
	_build_clouds_3d()
	_build_buoys_3d()
	_build_girl_character_3d()
	_build_dad_character_3d()
	_build_island_crab_3d()
	_build_fish_schools_3d()
	_build_boats_and_birds_3d()
	_setup_ui_overlay()


func _make_player(stream: AudioStream, polyphony: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.max_polyphony = polyphony
	add_child(p)
	return p


func _push_out_of_islands(pt: Vector3, actor_radius: float) -> Vector3:
	var res := Vector3(pt.x, 0.0, pt.z)
	for _pass in range(2):
		for isl in islands:
			var ipos: Vector3 = isl["pos"]
			var min_dist: float = float(isl["radius"]) + actor_radius
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


func _is_valid_dad_spawn(from_pt: Vector3, cand: Vector3, margin: float) -> bool:
	var p2 := Vector2(cand.x, cand.z)
	var p1 := Vector2(from_pt.x, from_pt.z)
	var seg := p2 - p1
	var seg_len_sq := seg.length_squared()
	for isl in islands:
		var ipos: Vector3 = isl["pos"]
		var center := Vector2(ipos.x, ipos.z)
		var safe_r: float = float(isl["radius"]) + margin
		if p2.distance_to(center) < safe_r:
			return false
		if seg_len_sq > 0.01:
			var t := clampf((center - p1).dot(seg) / seg_len_sq, 0.0, 1.0)
			var closest := p1 + seg * t
			if closest.distance_to(center) < float(isl["radius"]) + 0.85:
				return false
	return true


func _instantiate_glb(res_path: String, parent: Node3D, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, sc := Vector3.ONE, apply_kenney_tex: bool = false) -> Node3D:
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


func _init_shaders() -> void:
	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.82, 0.96, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.48, 0.88, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.99, 1.0, 1.0);

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


func _get_wave_height(x: float, z: float) -> float:
	var w1 := sin(x * 0.8 + world_time * 2.0) * cos(z * 0.7 + world_time * 1.6) * 0.12
	var w2 := sin((x + z) * 1.3 - world_time * 2.4) * 0.06
	return w1 + w2


func _setup_environment_and_camera() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#29B6F6")
	sky_mat.sky_horizon_color = Color("#B3E5FC")
	sky_mat.ground_bottom_color = Color("#0288D1")
	sky_mat.ground_horizon_color = Color("#81D4FA")
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("#FFFDF7")
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
	sun.light_color = Color("#FFF9E6")
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	add_child(sun)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.look_at_from_position(_cam_pos, _cam_look, Vector3.UP)
	add_child(_camera)


func _build_shader_sea_and_islands() -> void:
	# Оптимизированное море (36x36 полигонов для 60 FPS на Android)
	var sea_plane := PlaneMesh.new()
	sea_plane.size = Vector2(90.0, 90.0)
	sea_plane.subdivide_width = 36
	sea_plane.subdivide_depth = 36
	_add_mesh(self, sea_plane, _water_shader_mat, Vector3.ZERO)

	# 3 тропических острова с Kenney-моделями
	_create_glb_island(Vector3(-10.8, -0.05, -6.5), 3.4, true)
	_create_glb_island(Vector3(11.0, -0.05, -6.0), 3.5, false)
	_create_glb_island(Vector3(-0.4, -0.05, -11.8), 3.0, false)

	# Настоящая 3D резиновая уточка (Khronos Duck.glb)
	_floating_duck = Node3D.new()
	_floating_duck.position = Vector3(-4.2, 0.0, 1.5)
	add_child(_floating_duck)
	_instantiate_glb("res://assets/models/duck.glb", _floating_duck, Vector3(0.0, -0.08, 0.0), Vector3(0.0, 45.0, 0.0), Vector3.ONE * 0.48)

	# Кольцо-цель на воде
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.42
	ring_mesh.outer_radius = 0.58
	_target_ring = MeshInstance3D.new()
	_target_ring.mesh = ring_mesh
	_target_ring.material_override = _make_unshaded_mat(Color("#FFF200"))
	_target_ring.visible = false
	add_child(_target_ring)


func _create_glb_island(pos: Vector3, radius: float, with_tower: bool) -> void:
	islands.append({
		"pos": Vector3(pos.x, 0.0, pos.z),
		"radius": radius + 0.25
	})

	var isl := Node3D.new()
	isl.position = pos
	add_child(isl)

	# Песчаный купол острова
	var sand_dome := SphereMesh.new()
	sand_dome.radius = radius
	sand_dome.height = radius * 0.52
	_add_mesh(isl, sand_dome, _make_toon_mat(Color("#FFEAA7"), 0.75), Vector3(0.0, 0.05, 0.0))

	# Пена вокруг берега
	var shore_foam := TorusMesh.new()
	shore_foam.inner_radius = radius * 0.90
	shore_foam.outer_radius = radius * 1.05
	_add_mesh(isl, shore_foam, _make_unshaded_mat(Color(1.0, 1.0, 1.0, 0.55)), Vector3(0.0, 0.06, 0.0))

	var patch_scale := (radius * 0.78) / 3.87
	_instantiate_glb("res://assets/models/patch-sand-foliage.glb", isl, Vector3(0.0, 0.36, 0.0), Vector3.ZERO, Vector3.ONE * patch_scale, true)
	_instantiate_glb("res://assets/models/palm-detailed-bend.glb", isl, Vector3(-radius * 0.30, 0.42, 0.15), Vector3(0.0, 35.0, 0.0), Vector3.ONE * 1.08, true)
	_instantiate_glb("res://assets/models/palm-detailed-straight.glb", isl, Vector3(radius * 0.28, 0.42, -0.25), Vector3(0.0, -60.0, 0.0), Vector3.ONE * 1.02, true)
	_instantiate_glb("res://assets/models/rocks-sand-a.glb", isl, Vector3(radius * 0.36, 0.22, radius * 0.24), Vector3(0.0, 120.0, 0.0), Vector3.ONE * 0.45, true)

	if with_tower:
		_instantiate_glb("res://assets/models/tower-complete-small.glb", isl, Vector3(0.15, 0.50, -0.15), Vector3(0.0, 25.0, 0.0), Vector3.ONE * 0.72, true)
		_instantiate_glb("res://assets/models/chest.glb", isl, Vector3(-0.65, 0.52, 0.75), Vector3(0.0, 15.0, 0.0), Vector3.ONE * 0.90, true)
		var boat_offset := Vector3(radius * 0.88, 0.06, radius * 0.45)
		_instantiate_glb("res://assets/models/boat-row-small.glb", isl, boat_offset, Vector3(0.0, 45.0, 0.0), Vector3.ONE * 0.95, true)
		islands.append({
			"pos": Vector3(pos.x + boat_offset.x, 0.0, pos.z + boat_offset.z),
			"radius": 1.25
		})


func _build_clouds_3d() -> void:
	# 4 готовых 3D-облака Kenney (cloud.glb) плывут по небу
	var cloud_configs = [
		{"pos": Vector3(-16.0, 10.5, -27.0), "sc": 3.6, "speed": 0.45},
		{"pos": Vector3(2.0, 12.0, -30.0), "sc": 4.2, "speed": 0.38},
		{"pos": Vector3(18.0, 11.0, -26.0), "sc": 3.4, "speed": 0.52},
		{"pos": Vector3(-8.0, 13.5, -29.0), "sc": 3.8, "speed": 0.40}
	]
	for c in cloud_configs:
		var cnode := Node3D.new()
		cnode.position = c["pos"]
		add_child(cnode)
		_instantiate_glb("res://assets/models/cloud.glb", cnode, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * c["sc"], true)
		cnode.set_meta("speed", c["speed"])
		clouds.append(cnode)


func _build_buoys_3d() -> void:
	# 4 морских буйка-бампера (Kenney buoy.glb, buoy-flag.glb)
	var buoy_positions = [
		{"path": "res://assets/models/buoy-flag.glb", "pos": Vector3(4.5, 0.0, -4.5), "sc": 0.58},
		{"path": "res://assets/models/buoy.glb", "pos": Vector3(-5.2, 0.0, -3.8), "sc": 0.55},
		{"path": "res://assets/models/buoy.glb", "pos": Vector3(1.8, 0.0, -8.2), "sc": 0.55},
		{"path": "res://assets/models/buoy-flag.glb", "pos": Vector3(-7.5, 0.0, 0.5), "sc": 0.58}
	]
	for b in buoy_positions:
		var bnode := Node3D.new()
		bnode.position = b["pos"]
		add_child(bnode)
		_instantiate_glb(b["path"], bnode, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * b["sc"], true)
		buoys.append({
			"node": bnode,
			"pos": b["pos"],
			"wobble": Vector2.ZERO,
			"wobble_vel": Vector2.ZERO,
			"radius": 1.05
		})


func _build_girl_character_3d() -> void:
	_girl_root = Node3D.new()
	_girl_root.position = girl_pos
	add_child(_girl_root)

	_girl_visual = Node3D.new()
	_girl_visual.rotation.y = girl_yaw
	_girl_root.add_child(_girl_visual)

	# 1. Жёлтый детский спасательный круг
	var ring_torus := TorusMesh.new()
	ring_torus.inner_radius = 0.52
	ring_torus.outer_radius = 1.18
	ring_torus.rings = 48
	ring_torus.ring_segments = 24
	var yellow_mat := _make_toon_mat(Color("#FFD32A"), 0.12)
	_add_mesh(_girl_visual, ring_torus, yellow_mat, Vector3(0.0, 0.14, 0.0))

	# Ручки круга
	var handle_torus := TorusMesh.new()
	handle_torus.inner_radius = 0.08
	handle_torus.outer_radius = 0.18
	var orange_mat := _make_toon_mat(Color("#FF9F43"), 0.25)
	_add_mesh(_girl_visual, handle_torus, orange_mat, Vector3(-0.84, 0.42, -0.1), Vector3(0, 0, 25))
	_add_mesh(_girl_visual, handle_torus, orange_mat, Vector3(0.84, 0.42, -0.1), Vector3(0, 0, -25))

	# 2. Настоящий анимированный 3D-персонаж девочки (Kenney character-girl.glb)
	# Посажена в спасательный круг, руки держат руль в анимации 'drive'
	var girl_model := _instantiate_glb("res://assets/models/character-girl.glb", _girl_visual, Vector3(0.0, 0.04, -0.12), Vector3(0.0, 180.0, 0.0), Vector3.ONE * 0.22)
	_girl_anim = _play_glb_anim(girl_model, ["drive", "sit", "idle"])

	# 3. Детский руль с красной кнопкой-бибипкой и соплом водяной брызгалки
	var col_mount := Node3D.new()
	col_mount.position = Vector3(0.0, 0.42, 0.72)
	col_mount.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	_girl_visual.add_child(col_mount)

	var dashboard := SphereMesh.new()
	dashboard.radius = 0.20
	dashboard.height = 0.28
	_add_mesh(col_mount, dashboard, orange_mat, Vector3.ZERO)

	var stem := CylinderMesh.new()
	stem.top_radius = 0.07
	stem.bottom_radius = 0.09
	stem.height = 0.36
	_add_mesh(col_mount, stem, _make_toon_mat(Color("#0984E3"), 0.2), Vector3(0.0, 0.18, 0.0))

	_wheel_pivot = Node3D.new()
	_wheel_pivot.position = Vector3(0.0, 0.36, 0.0)
	col_mount.add_child(_wheel_pivot)

	var wheel_torus := TorusMesh.new()
	wheel_torus.inner_radius = 0.25
	wheel_torus.outer_radius = 0.38
	wheel_torus.rings = 36
	wheel_torus.ring_segments = 18
	_add_mesh(_wheel_pivot, wheel_torus, _make_toon_mat(Color("#0984E3"), 0.15), Vector3.ZERO)

	var spoke := CapsuleMesh.new()
	spoke.radius = 0.04
	spoke.height = 0.60
	var light_blue := _make_toon_mat(Color("#48DBFB"), 0.2)
	_add_mesh(_wheel_pivot, spoke, light_blue, Vector3.ZERO, Vector3(0, 0, 90))
	_add_mesh(_wheel_pivot, spoke, light_blue, Vector3.ZERO, Vector3(90, 0, 0))

	# Красная кнопка-бибипка (водяная пушка!)
	var horn_btn := SphereMesh.new()
	horn_btn.radius = 0.13
	horn_btn.height = 0.20
	_add_mesh(_wheel_pivot, horn_btn, _make_toon_mat(Color("#FF3F34"), 0.15), Vector3(0.0, 0.04, 0.0))

	# Сопло водяной пушки на передке круга
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = 0.05
	nozzle.bottom_radius = 0.07
	nozzle.height = 0.18
	_add_mesh(_girl_visual, nozzle, _make_toon_mat(Color("#00CEC9"), 0.2), Vector3(0.0, 0.30, 1.15), Vector3(90.0, 0.0, 0.0))


func _build_dad_character_3d() -> void:
	_dad_root = Node3D.new()
	_dad_root.position = dad_pos
	add_child(_dad_root)

	_dad_visual = Node3D.new()
	_dad_root.add_child(_dad_visual)

	# Пенный круг вокруг Папы в воде
	var foam_ring := TorusMesh.new()
	foam_ring.inner_radius = 0.78
	foam_ring.outer_radius = 1.08
	_add_mesh(_dad_visual, foam_ring, _make_unshaded_mat(Color(1, 1, 1, 0.55)), Vector3(0.0, 0.05, 0.0))

	# Настоящая 3D-модель Папы (Kenney character-dad.glb)
	var dad_model := _instantiate_glb("res://assets/models/character-dad.glb", _dad_visual, Vector3(0.0, -0.32, 0.0), Vector3.ZERO, Vector3.ONE * 0.26)
	_dad_anim = _play_glb_anim(dad_model, ["emote-yes", "idle"])

	# Сюрпризы на голове у Папы после выныривания (100% настоящие 3D-модели!)
	var hats_root := Node3D.new()
	hats_root.position = Vector3(0.0, 1.62, 0.0)
	_dad_visual.add_child(hats_root)

	# 1. Резиновая уточка (Khronos Duck.glb)
	var hat_duck := Node3D.new()
	hat_duck.visible = false
	hats_root.add_child(hat_duck)
	_instantiate_glb("res://assets/models/duck.glb", hat_duck, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.35)
	_dad_hats.append(hat_duck)

	# 2. Сундук с сокровищами (Kenney chest.glb)
	var hat_chest := Node3D.new()
	hat_chest.visible = false
	hats_root.add_child(hat_chest)
	_instantiate_glb("res://assets/models/chest.glb", hat_chest, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 0.82, true)
	_dad_hats.append(hat_chest)

	# 3. Живой крабик на голове (Kenney animal-crab.glb)
	var hat_crab := Node3D.new()
	hat_crab.visible = false
	hats_root.add_child(hat_crab)
	var cr_inst := _instantiate_glb("res://assets/models/animal-crab.glb", hat_crab, Vector3(0.0, 0.08, 0.0), Vector3.ZERO, Vector3.ONE * 0.32, true)
	_play_glb_anim(cr_inst, ["dance", "idle"])
	_dad_hats.append(hat_crab)

	# 4. Яркая рыбка на голове (Kenney animal-fish.glb)
	var hat_fish := Node3D.new()
	hat_fish.visible = false
	hats_root.add_child(hat_fish)
	var fi_inst := _instantiate_glb("res://assets/models/animal-fish.glb", hat_fish, Vector3(0.0, 0.06, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.32, true)
	_play_glb_anim(fi_inst, ["dance", "idle"])
	_dad_hats.append(hat_fish)

	# 5. Полосатый морской буёк (Kenney buoy.glb)
	var hat_buoy := Node3D.new()
	hat_buoy.visible = false
	hats_root.add_child(hat_buoy)
	_instantiate_glb("res://assets/models/buoy.glb", hat_buoy, Vector3(0.0, -0.05, 0.0), Vector3.ZERO, Vector3.ONE * 0.32, true)
	_dad_hats.append(hat_buoy)


func _build_island_crab_3d() -> void:
	# Анимированный крабик на песчаном берегу острова возле лодки
	_island_crab = Node3D.new()
	_island_crab.position = Vector3(-9.2, 0.32, -5.6)
	add_child(_island_crab)
	var crab_inst := _instantiate_glb("res://assets/models/animal-crab.glb", _island_crab, Vector3.ZERO, Vector3(0.0, 35.0, 0.0), Vector3.ONE * 0.38, true)
	_crab_anim = _play_glb_anim(crab_inst, ["idle", "walk"])


func _build_fish_schools_3d() -> void:
	# Стайки анимированных рыбок в море (Kenney animal-fish.glb)
	var fish_spawns = [
		{"pos": Vector3(-4.5, 0.0, -1.0), "dir": Vector3(1, 0, 0.2).normalized(), "speed": 1.4},
		{"pos": Vector3(5.2, 0.0, -1.5), "dir": Vector3(-1, 0, -0.1).normalized(), "speed": 1.6},
		{"pos": Vector3(0.5, 0.0, -5.5), "dir": Vector3(0.4, 0, 1).normalized(), "speed": 1.5}
	]
	for sp in fish_spawns:
		var fnode := Node3D.new()
		fnode.position = sp["pos"]
		add_child(fnode)
		var finst := _instantiate_glb("res://assets/models/animal-fish.glb", fnode, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 0.34, true)
		var anim := _play_glb_anim(finst, ["run", "walk", "idle"])
		fishes.append({
			"node": fnode,
			"pos": sp["pos"],
			"dir": sp["dir"],
			"speed": sp["speed"],
			"anim": anim,
			"jump_t": 0.0,
			"spin": 0.0
		})


func _build_boats_and_birds_3d() -> void:
	# Разнообразный морской флот (Kenney: океанский лайнер, скоростной катер, буксир)
	# 1. Большой круизный лайнер на горизонте
	var liner := Node3D.new()
	liner.position = Vector3(-12.0, 0.0, -18.5)
	add_child(liner)
	_instantiate_glb("res://assets/models/ship-ocean-liner.glb", liner, Vector3(0.0, -0.18, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.32, true)
	boats.append({
		"node": liner,
		"x": -12.0,
		"z": -18.5,
		"dir": 1.0,
		"speed": 1.4,
		"type": "liner",
		"bounce": 0.0
	})

	# 2. Скоростной катер
	var speedboat := Node3D.new()
	speedboat.position = Vector3(12.0, 0.0, -15.5)
	add_child(speedboat)
	_instantiate_glb("res://assets/models/boat-speed-a.glb", speedboat, Vector3(0.0, -0.08, 0.0), Vector3(0.0, -90.0, 0.0), Vector3.ONE * 0.65, true)
	boats.append({
		"node": speedboat,
		"x": 12.0,
		"z": -15.5,
		"dir": -1.0,
		"speed": 2.8,
		"type": "speedboat",
		"bounce": 0.0
	})

	# 3. Буксирчик
	var tug := Node3D.new()
	tug.position = Vector3(-6.0, 0.0, -16.8)
	add_child(tug)
	_instantiate_glb("res://assets/models/boat-tug-a.glb", tug, Vector3(0.0, -0.12, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.58, true)
	boats.append({
		"node": tug,
		"x": -6.0,
		"z": -16.8,
		"dir": 1.0,
		"speed": 1.8,
		"type": "tug",
		"bounce": 0.0
	})

	# Птицы в небе (Flamingo.glb, Parrot.glb, Stork.glb с готовыми анимациями полёта!)
	var flamingo := Node3D.new()
	flamingo.position = Vector3(-11.0, 4.8, -7.5)
	add_child(flamingo)
	var fl_inst := _instantiate_glb("res://assets/models/Flamingo.glb", flamingo, Vector3.ZERO, Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.016)
	_play_glb_anim(fl_inst, ["fly", "take"])
	birds.append({"node": flamingo, "x": -11.0, "y": 4.8, "z": -7.5, "dir": 1.0, "speed": 2.8})

	var parrot := Node3D.new()
	parrot.position = Vector3(11.0, 4.2, -6.0)
	add_child(parrot)
	var pr_inst := _instantiate_glb("res://assets/models/Parrot.glb", parrot, Vector3.ZERO, Vector3(0.0, -90.0, 0.0), Vector3.ONE * 0.016)
	_play_glb_anim(pr_inst, ["fly", "take"])
	birds.append({"node": parrot, "x": 11.0, "y": 4.2, "z": -6.0, "dir": -1.0, "speed": 3.2})

	var stork := Node3D.new()
	stork.position = Vector3(0.0, 5.4, -9.5)
	add_child(stork)
	var st_inst := _instantiate_glb("res://assets/models/Stork.glb", stork, Vector3.ZERO, Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.016)
	_play_glb_anim(st_inst, ["storkFly_B_", "fly"])
	birds.append({"node": stork, "x": 0.0, "y": 5.4, "z": -9.5, "dir": 1.0, "speed": 2.6})


func _setup_ui_overlay() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_ui_canvas = Node2D.new()
	_ui_canvas.draw.connect(_draw_ui_overlay)
	canvas.add_child(_ui_canvas)


func _draw_ui_overlay() -> void:
	var hb := Vector2(65, 62)
	_ui_canvas.draw_circle(hb, 36.0, Color(1, 1, 1, 0.94))
	_ui_canvas.draw_arc(hb, 36.0, 0, TAU, 28, Color("#0984E3"), 4.0, true)
	_ui_canvas.draw_rect(Rect2(hb.x - 14, hb.y - 2, 28, 20), Color("#0984E3"))
	_ui_canvas.draw_colored_polygon(PackedVector2Array([
		hb + Vector2(-21, 0),
		hb + Vector2(0, -19),
		hb + Vector2(21, 0)
	]), Color("#FF7675"))
	_ui_canvas.draw_rect(Rect2(hb.x - 5, hb.y + 6, 10, 12), Color("#FFF9E6"))


func _process(delta: float) -> void:
	world_time += delta

	# Движение облаков по небу
	for c in clouds:
		var spd: float = float(c.get_meta("speed", 0.4))
		c.position.x += spd * delta
		if c.position.x > 26.0:
			c.position.x = -26.0

	# Анимация крабика на острове
	if _crab_bounce > 0.0:
		_crab_bounce = maxf(0.0, _crab_bounce - delta * 3.5)
	if _island_crab != null:
		_island_crab.position.y = 0.32 + sin(_crab_bounce * PI) * 0.65

	if wheel_spin_boost > 0.0:
		wheel_spin_boost = maxf(0.0, wheel_spin_boost - delta * 2.2)
		wheel_angle += delta * 15.0 * wheel_spin_boost

	if girl_bounce > 0.0:
		girl_bounce = maxf(0.0, girl_bounce - delta * 3.0)

	if _duck_bounce > 0.0:
		_duck_bounce = maxf(0.0, _duck_bounce - delta * 3.0)

	if _floating_duck != null:
		var dx := _floating_duck.position.x
		var dz := _floating_duck.position.z
		_floating_duck.position.y = _get_wave_height(dx, dz) + _duck_bounce * 0.55
		_floating_duck.rotation.y += delta * (6.0 if _duck_bounce > 0.0 else 0.5)

	if _target_ring != null:
		if _target_ring_timer > 0.0:
			_target_ring_timer = maxf(0.0, _target_ring_timer - delta)
			_target_ring.visible = true
			var s := 1.0 + (0.6 - _target_ring_timer) * 1.5
			_target_ring.scale = Vector3(s, 1.0, s)
		else:
			_target_ring.visible = false

	# 1. Движение девочки на круге
	if swim_to_dad and dad_state == DadState.WAITING:
		girl_target = dad_pos

	var to_target := girl_target - girl_pos
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > 0.15:
		var dir := to_target / dist
		for isl in islands:
			var ipos: Vector3 = isl["pos"]
			var safe_r: float = float(isl["radius"]) + 1.60
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

		var target_yaw := atan2(dir.x, dir.z)
		var yaw_diff := wrapf(target_yaw - girl_yaw, -PI, PI)
		girl_yaw = lerp_angle(girl_yaw, target_yaw, delta * 6.5)

		var max_spd := 7.6 if swim_to_dad else 6.2
		var speed := clampf(dist * 2.8, 2.6, max_spd)
		girl_vel = girl_vel.lerp(dir * speed, delta * 6.0)
		girl_pos += girl_vel * delta

		_wheel_pivot.rotation.y = clampf(yaw_diff * 1.6, -1.2, 1.2) + wheel_angle

		if _girl_anim != null and _girl_anim.current_animation != "drive":
			_girl_anim.play("drive")

		_foam_cooldown -= delta
		if _foam_cooldown <= 0.0:
			_foam_cooldown = 0.16
			_spawn_3d_particle(
				girl_pos - dir * 1.05 + Vector3(randf_range(-0.25, 0.25), 0.08, randf_range(-0.25, 0.25)),
				Vector3(0.0, 0.22, 0.0),
				Color(1, 1, 1, 0.85),
				0.38,
				false,
				1.0
			)
	else:
		girl_vel = girl_vel.lerp(Vector3.ZERO, delta * 6.0)
		_wheel_pivot.rotation.y = wheel_angle
		if _girl_anim != null and _girl_anim.current_animation == "drive":
			_girl_anim.play("sit" if _girl_anim.has_animation("sit") else "idle")

	# Коллизия с островами
	var prev_pos := girl_pos
	girl_pos = _push_out_of_islands(girl_pos, 1.55)
	if girl_pos.distance_to(prev_pos) > 0.0005:
		for isl in islands:
			var ipos: Vector3 = isl["pos"]
			var away := girl_pos - ipos
			away.y = 0.0
			if away.length() <= float(isl["radius"]) + 1.60 and away.length() > 0.001:
				var n_out := away.normalized()
				var vn := girl_vel.dot(n_out)
				if vn < 0.0:
					girl_vel -= n_out * vn
		if girl_pos.distance_to(girl_target) < 0.65:
			girl_vel = Vector3.ZERO
			girl_target = girl_pos

	# 2. Физика буйков-бамперов и столкновение с кругом девочки
	_update_buoys_physics(delta)

	var girl_wave_y := _get_wave_height(girl_pos.x, girl_pos.z)
	_girl_root.position = Vector3(
		girl_pos.x,
		girl_wave_y + girl_bounce * 0.42,
		girl_pos.z
	)
	_girl_visual.rotation.y = girl_yaw
	_girl_visual.rotation.z = sin(world_time * 3.0) * 0.07
	_girl_visual.rotation.x = cos(world_time * 2.6) * 0.06

	# Камера от 3-го лица
	var desired_cam_pos := Vector3(girl_pos.x * 0.78, 5.4, girl_pos.z + 7.2)
	var desired_look := Vector3(
		lerpf(girl_pos.x, dad_pos.x, 0.35),
		0.45,
		lerpf(girl_pos.z, dad_pos.z, 0.40) - 0.8
	)
	_cam_pos = _cam_pos.lerp(desired_cam_pos, delta * 4.5)
	_cam_look = _cam_look.lerp(desired_look, delta * 5.5)
	_camera.look_at_from_position(_cam_pos, _cam_look, Vector3.UP)

	# Купание Папы при сближении вплотную
	if dad_state == DadState.WAITING and girl_pos.distance_to(dad_pos) <= 2.55:
		_splash_dad_3d()

	_update_dad_3d(delta)
	_update_fishes_3d(delta)
	_update_boats_and_birds(delta)
	_update_water_jets(delta)

	# Обновление 3D-партиклов
	for i in range(fx_particles.size() - 1, -1, -1):
		var p: Dictionary = fx_particles[i]
		p["life"] -= delta
		var pnode: MeshInstance3D = p["node"]
		if p["life"] <= 0.0:
			pnode.queue_free()
			fx_particles.remove_at(i)
		else:
			if p["gravity"]:
				p["vel"].y -= 13.5 * delta
			pnode.position += p["vel"] * delta
			var ratio: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
			pnode.scale = Vector3.ONE * (ratio * float(p["base_scale"]))


func _update_buoys_physics(delta: float) -> void:
	for b in buoys:
		var bnode: Node3D = b["node"]
		var bpos: Vector3 = b["pos"]
		var wave_y := _get_wave_height(bpos.x, bpos.z)

		# Пружинный возврат качания буйка
		var wob: Vector2 = b["wobble"]
		var wob_vel: Vector2 = b["wobble_vel"]
		wob_vel += -wob * 22.0 * delta - wob_vel * 4.2 * delta
		wob += wob_vel * delta
		b["wobble"] = wob
		b["wobble_vel"] = wob_vel

		bnode.position = Vector3(bpos.x, wave_y, bpos.z)
		bnode.rotation_degrees = Vector3(
			wob.x + sin(world_time * 2.8 + bpos.x) * 6.0,
			0.0,
			wob.y + cos(world_time * 2.4 + bpos.z) * 6.0
		)

		# Столкновение круга девочки с буйком (упругий бампер!)
		var to_girl := girl_pos - bpos
		to_girl.y = 0.0
		var d := to_girl.length()
		var min_dist := float(b["radius"]) + 1.25
		if d < min_dist and d > 0.01:
			var n := to_girl / d
			# Отталкиваем девочку
			girl_pos = bpos + n * min_dist
			girl_vel = girl_vel.bounce(n) * 0.65 + n * 4.2
			girl_bounce = 1.0

			# Раскачиваем буёк в сторону удара
			b["wobble_vel"] += Vector2(-n.z, n.x) * 45.0

			_bell_player.pitch_scale = randf_range(0.95, 1.15)
			_bell_player.play()
			_boing_player.pitch_scale = randf_range(1.0, 1.2)
			_boing_player.play()
			Input.vibrate_handheld(35)

			_spawn_splash_3d(bpos + n * 0.8, 10, Color("#E3F9FF"))


func _update_dad_3d(delta: float) -> void:
	var dad_wave_y := _get_wave_height(dad_pos.x, dad_pos.z)

	match dad_state:
		DadState.WAITING:
			_dad_root.visible = true
			_dad_root.position = Vector3(dad_pos.x, dad_wave_y, dad_pos.z)
			_dad_visual.scale = _dad_visual.scale.lerp(Vector3.ONE, delta * 8.0)
			var look_to_cam := (_cam_pos - dad_pos).normalized()
			_dad_visual.rotation.y = lerp_angle(_dad_visual.rotation.y, atan2(look_to_cam.x, look_to_cam.z), delta * 6.0)

		DadState.DIVING:
			dad_timer -= delta
			var t := clampf(dad_timer / 0.40, 0.0, 1.0)
			_dad_root.position = Vector3(dad_pos.x, dad_wave_y + (1.0 - t) * -2.4, dad_pos.z)
			_dad_visual.scale = Vector3.ONE * t
			_dad_visual.rotation.y += delta * 12.0
			if dad_timer <= 0.0:
				_dad_root.visible = false
				dad_state = DadState.UNDERWATER
				dad_timer = 1.55
				bubble_trail_pos = dad_pos

				var found := false
				for attempt in range(40):
					var cand := Vector3(
						randf_range(SEA_MIN_X + 2.5, SEA_MAX_X - 2.5),
						0.0,
						randf_range(SEA_MIN_Z + 2.5, SEA_MAX_Z - 1.5)
					)
					var d_girl := cand.distance_to(girl_pos)
					if d_girl >= 5.0 and d_girl <= 14.5 and _is_valid_dad_spawn(dad_pos, cand, 2.1):
						dad_next_pos = cand
						found = true
						break
				if not found:
					dad_next_pos = _push_out_of_islands(Vector3(0.0, 0.0, 0.0), 2.2)

		DadState.UNDERWATER:
			dad_timer -= delta
			var progress := 1.0 - clampf(dad_timer / 1.55, 0.0, 1.0)
			bubble_trail_pos = _push_out_of_islands(dad_pos.lerp(dad_next_pos, progress), 1.4)

			_glug_cooldown -= delta
			if _glug_cooldown <= 0.0:
				_glug_cooldown = 0.15
				_glug_player.pitch_scale = randf_range(0.9, 1.25)
				_glug_player.play()
				for b in range(2):
					_spawn_3d_particle(
						bubble_trail_pos + Vector3(randf_range(-0.35, 0.35), 0.12, randf_range(-0.35, 0.35)),
						Vector3(0.0, randf_range(0.7, 1.3), 0.0),
						Color(1.0, 1.0, 1.0, 0.92),
						0.5,
						false,
						1.35
					)

			if dad_timer <= 0.0:
				dad_pos = _push_out_of_islands(dad_next_pos, 2.0)
				dad_state = DadState.EMERGING
				dad_timer = 0.40
				_dad_root.visible = true

				dad_hat_idx = (dad_hat_idx + 1) % (_dad_hats.size() + 1)
				for i in range(_dad_hats.size()):
					_dad_hats[i].visible = (i + 1 == dad_hat_idx)

				_slide_player.pitch_scale = randf_range(0.95, 1.15)
				_slide_player.play()
				_splash_player.pitch_scale = 1.12
				_splash_player.play()
				_spawn_splash_3d(dad_pos, 14, Color("#E3F9FF"))

		DadState.EMERGING:
			dad_timer -= delta
			var t := 1.0 - clampf(dad_timer / 0.40, 0.0, 1.0)
			_dad_root.position = Vector3(dad_pos.x, dad_wave_y + sin(t * PI) * 0.85, dad_pos.z)
			_dad_visual.scale = Vector3.ONE * clampf(t * 1.2, 0.1, 1.12)
			if dad_timer <= 0.0:
				_dad_visual.scale = Vector3.ONE
				dad_state = DadState.WAITING
				if _dad_anim != null:
					_dad_anim.play("emote-yes")


func _update_fishes_3d(delta: float) -> void:
	for f in fishes:
		var fnode: Node3D = f["node"]
		var fpos: Vector3 = f["pos"]
		var dir: Vector3 = f["dir"]
		var spd: float = float(f["speed"])

		fpos += dir * spd * delta
		# Разворот у границ моря
		if fpos.x < SEA_MIN_X + 2.0 or fpos.x > SEA_MAX_X - 2.0:
			dir.x = -dir.x
		if fpos.z < SEA_MIN_Z + 2.0 or fpos.z > SEA_MAX_Z - 2.0:
			dir.z = -dir.z
		f["dir"] = dir
		f["pos"] = fpos

		var wave_y := _get_wave_height(fpos.x, fpos.z)
		var jump_t: float = float(f["jump_t"])
		if jump_t > 0.0:
			jump_t = maxf(0.0, jump_t - delta * 1.8)
			f["jump_t"] = jump_t
			fnode.position = Vector3(fpos.x, wave_y + sin(jump_t * PI) * 1.25, fpos.z)
			fnode.rotation.x = (jump_t - 0.5) * 1.8
		else:
			fnode.position = Vector3(fpos.x, wave_y - 0.06, fpos.z)
			fnode.rotation.x = 0.0

		fnode.rotation.y = atan2(dir.x, dir.z)

		# Если девочка подплыла близко — рыбка весело выпрыгивает над волной!
		if girl_pos.distance_to(fpos) < 2.6 and jump_t <= 0.0:
			f["jump_t"] = 1.0
			_splash_player.pitch_scale = randf_range(1.15, 1.35)
			_splash_player.play()
			_spawn_splash_3d(fpos, 8, Color("#81D4FA"))


func _update_boats_and_birds(delta: float) -> void:
	for b in boats:
		b["x"] += float(b["dir"]) * float(b["speed"]) * delta
		if float(b["dir"]) > 0.0 and float(b["x"]) > 22.0:
			b["x"] = -22.0
		elif float(b["dir"]) < 0.0 and float(b["x"]) < -22.0:
			b["x"] = 22.0
		if float(b["bounce"]) > 0.0:
			b["bounce"] = maxf(0.0, float(b["bounce"]) - delta * 2.5)

		var bnode: Node3D = b["node"]
		var bx: float = b["x"]
		var bz: float = b["z"]
		bnode.position = Vector3(
			bx,
			_get_wave_height(bx, bz) + float(b["bounce"]) * 0.35,
			bz
		)
		bnode.rotation.z = sin(world_time * 2.6 + bx) * 0.07

	for br in birds:
		br["x"] += float(br["dir"]) * float(br["speed"]) * delta
		if float(br["dir"]) > 0.0 and float(br["x"]) > 24.0:
			br["x"] = -24.0
		elif float(br["dir"]) < 0.0 and float(br["x"]) < -24.0:
			br["x"] = 24.0
		var br_node: Node3D = br["node"]
		br_node.position = Vector3(
			float(br["x"]),
			float(br["y"]) + sin(world_time * 2.5 + float(br["x"])) * 0.25,
			float(br["z"])
		)


func _update_water_jets(delta: float) -> void:
	for i in range(water_jets.size() - 1, -1, -1):
		var jet: Dictionary = water_jets[i]
		jet["life"] -= delta
		var pnode: MeshInstance3D = jet["node"]
		if jet["life"] <= 0.0:
			pnode.queue_free()
			water_jets.remove_at(i)
		else:
			jet["vel"].y -= 11.0 * delta
			pnode.position += jet["vel"] * delta
			# Проверяем попадание брызг в Папу!
			if dad_state == DadState.WAITING and pnode.position.distance_to(dad_pos) <= 2.2:
				pnode.queue_free()
				water_jets.remove_at(i)
				_splash_dad_3d()
				break


func _fire_water_jet() -> void:
	_squeak_player.pitch_scale = randf_range(1.05, 1.25)
	_squeak_player.play()
	wheel_spin_boost = 1.0
	girl_bounce = 0.85

	if _girl_anim != null:
		_girl_anim.play("emote-yes")

	var forward := Vector3(sin(girl_yaw), 0.0, cos(girl_yaw))
	var nozzle_pos := girl_pos + forward * 1.15 + Vector3(0.0, 0.45, 0.0)

	# Запускаем дугу сверкающих капель воды вперёд
	for i in range(8):
		var spread := Vector3(randf_range(-0.15, 0.15), randf_range(-0.08, 0.12), randf_range(-0.15, 0.15))
		var v := (forward + spread).normalized() * randf_range(6.5, 9.2)
		v.y += randf_range(2.8, 4.4)

		var mi := MeshInstance3D.new()
		mi.mesh = _sphere_mesh_small
		mi.material_override = _make_unshaded_mat(Color("#48DBFB"))
		mi.position = nozzle_pos
		mi.scale = Vector3.ONE * randf_range(0.8, 1.3)
		add_child(mi)

		water_jets.append({
			"node": mi,
			"vel": v,
			"life": 0.95
		})


func _splash_dad_3d() -> void:
	if dad_state != DadState.WAITING:
		return

	swim_to_dad = false
	dad_state = DadState.DIVING
	dad_timer = 0.40
	girl_bounce = 1.0
	wheel_spin_boost = 1.0

	if _dad_anim != null and _dad_anim.has_animation("die"):
		_dad_anim.play("die")

	_splash_player.pitch_scale = randf_range(0.92, 1.08)
	_splash_player.play()
	_laugh_player.pitch_scale = randf_range(0.95, 1.08)
	_laugh_player.play()
	Input.vibrate_handheld(45)

	_spawn_splash_3d(dad_pos, 16, Color.WHITE)
	_spawn_splash_3d(girl_pos + Vector3(0, 1.1, 0), 8, Color("#FFD32A"))


func _spawn_splash_3d(origin: Vector3, count: int, col: Color) -> void:
	for i in range(count):
		var a := randf() * TAU
		var h_speed := randf_range(1.4, 4.2)
		var v_speed := randf_range(3.8, 6.8)
		_spawn_3d_particle(
			origin + Vector3(0.0, 0.25, 0.0),
			Vector3(cos(a) * h_speed, v_speed, sin(a) * h_speed),
			col,
			randf_range(0.35, 0.55),
			true,
			randf_range(0.85, 1.35)
		)


func _spawn_3d_particle(pos: Vector3, vel: Vector3, col: Color, life: float, gravity: bool, base_scale: float = 1.0) -> void:
	if fx_particles.size() >= 24:
		var oldest: Dictionary = fx_particles[0]
		var old_node: MeshInstance3D = oldest["node"]
		old_node.queue_free()
		fx_particles.remove_at(0)
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere_mesh_small
	mi.material_override = _make_unshaded_mat(col)
	mi.position = pos
	mi.scale = Vector3.ONE * base_scale
	add_child(mi)
	fx_particles.append({
		"node": mi,
		"vel": vel,
		"life": life,
		"max_life": life,
		"gravity": gravity,
		"base_scale": base_scale
	})


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_screen_touch(event.position, false)
	elif event is InputEventScreenDrag:
		_handle_screen_touch(event.position, true)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_screen_touch(event.position, false)


func _handle_screen_touch(screen_pt: Vector2, is_drag: bool) -> void:
	# 1. Кнопка "Домик" в левом верхнем углу
	if not is_drag and screen_pt.distance_to(Vector2(65, 62)) <= 45.0:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return

	# 2. Нажатие на Папу в воде
	if dad_state == DadState.WAITING and _camera.is_position_in_frustum(_dad_root.global_position):
		var dad_screen := _camera.unproject_position(_dad_root.global_position + Vector3(0, 0.6, 0))
		if screen_pt.distance_to(dad_screen) <= 105.0:
			if girl_pos.distance_to(dad_pos) <= 3.2:
				_splash_dad_3d()
			else:
				swim_to_dad = true
				girl_target = dad_pos
				_target_ring.position = Vector3(dad_pos.x, 0.12, dad_pos.z)
				_target_ring_timer = 0.6
				if not is_drag:
					_squeak_player.pitch_scale = 1.08
					_squeak_player.play()
			return

	# 3. Нажатие на Девочку / круг / руль — ВОДЯНАЯ ПУШКА!
	if not is_drag and _camera.is_position_in_frustum(_girl_root.global_position):
		var girl_screen := _camera.unproject_position(_girl_root.global_position + Vector3(0, 0.6, 0))
		if screen_pt.distance_to(girl_screen) <= 80.0:
			_fire_water_jet()
			return

	# 4. Нажатие на крабика на пляже острова
	if not is_drag and _island_crab != null and _camera.is_position_in_frustum(_island_crab.global_position):
		var crab_screen := _camera.unproject_position(_island_crab.global_position + Vector3(0, 0.3, 0))
		if screen_pt.distance_to(crab_screen) <= 75.0:
			_crab_bounce = 1.0
			if _crab_anim != null and _crab_anim.has_animation("dance"):
				_crab_anim.play("dance")
			_tap_player.pitch_scale = randf_range(1.1, 1.3)
			_tap_player.play()
			_spawn_splash_3d(_island_crab.global_position, 8, Color("#FFEAA7"))
			return

	# 5. Нажатие на буйки-бамперы в море
	if not is_drag:
		for b in buoys:
			var bnode: Node3D = b["node"]
			if _camera.is_position_in_frustum(bnode.global_position):
				var b_screen := _camera.unproject_position(bnode.global_position + Vector3(0, 0.4, 0))
				if screen_pt.distance_to(b_screen) <= 75.0:
					b["wobble_vel"] += Vector2(randf_range(-35, 35), randf_range(-35, 35))
					_bell_player.pitch_scale = randf_range(1.0, 1.25)
					_bell_player.play()
					_spawn_splash_3d(bnode.global_position, 8, Color("#E3F9FF"))
					return

	# 6. Нажатие на плавающую 3D-уточку
	if not is_drag and _floating_duck != null and _camera.is_position_in_frustum(_floating_duck.global_position):
		var duck_screen := _camera.unproject_position(_floating_duck.global_position)
		if screen_pt.distance_to(duck_screen) <= 70.0:
			_duck_bounce = 1.0
			_squeak_player.pitch_scale = 1.25
			_squeak_player.play()
			_spawn_splash_3d(_floating_duck.global_position, 10, Color("#FFD32A"))
			return

	# 7. Нажатие на стайку рыбок
	if not is_drag:
		for f in fishes:
			var fnode: Node3D = f["node"]
			if _camera.is_position_in_frustum(fnode.global_position):
				var f_screen := _camera.unproject_position(fnode.global_position)
				if screen_pt.distance_to(f_screen) <= 75.0:
					f["jump_t"] = 1.0
					var anim: AnimationPlayer = f["anim"]
					if anim != null and anim.has_animation("dance"):
						anim.play("dance")
					_splash_player.pitch_scale = 1.3
					_splash_player.play()
					_spawn_splash_3d(fnode.global_position, 10, Color("#81D4FA"))
					return

	# 8. Нажатие на корабли на горизонте
	if not is_drag:
		for b in boats:
			var bnode: Node3D = b["node"]
			if _camera.is_position_in_frustum(bnode.global_position):
				var b_screen := _camera.unproject_position(bnode.global_position + Vector3(0, 0.5, 0))
				if screen_pt.distance_to(b_screen) <= 85.0:
					b["bounce"] = 1.0
					if b["type"] == "liner":
						_horn_player.pitch_scale = 0.82
					elif b["type"] == "tug":
						_horn_player.pitch_scale = 1.15
					else:
						_horn_player.pitch_scale = 1.35
					_horn_player.play()
					for i in range(6):
						_spawn_3d_particle(
							bnode.global_position + Vector3(0.0, 1.4, 0.0),
							Vector3(randf_range(-0.6, 0.6), randf_range(1.6, 2.8), randf_range(-0.4, 0.4)),
							Color.WHITE,
							0.95,
							false,
							1.7
						)
					return

	# 9. Нажатие или ведение пальчиком по воде — плывём к цели
	var ray_origin := _camera.project_ray_origin(screen_pt)
	var ray_dir := _camera.project_ray_normal(screen_pt)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_dir)
	if hit != null:
		var target_pt: Vector3 = hit
		girl_target = Vector3(
			clampf(target_pt.x, SEA_MIN_X, SEA_MAX_X),
			0.0,
			clampf(target_pt.z, SEA_MIN_Z, SEA_MAX_Z)
		)
		girl_target = _push_out_of_islands(girl_target, 1.45)
		if dad_state == DadState.WAITING and girl_target.distance_to(dad_pos) <= 2.4:
			swim_to_dad = true
			girl_target = dad_pos
		else:
			swim_to_dad = false
		if not is_drag:
			_target_ring.position = Vector3(girl_target.x, 0.10, girl_target.z)
			_target_ring_timer = 0.55

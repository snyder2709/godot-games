extends Node3D

enum DadState { WAITING, DIVING, UNDERWATER, EMERGING }

const SEA_MIN_X := -16.5
const SEA_MAX_X := 16.5
const SEA_MIN_Z := -13.5
const SEA_MAX_Z := 6.5

var world_time: float = 0.0

# 3D Камера (комфортный вид от 3-го лица из-за спины без укачивающего вращения горизонта!)
var _camera: Camera3D
var _ui_canvas: Node2D
var _cam_pos := Vector3(0.0, 5.4, 10.2)
var _cam_look := Vector3(0.0, 0.4, -1.5)

# Шейдеры и текстуры
var _water_shader_mat: ShaderMaterial
var _toon_shader: Shader
var _kenney_colormap: Texture2D

# --- Острова (коллизии для девочки и запретные зоны для появления папы) ---
var islands: Array[Dictionary] = []

# --- Главная героиня: Маленькая девочка в жёлтом круге с рулём ---
var _girl_root: Node3D
var _girl_visual: Node3D
var _wheel_pivot: Node3D
var _girl_head: Node3D
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

# --- Папа в 3D-море ---
var _dad_root: Node3D
var _dad_visual: Node3D
var _dad_left_arm: Node3D
var _dad_right_arm: Node3D
var _dad_hats: Array[Node3D] = []
var dad_pos := Vector3(0.0, 0.0, -2.0)
var dad_next_pos := Vector3(0.0, 0.0, -2.0)
var dad_state: int = DadState.WAITING
var dad_timer: float = 0.0
var dad_hat_idx: int = 0
var bubble_trail_pos := Vector3.ZERO
var _glug_cooldown: float = 0.0

# --- Окружение: Кораблики, Дельфины, Птицы, Уточка ---
var boats: Array[Dictionary] = []
var dolphins: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var _floating_duck: Node3D
var _duck_bounce: float = 0.0
var dolphin_spawn_timer: float = 1.5

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
var _chime_player: AudioStreamPlayer


func _ready() -> void:
	randomize()

	_splash_player = _make_player(SoundGen.get_splash_stream(), 6)
	_laugh_player = _make_player(SoundGen.get_laugh_stream(), 3)
	_squeak_player = _make_player(SoundGen.get_squeak_stream(), 4)
	_horn_player = _make_player(SoundGen.get_boat_horn_stream(), 3)
	_slide_player = _make_player(SoundGen.get_slide_up_stream(), 4)
	_glug_player = _make_player(SoundGen.get_glug_stream(), 4)
	_chime_player = _make_player(SoundGen.get_toy_stream(), 4)

	if ResourceLoader.exists("res://assets/models/Textures/colormap.png"):
		_kenney_colormap = load("res://assets/models/Textures/colormap.png")

	_sphere_mesh_small = SphereMesh.new()
	_sphere_mesh_small.radius = 0.14
	_sphere_mesh_small.height = 0.28
	_sphere_mesh_small.radial_segments = 16
	_sphere_mesh_small.rings = 8

	_init_shaders()
	_setup_environment_and_camera()
	_build_shader_sea_and_islands()
	_build_girl_in_yellow_ring_3d()
	_build_dad_3d()
	_build_boats_and_birds_3d()
	_setup_ui_overlay()


func _make_player(stream: AudioStream, polyphony: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.max_polyphony = polyphony
	add_child(p)
	return p


## Выталкивает точку (девочку или цель клика) за пределы всех островов
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


## Проверяет, не попадает ли точка или подводный маршрут Папы внутрь острова
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


## Загружает .glb модель и при необходимости накладывает яркую текстуру палитры Kenney
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


func _play_glb_anim(node: Node3D, preferred_names: Array[String]) -> void:
	if node == null:
		return
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
					return
		if list.size() > 0:
			var first_anim := ap.get_animation(list[0])
			if first_anim:
				first_anim.loop_mode = Animation.LOOP_LINEAR
			ap.play(list[0])
			return


func _init_shaders() -> void:
	_toon_shader = Shader.new()
	_toon_shader.code = """
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.32;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.85, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.38;

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.35;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * fresnel * rim_strength;
}
"""

	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.82, 0.96, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.48, 0.88, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.99, 1.0, 1.0);

varying float v_wave_h;
varying vec3 v_world_pos;

float wave_func(vec2 p, float t) {
	float w1 = sin(p.x * 0.8 + t * 2.0) * cos(p.y * 0.7 + t * 1.6) * 0.12;
	float w2 = sin((p.x + p.y) * 1.3 - t * 2.4) * 0.06;
	return w1 + w2;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = wave_func(v_world_pos.xz, TIME);
	VERTEX.y += h;
	v_wave_h = h;

	float eps = 0.15;
	float hx = wave_func(v_world_pos.xz + vec2(eps, 0.0), TIME);
	float hz = wave_func(v_world_pos.xz + vec2(0.0, eps), TIME);
	NORMAL = normalize(vec3(h - hx, eps, h - hz));
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	vec3 water_col = mix(shallow_color.rgb, deep_color.rgb, clamp(fresnel * 0.85 + 0.15, 0.0, 1.0));

	vec2 uv_p = v_world_pos.xz * 1.25;
	float caustic = sin(uv_p.x * 2.8 + TIME * 2.2) * sin(uv_p.y * 2.8 - TIME * 1.9);
	caustic = smoothstep(0.58, 0.92, caustic) * 0.25;

	float crest_foam = smoothstep(0.10, 0.19, v_wave_h);
	vec3 final_col = mix(water_col + vec3(caustic), foam_color.rgb, crest_foam * 0.55);

	ALBEDO = final_col;
	ROUGHNESS = 0.10;
	METALLIC = 0.10;
	SPECULAR = 0.80;
}
"""
	_water_shader_mat = ShaderMaterial.new()
	_water_shader_mat.shader = water_shader


func _make_toon_mat(col: Color, rough: float = 0.32) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = _toon_shader
	sm.set_shader_parameter("albedo_color", col)
	sm.set_shader_parameter("roughness_val", rough)
	return sm


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
	env.ambient_light_energy = 0.88
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
	sun.light_color = Color("#FFF9E6")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.look_at_from_position(_cam_pos, _cam_look, Vector3.UP)
	add_child(_camera)


func _build_shader_sea_and_islands() -> void:
	var sea_plane := PlaneMesh.new()
	sea_plane.size = Vector2(150.0, 150.0)
	sea_plane.subdivide_width = 140
	sea_plane.subdivide_depth = 140
	_add_mesh(self, sea_plane, _water_shader_mat, Vector3.ZERO)

	# Просторное море и 3 живописных тропических острова (с точными твёрдыми берегами-коллизиями!)
	_create_glb_island(Vector3(-10.8, -0.05, -6.5), 3.4, true)
	_create_glb_island(Vector3(11.0, -0.05, -6.0), 3.5, false)
	_create_glb_island(Vector3(-0.4, -0.05, -11.8), 3.0, false)

	# Настоящая 3D жёлтая резиновая уточка (duck.glb), плавающая на волнах
	_floating_duck = Node3D.new()
	_floating_duck.position = Vector3(-4.2, 0.0, 1.5)
	add_child(_floating_duck)
	_instantiate_glb("res://assets/models/duck.glb", _floating_duck, Vector3(0.0, -0.08, 0.0), Vector3(0.0, 45.0, 0.0), Vector3.ONE * 0.48)

	# Объёмные облака
	_create_fluffy_cloud(Vector3(-15.0, 10.5, -26.0), 1.4)
	_create_fluffy_cloud(Vector3(1.5, 11.5, -29.0), 1.7)
	_create_fluffy_cloud(Vector3(16.0, 10.0, -25.0), 1.3)

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
	# Регистрируем остров в списке коллизий (с запасом под береговую линию)
	islands.append({
		"pos": Vector3(pos.x, 0.0, pos.z),
		"radius": radius + 0.25
	})

	var isl := Node3D.new()
	isl.position = pos
	add_child(isl)

	# Песчаный купол острова (строго радиуса radius)
	var sand_dome := SphereMesh.new()
	sand_dome.radius = radius
	sand_dome.height = radius * 0.52
	_add_mesh(isl, sand_dome, _make_toon_mat(Color("#FFEAA7"), 0.75), Vector3(0.0, 0.05, 0.0))

	# Прибойная пена вокруг берега острова
	var shore_foam := TorusMesh.new()
	shore_foam.inner_radius = radius * 0.90
	shore_foam.outer_radius = radius * 1.05
	_add_mesh(isl, shore_foam, _make_unshaded_mat(Color(1.0, 1.0, 1.0, 0.55)), Vector3(0.0, 0.06, 0.0))

	# Внимание: родной размер patch-sand-foliage.glb равен ±3.87 по X и ±3.02 по Z!
	# Масштабируем так, чтобы листва и песок идеально помещались ВНУТРИ радиуса острова!
	var patch_scale := (radius * 0.78) / 3.87
	_instantiate_glb("res://assets/models/patch-sand-foliage.glb", isl, Vector3(0.0, 0.36, 0.0), Vector3.ZERO, Vector3.ONE * patch_scale, true)

	# Родной размер пальм ~4.25 в высоту, ставим масштаб ~1.05 внутри острова
	_instantiate_glb("res://assets/models/palm-detailed-bend.glb", isl, Vector3(-radius * 0.30, 0.42, 0.15), Vector3(0.0, 35.0, 0.0), Vector3.ONE * 1.08, true)
	_instantiate_glb("res://assets/models/palm-detailed-straight.glb", isl, Vector3(radius * 0.28, 0.42, -0.25), Vector3(0.0, -60.0, 0.0), Vector3.ONE * 1.02, true)

	# Родной размер rocks-sand-a.glb равен ±2.70! Масштабируем до 0.45, чтобы камни не вылезали за край острова!
	_instantiate_glb("res://assets/models/rocks-sand-a.glb", isl, Vector3(radius * 0.36, 0.22, radius * 0.24), Vector3(0.0, 120.0, 0.0), Vector3.ONE * 0.45, true)

	if with_tower:
		_instantiate_glb("res://assets/models/tower-complete-small.glb", isl, Vector3(0.15, 0.50, -0.15), Vector3(0.0, 25.0, 0.0), Vector3.ONE * 0.72, true)
		_instantiate_glb("res://assets/models/chest.glb", isl, Vector3(-0.65, 0.52, 0.75), Vector3(0.0, 15.0, 0.0), Vector3.ONE * 0.90, true)
		var boat_offset := Vector3(radius * 0.88, 0.06, radius * 0.45)
		_instantiate_glb("res://assets/models/boat-row-small.glb", isl, boat_offset, Vector3(0.0, 45.0, 0.0), Vector3.ONE * 0.95, true)
		# Коллизия для пришвартованной у берега лодки
		islands.append({
			"pos": Vector3(pos.x + boat_offset.x, 0.0, pos.z + boat_offset.z),
			"radius": 1.25
		})


func _create_fluffy_cloud(pos: Vector3, sc: float) -> void:
	var cl := Node3D.new()
	cl.position = pos
	cl.scale = Vector3.ONE * sc
	add_child(cl)
	var cmat := _make_unshaded_mat(Color(1.0, 1.0, 1.0, 0.92))
	var sph := SphereMesh.new()
	sph.radius = 1.4
	sph.height = 2.2
	_add_mesh(cl, sph, cmat, Vector3.ZERO)
	_add_mesh(cl, sph, cmat, Vector3(-1.3, -0.2, 0.2), Vector3.ZERO, Vector3.ONE * 0.75)
	_add_mesh(cl, sph, cmat, Vector3(1.3, -0.15, -0.1), Vector3.ZERO, Vector3.ONE * 0.8)


func _build_girl_in_yellow_ring_3d() -> void:
	_girl_root = Node3D.new()
	_girl_root.position = girl_pos
	add_child(_girl_root)

	_girl_visual = Node3D.new()
	_girl_visual.rotation.y = girl_yaw
	_girl_root.add_child(_girl_visual)

	# 1. ГЛЯНЦЕВЫЙ ЖЁЛТЫЙ ДЕТСКИЙ КРУГ С БОКОВЫМИ РУЧКАМИ
	var ring_torus := TorusMesh.new()
	ring_torus.inner_radius = 0.50
	ring_torus.outer_radius = 1.15
	ring_torus.rings = 64
	ring_torus.ring_segments = 36
	var yellow_mat := _make_toon_mat(Color("#FFD32A"), 0.12)
	_add_mesh(_girl_visual, ring_torus, yellow_mat, Vector3(0.0, 0.14, 0.0))

	var handle_torus := TorusMesh.new()
	handle_torus.inner_radius = 0.08
	handle_torus.outer_radius = 0.18
	var orange_mat := _make_toon_mat(Color("#FF9F43"), 0.25)
	_add_mesh(_girl_visual, handle_torus, orange_mat, Vector3(-0.82, 0.42, -0.1), Vector3(0, 0, 25))
	_add_mesh(_girl_visual, handle_torus, orange_mat, Vector3(0.82, 0.42, -0.1), Vector3(0, 0, -25))

	# 2. ДЕТСКИЙ РУЛЬ НА КРУГЕ С КРАСНОЙ КНОПКОЙ-БИБИПКОЙ
	var col_mount := Node3D.new()
	col_mount.position = Vector3(0.0, 0.44, 0.76)
	col_mount.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	_girl_visual.add_child(col_mount)

	var dashboard := SphereMesh.new()
	dashboard.radius = 0.22
	dashboard.height = 0.30
	_add_mesh(col_mount, dashboard, orange_mat, Vector3.ZERO)

	var stem := CylinderMesh.new()
	stem.top_radius = 0.07
	stem.bottom_radius = 0.09
	stem.height = 0.38
	_add_mesh(col_mount, stem, _make_toon_mat(Color("#0984E3"), 0.2), Vector3(0.0, 0.18, 0.0))

	_wheel_pivot = Node3D.new()
	_wheel_pivot.position = Vector3(0.0, 0.38, 0.0)
	col_mount.add_child(_wheel_pivot)

	var wheel_torus := TorusMesh.new()
	wheel_torus.inner_radius = 0.26
	wheel_torus.outer_radius = 0.38
	wheel_torus.rings = 48
	wheel_torus.ring_segments = 24
	_add_mesh(_wheel_pivot, wheel_torus, _make_toon_mat(Color("#0984E3"), 0.15), Vector3.ZERO)

	var spoke := CapsuleMesh.new()
	spoke.radius = 0.04
	spoke.height = 0.62
	var light_blue := _make_toon_mat(Color("#48DBFB"), 0.2)
	_add_mesh(_wheel_pivot, spoke, light_blue, Vector3.ZERO, Vector3(0, 0, 90))
	_add_mesh(_wheel_pivot, spoke, light_blue, Vector3.ZERO, Vector3(90, 0, 0))

	var horn_btn := SphereMesh.new()
	horn_btn.radius = 0.13
	horn_btn.height = 0.20
	_add_mesh(_wheel_pivot, horn_btn, _make_toon_mat(Color("#FF3F34"), 0.15), Vector3(0.0, 0.04, 0.0))

	# 3. МИЛАЯ СВЕТЛОВОЛОСАЯ ДЕВОЧКА С ВЫРАЗИТЕЛЬНЫМ 3D-ЛИЧИКОМ В ПАНАМКЕ
	var skin_mat := _make_toon_mat(Color("#FFE0CC"), 0.36)
	var suit_mat := _make_toon_mat(Color("#FF6B81"), 0.32)
	# Светлые золотисто-пшеничные волосы (блонд!)
	var hair_mat := _make_toon_mat(Color("#FDE073"), 0.32)
	var brow_mat := _make_toon_mat(Color("#D4A038"), 0.38)
	var hat_mat := _make_toon_mat(Color("#FFFDF2"), 0.45)

	var torso := CapsuleMesh.new()
	torso.radius = 0.36
	torso.height = 0.85
	_add_mesh(_girl_visual, torso, suit_mat, Vector3(0.0, 0.42, -0.04))

	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.105
	arm_mesh.height = 0.60
	_add_mesh(_girl_visual, arm_mesh, skin_mat, Vector3(-0.30, 0.56, 0.30), Vector3(68.0, -20.0, 0.0))
	_add_mesh(_girl_visual, arm_mesh, skin_mat, Vector3(0.30, 0.56, 0.30), Vector3(68.0, 20.0, 0.0))

	var hand_sph := SphereMesh.new()
	hand_sph.radius = 0.12
	hand_sph.height = 0.24
	_add_mesh(_girl_visual, hand_sph, skin_mat, Vector3(-0.26, 0.66, 0.56))
	_add_mesh(_girl_visual, hand_sph, skin_mat, Vector3(0.26, 0.66, 0.56))

	_girl_head = Node3D.new()
	_girl_head.position = Vector3(0.0, 1.06, -0.04)
	_girl_visual.add_child(_girl_head)

	var head_sph := SphereMesh.new()
	head_sph.radius = 0.44
	head_sph.height = 0.88
	head_sph.radial_segments = 32
	head_sph.rings = 16
	_add_mesh(_girl_head, head_sph, skin_mat)

	# Маленькие аккуратные ушки по бокам головы
	var ear_sph := SphereMesh.new()
	ear_sph.radius = 0.10
	ear_sph.height = 0.20
	_add_mesh(_girl_head, ear_sph, skin_mat, Vector3(-0.42, -0.02, 0.02))
	_add_mesh(_girl_head, ear_sph, skin_mat, Vector3(0.42, -0.02, 0.02))

	# --- ВЫРАЗИТЕЛЬНОЕ 3D-ЛИЧИКО ДЕВОЧКИ (смотрит вперёд по +Z, к рулю!) ---
	var white_mat := _make_toon_mat(Color.WHITE, 0.12)
	var iris_mat := _make_toon_mat(Color("#0984E3"), 0.15)
	var pupil_mat := _make_toon_mat(Color("#1E272E"), 0.10)
	var spark_mat := _make_unshaded_mat(Color.WHITE)
	var cheek_mat := _make_toon_mat(Color("#FF8FA3"), 0.35)
	var nose_mat := _make_toon_mat(Color("#FFCCB3"), 0.35)
	var mouth_mat := _make_toon_mat(Color("#D63031"), 0.28)
	var tongue_mat := _make_toon_mat(Color("#FF7675"), 0.30)

	var sclera_mesh := SphereMesh.new()
	sclera_mesh.radius = 0.098
	sclera_mesh.height = 0.196
	var iris_mesh := SphereMesh.new()
	iris_mesh.radius = 0.068
	iris_mesh.height = 0.136
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.045
	pupil_mesh.height = 0.09
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.022
	spark_mesh.height = 0.044
	var brow_mesh := CapsuleMesh.new()
	brow_mesh.radius = 0.020
	brow_mesh.height = 0.13
	var cheek_mesh := SphereMesh.new()
	cheek_mesh.radius = 0.082
	cheek_mesh.height = 0.13

	for side in [-1.0, 1.0]:
		# Белок глаза, голубая радужка, зрачок и живой белый блик
		_add_mesh(_girl_head, sclera_mesh, white_mat, Vector3(side * 0.155, 0.03, 0.365), Vector3.ZERO, Vector3(1.0, 1.08, 0.65))
		_add_mesh(_girl_head, iris_mesh, iris_mat, Vector3(side * 0.155, 0.03, 0.405), Vector3.ZERO, Vector3(1.0, 1.05, 0.65))
		_add_mesh(_girl_head, pupil_mesh, pupil_mat, Vector3(side * 0.155, 0.03, 0.428), Vector3.ZERO, Vector3(1.0, 1.05, 0.65))
		_add_mesh(_girl_head, spark_mesh, spark_mat, Vector3(side * 0.132, 0.068, 0.452))
		# Бровки домиком
		_add_mesh(_girl_head, brow_mesh, brow_mat, Vector3(side * 0.155, 0.155, 0.39), Vector3(0.0, 0.0, 90.0 - side * 12.0))
		# Румяные розовые щёчки
		_add_mesh(_girl_head, cheek_mesh, cheek_mat, Vector3(side * 0.255, -0.065, 0.345), Vector3.ZERO, Vector3(1.15, 0.85, 0.65))

	# Курносый детский носик-кнопочка
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.062
	nose_mesh.height = 0.12
	_add_mesh(_girl_head, nose_mesh, nose_mat, Vector3(0.0, -0.035, 0.435))

	# Радостная 3D-улыбка с язычком и зубками
	var smile_mesh := SphereMesh.new()
	smile_mesh.radius = 0.105
	smile_mesh.height = 0.14
	_add_mesh(_girl_head, smile_mesh, mouth_mat, Vector3(0.0, -0.16, 0.395), Vector3.ZERO, Vector3(1.25, 0.82, 0.55))

	var tongue_mesh := SphereMesh.new()
	tongue_mesh.radius = 0.058
	tongue_mesh.height = 0.08
	_add_mesh(_girl_head, tongue_mesh, tongue_mat, Vector3(0.0, -0.188, 0.418), Vector3.ZERO, Vector3(1.15, 0.65, 0.60))

	var teeth_mesh := SphereMesh.new()
	teeth_mesh.radius = 0.055
	teeth_mesh.height = 0.05
	_add_mesh(_girl_head, teeth_mesh, white_mat, Vector3(0.0, -0.125, 0.422), Vector3.ZERO, Vector3(1.35, 0.48, 0.50))

	# --- СВЕТЛЫЕ ЗОЛОТИСТЫЕ ВОЛОСЫ: причёска, пышная чёлка спереди, локоны и 2 хвостика ---
	var hair_cap := SphereMesh.new()
	hair_cap.radius = 0.455
	hair_cap.height = 0.86
	_add_mesh(_girl_head, hair_cap, hair_mat, Vector3(0.0, 0.07, -0.06))

	# Пышная светлая чёлка на лбу (чтобы спереди было хорошо видно светлые волосы!)
	var bang_center := CapsuleMesh.new()
	bang_center.radius = 0.095
	bang_center.height = 0.34
	_add_mesh(_girl_head, bang_center, hair_mat, Vector3(0.0, 0.23, 0.35), Vector3(12.0, 0.0, 90.0))

	var bang_side := CapsuleMesh.new()
	bang_side.radius = 0.085
	bang_side.height = 0.26
	_add_mesh(_girl_head, bang_side, hair_mat, Vector3(-0.19, 0.20, 0.32), Vector3(15.0, -24.0, 68.0))
	_add_mesh(_girl_head, bang_side, hair_mat, Vector3(0.19, 0.20, 0.32), Vector3(15.0, 24.0, -68.0))

	# Боковые светлые прядки-локоны у щёчек
	var side_lock := CapsuleMesh.new()
	side_lock.radius = 0.08
	side_lock.height = 0.32
	for side in [-1.0, 1.0]:
		_add_mesh(_girl_head, side_lock, hair_mat, Vector3(side * 0.36, 0.02, 0.20), Vector3(-12.0, 0.0, -side * 14.0))

	# Два пышных светлых хвостика с розовыми бантиками
	for side in [-1.0, 1.0]:
		var pt_pivot := Node3D.new()
		pt_pivot.position = Vector3(side * 0.43, 0.06, -0.14)
		_girl_head.add_child(pt_pivot)

		var bow_sph := SphereMesh.new()
		bow_sph.radius = 0.13
		bow_sph.height = 0.22
		_add_mesh(pt_pivot, bow_sph, suit_mat, Vector3(0.0, 0.06, 0.0))

		var tail_caps := CapsuleMesh.new()
		tail_caps.radius = 0.18
		tail_caps.height = 0.52
		_add_mesh(pt_pivot, tail_caps, hair_mat, Vector3(side * 0.15, -0.07, -0.06), Vector3(18.0, 0.0, -side * 40.0))

	# Летняя панамка чуть сдвинута на макушку, чтобы открывать светлую чёлку и личико
	var brim := CylinderMesh.new()
	brim.top_radius = 0.60
	brim.bottom_radius = 0.66
	brim.height = 0.07
	brim.radial_segments = 32
	_add_mesh(_girl_head, brim, hat_mat, Vector3(0.0, 0.34, -0.05), Vector3(-18.0, 0.0, 0.0))

	var crown_hat := SphereMesh.new()
	crown_hat.radius = 0.42
	crown_hat.height = 0.50
	_add_mesh(_girl_head, crown_hat, hat_mat, Vector3(0.0, 0.42, -0.07), Vector3(-18.0, 0.0, 0.0))

	var ribbon := TorusMesh.new()
	ribbon.inner_radius = 0.35
	ribbon.outer_radius = 0.44
	_add_mesh(_girl_head, ribbon, suit_mat, Vector3(0.0, 0.38, -0.06), Vector3(-18.0, 0.0, 0.0))


func _build_dad_3d() -> void:
	_dad_root = Node3D.new()
	_dad_root.position = dad_pos
	add_child(_dad_root)

	_dad_visual = Node3D.new()
	_dad_root.add_child(_dad_visual)

	var skin_mat := _make_toon_mat(Color("#FFD3B6"), 0.38)
	var hair_mat := _make_toon_mat(Color("#4E342E"), 0.48)
	var vest_mat := _make_toon_mat(Color("#00CEC9"), 0.35)

	# Пенный круг вокруг папы
	var foam_ring := TorusMesh.new()
	foam_ring.inner_radius = 0.78
	foam_ring.outer_radius = 1.04
	_add_mesh(_dad_visual, foam_ring, _make_unshaded_mat(Color(1, 1, 1, 0.55)), Vector3(0.0, 0.05, 0.0))

	var shoulders := CapsuleMesh.new()
	shoulders.radius = 0.52
	shoulders.height = 1.55
	_add_mesh(_dad_visual, shoulders, skin_mat, Vector3(0.0, 0.32, 0.0), Vector3(0, 0, 90))
	_add_mesh(_dad_visual, shoulders, vest_mat, Vector3(0.0, -0.08, 0.0), Vector3(0, 0, 90))

	_dad_left_arm = Node3D.new()
	_dad_left_arm.position = Vector3(-0.68, 0.48, 0.0)
	_dad_visual.add_child(_dad_left_arm)

	_dad_right_arm = Node3D.new()
	_dad_right_arm.position = Vector3(0.68, 0.48, 0.0)
	_dad_visual.add_child(_dad_right_arm)

	var arm_caps := CapsuleMesh.new()
	arm_caps.radius = 0.16
	arm_caps.height = 0.92
	var palm_sph := SphereMesh.new()
	palm_sph.radius = 0.19
	palm_sph.height = 0.38

	_add_mesh(_dad_left_arm, arm_caps, skin_mat, Vector3(-0.28, 0.38, 0.0), Vector3(0, 0, 32))
	_add_mesh(_dad_left_arm, palm_sph, skin_mat, Vector3(-0.50, 0.72, 0.0))

	_add_mesh(_dad_right_arm, arm_caps, skin_mat, Vector3(0.28, 0.38, 0.0), Vector3(0, 0, -32))
	_add_mesh(_dad_right_arm, palm_sph, skin_mat, Vector3(0.50, 0.72, 0.0))

	var head := Node3D.new()
	head.position = Vector3(0.0, 1.18, 0.0)
	_dad_visual.add_child(head)

	var head_sph := SphereMesh.new()
	head_sph.radius = 0.54
	head_sph.height = 1.08
	head_sph.radial_segments = 32
	head_sph.rings = 16
	_add_mesh(head, head_sph, skin_mat)

	var ear_sph := SphereMesh.new()
	ear_sph.radius = 0.14
	ear_sph.height = 0.28
	_add_mesh(head, ear_sph, skin_mat, Vector3(-0.52, 0.0, 0.0))
	_add_mesh(head, ear_sph, skin_mat, Vector3(0.52, 0.0, 0.0))

	var hair_top := SphereMesh.new()
	hair_top.radius = 0.55
	hair_top.height = 0.90
	_add_mesh(head, hair_top, hair_mat, Vector3(0.0, 0.18, -0.08))

	# --- ГУСТАЯ ОБЪЁМНАЯ 3D-БОРОДА ПАПЫ (окладистая борода + бакенбарды + усы) ---
	var beard_main := SphereMesh.new()
	beard_main.radius = 0.49
	beard_main.height = 0.72
	beard_main.radial_segments = 28
	beard_main.rings = 14
	_add_mesh(head, beard_main, hair_mat, Vector3(0.0, -0.22, 0.14), Vector3.ZERO, Vector3(1.06, 0.96, 1.04))

	var beard_chin := SphereMesh.new()
	beard_chin.radius = 0.36
	beard_chin.height = 0.56
	_add_mesh(head, beard_chin, hair_mat, Vector3(0.0, -0.35, 0.30), Vector3.ZERO, Vector3(1.12, 0.92, 0.96))

	var sideburn_mesh := CapsuleMesh.new()
	sideburn_mesh.radius = 0.16
	sideburn_mesh.height = 0.54
	for side in [-1.0, 1.0]:
		_add_mesh(head, sideburn_mesh, hair_mat, Vector3(side * 0.40, -0.08, 0.22), Vector3(18.0, 0.0, side * 16.0))

	var mustache := CapsuleMesh.new()
	mustache.radius = 0.09
	mustache.height = 0.54
	_add_mesh(head, mustache, hair_mat, Vector3(0.0, -0.09, 0.49), Vector3(0, 0, 90))

	var white_eye := SphereMesh.new()
	white_eye.radius = 0.12
	white_eye.height = 0.24
	var pupil := SphereMesh.new()
	pupil.radius = 0.065
	pupil.height = 0.13
	var white_mat := _make_toon_mat(Color.WHITE, 0.15)
	var dark_mat := _make_toon_mat(Color("#2D3436"), 0.15)

	for side in [-1.0, 1.0]:
		_add_mesh(head, white_eye, white_mat, Vector3(side * 0.20, 0.08, 0.45))
		_add_mesh(head, pupil, dark_mat, Vector3(side * 0.20, 0.08, 0.53))

	var nose := SphereMesh.new()
	nose.radius = 0.11
	nose.height = 0.22
	_add_mesh(head, nose, _make_toon_mat(Color("#FFBEA3"), 0.4), Vector3(0.0, -0.01, 0.55))

	# Радостная улыбка папы посреди бороды
	var mouth := SphereMesh.new()
	mouth.radius = 0.16
	mouth.height = 0.20
	_add_mesh(head, mouth, _make_toon_mat(Color("#FF5252"), 0.28), Vector3(0.0, -0.21, 0.50), Vector3.ZERO, Vector3(1.15, 0.85, 0.75))

	var goggle_ring := TorusMesh.new()
	goggle_ring.inner_radius = 0.09
	goggle_ring.outer_radius = 0.16
	var goggle_mat := _make_toon_mat(Color("#FF9F43"), 0.2)
	_add_mesh(head, goggle_ring, goggle_mat, Vector3(-0.20, 0.32, 0.42), Vector3(75, 0, 0))
	_add_mesh(head, goggle_ring, goggle_mat, Vector3(0.20, 0.32, 0.42), Vector3(75, 0, 0))

	# --- СЮРПРИЗЫ НА ГОЛОВЕ У ПАПЫ ПОСЛЕ ВЫНЫРИВАНИЯ (включая настоящие GLB!) ---
	var hats_root := Node3D.new()
	hats_root.position = Vector3(0.0, 0.62, 0.0)
	head.add_child(hats_root)

	# 1. Настоящая 3D резиновая уточка (duck.glb)
	var hat_duck := Node3D.new()
	hat_duck.visible = false
	hats_root.add_child(hat_duck)
	_instantiate_glb("res://assets/models/duck.glb", hat_duck, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.34)
	_dad_hats.append(hat_duck)

	# 2. Настоящий 3D сундук сокровищ (chest.glb с текстурой)
	var hat_chest := Node3D.new()
	hat_chest.visible = false
	hats_root.add_child(hat_chest)
	_instantiate_glb("res://assets/models/chest.glb", hat_chest, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 0.85, true)
	_dad_hats.append(hat_chest)

	# 3. Красная морская звезда
	var hat_star := Node3D.new()
	hat_star.visible = false
	hats_root.add_child(hat_star)
	var star_arm := CapsuleMesh.new()
	star_arm.radius = 0.11
	star_arm.height = 0.85
	var star_mat := _make_toon_mat(Color("#FF5252"), 0.3)
	for i in range(5):
		_add_mesh(hat_star, star_arm, star_mat, Vector3.ZERO, Vector3(90.0, float(i) * 36.0, 0.0))
	_dad_hats.append(hat_star)


func _build_boats_and_birds_3d() -> void:
	# 1. Настоящие 3D-корабли (ship-small.glb и ship-medium.glb с текстурой палитры Kenney!)
	var ship1 := Node3D.new()
	ship1.position = Vector3(-9.5, 0.0, -15.6)
	add_child(ship1)
	_instantiate_glb("res://assets/models/ship-small.glb", ship1, Vector3(0.0, -0.1, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.65, true)
	boats.append({
		"node": ship1,
		"x": -9.5,
		"z": -15.6,
		"dir": 1.0,
		"speed": 2.0,
		"type": "steamboat",
		"bounce": 0.0
	})

	var ship2 := Node3D.new()
	ship2.position = Vector3(9.5, 0.0, -17.8)
	add_child(ship2)
	_instantiate_glb("res://assets/models/ship-medium.glb", ship2, Vector3(0.0, -0.15, 0.0), Vector3(0.0, -90.0, 0.0), Vector3.ONE * 0.56, true)
	boats.append({
		"node": ship2,
		"x": 9.5,
		"z": -17.8,
		"dir": -1.0,
		"speed": 1.6,
		"type": "sailboat",
		"bounce": 0.0
	})

	# 2. Анимированные 3D тропические птицы в небе (Flamingo.glb и Parrot.glb)
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

	if _target_ring_timer > 0.0:
		_target_ring_timer = maxf(0.0, _target_ring_timer - delta)
		_target_ring.visible = true
		var s := 1.0 + (0.6 - _target_ring_timer) * 1.5
		_target_ring.scale = Vector3(s, 1.0, s)
	else:
		_target_ring.visible = false

	# 1. Движение девочки на жёлтом круге (с умным огибанием берегов островов!)
	if swim_to_dad and dad_state == DadState.WAITING:
		girl_target = dad_pos

	var to_target := girl_target - girl_pos
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > 0.15:
		var dir := to_target / dist
		# Если на пути к цели стоит остров — плавно рулим в обход берега!
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
					# Выбираем касательную (влево или вправо в сторону цели)
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

		_foam_cooldown -= delta
		if _foam_cooldown <= 0.0:
			_foam_cooldown = 0.09
			_spawn_3d_particle(
				girl_pos - dir * 1.05 + Vector3(randf_range(-0.3, 0.3), 0.08, randf_range(-0.3, 0.3)),
				Vector3(0.0, 0.25, 0.0),
				Color(1, 1, 1, 0.85),
				0.5,
				false,
				1.1
			)
	else:
		girl_vel = girl_vel.lerp(Vector3.ZERO, delta * 6.0)
		_wheel_pivot.rotation.y = wheel_angle

	# Жёсткая коллизия береговой линии: круг девочки никогда не заплывает на песок острова!
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

	var girl_wave_y := _get_wave_height(girl_pos.x, girl_pos.z)
	_girl_root.position = Vector3(
		girl_pos.x,
		girl_wave_y + girl_bounce * 0.42,
		girl_pos.z
	)
	_girl_visual.rotation.y = girl_yaw
	_girl_visual.rotation.z = sin(world_time * 3.0) * 0.07
	_girl_visual.rotation.x = cos(world_time * 2.6) * 0.06

	# 2. КОМФОРТНАЯ КАМЕРА ОТ 3-ГО ЛИЦА (плавно следует за девочкой по большой карте!)
	var desired_cam_pos := Vector3(girl_pos.x * 0.78, 5.4, girl_pos.z + 7.2)
	var desired_look := Vector3(
		lerpf(girl_pos.x, dad_pos.x, 0.35),
		0.45,
		lerpf(girl_pos.z, dad_pos.z, 0.40) - 0.8
	)
	_cam_pos = _cam_pos.lerp(desired_cam_pos, delta * 4.5)
	_cam_look = _cam_look.lerp(desired_look, delta * 5.5)
	_camera.look_at_from_position(_cam_pos, _cam_look, Vector3.UP)

	# ЖЕЛЕЗОБЕТОННАЯ МЕХАНИКА КУПАНИЯ ПАПЫ:
	# Как только девочка подплыла к папе вплотную — ПАПА ТОНЕТ С БРЫЗГАМИ!
	if dad_state == DadState.WAITING and girl_pos.distance_to(dad_pos) <= 2.55:
		_splash_dad_3d()

	# 3. Обновляем 3D-Папу
	_update_dad_3d(delta)

	# 4. Обновляем Кораблики, Птиц и Дельфинов
	_update_boats_birds_and_dolphins(delta)

	# 5. Обновляем 3D-Партиклы
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


func _update_dad_3d(delta: float) -> void:
	_dad_left_arm.rotation.z = sin(world_time * 7.2) * 0.45 - 0.25
	_dad_right_arm.rotation.z = -sin(world_time * 7.2) * 0.45 + 0.25

	var dad_wave_y := _get_wave_height(dad_pos.x, dad_pos.z)

	match dad_state:
		DadState.WAITING:
			_dad_root.visible = true
			_dad_root.position = Vector3(dad_pos.x, dad_wave_y, dad_pos.z)
			_dad_visual.scale = _dad_visual.scale.lerp(Vector3.ONE, delta * 8.0)
			# Папа поворачивается лицом к дочке и камере
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

				# Выбираем новое место в море вдали от девочки и СТРОГО ВНЕ ОСТРОВОВ!
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
				_spawn_splash_3d(dad_pos, 26, Color("#E3F9FF"))

		DadState.EMERGING:
			dad_timer -= delta
			var t := 1.0 - clampf(dad_timer / 0.40, 0.0, 1.0)
			_dad_root.position = Vector3(dad_pos.x, dad_wave_y + sin(t * PI) * 0.85, dad_pos.z)
			_dad_visual.scale = Vector3.ONE * clampf(t * 1.2, 0.1, 1.12)
			if dad_timer <= 0.0:
				_dad_visual.scale = Vector3.ONE
				dad_state = DadState.WAITING


func _update_boats_birds_and_dolphins(delta: float) -> void:
	for b in boats:
		b["x"] += float(b["dir"]) * float(b["speed"]) * delta
		if float(b["dir"]) > 0.0 and float(b["x"]) > 21.0:
			b["x"] = -21.0
		elif float(b["dir"]) < 0.0 and float(b["x"]) < -21.0:
			b["x"] = 21.0
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
		bnode.rotation.z = sin(world_time * 2.6 + bx) * 0.09

	for br in birds:
		br["x"] += float(br["dir"]) * float(br["speed"]) * delta
		if float(br["dir"]) > 0.0 and float(br["x"]) > 22.0:
			br["x"] = -22.0
		elif float(br["dir"]) < 0.0 and float(br["x"]) < -22.0:
			br["x"] = 22.0
		var br_node: Node3D = br["node"]
		br_node.position = Vector3(
			float(br["x"]),
			float(br["y"]) + sin(world_time * 2.5 + float(br["x"])) * 0.25,
			float(br["z"])
		)

	dolphin_spawn_timer -= delta
	if dolphin_spawn_timer <= 0.0:
		dolphin_spawn_timer = randf_range(3.5, 5.8)
		if dolphins.size() < 2:
			_spawn_dolphin_3d()

	for i in range(dolphins.size() - 1, -1, -1):
		var d: Dictionary = dolphins[i]
		var prev_t: float = d["t"]
		d["t"] += delta * 0.72
		var t: float = d["t"]
		var dnode: Node3D = d["node"]

		if prev_t < 0.08 and t >= 0.08:
			_spawn_splash_3d(d["start"], 10, Color.WHITE)

		if t >= 1.0:
			_spawn_splash_3d(d["end"], 12, Color.WHITE)
			dnode.queue_free()
			dolphins.remove_at(i)
		else:
			var s: Vector3 = d["start"]
			var e: Vector3 = d["end"]
			var pos := s.lerp(e, t)
			pos.y = sin(t * PI) * 3.0 - 0.35
			dnode.position = pos
			var jump_dir := (e - s).normalized()
			dnode.rotation.y = atan2(jump_dir.x, jump_dir.z)
			dnode.rotation.x = (t - 0.5) * 1.65
			if float(d["spin"]) > 0.0:
				d["spin"] = maxf(0.0, float(d["spin"]) - delta * 1.5)
				dnode.rotation.z += delta * 14.0


func _splash_dad_3d() -> void:
	if dad_state != DadState.WAITING:
		return

	swim_to_dad = false
	dad_state = DadState.DIVING
	dad_timer = 0.40
	girl_bounce = 1.0
	wheel_spin_boost = 1.0

	_splash_player.pitch_scale = randf_range(0.92, 1.08)
	_splash_player.play()
	_laugh_player.pitch_scale = randf_range(0.95, 1.08)
	_laugh_player.play()
	Input.vibrate_handheld(45)

	_spawn_splash_3d(dad_pos, 36, Color.WHITE)
	_spawn_splash_3d(girl_pos + Vector3(0, 1.1, 0), 12, Color("#FFD32A"))


func _spawn_splash_3d(origin: Vector3, count: int, col: Color) -> void:
	for i in range(count):
		var a := randf() * TAU
		var h_speed := randf_range(1.4, 4.5)
		var v_speed := randf_range(4.0, 7.6)
		_spawn_3d_particle(
			origin + Vector3(0.0, 0.25, 0.0),
			Vector3(cos(a) * h_speed, v_speed, sin(a) * h_speed),
			col,
			randf_range(0.45, 0.78),
			true,
			randf_range(0.9, 1.5)
		)


func _spawn_3d_particle(pos: Vector3, vel: Vector3, col: Color, life: float, gravity: bool, base_scale: float = 1.0) -> void:
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


func _spawn_dolphin_3d() -> void:
	var from_left := randf() < 0.5
	var s := Vector3(randf_range(-9.0, -2.5) if from_left else randf_range(2.5, 9.0), 0.0, randf_range(-8.0, 1.0))
	var e := s + Vector3(5.5 if from_left else -5.5, 0.0, randf_range(-1.2, 1.2))
	s = _push_out_of_islands(s, 1.8)
	e = _push_out_of_islands(e, 1.8)

	var dnode := Node3D.new()
	add_child(dnode)

	var body_mat := _make_toon_mat(Color("#48DBFB"), 0.18)
	var belly_mat := _make_toon_mat(Color("#E3F9FF"), 0.25)
	var fin_mat := _make_toon_mat(Color("#0984E3"), 0.22)

	var body := CapsuleMesh.new()
	body.radius = 0.36
	body.height = 1.65
	body.radial_segments = 24
	_add_mesh(dnode, body, body_mat, Vector3.ZERO, Vector3(90.0, 0.0, 0.0))
	_add_mesh(dnode, body, belly_mat, Vector3(0.0, -0.08, 0.0), Vector3(90.0, 0.0, 0.0), Vector3(0.82, 0.85, 0.92))

	var snout := CapsuleMesh.new()
	snout.radius = 0.14
	snout.height = 0.62
	_add_mesh(dnode, snout, body_mat, Vector3(0.0, -0.04, 0.82), Vector3(90.0, 0.0, 0.0))

	var fin := PrismMesh.new()
	fin.size = Vector3(0.12, 0.54, 0.52)
	_add_mesh(dnode, fin, fin_mat, Vector3(0.0, 0.42, -0.08))

	var tail := CapsuleMesh.new()
	tail.radius = 0.12
	tail.height = 0.85
	_add_mesh(dnode, tail, fin_mat, Vector3(0.0, 0.0, -0.88), Vector3(0.0, 0.0, 90.0), Vector3(0.35, 1.0, 1.2))

	dolphins.append({
		"node": dnode,
		"start": s,
		"end": e,
		"t": 0.0,
		"spin": 0.0
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

	# 2. Нажатие на Папу в воде (проверяем ПЕРВЫМ, чтобы папа всегда легко нажимался и тонул!)
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

	# 3. Нажатие на Девочку / жёлтый круг / руль — "Би-бип!"
	if not is_drag and _camera.is_position_in_frustum(_girl_root.global_position):
		var girl_screen := _camera.unproject_position(_girl_root.global_position + Vector3(0, 0.6, 0))
		if screen_pt.distance_to(girl_screen) <= 75.0:
			_squeak_player.pitch_scale = randf_range(0.95, 1.15)
			_squeak_player.play()
			wheel_spin_boost = 1.0
			girl_bounce = 0.85
			_spawn_splash_3d(girl_pos + Vector3(0, 0.9, 0), 8, Color("#FFD32A"))
			return

	# 4. Нажатие на плавающую 3D резиновую уточку (duck.glb)
	if not is_drag and _floating_duck != null and _camera.is_position_in_frustum(_floating_duck.global_position):
		var duck_screen := _camera.unproject_position(_floating_duck.global_position)
		if screen_pt.distance_to(duck_screen) <= 70.0:
			_duck_bounce = 1.0
			_squeak_player.pitch_scale = 1.25
			_squeak_player.play()
			_spawn_splash_3d(_floating_duck.global_position, 10, Color("#FFD32A"))
			return

	# 5. Нажатие на прыгающих 3D-Дельфинов
	if not is_drag:
		for d in dolphins:
			var dnode: Node3D = d["node"]
			if _camera.is_position_in_frustum(dnode.global_position):
				var d_screen := _camera.unproject_position(dnode.global_position)
				if screen_pt.distance_to(d_screen) <= 85.0:
					d["spin"] = 1.0
					_slide_player.pitch_scale = 1.25
					_slide_player.play()
					_spawn_splash_3d(dnode.global_position, 14, Color("#FFEAA7"))
					return

	# 6. Нажатие на 3D-Кораблики ("Ту-тууу!")
	if not is_drag:
		for b in boats:
			var bnode: Node3D = b["node"]
			if _camera.is_position_in_frustum(bnode.global_position):
				var b_screen := _camera.unproject_position(bnode.global_position + Vector3(0, 0.5, 0))
				if screen_pt.distance_to(b_screen) <= 85.0:
					b["bounce"] = 1.0
					_horn_player.pitch_scale = 1.0 if b["type"] == "steamboat" else 1.22
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

	# 7. Нажатие или ведение пальчиком по 3D-воде — девочка плывёт туда!
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
		# Если кликнули рядом с папой — сразу примагничиваем цель к папе!
		if dad_state == DadState.WAITING and girl_target.distance_to(dad_pos) <= 2.4:
			swim_to_dad = true
			girl_target = dad_pos
		else:
			swim_to_dad = false
		if not is_drag:
			_target_ring.position = Vector3(girl_target.x, 0.10, girl_target.z)
			_target_ring_timer = 0.55

class_name SeaGame
extends Node3D

var world_time: float = 0.0

# 3D Камера (комфортный тёплый ракурс от 3-го лица за спиной девочки)
var _camera: Camera3D
var _cam_pos := Vector3(0.0, 4.2, 8.2)
var _cam_look := Vector3(0.0, 0.8, 0.0)

var _ui_canvas: Node2D
var _kenney_colormap: Texture2D

# Подсистемы игры
var _fx_pool: FXPool
var _water_surface: WaterSurface
var _fleet: HorizonFleet
var _buoy_manager: BuoyManager
var _fauna: MarineFauna
var _dad: DadActor
var _girl: GirlController

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
	_init_audio()

	if ResourceLoader.exists("res://assets/models/Textures/colormap.png"):
		_kenney_colormap = load("res://assets/models/Textures/colormap.png")

	_setup_environment_and_camera()
	_setup_modules()
	_setup_ui_overlay()


func _setup_modules() -> void:
	_fx_pool = FXPool.new()
	add_child(_fx_pool)

	_water_surface = WaterSurface.new()
	add_child(_water_surface)
	_water_surface.init_surface(_kenney_colormap)
	_water_surface.duck_clicked.connect(_on_duck_clicked)

	_fleet = HorizonFleet.new()
	add_child(_fleet)
	_fleet.init_fleet(_kenney_colormap)
	_fleet.boat_clicked.connect(_on_boat_clicked)

	_buoy_manager = BuoyManager.new()
	add_child(_buoy_manager)
	_buoy_manager.init_buoys(_kenney_colormap)
	_buoy_manager.buoy_hit.connect(_on_buoy_hit)
	_buoy_manager.buoy_clicked.connect(_on_buoy_clicked)

	_fauna = MarineFauna.new()
	add_child(_fauna)
	_fauna.init_fauna(_kenney_colormap)
	_fauna.crab_clicked.connect(_on_crab_clicked)
	_fauna.fish_jumped.connect(_on_fish_jumped)
	_fauna.fish_clicked.connect(_on_fish_clicked)

	_dad = DadActor.new()
	add_child(_dad)
	_dad.init_actor(_kenney_colormap)
	_dad.dad_splashed.connect(_on_dad_splashed)
	_dad.bubble_tick.connect(_on_dad_bubble_tick)
	_dad.dad_emerged.connect(_on_dad_emerged)

	_girl = GirlController.new()
	add_child(_girl)
	_girl.init_controller()
	_girl.water_sprayed.connect(_on_girl_water_sprayed)
	_girl.water_hit_dad.connect(_on_water_hit_dad)
	_girl.foam_spawned.connect(_on_girl_foam_spawned)


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
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color("#FFF9E6")
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	add_child(sun)

	_camera = Camera3D.new()
	_camera.fov = 52.0
	_camera.look_at_from_position(_cam_pos, _cam_look, Vector3.UP)
	add_child(_camera)


func _init_audio() -> void:
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

	if ResourceLoader.exists("res://assets/sea_ambient.wav"):
		_sea_ambient = AudioStreamPlayer.new()
		_sea_ambient.stream = load("res://assets/sea_ambient.wav")
		if _sea_ambient.stream is AudioStreamWAV:
			(_sea_ambient.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_sea_ambient.volume_db = -17.0
		add_child(_sea_ambient)
		if is_inside_tree():
			_sea_ambient.play()


func _make_player(stream: AudioStream, polyphony: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.max_polyphony = polyphony
	add_child(p)
	return p


func _process(delta: float) -> void:
	world_time += delta

	_water_surface.update_surface(delta, world_time)
	_fleet.update_fleet(delta, world_time, _water_surface)
	_fauna.update_fauna(delta, world_time, _water_surface, _girl.girl_pos)
	_buoy_manager.update_buoys(delta, world_time, _water_surface)

	# Столкновение круга с буйками
	var hit := _buoy_manager.check_girl_collision(_girl.girl_pos, _girl.girl_vel)
	if hit["collided"]:
		_girl.bounce_back(hit["new_pos"], hit["new_vel"])
		_water_surface.hide_target_ring()

	_girl.update_controller(delta, world_time, _water_surface, _dad.get_pos(), _dad.is_waiting())

	# Купание Папы при сближении девочки вплотную
	if _dad.is_waiting() and _girl.girl_pos.distance_to(_dad.get_pos()) <= 2.45:
		_dad.splash_dad()

	_dad.update_actor(delta, world_time, _water_surface, _cam_pos, _girl.girl_pos)

	# Плавное слежение камеры
	var desired_cam_pos := Vector3(_girl.girl_pos.x * 0.72, 3.8, _girl.girl_pos.z + 5.8)
	var desired_look := Vector3(
		lerpf(_girl.girl_pos.x, _dad.get_pos().x, 0.28),
		1.0,
		lerpf(_girl.girl_pos.z, _dad.get_pos().z, 0.35) - 0.4
	)
	_cam_pos = _cam_pos.lerp(desired_cam_pos, delta * 4.8)
	_cam_look = _cam_look.lerp(desired_look, delta * 5.5)
	_camera.look_at_from_position(_cam_pos, _cam_look, Vector3.UP)


# --- Сигнальные обработчики подсистем ---

func _on_duck_clicked(duck_pos: Vector3) -> void:
	_squeak_player.pitch_scale = 1.25
	_squeak_player.play()
	_fx_pool.spawn_splash(duck_pos, 10, Color("#FFD32A"))


func _on_buoy_hit(buoy_pos: Vector3, normal: Vector3) -> void:
	_bell_player.pitch_scale = randf_range(0.95, 1.15)
	_bell_player.play()
	_boing_player.pitch_scale = randf_range(1.0, 1.2)
	_boing_player.play()
	Input.vibrate_handheld(35)
	_fx_pool.spawn_splash(buoy_pos + normal * 0.8, 10, Color("#E3F9FF"))


func _on_buoy_clicked(buoy_pos: Vector3) -> void:
	_bell_player.pitch_scale = randf_range(1.0, 1.25)
	_bell_player.play()
	_fx_pool.spawn_splash(buoy_pos, 8, Color("#E3F9FF"))


func _on_crab_clicked(crab_pos: Vector3) -> void:
	_tap_player.pitch_scale = randf_range(1.1, 1.3)
	_tap_player.play()
	_fx_pool.spawn_splash(crab_pos, 8, Color("#FFEAA7"))


func _on_fish_jumped(fish_pos: Vector3) -> void:
	_splash_player.pitch_scale = randf_range(1.15, 1.35)
	_splash_player.play()
	_fx_pool.spawn_splash(fish_pos, 8, Color("#81D4FA"))


func _on_fish_clicked(fish_pos: Vector3) -> void:
	_splash_player.pitch_scale = 1.30
	_splash_player.play()
	_fx_pool.spawn_splash(fish_pos, 10, Color("#81D4FA"))


func _on_boat_clicked(boat_pos: Vector3, boat_type: String) -> void:
	if boat_type == "liner":
		_horn_player.pitch_scale = 0.82
	elif boat_type == "tug":
		_horn_player.pitch_scale = 1.15
	else:
		_horn_player.pitch_scale = 1.35
	_horn_player.play()

	for i in range(6):
		_fx_pool.spawn_particle(
			boat_pos + Vector3(0.0, 1.4, 0.0),
			Vector3(randf_range(-0.6, 0.6), randf_range(1.6, 2.8), randf_range(-0.4, 0.4)),
			Color.WHITE,
			0.95,
			false,
			1.7
		)


func _on_dad_splashed() -> void:
	_girl.stop_navigation()
	_girl.girl_bounce = 1.0
	_girl.wheel_spin_boost = 1.0

	_splash_player.pitch_scale = randf_range(0.92, 1.08)
	_splash_player.play()
	_laugh_player.pitch_scale = randf_range(0.95, 1.08)
	_laugh_player.play()
	Input.vibrate_handheld(45)

	_fx_pool.spawn_splash(_dad.get_pos(), 16, Color.WHITE)
	_fx_pool.spawn_splash(_girl.girl_pos + Vector3(0, 1.0, 0), 8, Color("#FFD32A"))


func _on_dad_bubble_tick(pos: Vector3) -> void:
	_glug_player.pitch_scale = randf_range(0.9, 1.25)
	_glug_player.play()
	for b in range(2):
		_fx_pool.spawn_particle(
			pos + Vector3(randf_range(-0.35, 0.35), 0.12, randf_range(-0.35, 0.35)),
			Vector3(0.0, randf_range(0.7, 1.3), 0.0),
			Color(1.0, 1.0, 1.0, 0.92),
			0.5,
			false,
			1.35
		)


func _on_dad_emerged(_hat_idx: int) -> void:
	_slide_player.pitch_scale = randf_range(0.95, 1.15)
	_slide_player.play()
	_splash_player.pitch_scale = 1.12
	_splash_player.play()
	_fx_pool.spawn_splash(_dad.get_pos(), 14, Color("#E3F9FF"))


func _on_girl_water_sprayed(_nozzle_pos: Vector3, _forward_dir: Vector3) -> void:
	_squeak_player.pitch_scale = randf_range(1.05, 1.25)
	_squeak_player.play()


func _on_water_hit_dad() -> void:
	_dad.splash_dad()


func _on_girl_foam_spawned(pos: Vector3) -> void:
	_fx_pool.spawn_particle(
		pos,
		Vector3(0.0, 0.22, 0.0),
		Color(1, 1, 1, 0.85),
		0.38,
		false,
		1.0
	)


# --- Обработка ввода (Touch / Mouse) ---

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_screen_touch(event.position, false)
	elif event is InputEventScreenDrag:
		_handle_screen_touch(event.position, true)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_screen_touch(event.position, false)


func _handle_screen_touch(screen_pt: Vector2, is_drag: bool) -> void:
	# 1. Кнопка "Домик"
	if not is_drag and screen_pt.distance_to(Vector2(65, 62)) <= 45.0:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return

	# 2. Нажатие на Папу в воде
	if _dad.check_touch(_camera, screen_pt):
		if _girl.girl_pos.distance_to(_dad.get_pos()) <= 3.0:
			_dad.splash_dad()
		else:
			_girl.navigate_to(_dad.get_pos(), true)
			_water_surface.show_target_ring(_dad.get_pos(), 0.6)
			if not is_drag:
				_squeak_player.pitch_scale = 1.08
				_squeak_player.play()
		return

	# 3. Нажатие на Девочку / круг / руль — ВОДЯНАЯ ПУШКА!
	if not is_drag and _girl.check_touch(_camera, screen_pt):
		return

	# 4. Нажатие на фауну (крабик, рыбки)
	if not is_drag and _fauna.check_touch(_camera, screen_pt):
		return

	# 5. Нажатие на буйки
	if not is_drag and _buoy_manager.check_touch(_camera, screen_pt):
		return

	# 6. Нажатие на резиновую уточку
	if not is_drag and _water_surface.check_duck_touch(_camera, screen_pt):
		return

	# 7. Нажатие на корабли на горизонте
	if not is_drag and _fleet.check_touch(_camera, screen_pt):
		return

	# 8. Нажатие или ведение пальчиком по воде — плывём к цели
	var ray_origin := _camera.project_ray_origin(screen_pt)
	var ray_dir := _camera.project_ray_normal(screen_pt)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_dir)
	if hit != null:
		var target_pt: Vector3 = hit
		target_pt.x = clampf(target_pt.x, WaterSurface.SEA_MIN_X, WaterSurface.SEA_MAX_X)
		target_pt.z = clampf(target_pt.z, WaterSurface.SEA_MIN_Z, WaterSurface.SEA_MAX_Z)
		target_pt = _water_surface.push_out_of_islands(target_pt, 1.45)

		var is_targeting_dad: bool = _dad.is_waiting() and target_pt.distance_to(_dad.get_pos()) <= 2.4
		if is_targeting_dad:
			target_pt = _dad.get_pos()

		_girl.navigate_to(target_pt, is_targeting_dad)
		if not is_drag:
			_water_surface.show_target_ring(target_pt, 0.55)


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

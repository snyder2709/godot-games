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
var _beach_ball: BeachBall
var _treasures: MarineTreasures
var _sky_controller: SkyController

var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _splash_streak: int = 0

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
	_fx_pool.bubble_popped.connect(_on_bubble_popped)

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

	_beach_ball = BeachBall.new()
	add_child(_beach_ball)
	_beach_ball.init_ball()
	_beach_ball.ball_kicked.connect(_on_ball_kicked)
	_beach_ball.ball_splashed.connect(_on_ball_splashed)
	_beach_ball.ball_bumped.connect(_on_ball_bumped)
	_beach_ball.dad_passed_ball.connect(_on_dad_passed_ball)

	_treasures = MarineTreasures.new()
	add_child(_treasures)
	_treasures.init_treasures()
	_treasures.pearl_revealed.connect(_on_pearl_revealed)
	_treasures.starfish_clicked.connect(_on_starfish_clicked)
	_treasures.lighthouse_clicked.connect(_on_lighthouse_clicked)

	_sky_controller = SkyController.new()
	add_child(_sky_controller)
	_sky_controller.init_sky(_env, _sky_mat, _sun, _water_surface)
	_sky_controller.time_changed.connect(_on_time_changed)

	_girl = GirlController.new()
	add_child(_girl)
	_girl.init_controller()
	_girl.water_sprayed.connect(_on_girl_water_sprayed)
	_girl.water_hit_dad.connect(_on_water_hit_dad)
	_girl.foam_spawned.connect(_on_girl_foam_spawned)




func _setup_environment_and_camera() -> void:
	_env = Environment.new()
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = Color("#29B6F6")
	_sky_mat.sky_horizon_color = Color("#B3E5FC")
	_sky_mat.ground_bottom_color = Color("#0288D1")
	_sky_mat.ground_horizon_color = Color("#81D4FA")
	sky.sky_material = _sky_mat

	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_color = Color("#FFFDF7")
	_env.ambient_light_energy = 1.05
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.glow_enabled = false

	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	_sun.light_color = Color("#FFF9E6")
	_sun.light_energy = 1.25
	_sun.shadow_enabled = false
	add_child(_sun)


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
	_treasures.update_treasures(delta, world_time)


	# Столкновение круга с буйками
	var hit := _buoy_manager.check_girl_collision(_girl.girl_pos, _girl.girl_vel)
	if hit["collided"]:
		_girl.bounce_back(hit["new_pos"], hit["new_vel"])
		_water_surface.hide_target_ring()

	_beach_ball.update_ball(delta, world_time, _water_surface, _dad.get_pos(), _dad.is_waiting())
	_beach_ball.check_girl_collision(_girl.girl_pos, _girl.girl_vel)

	_girl.update_controller(delta, world_time, _water_surface, _dad.get_pos(), _dad.is_waiting(), _beach_ball)


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
	_fx_pool.spawn_ripple(duck_pos, 0.25, 1.5, Color(1.0, 1.0, 1.0, 0.7), 0.45)


func _on_buoy_hit(buoy_pos: Vector3, normal: Vector3) -> void:
	_bell_player.pitch_scale = randf_range(0.95, 1.15)
	_bell_player.play()
	_boing_player.pitch_scale = randf_range(1.0, 1.2)
	_boing_player.play()
	Input.vibrate_handheld(35)
	_fx_pool.spawn_splash(buoy_pos + normal * 0.8, 10, Color("#E3F9FF"))
	_fx_pool.spawn_ripple(buoy_pos, 0.35, 1.9, Color(1.0, 1.0, 1.0, 0.75), 0.5)


func _on_buoy_clicked(buoy_pos: Vector3) -> void:
	_bell_player.pitch_scale = randf_range(1.0, 1.25)
	_bell_player.play()
	_fx_pool.spawn_splash(buoy_pos, 8, Color("#E3F9FF"))
	_fx_pool.spawn_ripple(buoy_pos, 0.3, 1.6, Color(1.0, 1.0, 1.0, 0.7), 0.45)


func _on_crab_clicked(crab_pos: Vector3) -> void:
	_tap_player.pitch_scale = randf_range(1.1, 1.3)
	_tap_player.play()
	_fx_pool.spawn_splash(crab_pos, 8, Color("#FFEAA7"))
	_fx_pool.spawn_ripple(crab_pos, 0.2, 1.3, Color(1.0, 1.0, 1.0, 0.6), 0.4)


func _on_fish_jumped(fish_pos: Vector3) -> void:
	_splash_player.pitch_scale = randf_range(1.15, 1.35)
	_splash_player.play()
	_fx_pool.spawn_splash(fish_pos, 8, Color("#81D4FA"))
	_fx_pool.spawn_ripple(fish_pos, 0.25, 1.5, Color(1.0, 1.0, 1.0, 0.7), 0.45)


func _on_fish_clicked(fish_pos: Vector3) -> void:
	_splash_player.pitch_scale = 1.30
	_splash_player.play()
	_fx_pool.spawn_splash(fish_pos, 10, Color("#81D4FA"))
	_fx_pool.spawn_ripple(fish_pos, 0.3, 1.6, Color(1.0, 1.0, 1.0, 0.7), 0.45)


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
	_splash_streak += 1
	_girl.stop_navigation()
	_girl.girl_bounce = 1.0
	_girl.wheel_spin_boost = 1.0

	_splash_player.pitch_scale = randf_range(0.92, 1.08)
	_splash_player.play()
	_laugh_player.pitch_scale = randf_range(0.95, 1.08)
	_laugh_player.play()
	Input.vibrate_handheld(45)

	_fx_pool.spawn_splash(_dad.get_pos(), 16, Color.WHITE)
	_fx_pool.spawn_ripple(_dad.get_pos(), 0.4, 2.5, Color(1.0, 1.0, 1.0, 0.8), 0.65)
	_fx_pool.spawn_splash(_girl.girl_pos + Vector3(0, 1.0, 0), 8, Color("#FFD32A"))

	if _splash_streak % 5 == 0:
		_trigger_celebration()



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
	_fx_pool.spawn_ripple(_dad.get_pos(), 0.4, 2.6, Color(1.0, 1.0, 1.0, 0.8), 0.7)

	# Весёлые плавающие мыльные пузыри от Папы
	for i in range(4):
		var b_offset := Vector3(randf_range(-0.6, 0.6), 0.75, randf_range(-0.6, 0.6))
		var b_vel := Vector3(randf_range(-0.35, 0.35), randf_range(0.85, 1.55), randf_range(-0.35, 0.35))
		_fx_pool.spawn_floating_bubble(_dad.get_pos() + b_offset, b_vel, randf_range(0.20, 0.32))


func _on_ball_kicked(pos: Vector3) -> void:
	_boing_player.pitch_scale = randf_range(1.15, 1.35)
	_boing_player.play()
	_fx_pool.spawn_splash(pos, 8, Color("#81D4FA"))
	_fx_pool.spawn_ripple(pos, 0.25, 1.6, Color(1.0, 1.0, 1.0, 0.75), 0.45)


func _on_ball_splashed(pos: Vector3) -> void:
	_splash_player.pitch_scale = randf_range(1.25, 1.45)
	_splash_player.play()
	_fx_pool.spawn_splash(pos, 7, Color.WHITE)
	_fx_pool.spawn_ripple(pos, 0.3, 1.9, Color(1.0, 1.0, 1.0, 0.7), 0.5)


func _on_ball_bumped(pos: Vector3) -> void:
	_boing_player.pitch_scale = randf_range(0.95, 1.15)
	_boing_player.play()
	_fx_pool.spawn_splash(pos, 6, Color("#FFEAA7"))
	_fx_pool.spawn_ripple(pos, 0.2, 1.4, Color(1.0, 1.0, 1.0, 0.7), 0.4)


func _on_dad_passed_ball(pos: Vector3) -> void:
	_laugh_player.pitch_scale = randf_range(1.05, 1.2)
	_laugh_player.play()
	_splash_player.pitch_scale = 1.15
	_splash_player.play()
	_fx_pool.spawn_splash(pos, 12, Color.WHITE)
	_fx_pool.spawn_ripple(pos, 0.35, 2.2, Color(1.0, 1.0, 1.0, 0.8), 0.6)


func _on_bubble_popped(pos: Vector3) -> void:
	_tap_player.pitch_scale = randf_range(1.25, 1.5)
	_tap_player.play()


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
	_fx_pool.spawn_ripple(pos, 0.18, 0.85, Color(1.0, 1.0, 1.0, 0.45), 0.35)


func _trigger_celebration() -> void:
	var dpos := _dad.get_pos()
	_fx_pool.spawn_firework(dpos + Vector3(-2.4, 0.0, -1.8))
	_fx_pool.spawn_firework(dpos + Vector3(2.5, 0.0, 1.5))
	_fx_pool.spawn_firework(_girl.girl_pos + Vector3(-2.0, 0.0, 2.0))
	_fx_pool.spawn_firework(_girl.girl_pos + Vector3(2.2, 0.0, -1.6))

	_laugh_player.pitch_scale = 1.15
	_laugh_player.play()
	_bell_player.pitch_scale = 1.35
	_bell_player.play()
	_horn_player.pitch_scale = 1.25
	_horn_player.play()

	for i in range(8):
		var b_offset := Vector3(randf_range(-1.5, 1.5), 1.0, randf_range(-1.5, 1.5))
		var b_vel := Vector3(randf_range(-0.5, 0.5), randf_range(1.2, 2.2), randf_range(-0.5, 0.5))
		_fx_pool.spawn_floating_bubble(dpos + b_offset, b_vel, randf_range(0.24, 0.38))


func _on_pearl_revealed(pos: Vector3) -> void:
	_bell_player.pitch_scale = randf_range(1.25, 1.45)
	_bell_player.play()
	_fx_pool.spawn_sparkles(pos, 12, Color("#FFEAA7"))
	_fx_pool.spawn_floating_bubble(pos, Vector3(0.0, 1.3, 0.0), 0.28, 4.0)


func _on_starfish_clicked(pos: Vector3) -> void:
	_boing_player.pitch_scale = randf_range(1.35, 1.55)
	_boing_player.play()
	_fx_pool.spawn_sparkles(pos, 8, Color("#FF6B6B"))
	_fx_pool.spawn_ripple(pos, 0.2, 1.3, Color(1.0, 0.8, 0.8, 0.7), 0.4)


func _on_lighthouse_clicked(pos: Vector3) -> void:
	_bell_player.pitch_scale = 0.92
	_bell_player.play()
	_fx_pool.spawn_sparkles(pos, 8, Color("#FFF9E6"))


func _on_time_changed(new_time: int) -> void:
	_treasures.set_night_mode(new_time == SkyController.TimeOfDay.NIGHT)
	if _ui_canvas:
		_ui_canvas.queue_redraw()




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

	# 1.2. Кнопка смены времени суток "Солнышко / Луна"
	var vp_width := get_viewport().size.x if get_viewport() else 1280.0
	var sb := Vector2(vp_width - 65, 62)
	if not is_drag and screen_pt.distance_to(sb) <= 45.0:
		if _sky_controller:
			_sky_controller.cycle_time()
			_bell_player.pitch_scale = randf_range(1.15, 1.35)
			_bell_player.play()
		return

	# 1.5. Лопание летающих мыльных пузырей от Папы
	if not is_drag and _fx_pool.check_bubble_touch(_camera, screen_pt):
		return

	# 1.8. Нажатие на надувной пляжный мячик
	if not is_drag and _beach_ball.check_touch(_camera, screen_pt):
		return

	# 1.9. Нажатие на морские сокровища (ракушка с жемчужиной, звёздочка, маяк)
	if not is_drag and _treasures.check_touch(_camera, screen_pt):
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

		_fx_pool.spawn_ripple(target_pt, 0.18, 1.45, Color(0.92, 0.98, 1.0, 0.65), 0.45)

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
	# 1. Кнопка "Домик"
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

	# 2. Кнопка "Солнышко / Закат / Луна"
	var vp_width := get_viewport().size.x if get_viewport() else 1280.0
	var sb := Vector2(vp_width - 65, 62)
	_ui_canvas.draw_circle(sb, 36.0, Color(1, 1, 1, 0.94))
	_ui_canvas.draw_arc(sb, 36.0, 0, TAU, 28, Color("#FFA502"), 4.0, true)

	if _sky_controller and _sky_controller.current_time == SkyController.TimeOfDay.DAY:
		_ui_canvas.draw_circle(sb, 16.0, Color("#FFD32A"))
		for i in range(8):
			var a := i * (TAU / 8.0)
			var p1 := sb + Vector2(cos(a) * 20.0, sin(a) * 20.0)
			var p2 := sb + Vector2(cos(a) * 26.0, sin(a) * 26.0)
			_ui_canvas.draw_line(p1, p2, Color("#FFA502"), 3.5, true)
	elif _sky_controller and _sky_controller.current_time == SkyController.TimeOfDay.SUNSET:
		_ui_canvas.draw_circle(sb + Vector2(0, -3), 16.0, Color("#FF6B6B"))
		_ui_canvas.draw_rect(Rect2(sb.x - 20, sb.y + 3, 40, 16), Color("#FD79A8"))
		_ui_canvas.draw_line(sb + Vector2(-18, 5), sb + Vector2(18, 5), Color("#F39C12"), 3.0, true)
	else:
		_ui_canvas.draw_circle(sb + Vector2(-2, 0), 16.0, Color("#F1C40F"))
		_ui_canvas.draw_circle(sb + Vector2(5, -4), 14.0, Color(1, 1, 1, 0.94))
		_ui_canvas.draw_circle(sb + Vector2(14, 5), 2.8, Color("#F39C12"))
		_ui_canvas.draw_circle(sb + Vector2(9, -12), 2.2, Color("#F39C12"))


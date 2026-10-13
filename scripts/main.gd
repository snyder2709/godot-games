extends Node2D

const VIEW_W := 1280.0
const VIEW_H := 720.0
const FENCE_Y := 545.0

var cats: Array[ChoirCat] = []
var bubbles_layer: Node2D
var cats_layer: Node2D
var fx_layer: Node2D

var spawn_timer: float = 0.4
var zzz_timer: float = 1.2
var world_time: float = 0.0
var sun_bounce: float = 0.0
var is_night: bool = false
var night_blend: float = 0.0

# Облачка на небе
var clouds := [
	{"x": 180.0, "y": 115.0, "speed": 18.0, "scale": 1.0},
	{"x": 620.0, "y": 85.0, "speed": 13.0, "scale": 1.25},
	{"x": 1020.0, "y": 140.0, "speed": 22.0, "scale": 0.9}
]

# Интерактивные звёздочки на ночном небе (по ним тоже можно нажимать!)
var night_stars := [
	{"pos": Vector2(150, 95), "phase": 0.0, "pitch": 1.0, "bounce": 0.0},
	{"pos": Vector2(330, 165), "phase": 1.2, "pitch": 1.12, "bounce": 0.0},
	{"pos": Vector2(510, 80), "phase": 2.4, "pitch": 1.26, "bounce": 0.0},
	{"pos": Vector2(710, 155), "phase": 3.5, "pitch": 1.5, "bounce": 0.0},
	{"pos": Vector2(910, 90), "phase": 4.7, "pitch": 1.68, "bounce": 0.0},
	{"pos": Vector2(240, 260), "phase": 5.3, "pitch": 1.35, "bounce": 0.0},
	{"pos": Vector2(830, 245), "phase": 2.0, "pitch": 1.8, "bounce": 0.0}
]

# Летящие нотки, сердечки и брызги от пузырей
var floating_fx: Array[Dictionary] = []
# Игрушки, падающие из лопнувших пузырей к котикам
var falling_toys: Array[Dictionary] = []

# Защита от слишком частого срабатывания при проведении пальцем по одному котику
var _cat_drag_cooldown: Dictionary = {}

var _pop_player: AudioStreamPlayer
var _toy_player: AudioStreamPlayer


func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	randomize()

	_pop_player = AudioStreamPlayer.new()

	_pop_player.stream = SoundGen.get_pop_stream()
	_pop_player.max_polyphony = 8
	add_child(_pop_player)

	_toy_player = AudioStreamPlayer.new()
	_toy_player.stream = SoundGen.get_toy_stream()
	_toy_player.max_polyphony = 6
	add_child(_toy_player)

	cats_layer = Node2D.new()
	add_child(cats_layer)

	bubbles_layer = Node2D.new()
	add_child(bubbles_layer)

	fx_layer = Node2D.new()
	fx_layer.draw.connect(_draw_falling_toys_and_fx)
	add_child(fx_layer)

	_setup_cats()

	# Сразу создаём несколько пузырей на старте
	for i in range(5):
		_spawn_bubble(randf_range(260.0, 680.0))


func _setup_cats() -> void:
	# Живые голоса котят (meow.wav) и котиков (meow2.wav) на естественных тонах
	var configs := [
		{
			"name": "Рыжик",
			"fur": Color("#FF9F43"),
			"belly": Color("#FFEAA7"),
			"ear": Color("#FF85A2"),
			"eye": Color("#2D3436"),
			"note_col": Color("#FF6B6B"),
			"pitch": 0.92,
			"variant": 1,
			"chubby": 1.08
		},
		{
			"name": "Снежок",
			"fur": Color("#F5F6FA"),
			"belly": Color("#FFFFFF"),
			"ear": Color("#FDA7DF"),
			"eye": Color("#0984E3"),
			"note_col": Color("#48DBFB"),
			"pitch": 0.90,
			"variant": 0,
			"chubby": 0.94
		},
		{
			"name": "Дымок",
			"fur": Color("#A4B0BE"),
			"belly": Color("#DFE4EA"),
			"ear": Color("#FF85A2"),
			"eye": Color("#2ED573"),
			"note_col": Color("#1DD1A1"),
			"pitch": 1.05,
			"variant": 1,
			"chubby": 1.15
		},
		{
			"name": "Персик",
			"fur": Color("#FAB1A0"),
			"belly": Color("#FFF0ED"),
			"ear": Color("#FD79A8"),
			"eye": Color("#2D3436"),
			"note_col": Color("#FECA57"),
			"pitch": 1.02,
			"variant": 0,
			"chubby": 1.0
		},
		{
			"name": "Уголёк",
			"fur": Color("#3D3D3D"),
			"belly": Color("#57606F"),
			"ear": Color("#FF6B81"),
			"eye": Color("#FFEAA7"),
			"note_col": Color("#FF9FF3"),
			"pitch": 1.16,
			"variant": 0,
			"chubby": 0.92
		}
	]

	var w := _get_view_width()
	var cat_count := configs.size()
	var total_w := (cat_count - 1) * 220.0
	var start_x := (w - total_w) * 0.5
	var spacing := 220.0

	for i in range(configs.size()):
		var cfg: Dictionary = configs[i]
		var cat := ChoirCat.new()
		cat.cat_name = cfg["name"]
		cat.fur_color = cfg["fur"]
		cat.belly_color = cfg["belly"]
		cat.ear_inner_color = cfg["ear"]
		cat.eye_color = cfg["eye"]
		cat.note_color = cfg["note_col"]
		cat.pitch_note = cfg["pitch"]
		cat.meow_variant = cfg["variant"]
		cat.chubby_factor = cfg["chubby"]
		cat.position = Vector2(start_x + i * spacing, FENCE_Y)
		cat.cat_sang.connect(_on_cat_sang)
		cats_layer.add_child(cat)
		cats.append(cat)


func _get_view_width() -> float:
	var vp := get_viewport()
	return float(vp.get_visible_rect().size.x) if vp != null else 1280.0



func _process(delta: float) -> void:
	world_time += delta
	if sun_bounce > 0.0:
		sun_bounce = maxf(0.0, sun_bounce - delta * 3.0)

	# Плавный переход День <-> Ночь
	var target_night := 1.0 if is_night else 0.0
	night_blend = move_toward(night_blend, target_night, delta * 1.8)

	for s in night_stars:
		if s["bounce"] > 0.0:
			s["bounce"] = maxf(0.0, s["bounce"] - delta * 3.0)

	# Движение облачков
	var w := _get_view_width()
	for c in clouds:
		c["x"] += c["speed"] * delta
		if c["x"] > w + 160.0:
			c["x"] = -160.0


	# Спавн мыльных пузырей
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var max_bubbles := 7 if is_night else 11
		if bubbles_layer.get_child_count() < max_bubbles:
			_spawn_bubble(VIEW_H + 60.0)
		spawn_timer = randf_range(0.85, 1.45) if is_night else randf_range(0.65, 1.25)

	# Ночью над спящими котиками плавно всплывают сонные кружочки-сны
	if is_night:
		zzz_timer -= delta
		if zzz_timer <= 0.0:
			zzz_timer = randf_range(0.7, 1.3)
			var sleepy_cat: ChoirCat = cats[randi() % cats.size()]
			if sleepy_cat.sing_timer <= 0.0:
				floating_fx.append({
					"type": "zzz",
					"pos": sleepy_cat.global_position + Vector2(randf_range(10.0, 28.0), -110.0),
					"vel": Vector2(randf_range(8.0, 22.0), -42.0),
					"color": Color("#FFEAA7"),
					"life": 1.4,
					"max_life": 1.4
				})

	# Обновляем падающие игрушки из пузырей
	for i in range(falling_toys.size() - 1, -1, -1):
		var toy: Dictionary = falling_toys[i]
		toy["t"] += delta * 2.1
		var t: float = clampf(toy["t"], 0.0, 1.0)
		var start_pos: Vector2 = toy["start"]
		var target_cat: ChoirCat = toy["cat"]
		var end_pos := target_cat.global_position + Vector2(0, -65)
		# Красивая дуга падения к котику
		toy["pos"] = start_pos.lerp(end_pos, t) + Vector2(0, -sin(t * PI) * 85.0)
		toy["rot"] += delta * 6.0

		if t >= 1.0:
			target_cat.sing(true)
			falling_toys.remove_at(i)

	# Обновляем партиклы (нотки, сердечки, брызги)
	for i in range(floating_fx.size() - 1, -1, -1):
		var fx: Dictionary = floating_fx[i]
		fx["life"] -= delta
		fx["pos"] += fx["vel"] * delta
		if fx["life"] <= 0.0:
			floating_fx.remove_at(i)

	# Очищаем кулдауны свайпа по котикам
	for key in _cat_drag_cooldown.keys():
		_cat_drag_cooldown[key] -= delta
		if _cat_drag_cooldown[key] <= 0.0:
			_cat_drag_cooldown.erase(key)

	queue_redraw()
	fx_layer.queue_redraw()


## Мультитач-обработка: каждый пальчик работает независимо!
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_touch_point(event.position, false)
	elif event is InputEventScreenDrag:
		_handle_touch_point(event.position, true)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_touch_point(event.position, false)


func _handle_touch_point(pt: Vector2, is_drag: bool) -> void:
	# 1. Сначала проверяем мыльные пузыри (их приятно лопать и тапом, и проводя пальцем)
	var popped_any := false
	for child in bubbles_layer.get_children():
		if child is SoapBubble and child.is_point_inside(pt):
			child.pop()
			popped_any = true
			if not is_drag:
				break

	if popped_any and not is_drag:
		return

	# 2. Проверяем нажатие или поглаживание котиков
	for i in range(cats.size()):
		var cat := cats[i]
		if cat.is_point_inside(pt):
			if is_drag:
				if not _cat_drag_cooldown.has(i):
					_cat_drag_cooldown[i] = 0.35
					cat.sing(false)
			else:
				cat.sing(false)
			return

	# 0. Кнопка "Домик" (возврат в главное меню выбора игр)
	if not is_drag and pt.distance_to(Vector2(65, 62)) <= 45.0:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return

	# 3. Ночью можно нажимать на звёздочки на небе — они звенят по нотам!
	if is_night and not is_drag:
		for s in night_stars:
			var spos: Vector2 = s["pos"]
			if pt.distance_to(spos) <= 48.0:
				s["bounce"] = 1.0
				_toy_player.pitch_scale = s["pitch"]
				_toy_player.play()
				for i in range(6):
					var a := TAU * float(i) / 6.0
					floating_fx.append({
						"type": "drop",
						"pos": spos,
						"vel": Vector2(cos(a) * 110.0, sin(a) * 110.0),
						"color": Color("#FFEAA7"),
						"life": 0.4,
						"max_life": 0.4
					})
				return

	# 4. Нажатие на Солнышко / Луну переключает День и Ночь + выпускает пузыри!
	if not is_drag and pt.distance_to(Vector2(_get_view_width() - 150.0, 105.0)) <= 80.0:
		is_night = not is_night
		for cat in cats:
			cat.is_night = is_night
		sun_bounce = 1.0
		_toy_player.pitch_scale = 0.85 if is_night else 1.2
		_toy_player.play()
		for i in range(3):
			_spawn_bubble(randf_range(520.0, 720.0))


func _spawn_bubble(start_y: float) -> void:
	var bubble := SoapBubble.new()
	bubble.position = Vector2(randf_range(120.0, _get_view_width() - 120.0), start_y)
	bubble.bubble_popped.connect(_on_bubble_popped)
	bubbles_layer.add_child(bubble)



func _on_bubble_popped(pos: Vector2, toy_type: int, toy_color: Color) -> void:
	_pop_player.pitch_scale = randf_range(0.88, 1.22)
	_pop_player.play()

	# Брызги мыльного пузыря
	for i in range(10):
		var angle := TAU * float(i) / 10.0 + randf_range(-0.2, 0.2)
		var speed := randf_range(90.0, 190.0)
		floating_fx.append({
			"type": "drop",
			"pos": pos,
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed),
			"color": toy_color.lightened(0.3),
			"life": 0.35,
			"max_life": 0.35
		})

	# Находим ближайшего котика, которому упадёт игрушка из пузыря
	var nearest_cat: ChoirCat = cats[0]
	var best_dist := INF
	for cat in cats:
		var d := absf(cat.global_position.x - pos.x)
		if d < best_dist:
			best_dist = d
			nearest_cat = cat

	falling_toys.append({
		"pos": pos,
		"start": pos,
		"cat": nearest_cat,
		"toy_type": toy_type,
		"color": toy_color,
		"t": 0.0,
		"rot": 0.0
	})


func _on_cat_sang(pos: Vector2, col: Color) -> void:
	# Выпускаем летящую музыкальную нотку (днём) или сердечко (ночью при мурчании)
	for i in range(2):
		var fx_type := "heart" if (is_night or i == 1) else "note"
		floating_fx.append({
			"type": fx_type,
			"pos": pos + Vector2(randf_range(-25.0, 25.0), randf_range(-10.0, 10.0)),
			"vel": Vector2(randf_range(-25.0, 25.0), randf_range(-95.0, -65.0)),
			"color": col,
			"life": 0.95,
			"max_life": 0.95
		})


func _draw() -> void:
	var w := _get_view_width()

	# 1. Небо (плавный переход День <-> Ночь)
	var sky_top := Color("#74B9FF").lerp(Color("#192A56"), night_blend)
	var sky_bot := Color("#A3DAFF").lerp(Color("#273C75"), night_blend)
	draw_rect(Rect2(-300, -300, w + 600, VIEW_H + 600), sky_top)
	draw_rect(Rect2(-300, 240, w + 600, VIEW_H + 200), sky_bot)

	# 1.5 Звёздочки ночью
	if night_blend > 0.02:
		for s in night_stars:
			var spos: Vector2 = s["pos"]
			var twinkle := 0.65 + 0.35 * sin(world_time * 3.2 + float(s["phase"]))
			var r := (14.0 + float(s["bounce"]) * 10.0) * night_blend
			var scol := Color(1.0, 0.93, 0.55, night_blend * twinkle)
			var pts := PackedVector2Array()
			for i in range(10):
				var angle := -PI * 0.5 + float(i) * PI / 5.0
				var rad := r if i % 2 == 0 else r * 0.42
				pts.append(spos + Vector2(cos(angle) * rad, sin(angle) * rad))
			draw_colored_polygon(pts, scol)

	# 2. Солнышко / Луна в углу (привязано к правому краю экрана)
	var sun_pos := Vector2(w - 150.0, 105.0)
	var sun_r := 54.0 + sin(world_time * 3.0) * 3.0 + sun_bounce * 16.0
	draw_circle(sun_pos, sun_r + 18.0, Color(1.0, 0.92, 0.4, 0.28))

	if night_blend < 0.5:
		# Лучики солнышка днём
		for i in range(12):
			var a := world_time * 0.4 + float(i) * TAU / 12.0
			draw_line(
				sun_pos + Vector2(cos(a) * (sun_r + 6.0), sin(a) * (sun_r + 6.0)),
				sun_pos + Vector2(cos(a) * (sun_r + 24.0), sin(a) * (sun_r + 24.0)),
				Color("#FFEAA7"),
				5.0,
				true
			)
		draw_circle(sun_pos, sun_r, Color("#FDCB6E"))
		draw_circle(sun_pos + Vector2(-15, -8), 5.0, Color("#2D3436"))
		draw_circle(sun_pos + Vector2(15, -8), 5.0, Color("#2D3436"))
		draw_arc(sun_pos + Vector2(0, 4), 16.0, 0.2, PI - 0.2, 14, Color("#2D3436"), 3.5, true)
	else:
		# Уютный полумесяц ночью
		draw_circle(sun_pos, sun_r, Color("#FFEAA7"))
		draw_circle(sun_pos + Vector2(-22, -14), sun_r * 0.82, sky_top)
		draw_arc(sun_pos + Vector2(10, -4), 6.0, 0.2, PI - 0.2, 10, Color("#2D3436"), 3.0, true)
		draw_arc(sun_pos + Vector2(12, 12), 10.0, 0.2, PI - 0.2, 10, Color("#2D3436"), 3.0, true)

	# 3. Облака
	var cloud_alpha := lerpf(0.92, 0.28, night_blend)
	for c in clouds:
		var cx: float = c["x"]
		var cy: float = c["y"]
		var sc: float = c["scale"]
		var col := Color(1, 1, 1, cloud_alpha)
		draw_circle(Vector2(cx, cy), 34.0 * sc, col)
		draw_circle(Vector2(cx - 30.0 * sc, cy + 8.0 * sc), 25.0 * sc, col)
		draw_circle(Vector2(cx + 32.0 * sc, cy + 6.0 * sc), 27.0 * sc, col)

	# 4. Зелёные холмы и полянка на всю ширину
	var hill1 := Color("#55EFC4").darkened(0.12).lerp(Color("#1E3799"), night_blend * 0.65)
	var hill2 := Color("#00B894").lightened(0.12).lerp(Color("#0C2461"), night_blend * 0.65)
	var lawn := Color("#58B19F").lerp(Color("#1B1464"), night_blend * 0.65)
	draw_circle(Vector2(w * 0.22, 920), 540.0, hill1)
	draw_circle(Vector2(w * 0.78, 940), 580.0, hill2)
	draw_rect(Rect2(-200, FENCE_Y - 10, w + 400, 300), lawn)

	# 5. Деревянный заборчик, на котором сидят котики
	var fence_wood := Color("#E1B12C").lerp(Color("#8C7AE6"), night_blend * 0.45)
	var fence_dark := Color("#C29216").lerp(Color("#40407A"), night_blend * 0.55)
	# Горизонтальные перекладины через весь экран
	draw_rect(Rect2(-80, FENCE_Y + 25, w + 160, 22), fence_dark)
	draw_rect(Rect2(-80, FENCE_Y + 110, w + 160, 22), fence_dark)

	# Вертикальные дощечки забора через всю ширину экрана
	for x in range(-30, int(w) + 70, 65):
		var px := float(x)
		draw_rect(Rect2(px, FENCE_Y - 4, 46, 185), fence_wood)
		var top_tri := PackedVector2Array([
			Vector2(px, FENCE_Y - 4),
			Vector2(px + 23, FENCE_Y - 26),
			Vector2(px + 46, FENCE_Y - 4)
		])
		draw_colored_polygon(top_tri, fence_wood)



func _draw_falling_toys_and_fx() -> void:
	for toy in falling_toys:
		var p: Vector2 = toy["pos"]
		var col: Color = toy["color"]
		fx_layer.draw_circle(p, 18.0, col)
		fx_layer.draw_circle(p + Vector2(-5, -5), 5.0, Color.WHITE)

	for fx in floating_fx:
		var alpha: float = clampf(fx["life"] / fx["max_life"], 0.0, 1.0)
		var col: Color = fx["color"]
		col.a = alpha
		var p: Vector2 = fx["pos"]

		match fx["type"]:
			"drop":
				fx_layer.draw_circle(p, 6.0 * alpha, col)
			"note":
				# Рисуем красивую музыкальную нотку ♪
				fx_layer.draw_circle(p, 9.0, col)
				fx_layer.draw_line(p + Vector2(7, 0), p + Vector2(7, -26), col, 4.0)
				fx_layer.draw_line(p + Vector2(7, -26), p + Vector2(20, -20), col, 5.0)
			"heart":
				fx_layer.draw_circle(p + Vector2(-6, 0), 7.5, col)
				fx_layer.draw_circle(p + Vector2(6, 0), 7.5, col)
				var tri := PackedVector2Array([
					p + Vector2(-13, 3),
					p + Vector2(13, 3),
					p + Vector2(0, 18)
				])
				fx_layer.draw_colored_polygon(tri, col)
			"zzz":
				# Рисуем букву Z над спящим котиком
				fx_layer.draw_line(p + Vector2(-8, -8), p + Vector2(8, -8), col, 3.0)
				fx_layer.draw_line(p + Vector2(8, -8), p + Vector2(-8, 8), col, 3.0)
				fx_layer.draw_line(p + Vector2(-8, 8), p + Vector2(8, 8), col, 3.0)

	# Кнопка "Домик" в левом верхнем углу
	var hb := Vector2(65, 62)
	fx_layer.draw_circle(hb, 36.0, Color(1, 1, 1, 0.92))
	fx_layer.draw_arc(hb, 36.0, 0, TAU, 28, Color("#FF9F43"), 4.0, true)
	# Домик (крыша и стены)
	fx_layer.draw_rect(Rect2(hb.x - 14, hb.y - 2, 28, 20), Color("#FF9F43"))
	fx_layer.draw_colored_polygon(PackedVector2Array([
		hb + Vector2(-21, 0),
		hb + Vector2(0, -19),
		hb + Vector2(21, 0)
	]), Color("#E17055"))
	fx_layer.draw_rect(Rect2(hb.x - 5, hb.y + 6, 10, 12), Color("#FFF9E6"))

extends Node2D

const VIEW_W := 1280.0
const VIEW_H := 720.0

const CARD_CATS_RECT := Rect2(140, 175, 450, 440)
const CARD_SEA_RECT := Rect2(690, 175, 450, 440)

var anim_time: float = 0.0
var _chime_player: AudioStreamPlayer
var _meow_player: AudioStreamPlayer
var _splash_player: AudioStreamPlayer
var _switching: bool = false

var clouds := [
	{"x": 160.0, "y": 85.0, "speed": 16.0, "scale": 0.95},
	{"x": 640.0, "y": 65.0, "speed": 12.0, "scale": 1.15},
	{"x": 1080.0, "y": 95.0, "speed": 20.0, "scale": 0.85}
]


func _ready() -> void:
	_chime_player = AudioStreamPlayer.new()
	_chime_player.stream = SoundGen.get_toy_stream()
	add_child(_chime_player)

	_meow_player = AudioStreamPlayer.new()
	_meow_player.stream = SoundGen.get_meow_stream(0)
	add_child(_meow_player)

	_splash_player = AudioStreamPlayer.new()
	_splash_player.stream = SoundGen.get_splash_stream()
	add_child(_splash_player)


func _process(delta: float) -> void:
	anim_time += delta
	for c in clouds:
		c["x"] += c["speed"] * delta
		if c["x"] > VIEW_W + 150.0:
			c["x"] = -150.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _switching:
		return
	if event is InputEventScreenTouch and event.pressed:
		_on_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tap(event.position)


func _on_tap(pt: Vector2) -> void:
	if CARD_CATS_RECT.has_point(pt):
		_switching = true
		_meow_player.play()
		_chime_player.play()
		var tw := create_tween()
		tw.tween_interval(0.28)
		tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	elif CARD_SEA_RECT.has_point(pt):
		_switching = true
		_splash_player.play()
		_chime_player.play()
		var tw := create_tween()
		tw.tween_interval(0.28)
		tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/sea_game.tscn"))


func _draw() -> void:
	var font := ThemeDB.fallback_font

	# 1. Фон неба и лужайки
	draw_rect(Rect2(-200, -200, VIEW_W + 400, VIEW_H + 400), Color("#74B9FF"))
	draw_rect(Rect2(-200, 320, VIEW_W + 400, VIEW_H), Color("#A3DAFF"))
	draw_circle(Vector2(320, 960), 540.0, Color("#55EFC4").darkened(0.1))
	draw_circle(Vector2(980, 960), 560.0, Color("#00B894").lightened(0.1))

	# Облака
	for c in clouds:
		var cx: float = c["x"]
		var cy: float = c["y"]
		var sc: float = c["scale"]
		var col := Color(1, 1, 1, 0.9)
		draw_circle(Vector2(cx, cy), 30.0 * sc, col)
		draw_circle(Vector2(cx - 26.0 * sc, cy + 6.0 * sc), 22.0 * sc, col)
		draw_circle(Vector2(cx + 28.0 * sc, cy + 5.0 * sc), 24.0 * sc, col)

	# 2. Заголовок библиотеки игр
	var title_box := Rect2(310, 26, 660, 96)
	_draw_rounded_panel(title_box, Color("#FFFFFF"), Color("#FFEAA7"), 8.0)
	draw_string(
		font,
		Vector2(0, 74),
		"ЛАДУШКИ: ИГРЫ ДЛЯ МАЛЫШЕЙ 2+",
		HORIZONTAL_ALIGNMENT_CENTER,
		VIEW_W,
		34,
		Color("#2D3436")
	)
	draw_string(
		font,
		Vector2(0, 108),
		"Нажми на картинку, чтобы играть!",
		HORIZONTAL_ALIGNMENT_CENTER,
		VIEW_W,
		20,
		Color("#636E72")
	)

	# 3. КАРТОЧКА 1: «ПОЮЩИЕ КОТИКИ»
	var bounce1 := sin(anim_time * 3.0) * 5.0
	var r1 := CARD_CATS_RECT.grow(bounce1 * 0.4)
	# Тень карточки
	_draw_rounded_panel(Rect2(r1.position + Vector2(0, 10), r1.size), Color(0, 0, 0, 0.18), Color.TRANSPARENT, 0.0)
	_draw_rounded_panel(r1, Color("#FFF9E6"), Color("#FF9F43"), 10.0)

	# Иллюстрация внутри карточки 1 (Котик и мыльные пузыри)
	var c1_center := r1.position + Vector2(r1.size.x * 0.5, 200.0 + bounce1)
	draw_rect(Rect2(r1.position.x + 18, r1.position.y + 18, r1.size.x - 36, 290), Color("#A3DAFF"))
	draw_rect(Rect2(r1.position.x + 18, r1.position.y + 235, r1.size.x - 36, 75), Color("#55EFC4").darkened(0.15))

	# Мини-заборчик
	draw_rect(Rect2(r1.position.x + 18, r1.position.y + 250, r1.size.x - 36, 58), Color("#E1B12C"))
	# Рыжий котик на карточке
	_draw_cat_icon(c1_center + Vector2(0, 15))
	# Пузыри вокруг котика
	_draw_mini_bubble(c1_center + Vector2(-125, -55 + sin(anim_time * 2.5) * 10.0), 30.0)
	_draw_mini_bubble(c1_center + Vector2(125, -35 + cos(anim_time * 2.8) * 10.0), 26.0)
	# Нотка
	var note_p := c1_center + Vector2(85, -85 + sin(anim_time * 4.0) * 6.0)
	draw_circle(note_p, 8.0, Color("#FF6B81"))
	draw_line(note_p + Vector2(6, 0), note_p + Vector2(6, -24), Color("#FF6B81"), 4.0)
	draw_line(note_p + Vector2(6, -24), note_p + Vector2(18, -18), Color("#FF6B81"), 5.0)

	# Подпись карточки 1
	draw_string(
		font,
		Vector2(r1.position.x, r1.position.y + 360),
		"ПОЮЩИЕ КОТИКИ",
		HORIZONTAL_ALIGNMENT_CENTER,
		r1.size.x,
		32,
		Color("#D35400")
	)
	draw_string(
		font,
		Vector2(r1.position.x, r1.position.y + 398),
		"Кото-хор и мыльные пузыри",
		HORIZONTAL_ALIGNMENT_CENTER,
		r1.size.x,
		20,
		Color("#636E72")
	)

	# 4. КАРТОЧКА 2: «КУПАЕМ ПАПУ!»
	var bounce2 := sin(anim_time * 3.0 + 1.5) * 5.0
	var r2 := CARD_SEA_RECT.grow(bounce2 * 0.4)
	_draw_rounded_panel(Rect2(r2.position + Vector2(0, 10), r2.size), Color(0, 0, 0, 0.18), Color.TRANSPARENT, 0.0)
	_draw_rounded_panel(r2, Color("#EBF9FF"), Color("#0984E3"), 10.0)

	# Иллюстрация внутри карточки 2 (Море, девочка в жёлтом круге с рулём и папа)
	draw_rect(Rect2(r2.position.x + 18, r2.position.y + 18, r2.size.x - 36, 95), Color("#81ECEC"))
	draw_rect(Rect2(r2.position.x + 18, r2.position.y + 105, r2.size.x - 36, 203), Color("#0984E3").lightened(0.18))

	var c2_center := r2.position + Vector2(r2.size.x * 0.5, 200.0 + bounce2)
	# Волны
	for wx in range(-160, 180, 55):
		draw_arc(c2_center + Vector2(wx, 45), 22.0, 0.2, PI - 0.2, 10, Color(1, 1, 1, 0.5), 3.0, true)

	# Папа в воде машет рукой (справа на карточке)
	var dad_pos := c2_center + Vector2(95, -20 + sin(anim_time * 3.5) * 6.0)
	draw_circle(dad_pos + Vector2(0, 22), 28.0, Color("#74B9FF")) # Брызги/вода вокруг папы
	draw_circle(dad_pos, 24.0, Color("#FFD3B6")) # Голова папы
	# Причёска и улыбка папы
	draw_arc(dad_pos + Vector2(0, -6), 22.0, PI, TAU, 12, Color("#5D4037"), 8.0, true)
	draw_circle(dad_pos + Vector2(-8, -2), 3.5, Color("#2D3436"))
	draw_circle(dad_pos + Vector2(8, -2), 3.5, Color("#2D3436"))
	draw_arc(dad_pos + Vector2(0, 4), 9.0, 0.2, PI - 0.2, 10, Color("#2D3436"), 2.5, true)
	# Машущая рука папы
	var wave_angle := -0.8 + sin(anim_time * 7.0) * 0.35
	draw_line(dad_pos + Vector2(18, 16), dad_pos + Vector2(18, 16) + Vector2(cos(wave_angle), sin(wave_angle)) * 30.0, Color("#FFD3B6"), 9.0, true)

	# Девочка в жёлтом круге с рулём (слева на карточке)
	var girl_pos := c2_center + Vector2(-75, 10 + cos(anim_time * 3.2) * 6.0)
	# Жёлтый круг
	draw_circle(girl_pos + Vector2(0, 14), 46.0, Color("#FDCB6E"))
	draw_circle(girl_pos + Vector2(0, 14), 46.0, Color("#F39C12"), false, 4.0)
	draw_circle(girl_pos + Vector2(0, 14), 22.0, Color("#E17055"))
	# Руль на круге
	var wheel_c := girl_pos + Vector2(22, 18)
	draw_circle(wheel_c, 13.0, Color("#0984E3"), false, 4.0)
	draw_circle(wheel_c, 5.0, Color("#D63031"))
	# Личико девочки и бантики
	draw_circle(girl_pos + Vector2(-4, -14), 20.0, Color("#FFE0CC"))
	draw_circle(girl_pos + Vector2(-24, -22), 9.0, Color("#5D4037")) # Хвостик 1
	draw_circle(girl_pos + Vector2(16, -22), 9.0, Color("#5D4037"))  # Хвостик 2
	draw_circle(girl_pos + Vector2(-19, -22), 5.0, Color("#FD79A8")) # Бантик 1
	draw_circle(girl_pos + Vector2(11, -22), 5.0, Color("#FD79A8"))  # Бантик 2
	draw_circle(girl_pos + Vector2(-10, -15), 3.0, Color("#2D3436"))
	draw_circle(girl_pos + Vector2(2, -15), 3.0, Color("#2D3436"))
	draw_arc(girl_pos + Vector2(-4, -10), 6.5, 0.2, PI - 0.2, 8, Color("#D63031"), 2.5, true)

	# Подпись карточки 2
	draw_string(
		font,
		Vector2(r2.position.x, r2.position.y + 360),
		"КУПАЕМ ПАПУ! (3D)",
		HORIZONTAL_ALIGNMENT_CENTER,
		r2.size.x,
		32,
		Color("#0984E3")
	)
	draw_string(
		font,
		Vector2(r2.position.x, r2.position.y + 398),
		"Море, жёлтый круг, папа и дельфины",
		HORIZONTAL_ALIGNMENT_CENTER,
		r2.size.x,
		20,
		Color("#636E72")
	)


func _draw_rounded_panel(rect: Rect2, bg: Color, border: Color, border_w: float) -> void:
	draw_rect(rect, bg, true)
	if border_w > 0.0:
		draw_rect(rect, border, false, border_w)


func _draw_cat_icon(center: Vector2) -> void:
	# Ушки
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-36, -20),
		center + Vector2(-44, -66),
		center + Vector2(-10, -44)
	]), Color("#FF9F43"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(36, -20),
		center + Vector2(44, -66),
		center + Vector2(10, -44)
	]), Color("#FF9F43"))
	# Голова и тело
	draw_circle(center + Vector2(0, 22), 40.0, Color("#FF9F43"))
	draw_circle(center + Vector2(0, -20), 42.0, Color("#FF9F43"))
	# Глазки и ротик
	draw_circle(center + Vector2(-16, -24), 6.5, Color("#2D3436"))
	draw_circle(center + Vector2(16, -24), 6.5, Color("#2D3436"))
	draw_circle(center + Vector2(-18, -26), 2.5, Color.WHITE)
	draw_circle(center + Vector2(14, -26), 2.5, Color.WHITE)
	draw_circle(center + Vector2(0, -7), 8.0, Color("#D63031"))


func _draw_mini_bubble(pos: Vector2, r: float) -> void:
	draw_circle(pos, r, Color(1, 1, 1, 0.35))
	draw_arc(pos, r, 0, TAU, 24, Color(1, 1, 1, 0.85), 2.5, true)
	draw_circle(pos + Vector2(-r * 0.35, -r * 0.35), r * 0.18, Color(1, 1, 1, 0.9))


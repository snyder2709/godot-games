extends Node2D

const VIEW_W := 1280.0
const VIEW_H := 720.0

var anim_time: float = 0.0

var clouds := [
	{"x": 160.0, "y": 85.0, "speed": 16.0, "scale": 0.95},
	{"x": 640.0, "y": 65.0, "speed": 12.0, "scale": 1.15},
	{"x": 1080.0, "y": 95.0, "speed": 20.0, "scale": 0.85}
]

var _chime_player: AudioStreamPlayer
var _meow_player: AudioStreamPlayer
var _splash_player: AudioStreamPlayer
var _switching: bool = false


func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

	_chime_player = AudioStreamPlayer.new()
	_chime_player.stream = SoundGen.get_toy_stream()
	add_child(_chime_player)

	_meow_player = AudioStreamPlayer.new()
	_meow_player.stream = SoundGen.get_meow_stream(0)
	add_child(_meow_player)

	_splash_player = AudioStreamPlayer.new()
	_splash_player.stream = SoundGen.get_splash_stream()
	add_child(_splash_player)


func _get_view_size() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(1280.0, 720.0)


func _get_card_geometry(idx: int) -> Rect2:
	var vs := _get_view_size()
	var card_w := 360.0
	var card_h := 450.0
	var gap := 24.0
	var total_w := 3.0 * card_w + 2.0 * gap
	var start_x := (vs.x - total_w) * 0.5
	var card_x := start_x + idx * (card_w + gap)
	return Rect2(card_x, 172.0, card_w, card_h)


func _get_card_cats_rect() -> Rect2:
	return _get_card_geometry(0)


func _get_card_sea_rect() -> Rect2:
	return _get_card_geometry(1)


func _get_card_piano_rect() -> Rect2:
	return _get_card_geometry(2)


func _process(delta: float) -> void:
	anim_time += delta
	var vs := _get_view_size()
	for c in clouds:
		c["x"] += float(c["speed"]) * delta
		if float(c["x"]) > vs.x + 150.0:
			c["x"] = -150.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _switching:
		return
	if event is InputEventScreenTouch and event.pressed:
		_on_tap(event.position)
	elif (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		_on_tap(event.position)


func _on_tap(pt: Vector2) -> void:
	if _get_card_cats_rect().has_point(pt):
		_switching = true
		_meow_player.play()
		_chime_player.play()
		var tw := create_tween()
		tw.tween_interval(0.28)
		tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	elif _get_card_sea_rect().has_point(pt):
		_switching = true
		_splash_player.play()
		_chime_player.play()
		var tw := create_tween()
		tw.tween_interval(0.28)
		tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/sea_game.tscn"))
	elif _get_card_piano_rect().has_point(pt):
		_switching = true
		_meow_player.play()
		_chime_player.play()
		var tw := create_tween()
		tw.tween_interval(0.28)
		tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/piano.tscn"))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vs := _get_view_size()
	var w := vs.x
	var h := vs.y

	# Фон неба и лужайки
	draw_rect(Rect2(-300, -300, w + 600, h + 600), Color("#74B9FF"))
	draw_rect(Rect2(-300, 320, w + 600, h + 200), Color("#A3DAFF"))
	draw_circle(Vector2(w * 0.25, 960), 540.0, Color("#55EFC4").darkened(0.1))
	draw_circle(Vector2(w * 0.75, 960), 560.0, Color("#00B894").lightened(0.1))

	# Облака
	for c in clouds:
		var cx: float = float(c["x"])
		var cy: float = float(c["y"])
		var sc: float = float(c["scale"])
		var col := Color(1, 1, 1, 0.9)
		draw_circle(Vector2(cx, cy), 30.0 * sc, col)
		draw_circle(Vector2(cx - 26.0 * sc, cy + 6.0 * sc), 22.0 * sc, col)
		draw_circle(Vector2(cx + 28.0 * sc, cy + 5.0 * sc), 24.0 * sc, col)

	# Заголовок библиотеки игр
	var title_w := 680.0
	var title_box := Rect2((w - title_w) * 0.5, 24, title_w, 98)
	_draw_rounded_panel(title_box, Color("#FFFFFF"), Color("#FFEAA7"), 8.0)
	draw_string(
		font,
		Vector2(0, 72),
		"ЛАДУШКИ: ИГРЫ ДЛЯ МАЛЫШЕЙ 2+",
		HORIZONTAL_ALIGNMENT_CENTER,
		w,
		32,
		Color("#2D3436")
	)
	draw_string(
		font,
		Vector2(0, 106),
		"Нажми на картинку, чтобы играть!",
		HORIZONTAL_ALIGNMENT_CENTER,
		w,
		20,
		Color("#636E72")
	)

	# 1. КАРТОЧКА 1: «ПОЮЩИЕ КОТИКИ»
	_draw_cats_card(font)

	# 2. КАРТОЧКА 2: «КУПАЕМ ПАПУ!»
	_draw_sea_card(font)

	# 3. КАРТОЧКА 3: «КОТОПИАНИНО»
	_draw_piano_card(font)


func _draw_cats_card(font: Font) -> void:
	var bounce1 := sin(anim_time * 3.0) * 4.0
	var r1 := _get_card_cats_rect().grow(bounce1 * 0.4)

	_draw_rounded_panel(
		Rect2(r1.position + Vector2(0, 10), r1.size),
		Color(0, 0, 0, 0.16),
		Color.TRANSPARENT,
		0.0
	)
	_draw_rounded_panel(r1, Color("#FFF9E6"), Color("#FF9F43"), 8.0)

	var c1_center := r1.position + Vector2(r1.size.x * 0.5, 195.0 + bounce1)
	draw_rect(Rect2(r1.position.x + 16, r1.position.y + 16, r1.size.x - 32, 280), Color("#A3DAFF"))
	draw_rect(
		Rect2(r1.position.x + 16, r1.position.y + 225, r1.size.x - 32, 71),
		Color("#55EFC4").darkened(0.15)
	)
	draw_rect(
		Rect2(r1.position.x + 16, r1.position.y + 240, r1.size.x - 32, 56),
		Color("#E1B12C")
	)

	_draw_cat_icon(c1_center + Vector2(0, 15))
	_draw_mini_bubble(c1_center + Vector2(-105, -55 + sin(anim_time * 2.5) * 8.0), 26.0)
	_draw_mini_bubble(c1_center + Vector2(105, -35 + cos(anim_time * 2.8) * 8.0), 22.0)

	var note_p := c1_center + Vector2(75, -85 + sin(anim_time * 4.0) * 6.0)
	draw_circle(note_p, 7.0, Color("#FF6B81"))
	draw_line(note_p + Vector2(5, 0), note_p + Vector2(5, -20), Color("#FF6B81"), 3.5)
	draw_line(note_p + Vector2(5, -20), note_p + Vector2(16, -15), Color("#FF6B81"), 4.0)

	draw_string(
		font,
		Vector2(r1.position.x, r1.position.y + 355),
		"ПОЮЩИЕ КОТИКИ",
		HORIZONTAL_ALIGNMENT_CENTER,
		r1.size.x,
		26,
		Color("#D35400")
	)
	draw_string(
		font,
		Vector2(r1.position.x, r1.position.y + 395),
		"Кото-хор и мыльные пузыри",
		HORIZONTAL_ALIGNMENT_CENTER,
		r1.size.x,
		18,
		Color("#636E72")
	)


func _draw_sea_card(font: Font) -> void:
	var bounce2 := sin(anim_time * 3.0 + 1.2) * 4.0
	var r2 := _get_card_sea_rect().grow(bounce2 * 0.4)

	_draw_rounded_panel(
		Rect2(r2.position + Vector2(0, 10), r2.size),
		Color(0, 0, 0, 0.16),
		Color.TRANSPARENT,
		0.0
	)
	_draw_rounded_panel(r2, Color("#EBF9FF"), Color("#0984E3"), 8.0)

	draw_rect(Rect2(r2.position.x + 16, r2.position.y + 16, r2.size.x - 32, 90), Color("#81ECEC"))
	draw_rect(
		Rect2(r2.position.x + 16, r2.position.y + 100, r2.size.x - 32, 196),
		Color("#0984E3").lightened(0.18)
	)

	var c2_center := r2.position + Vector2(r2.size.x * 0.5, 195.0 + bounce2)
	for wx in range(-130, 150, 48):
		draw_arc(c2_center + Vector2(wx, 42), 18.0, 0.2, PI - 0.2, 8, Color(1, 1, 1, 0.5), 2.5, true)

	var dad_pos := c2_center + Vector2(72, -18 + sin(anim_time * 3.5) * 5.0)
	draw_circle(dad_pos + Vector2(0, 18), 24.0, Color("#74B9FF"))
	draw_circle(dad_pos, 20.0, Color("#FFD3B6"))
	draw_arc(dad_pos + Vector2(0, -5), 18.0, PI, TAU, 10, Color("#5D4037"), 7.0, true)
	draw_circle(dad_pos + Vector2(-6, -2), 3.0, Color("#2D3436"))
	draw_circle(dad_pos + Vector2(6, -2), 3.0, Color("#2D3436"))
	draw_arc(dad_pos + Vector2(0, 3), 7.5, 0.2, PI - 0.2, 8, Color("#2D3436"), 2.0, true)

	var girl_pos := c2_center + Vector2(-60, 12 + cos(anim_time * 3.2) * 5.0)
	draw_circle(girl_pos + Vector2(0, 12), 38.0, Color("#FDCB6E"))
	draw_circle(girl_pos + Vector2(0, 12), 38.0, Color("#F39C12"), false, 3.5)
	draw_circle(girl_pos + Vector2(0, 12), 18.0, Color("#E17055"))

	draw_circle(girl_pos + Vector2(-3, -12), 17.0, Color("#FFE0CC"))
	draw_circle(girl_pos + Vector2(-20, -18), 8.0, Color("#5D4037"))
	draw_circle(girl_pos + Vector2(14, -18), 8.0, Color("#5D4037"))
	draw_circle(girl_pos + Vector2(-16, -18), 4.0, Color("#FD79A8"))
	draw_circle(girl_pos + Vector2(10, -18), 4.0, Color("#FD79A8"))
	draw_circle(girl_pos + Vector2(-8, -13), 2.5, Color("#2D3436"))
	draw_circle(girl_pos + Vector2(2, -13), 2.5, Color("#2D3436"))

	draw_string(
		font,
		Vector2(r2.position.x, r2.position.y + 355),
		"КУПАЕМ ПАПУ! (3D)",
		HORIZONTAL_ALIGNMENT_CENTER,
		r2.size.x,
		26,
		Color("#0984E3")
	)
	draw_string(
		font,
		Vector2(r2.position.x, r2.position.y + 395),
		"Море, круг и дельфины",
		HORIZONTAL_ALIGNMENT_CENTER,
		r2.size.x,
		18,
		Color("#636E72")
	)


func _draw_piano_card(font: Font) -> void:
	var bounce3 := sin(anim_time * 3.0 + 2.4) * 4.0
	var r3 := _get_card_piano_rect().grow(bounce3 * 0.4)

	_draw_rounded_panel(
		Rect2(r3.position + Vector2(0, 10), r3.size),
		Color(0, 0, 0, 0.16),
		Color.TRANSPARENT,
		0.0
	)
	_draw_rounded_panel(r3, Color("#FFF0F5"), Color("#A29BFE"), 8.0)

	# Фон иллюстрации карточки
	var c3_center := r3.position + Vector2(r3.size.x * 0.5, 195.0 + bounce3)
	draw_rect(Rect2(r3.position.x + 16, r3.position.y + 16, r3.size.x - 32, 280), Color("#DDF3FF"))

	# Иконка мини-клавиатуры с котятами
	var kb_x := r3.position.x + 32.0
	var kb_y := c3_center.y - 45.0
	var kb_w := r3.size.x - 64.0
	var kb_h := 115.0

	# Корпус пианино
	draw_rect(Rect2(kb_x - 6, kb_y - 20, kb_w + 12, kb_h + 26), Color("#6C5CE7"))
	draw_rect(Rect2(kb_x - 4, kb_y - 18, kb_w + 8, kb_h + 22), Color("#A29BFE"))

	# 4 цветные клавиши котиков
	var kw := kb_w / 4.0
	var key_cols := [Color("#FF9F43"), Color("#55EFC4"), Color("#74B9FF"), Color("#FD79A8")]
	for i in range(4):
		var kx := kb_x + i * kw
		var k_press := sin(anim_time * 4.0 + i * 1.5) * 4.0
		var k_rect := Rect2(kx + 2, kb_y + k_press, kw - 4, kb_h - k_press)
		draw_rect(k_rect, Color.WHITE)
		draw_rect(Rect2(kx + 4, kb_y + k_press + 2, kw - 8, 38), key_cols[i])

		# Ушки котика на клавише
		var hc := Vector2(kx + kw * 0.5, kb_y + k_press + 20)
		draw_circle(hc, 14.0, key_cols[i])
		draw_circle(hc + Vector2(-5, -2), 2.2, Color("#2D3436"))
		draw_circle(hc + Vector2(5, -2), 2.2, Color("#2D3436"))
		draw_circle(hc + Vector2(0, 4), 1.8, Color("#D63031"))

		# Лапка внизу клавиши
		draw_circle(Vector2(kx + kw * 0.5, kb_y + kb_h - 10), 6.0, Color("#FFEAA7"))

	# Чёрная клавиша по центру
	draw_rect(Rect2(kb_x + kw * 1.5 - 10, kb_y, 20, 58), Color("#2D3436"))
	draw_circle(Vector2(kb_x + kw * 1.5, kb_y + 14), 7.0, Color("#2D3436"))
	draw_circle(Vector2(kb_x + kw * 1.5 - 2, kb_y + 14), 1.4, Color("#F1C40F"))
	draw_circle(Vector2(kb_x + kw * 1.5 + 2, kb_y + 14), 1.4, Color("#F1C40F"))

	# Парящие нотки и звездочки
	var note1 := c3_center + Vector2(-80, -75 + sin(anim_time * 3.5) * 7.0)
	var note2 := c3_center + Vector2(80, -82 + cos(anim_time * 3.8) * 7.0)
	draw_circle(note1, 7.0, Color("#A29BFE"))
	draw_line(note1 + Vector2(5, 0), note1 + Vector2(5, -18), Color("#A29BFE"), 3.0)
	draw_circle(note2, 7.0, Color("#FF7675"))
	draw_line(note2 + Vector2(5, 0), note2 + Vector2(5, -18), Color("#FF7675"), 3.0)

	draw_string(
		font,
		Vector2(r3.position.x, r3.position.y + 355),
		"КОТОПИАНИНО",
		HORIZONTAL_ALIGNMENT_CENTER,
		r3.size.x,
		26,
		Color("#6C5CE7")
	)
	draw_string(
		font,
		Vector2(r3.position.x, r3.position.y + 395),
		"Играй на котиках и пой песни",
		HORIZONTAL_ALIGNMENT_CENTER,
		r3.size.x,
		18,
		Color("#636E72")
	)


func _draw_rounded_panel(rect: Rect2, bg: Color, border: Color, border_w: float) -> void:
	draw_rect(rect, bg, true)
	if border_w > 0.0:
		draw_rect(rect, border, false, border_w)


func _draw_cat_icon(center: Vector2) -> void:
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
	draw_circle(center + Vector2(0, 22), 36.0, Color("#FF9F43"))
	draw_circle(center + Vector2(0, -18), 38.0, Color("#FF9F43"))
	draw_circle(center + Vector2(-14, -22), 6.0, Color("#2D3436"))
	draw_circle(center + Vector2(14, -22), 6.0, Color("#2D3436"))
	draw_circle(center + Vector2(-16, -24), 2.2, Color.WHITE)
	draw_circle(center + Vector2(12, -24), 2.2, Color.WHITE)
	draw_circle(center + Vector2(0, -6), 7.5, Color("#D63031"))


func _draw_mini_bubble(pos: Vector2, r: float) -> void:
	draw_circle(pos, r, Color(1, 1, 1, 0.35))
	draw_arc(pos, r, 0, TAU, 24, Color(1, 1, 1, 0.85), 2.5, true)
	draw_circle(pos + Vector2(-r * 0.35, -r * 0.35), r * 0.18, Color(1, 1, 1, 0.9))

class_name CatPiano
extends Node2D

enum SoundMode {
	MEOW,
	PIANO,
	BELL,
	QUACK,
}

const VIEW_W := 1280.0
const VIEW_H := 720.0

# 12-TET хроматические коэффициенты высоты тона для C4..C5
const NOTE_RATIOS_WHITE := [
	1.0,
	1.12246,
	1.25992,
	1.33484,
	1.49831,
	1.68179,
	1.88775,
	2.0,
]

const WHITE_NOTE_NAMES := ["ДО", "РЕ", "МИ", "ФА", "СОЛЬ", "ЛЯ", "СИ", "ДО"]
const WHITE_NOTE_LETTERS := ["C", "D", "E", "F", "G", "A", "B", "C"]

const NOTE_RATIOS_BLACK := [
	1.05946,
	1.18921,
	1.41421,
	1.58740,
	1.78180,
]

const BLACK_NOTE_NAMES := ["ДО#", "РЕ#", "ФА#", "СОЛЬ#", "ЛЯ#"]
const BLACK_KEY_SLOTS := [0, 1, 3, 4, 5]

# Мелодии в формате: [тип_клавиши (0=белая, 1=черная), индекс, длительность_сек]
const SONGS := [
	{
		"title": "Два весёлых гуся",
		"notes": [
			[0, 3, 0.32], [0, 2, 0.32], [0, 1, 0.32], [0, 0, 0.50],
			[0, 4, 0.40], [0, 4, 0.55],
			[0, 3, 0.32], [0, 2, 0.32], [0, 1, 0.32], [0, 0, 0.50],
			[0, 4, 0.40], [0, 4, 0.55],
			[0, 3, 0.32], [0, 5, 0.35], [0, 5, 0.35], [0, 3, 0.40],
			[0, 2, 0.32], [0, 4, 0.35], [0, 4, 0.35], [0, 2, 0.40],
			[0, 1, 0.30], [0, 2, 0.30], [0, 3, 0.30], [0, 1, 0.40], [0, 0, 0.65],
		]
	},
	{
		"title": "В траве сидел кузнечик",
		"notes": [
			[0, 5, 0.32], [0, 2, 0.32], [0, 5, 0.32], [0, 2, 0.32],
			[0, 5, 0.32], [1, 3, 0.32], [1, 3, 0.60],
			[1, 3, 0.32], [0, 2, 0.32], [1, 3, 0.32], [0, 2, 0.32],
			[1, 3, 0.32], [0, 5, 0.32], [0, 5, 0.60],
		]
	},
	{
		"title": "Чижик-пыжик",
		"notes": [
			[0, 2, 0.32], [0, 0, 0.32], [0, 2, 0.32], [0, 0, 0.32],
			[0, 3, 0.32], [0, 2, 0.32], [0, 1, 0.55],
			[0, 4, 0.32], [0, 4, 0.32], [0, 4, 0.32], [0, 5, 0.32],
			[0, 4, 0.32], [0, 3, 0.32], [0, 2, 0.32], [0, 1, 0.32], [0, 0, 0.65],
		]
	}
]

var current_mode: int = SoundMode.MEOW
var anim_time: float = 0.0

var white_keys: Array[Dictionary] = []
var black_keys: Array[Dictionary] = []

var floating_particles: Array[Dictionary] = []

var maestro_bounce: float = 0.0
var maestro_eye_blink: float = 2.5
var maestro_is_blinking: bool = false

var is_playing_song: bool = false
var current_song_idx: int = 0
var song_step_idx: int = 0
var song_step_timer: float = 0.0
var song_hint_key_type: int = -1
var song_hint_key_idx: int = -1

var _active_touches: Dictionary = {}
var _mouse_pressed: bool = false
var _audio_players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var _chime_player: AudioStreamPlayer
var _meow_player: AudioStreamPlayer
var _purr_player: AudioStreamPlayer


func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	randomize()

	_init_audio_pool()
	_init_keys()


func _init_audio_pool() -> void:
	for i in range(10):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_audio_players.append(p)

	_chime_player = AudioStreamPlayer.new()
	_chime_player.stream = SoundGen.get_toy_stream()
	add_child(_chime_player)

	_meow_player = AudioStreamPlayer.new()
	_meow_player.stream = SoundGen.get_meow_stream(0)
	add_child(_meow_player)

	_purr_player = AudioStreamPlayer.new()
	_purr_player.stream = SoundGen.get_purr_stream()
	add_child(_purr_player)


func _init_keys() -> void:
	white_keys.clear()
	black_keys.clear()

	var white_colors := [
		Color("#FF9F43"),
		Color("#FAB1A0"),
		Color("#FDCB6E"),
		Color("#55EFC4"),
		Color("#74B9FF"),
		Color("#A29BFE"),
		Color("#FD79A8"),
		Color("#FFEAA7"),
	]

	var white_names := [
		"Рыжик", "Персик", "Лучик", "Мятка", "Капелька", "Черничка", "Пуговка", "Снежок"
	]

	for i in range(8):
		white_keys.append({
			"name": white_names[i],
			"note": WHITE_NOTE_NAMES[i],
			"letter": WHITE_NOTE_LETTERS[i],
			"color": white_colors[i],
			"belly_col": white_colors[i].lightened(0.35),
			"ratio": NOTE_RATIOS_WHITE[i],
			"is_pressed": false,
			"press_depth": 0.0,
			"sing_timer": 0.0,
		})

	for i in range(5):
		black_keys.append({
			"note": BLACK_NOTE_NAMES[i],
			"slot": BLACK_KEY_SLOTS[i],
			"color": Color("#2D3436"),
			"ratio": NOTE_RATIOS_BLACK[i],
			"is_pressed": false,
			"press_depth": 0.0,
			"sing_timer": 0.0,
		})


func _get_view_size() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(VIEW_W, VIEW_H)


func _get_keyboard_rect() -> Rect2:
	var vs := _get_view_size()
	var pad_x := maxf(16.0, (vs.x - 1240.0) * 0.5)
	var kb_w := vs.x - pad_x * 2.0
	var kb_y := 178.0
	var kb_h := vs.y - kb_y - 12.0
	return Rect2(pad_x, kb_y, kb_w, kb_h)


func _get_white_key_rect(idx: int) -> Rect2:
	var kb := _get_keyboard_rect()
	var gap := 4.0
	var total_gaps := gap * 7.0
	var key_w := (kb.size.x - total_gaps) / 8.0
	var key_x := kb.position.x + idx * (key_w + gap)
	return Rect2(key_x, kb.position.y, key_w, kb.size.y)


func _get_black_key_rect(idx: int) -> Rect2:
	var slot: int = BLACK_KEY_SLOTS[idx]
	var w1 := _get_white_key_rect(slot)
	var w2 := _get_white_key_rect(slot + 1)
	var bw := w1.size.x * 0.60
	var bh := w1.size.y * 0.58
	var bx := (w1.position.x + w1.size.x + w2.position.x) * 0.5 - bw * 0.5
	return Rect2(bx, w1.position.y, bw, bh)


func _process(delta: float) -> void:
	anim_time += delta

	maestro_eye_blink -= delta
	if maestro_eye_blink <= 0.0:
		if maestro_is_blinking:
			maestro_is_blinking = false
			maestro_eye_blink = randf_range(2.0, 4.5)
		else:
			maestro_is_blinking = true
			maestro_eye_blink = 0.14

	if maestro_bounce > 0.0:
		maestro_bounce = maxf(0.0, maestro_bounce - delta * 3.5)

	for k in white_keys:
		var target: float = 1.0 if k["is_pressed"] else 0.0
		var spd: float = 20.0 if k["is_pressed"] else 12.0
		k["press_depth"] = move_toward(k["press_depth"], target, delta * spd)
		if k["sing_timer"] > 0.0:
			k["sing_timer"] = maxf(0.0, k["sing_timer"] - delta)

	for k in black_keys:
		var target: float = 1.0 if k["is_pressed"] else 0.0
		var spd: float = 20.0 if k["is_pressed"] else 12.0
		k["press_depth"] = move_toward(k["press_depth"], target, delta * spd)
		if k["sing_timer"] > 0.0:
			k["sing_timer"] = maxf(0.0, k["sing_timer"] - delta)

	var keep_particles: Array[Dictionary] = []
	for p in floating_particles:
		p["age"] += delta
		p["pos"] += p["vel"] * delta
		p["rot"] += p["rot_vel"] * delta
		if p["age"] < p["life"]:
			keep_particles.append(p)
	floating_particles = keep_particles

	if is_playing_song:
		_process_song(delta)

	queue_redraw()


func _process_song(delta: float) -> void:
	song_step_timer -= delta
	if song_step_timer <= 0.0:
		var song: Dictionary = SONGS[current_song_idx]
		var notes: Array = song["notes"]
		if song_step_idx < notes.size():
			var n: Array = notes[song_step_idx]
			var n_type: int = int(n[0])
			var n_idx: int = int(n[1])
			var dur: float = float(n[2])

			song_hint_key_type = n_type
			song_hint_key_idx = n_idx

			_play_key(n_type, n_idx, true)
			song_step_idx += 1
			song_step_timer = dur
		else:
			is_playing_song = false
			song_step_idx = 0
			song_hint_key_type = -1
			song_hint_key_idx = -1
			maestro_bounce = 1.0
			_purr_player.play()
			_spawn_confetti(Vector2(_get_view_size().x * 0.5, 95.0))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_down(event.index, event.position)
		else:
			_handle_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event.index, event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_pressed = true
				_handle_touch_down(999, event.position)
			else:
				_mouse_pressed = false
				_handle_touch_up(999)
	elif event is InputEventMouseMotion and _mouse_pressed:
		_handle_touch_drag(999, event.position)


func _get_home_button_rect() -> Rect2:
	return Rect2(24.0, 24.0, 80.0, 80.0)


func _get_maestro_rect() -> Rect2:
	var vs := _get_view_size()
	return Rect2(vs.x * 0.5 - 75.0, 15.0, 150.0, 140.0)


func _get_mode_button_rect(idx: int) -> Rect2:
	var vs := _get_view_size()
	var right_edge := vs.x - 24.0
	var btn_w := 92.0
	var btn_h := 68.0
	var gap := 10.0
	var total_w := 5.0 * btn_w + 4.0 * gap
	var start_x := right_edge - total_w
	return Rect2(start_x + idx * (btn_w + gap), 30.0, btn_w, btn_h)


func _get_song_button_rect() -> Rect2:
	return _get_mode_button_rect(4)


func _handle_touch_down(touch_id: int, pos: Vector2) -> void:
	if _get_home_button_rect().has_point(pos):
		_chime_player.play()
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
		return

	if _get_maestro_rect().has_point(pos):
		maestro_bounce = 1.0
		_meow_player.pitch_scale = randf_range(1.1, 1.3)
		_meow_player.play()
		_spawn_confetti(pos)
		Input.vibrate_handheld(25)
		return

	for m in range(4):
		if _get_mode_button_rect(m).has_point(pos):
			current_mode = m
			_chime_player.pitch_scale = 1.0 + m * 0.12
			_chime_player.play()
			Input.vibrate_handheld(20)
			return

	if _get_song_button_rect().has_point(pos):
		if is_playing_song:
			is_playing_song = false
			song_hint_key_type = -1
			song_hint_key_idx = -1
		else:
			is_playing_song = true
			song_step_idx = 0
			song_step_timer = 0.05
			current_song_idx = (current_song_idx + 1) % SONGS.size()
			maestro_bounce = 0.8
		_chime_player.play()
		Input.vibrate_handheld(30)
		return

	for i in range(black_keys.size()):
		if _get_black_key_rect(i).has_point(pos):
			_press_key(touch_id, 1, i)
			return

	for i in range(white_keys.size()):
		if _get_white_key_rect(i).has_point(pos):
			_press_key(touch_id, 0, i)
			return


func _handle_touch_drag(touch_id: int, pos: Vector2) -> void:
	var hit_type := -1
	var hit_idx := -1

	for i in range(black_keys.size()):
		if _get_black_key_rect(i).has_point(pos):
			hit_type = 1
			hit_idx = i
			break

	if hit_type == -1:
		for i in range(white_keys.size()):
			if _get_white_key_rect(i).has_point(pos):
				hit_type = 0
				hit_idx = i
				break

	if not _active_touches.has(touch_id):
		if hit_type != -1:
			_press_key(touch_id, hit_type, hit_idx)
		return

	var last_info: Dictionary = _active_touches[touch_id]
	if last_info["type"] != hit_type or last_info["idx"] != hit_idx:
		_release_key(touch_id)
		if hit_type != -1:
			_press_key(touch_id, hit_type, hit_idx)


func _handle_touch_up(touch_id: int) -> void:
	_release_key(touch_id)


func _press_key(touch_id: int, key_type: int, key_idx: int) -> void:
	_active_touches[touch_id] = {"type": key_type, "idx": key_idx}
	_play_key(key_type, key_idx, false)


func _play_key(key_type: int, key_idx: int, is_auto: bool) -> void:
	var key_dict: Dictionary
	var key_rect: Rect2
	if key_type == 0:
		key_dict = white_keys[key_idx]
		key_rect = _get_white_key_rect(key_idx)
	else:
		key_dict = black_keys[key_idx]
		key_rect = _get_black_key_rect(key_idx)

	key_dict["is_pressed"] = true
	key_dict["sing_timer"] = 0.45

	var ratio: float = float(key_dict["ratio"])
	_play_sound(ratio)

	if not is_auto:
		Input.vibrate_handheld(20)

	var p_x: float = key_rect.position.x + key_rect.size.x * 0.5
	var p_y: float = key_rect.position.y + 20.0
	var p_col: Color = key_dict["color"]
	_spawn_particle(Vector2(p_x, p_y), p_col)


func _release_key(touch_id: int) -> void:
	if not _active_touches.has(touch_id):
		return
	var info: Dictionary = _active_touches[touch_id]
	var k_type: int = int(info["type"])
	var k_idx: int = int(info["idx"])
	if k_type == 0 and k_idx < white_keys.size():
		white_keys[k_idx]["is_pressed"] = false
	elif k_type == 1 and k_idx < black_keys.size():
		black_keys[k_idx]["is_pressed"] = false
	_active_touches.erase(touch_id)


func _play_sound(ratio: float) -> void:
	var player: AudioStreamPlayer = _audio_players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _audio_players.size()

	match current_mode:
		SoundMode.MEOW:
			player.stream = SoundGen.get_meow_stream(0)
			player.pitch_scale = ratio * randf_range(0.99, 1.01)
		SoundMode.PIANO:
			player.stream = SoundGen.get_piano_stream()
			player.pitch_scale = ratio
		SoundMode.BELL:
			player.stream = SoundGen.get_bell_stream()
			player.pitch_scale = ratio
		SoundMode.QUACK:
			player.stream = SoundGen.get_quack_stream()
			player.pitch_scale = ratio * 0.95

	player.play()


func _spawn_particle(pos: Vector2, col: Color) -> void:
	var symbols := ["♪", "♫", "★", "♥", "🐾"]
	floating_particles.append({
		"pos": pos,
		"vel": Vector2(randf_range(-40.0, 40.0), randf_range(-110.0, -170.0)),
		"color": col,
		"symbol": symbols[randi() % symbols.size()],
		"size": randf_range(24.0, 34.0),
		"rot": randf_range(-0.4, 0.4),
		"rot_vel": randf_range(-1.5, 1.5),
		"age": 0.0,
		"life": randf_range(0.85, 1.25)
	})


func _spawn_confetti(center: Vector2) -> void:
	for i in range(16):
		var angle := randf() * TAU
		var spd := randf_range(90.0, 240.0)
		floating_particles.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"color": Color.from_hsv(randf(), 0.85, 1.0),
			"symbol": ["★", "♪", "●", "♥"][randi() % 4],
			"size": randf_range(18.0, 28.0),
			"rot": randf() * TAU,
			"rot_vel": randf_range(-3.0, 3.0),
			"age": 0.0,
			"life": randf_range(0.9, 1.4)
		})


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vs := _get_view_size()
	var w := vs.x
	var h := vs.y

	draw_rect(Rect2(0, 0, w, h), Color("#FFEAA7").lightened(0.55))
	draw_rect(Rect2(0, 0, w, 168), Color("#74B9FF").lightened(0.25))

	_draw_decorations()
	_draw_home_button()
	_draw_maestro()
	_draw_mode_selector()
	_draw_keyboard(font)
	_draw_particles(font)


func _draw_decorations() -> void:
	var vs := _get_view_size()
	var flag_colors := [
		Color("#FF7675"),
		Color("#FDCB6E"),
		Color("#55EFC4"),
		Color("#74B9FF"),
		Color("#A29BFE"),
	]
	var flag_y := 6.0
	for i in range(18):
		var fx := 110.0 + i * 62.0
		if fx > vs.x - 480.0 and fx < vs.x - 20.0:
			continue
		var col: Color = flag_colors[i % flag_colors.size()]
		var sway := sin(anim_time * 2.0 + i * 0.4) * 3.0
		var pts := PackedVector2Array([
			Vector2(fx - 14, flag_y),
			Vector2(fx + 14, flag_y),
			Vector2(fx, flag_y + 24.0 + sway)
		])
		draw_colored_polygon(pts, col)


func _draw_home_button() -> void:
	var r := _get_home_button_rect()
	var center := r.position + r.size * 0.5
	draw_circle(center + Vector2(0, 4), 38.0, Color(0, 0, 0, 0.15))
	draw_circle(center, 38.0, Color("#FFFFFF"))
	draw_circle(center, 34.0, Color("#FF7675"))
	var roof := PackedVector2Array([
		center + Vector2(0, -18),
		center + Vector2(-18, -2),
		center + Vector2(18, -2)
	])
	draw_colored_polygon(roof, Color.WHITE)
	draw_rect(Rect2(center.x - 12, center.y - 2, 24, 18), Color.WHITE)
	draw_rect(Rect2(center.x - 5, center.y + 4, 10, 12), Color("#FF7675"))


func _draw_maestro() -> void:
	var r := _get_maestro_rect()
	var cx := r.position.x + r.size.x * 0.5
	var cy := r.position.y + r.size.y * 0.5 + sin(anim_time * 3.5) * 4.0 - maestro_bounce * 16.0

	var cloud_col := Color(1, 1, 1, 0.95)
	draw_circle(Vector2(cx, cy + 38), 34.0, cloud_col)
	draw_circle(Vector2(cx - 38, cy + 42), 24.0, cloud_col)
	draw_circle(Vector2(cx + 38, cy + 42), 24.0, cloud_col)

	draw_circle(Vector2(cx, cy + 10), 28.0, Color("#FFFFFF"))

	var bow_col := Color("#D63031")
	var bow_l := PackedVector2Array([
		Vector2(cx, cy + 18),
		Vector2(cx - 12, cy + 12),
		Vector2(cx - 12, cy + 24)
	])
	var bow_r := PackedVector2Array([
		Vector2(cx, cy + 18),
		Vector2(cx + 12, cy + 12),
		Vector2(cx + 12, cy + 24)
	])
	draw_colored_polygon(bow_l, bow_col)
	draw_colored_polygon(bow_r, bow_col)
	draw_circle(Vector2(cx, cy + 18), 4.0, Color("#FFEAA7"))

	var head_c := Vector2(cx, cy - 14)
	draw_circle(head_c, 24.0, Color("#FFFFFF"))
	var ear_l := PackedVector2Array([
		head_c + Vector2(-18, -12),
		head_c + Vector2(-26, -34),
		head_c + Vector2(-6, -20)
	])
	var ear_r := PackedVector2Array([
		head_c + Vector2(18, -12),
		head_c + Vector2(26, -34),
		head_c + Vector2(6, -20)
	])
	draw_colored_polygon(ear_l, Color("#FFFFFF"))
	draw_colored_polygon(ear_r, Color("#FFFFFF"))
	draw_colored_polygon(ear_l, Color("#FDA7DF"))
	draw_colored_polygon(ear_r, Color("#FDA7DF"))

	if maestro_is_blinking:
		draw_line(head_c + Vector2(-12, -2), head_c + Vector2(-4, -2), Color("#2D3436"), 2.5)
		draw_line(head_c + Vector2(4, -2), head_c + Vector2(12, -2), Color("#2D3436"), 2.5)
	else:
		draw_circle(head_c + Vector2(-8, -2), 3.5, Color("#2D3436"))
		draw_circle(head_c + Vector2(8, -2), 3.5, Color("#2D3436"))
		draw_circle(head_c + Vector2(-9, -3), 1.2, Color.WHITE)
		draw_circle(head_c + Vector2(7, -3), 1.2, Color.WHITE)

	draw_circle(head_c + Vector2(0, 4), 2.5, Color("#FD79A8"))
	draw_arc(head_c + Vector2(-4, 7), 4.0, 0.1, PI * 0.9, 6, Color("#2D3436"), 2.0, true)
	draw_arc(head_c + Vector2(4, 7), 4.0, 0.1, PI * 0.9, 6, Color("#2D3436"), 2.0, true)

	var wand_angle := -0.6 + sin(anim_time * 5.0) * 0.4
	var wand_start := head_c + Vector2(22, 12)
	var wand_end := wand_start + Vector2(cos(wand_angle), sin(wand_angle)) * 36.0
	draw_line(wand_start, wand_end, Color("#E17055"), 3.5, true)
	draw_circle(wand_end, 6.0, Color("#F1C40F"))


func _draw_mode_selector() -> void:
	var font := ThemeDB.fallback_font
	var mode_titles := ["МЯУ 🐱", "ПИАНО 🎹", "ЗВОН 🔔", "КРЯ 🦆"]

	for i in range(4):
		var r := _get_mode_button_rect(i)
		var is_sel := (current_mode == i)
		var bg_col := Color("#FF9F43") if is_sel else Color("#FFFFFF")
		var text_col := Color.WHITE if is_sel else Color("#2D3436")
		var border_col := Color("#E67E22") if is_sel else Color("#DFE4EA")

		_draw_rounded_rect(r, bg_col, border_col, 16.0, 3.5)
		draw_string(
			font,
			Vector2(r.position.x, r.position.y + 42),
			mode_titles[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x,
			16,
			text_col
		)

	var song_r := _get_song_button_rect()
	var song_bg := Color("#2ED573") if is_playing_song else Color("#1DD1A1").lightened(0.8)
	var song_txt := "СТОП ⏹" if is_playing_song else "ПЕСНЯ 🎵"
	var song_col := Color.WHITE if is_playing_song else Color("#10AC84")
	_draw_rounded_rect(song_r, song_bg, Color("#10AC84"), 16.0, 3.5)
	draw_string(
		font,
		Vector2(song_r.position.x, song_r.position.y + 42),
		song_txt,
		HORIZONTAL_ALIGNMENT_CENTER,
		song_r.size.x,
		16,
		song_col
	)


func _draw_keyboard(font: Font) -> void:
	for i in range(white_keys.size()):
		_draw_white_key(i, font)

	for i in range(black_keys.size()):
		_draw_black_key(i, font)


func _draw_white_key(idx: int, font: Font) -> void:
	var k: Dictionary = white_keys[idx]
	var base_r := _get_white_key_rect(idx)
	var depth: float = float(k["press_depth"])
	var offset_y := depth * 14.0

	var r := Rect2(
		base_r.position.x,
		base_r.position.y + offset_y,
		base_r.size.x,
		base_r.size.y - offset_y
	)
	var main_col: Color = k["color"]
	var belly_col: Color = k["belly_col"]
	var is_singing: bool = float(k["sing_timer"]) > 0.0

	_draw_rounded_rect(
		Rect2(base_r.position.x, base_r.position.y + 12, base_r.size.x, base_r.size.y),
		Color(0, 0, 0, 0.14),
		Color.TRANSPARENT,
		20.0,
		0.0
	)

	var key_fill := Color("#FFFFFF").lerp(main_col.lightened(0.7), 0.35)
	if bool(k["is_pressed"]):
		key_fill = key_fill.darkened(0.06)
	_draw_rounded_rect(r, key_fill, main_col, 20.0, 3.5)

	if song_hint_key_type == 0 and song_hint_key_idx == idx:
		var hint_rect := Rect2(r.position.x + 4, r.position.y + 4, r.size.x - 8, r.size.y - 8)
		draw_rect(hint_rect, Color(1, 1, 0, 0.28))

	var head_cx := r.position.x + r.size.x * 0.5
	var head_cy := r.position.y + 75.0

	var el := PackedVector2Array([
		Vector2(head_cx - 42, head_cy - 20),
		Vector2(head_cx - 52, head_cy - 68),
		Vector2(head_cx - 18, head_cy - 42)
	])
	var er := PackedVector2Array([
		Vector2(head_cx + 42, head_cy - 20),
		Vector2(head_cx + 52, head_cy - 68),
		Vector2(head_cx + 18, head_cy - 42)
	])
	draw_colored_polygon(el, main_col)
	draw_colored_polygon(er, main_col)
	draw_colored_polygon(el, Color("#FF85A2"))
	draw_colored_polygon(er, Color("#FF85A2"))

	draw_circle(Vector2(head_cx, head_cy), 44.0, main_col)
	draw_circle(Vector2(head_cx, head_cy + 10), 34.0, belly_col)

	if is_singing or bool(k["is_pressed"]):
		draw_arc(
			Vector2(head_cx - 18, head_cy - 4), 10.0, PI * 1.1, PI * 1.9, 8, Color("#2D3436"), 3.5
		)
		draw_arc(
			Vector2(head_cx + 18, head_cy - 4), 10.0, PI * 1.1, PI * 1.9, 8, Color("#2D3436"), 3.5
		)
	else:
		draw_circle(Vector2(head_cx - 16, head_cy - 4), 7.0, Color("#2D3436"))
		draw_circle(Vector2(head_cx + 16, head_cy - 4), 7.0, Color("#2D3436"))
		draw_circle(Vector2(head_cx - 18, head_cy - 6), 2.5, Color.WHITE)
		draw_circle(Vector2(head_cx + 14, head_cy - 6), 2.5, Color.WHITE)

	var nose_pts := PackedVector2Array([
		Vector2(head_cx - 5, head_cy + 8),
		Vector2(head_cx + 5, head_cy + 8),
		Vector2(head_cx, head_cy + 15)
	])
	draw_colored_polygon(nose_pts, Color("#FF7675"))

	draw_line(
		Vector2(head_cx - 26, head_cy + 12),
		Vector2(head_cx - 52, head_cy + 6),
		Color("#636E72"),
		2.0
	)
	draw_line(
		Vector2(head_cx - 26, head_cy + 18),
		Vector2(head_cx - 52, head_cy + 22),
		Color("#636E72"),
		2.0
	)
	draw_line(
		Vector2(head_cx + 26, head_cy + 12),
		Vector2(head_cx + 52, head_cy + 6),
		Color("#636E72"),
		2.0
	)
	draw_line(
		Vector2(head_cx + 26, head_cy + 18),
		Vector2(head_cx + 52, head_cy + 22),
		Color("#636E72"),
		2.0
	)

	if is_singing or bool(k["is_pressed"]):
		draw_circle(Vector2(head_cx, head_cy + 25), 11.0, Color("#D63031"))
		draw_circle(Vector2(head_cx, head_cy + 28), 6.5, Color("#FF7675"))
	else:
		draw_arc(
			Vector2(head_cx - 6, head_cy + 16), 6.0, 0.1, PI * 0.9, 6, Color("#2D3436"), 2.5, true
		)
		draw_arc(
			Vector2(head_cx + 6, head_cy + 16), 6.0, 0.1, PI * 0.9, 6, Color("#2D3436"), 2.5, true
		)

	var medal_cy := r.position.y + r.size.y * 0.58
	draw_circle(Vector2(head_cx, medal_cy), 28.0, main_col)
	draw_circle(Vector2(head_cx, medal_cy), 24.0, Color.WHITE)
	draw_string(
		font,
		Vector2(r.position.x, medal_cy + 10),
		String(k["note"]),
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x,
		22,
		main_col.darkened(0.3)
	)

	var paw_y := r.position.y + r.size.y - 28.0
	draw_circle(Vector2(head_cx - 26, paw_y), 16.0, Color.WHITE)
	draw_circle(Vector2(head_cx + 26, paw_y), 16.0, Color.WHITE)
	draw_circle(Vector2(head_cx - 26, paw_y + 2), 6.0, Color("#FDA7DF"))
	draw_circle(Vector2(head_cx + 26, paw_y + 2), 6.0, Color("#FDA7DF"))


func _draw_black_key(idx: int, font: Font) -> void:
	var k: Dictionary = black_keys[idx]
	var base_r := _get_black_key_rect(idx)
	var depth: float = float(k["press_depth"])
	var offset_y := depth * 12.0
	var r := Rect2(
		base_r.position.x,
		base_r.position.y + offset_y,
		base_r.size.x,
		base_r.size.y - offset_y
	)
	var is_singing: bool = float(k["sing_timer"]) > 0.0

	_draw_rounded_rect(
		Rect2(base_r.position.x, base_r.position.y + 8, base_r.size.x, base_r.size.y),
		Color(0, 0, 0, 0.28),
		Color.TRANSPARENT,
		14.0,
		0.0
	)

	var fill_col := Color("#2D3436") if not bool(k["is_pressed"]) else Color("#1E272E")
	_draw_rounded_rect(r, fill_col, Color("#636E72"), 14.0, 2.5)

	if song_hint_key_type == 1 and song_hint_key_idx == idx:
		var hint_rect := Rect2(r.position.x + 3, r.position.y + 3, r.size.x - 6, r.size.y - 6)
		draw_rect(hint_rect, Color(1, 1, 0, 0.35))

	var cx := r.position.x + r.size.x * 0.5
	var cy := r.position.y + 55.0

	var el := PackedVector2Array([
		Vector2(cx - 24, cy - 14),
		Vector2(cx - 30, cy - 44),
		Vector2(cx - 10, cy - 28)
	])
	var er := PackedVector2Array([
		Vector2(cx + 24, cy - 14),
		Vector2(cx + 30, cy - 44),
		Vector2(cx + 10, cy - 28)
	])
	draw_colored_polygon(el, Color("#2D3436"))
	draw_colored_polygon(er, Color("#2D3436"))
	draw_colored_polygon(el, Color("#9B59B6"))
	draw_colored_polygon(er, Color("#9B59B6"))

	draw_circle(Vector2(cx, cy), 28.0, Color("#2D3436"))

	if is_singing or bool(k["is_pressed"]):
		draw_arc(
			Vector2(cx - 10, cy - 2), 6.0, PI * 1.1, PI * 1.9, 6, Color("#F1C40F"), 2.5, true
		)
		draw_arc(
			Vector2(cx + 10, cy - 2), 6.0, PI * 1.1, PI * 1.9, 6, Color("#F1C40F"), 2.5, true
		)
	else:
		draw_circle(Vector2(cx - 10, cy - 2), 5.0, Color("#F1C40F"))
		draw_circle(Vector2(cx + 10, cy - 2), 5.0, Color("#F1C40F"))
		draw_circle(Vector2(cx - 10, cy - 2), 2.5, Color("#2D3436"))
		draw_circle(Vector2(cx + 10, cy - 2), 2.5, Color("#2D3436"))

	if is_singing or bool(k["is_pressed"]):
		draw_circle(Vector2(cx, cy + 14), 7.0, Color("#E74C3C"))
	else:
		draw_arc(Vector2(cx - 4, cy + 10), 4.0, 0.1, PI * 0.9, 6, Color.WHITE, 1.8, true)
		draw_arc(Vector2(cx + 4, cy + 10), 4.0, 0.1, PI * 0.9, 6, Color.WHITE, 1.8, true)

	draw_string(
		font,
		Vector2(r.position.x, r.position.y + r.size.y - 24),
		String(k["note"]),
		HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x,
		18,
		Color("#F1C40F")
	)


func _draw_particles(font: Font) -> void:
	for p in floating_particles:
		var alpha: float = 1.0 - (float(p["age"]) / float(p["life"]))
		var col: Color = p["color"]
		col.a = alpha
		var sz: float = float(p["size"])
		var sym: String = String(p["symbol"])

		draw_set_transform(p["pos"], float(p["rot"]), Vector2.ONE)
		draw_string(
			font,
			Vector2(-sz * 0.5, sz * 0.5),
			sym,
			HORIZONTAL_ALIGNMENT_CENTER,
			sz,
			int(sz),
			col
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rounded_rect(
	r: Rect2, fill_col: Color, border_col: Color, radius: float, border_width: float
) -> void:
	var pts := PackedVector2Array()
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)

	_add_arc_points(
		pts, Vector2(r.position.x + r.size.x - rad, r.position.y + rad), rad, -PI * 0.5, 0.0
	)
	_add_arc_points(
		pts, Vector2(r.position.x + r.size.x - rad, r.position.y + r.size.y - rad), rad, 0.0, PI * 0.5
	)
	_add_arc_points(
		pts, Vector2(r.position.x + rad, r.position.y + r.size.y - rad), rad, PI * 0.5, PI
	)
	_add_arc_points(
		pts, Vector2(r.position.x + rad, r.position.y + rad), rad, PI, PI * 1.5
	)

	draw_colored_polygon(pts, fill_col)
	if border_width > 0.0 and border_col != Color.TRANSPARENT:
		pts.append(pts[0])
		draw_polyline(pts, border_col, border_width, true)


func _add_arc_points(
	pts: PackedVector2Array, center: Vector2, rad: float, a1: float, a2: float
) -> void:
	const STEPS := 6
	for i in range(STEPS + 1):
		var ang := lerpf(a1, a2, float(i) / float(STEPS))
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)

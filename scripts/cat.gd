class_name ChoirCat
extends Node2D

signal cat_sang(cat_position: Vector2, note_color: Color)

@export var cat_name: String = "Рыжик"
@export var fur_color: Color = Color("#FF9F43")
@export var belly_color: Color = Color("#FFEAA7")
@export var ear_inner_color: Color = Color("#FF85A2")
@export var eye_color: Color = Color("#2D3436")
@export var note_color: Color = Color("#FF6B81")
@export var pitch_note: float = 1.0
@export var chubby_factor: float = 1.0
@export var meow_variant: int = 0

var base_position: Vector2
var sing_timer: float = 0.0
var blink_timer: float = 2.5
var is_blinking: bool = false
var is_night: bool = false
var anim_time: float = 0.0
var hit_radius: float = 95.0

var _audio_player: AudioStreamPlayer
var _purr_player: AudioStreamPlayer
var _tween: Tween


func _ready() -> void:
	base_position = position
	anim_time = randf() * 10.0
	blink_timer = randf_range(1.5, 4.0)

	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = SoundGen.get_meow_stream(meow_variant)
	_audio_player.pitch_scale = pitch_note
	_audio_player.max_polyphony = 4
	add_child(_audio_player)

	_purr_player = AudioStreamPlayer.new()
	_purr_player.stream = SoundGen.get_purr_stream()
	_purr_player.pitch_scale = pitch_note * 0.85
	_purr_player.max_polyphony = 2
	add_child(_purr_player)


func _process(delta: float) -> void:
	anim_time += delta

	# Таймер пения (открытый ротик и зажмуренные от удовольствия глазки)
	if sing_timer > 0.0:
		sing_timer = maxf(0.0, sing_timer - delta)

	# Естественное моргание
	blink_timer -= delta
	if blink_timer <= 0.0:
		if is_blinking:
			is_blinking = false
			blink_timer = randf_range(2.2, 4.8)
		else:
			is_blinking = true
			blink_timer = 0.14

	queue_redraw()


## Проверка попадания пальчика (увеличенная зона для малышей 2+)
func is_point_inside(global_pt: Vector2) -> bool:
	return global_pt.distance_to(global_position + Vector2(0, -35)) <= hit_radius


## Вызывается при нажатии на котика или когда ему падает игрушка из пузыря
func sing(from_toy: bool = false) -> void:
	if is_night and not from_toy:
		sing_timer = 0.65
		_purr_player.pitch_scale = pitch_note * randf_range(0.82, 0.92)
		_purr_player.play()
		Input.vibrate_handheld(35)

		if _tween and _tween.is_running():
			_tween.kill()
		_tween = create_tween()
		scale = Vector2(1.16, 0.86)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		cat_sang.emit(global_position + Vector2(0, -110), note_color)
		return

	sing_timer = 0.48
	_audio_player.pitch_scale = pitch_note * randf_range(0.985, 1.015)
	_audio_player.play()

	# Пружинящая анимация Squash & Stretch + прыжок
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	var jump_height := -38.0 if from_toy else -26.0
	scale = Vector2(1.26, 0.76)
	position = base_position

	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(0.88, 1.18), 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", base_position.y + jump_height, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_tween.chain().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", base_position.y, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	cat_sang.emit(global_position + Vector2(0, -110), note_color)


func _draw() -> void:
	var is_singing := sing_timer > 0.0
	var breath := sin(anim_time * 2.6) * 2.0
	var tail_wag := sin(anim_time * (8.0 if is_singing else 3.2)) * 18.0

	# 1. Хвостик (виляет позади котика)
	var tail_start := Vector2(32.0 * chubby_factor, -10.0)
	var tail_mid := Vector2(62.0 * chubby_factor, -28.0 + tail_wag * 0.5)
	var tail_tip := Vector2(74.0 * chubby_factor + tail_wag * 0.6, -62.0 + tail_wag)
	draw_line(tail_start, tail_mid, fur_color.darkened(0.1), 16.0, true)
	draw_line(tail_mid, tail_tip, fur_color.darkened(0.1), 14.0, true)
	draw_circle(tail_tip, 7.0, fur_color.darkened(0.1))

	# 2. Пухлое тельце
	var body_w := 52.0 * chubby_factor
	var body_h := 46.0 + breath
	_draw_ellipse(Vector2(0, -24), body_w, body_h, fur_color)
	# Светлое пузико
	_draw_ellipse(Vector2(0, -20), body_w * 0.65, body_h * 0.68, belly_color)

	# 3. Ушки
	var head_center := Vector2(0, -76.0 + breath * 0.5)
	var ear_spread := 3.0 if is_singing else 0.0
	# Левое ушко
	var l_ear := PackedVector2Array([
		head_center + Vector2(-38, -8),
		head_center + Vector2(-46 - ear_spread, -56),
		head_center + Vector2(-10, -34)
	])
	var l_ear_in := PackedVector2Array([
		head_center + Vector2(-34, -14),
		head_center + Vector2(-40 - ear_spread, -46),
		head_center + Vector2(-15, -31)
	])
	draw_colored_polygon(l_ear, fur_color)
	draw_colored_polygon(l_ear_in, ear_inner_color)

	# Правое ушко
	var r_ear := PackedVector2Array([
		head_center + Vector2(38, -8),
		head_center + Vector2(46 + ear_spread, -56),
		head_center + Vector2(10, -34)
	])
	var r_ear_in := PackedVector2Array([
		head_center + Vector2(34, -14),
		head_center + Vector2(40 + ear_spread, -46),
		head_center + Vector2(15, -31)
	])
	draw_colored_polygon(r_ear, fur_color)
	draw_colored_polygon(r_ear_in, ear_inner_color)

	# 4. Голова
	_draw_ellipse(head_center, 46.0, 39.0, fur_color)

	# Полоски на лбу
	var stripe_col := fur_color.darkened(0.18)
	draw_line(head_center + Vector2(0, -36), head_center + Vector2(0, -22), stripe_col, 4.0)
	draw_line(head_center + Vector2(-10, -34), head_center + Vector2(-7, -23), stripe_col, 3.5)
	draw_line(head_center + Vector2(10, -34), head_center + Vector2(7, -23), stripe_col, 3.5)

	# Розовые щёчки
	draw_circle(head_center + Vector2(-28, 7), 8.5, Color(ear_inner_color, 0.55))
	draw_circle(head_center + Vector2(28, 7), 8.5, Color(ear_inner_color, 0.55))

	# 5. Глазки
	var left_eye_pos := head_center + Vector2(-18, -5)
	var right_eye_pos := head_center + Vector2(18, -5)
	if is_singing:
		# Радостные дуги ^ ^ когда поёт или мурчит
		draw_arc(left_eye_pos + Vector2(0, 3), 8.0, PI + 0.3, TAU - 0.3, 12, eye_color, 4.0, true)
		draw_arc(right_eye_pos + Vector2(0, 3), 8.0, PI + 0.3, TAU - 0.3, 12, eye_color, 4.0, true)
	elif is_night:
		# Спящие глазки ︶ ︶ ночью
		draw_arc(left_eye_pos + Vector2(0, -3), 7.5, 0.3, PI - 0.3, 12, Color("#2D3436"), 3.5, true)
		draw_arc(right_eye_pos + Vector2(0, -3), 7.5, 0.3, PI - 0.3, 12, Color("#2D3436"), 3.5, true)
	elif is_blinking:
		draw_line(left_eye_pos + Vector2(-7, 0), left_eye_pos + Vector2(7, 0), eye_color, 3.5)
		draw_line(right_eye_pos + Vector2(-7, 0), right_eye_pos + Vector2(7, 0), eye_color, 3.5)
	else:
		draw_circle(left_eye_pos, 8.0, eye_color)
		draw_circle(left_eye_pos + Vector2(-2.5, -2.5), 3.0, Color.WHITE)
		draw_circle(right_eye_pos, 8.0, eye_color)
		draw_circle(right_eye_pos + Vector2(-2.5, -2.5), 3.0, Color.WHITE)

	# 6. Носик и ротик
	var nose_poly := PackedVector2Array([
		head_center + Vector2(-6, 4),
		head_center + Vector2(6, 4),
		head_center + Vector2(0, 10)
	])
	draw_colored_polygon(nose_poly, Color("#FF6B81"))

	if is_singing and not is_night:
		# Открытый поющий ротик "О" днём
		_draw_ellipse(head_center + Vector2(0, 19), 9.0, 11.0, Color("#D63031"))
		_draw_ellipse(head_center + Vector2(0, 23), 6.0, 5.5, Color("#FF7675"))
	else:
		# Улыбка котика "w" (или сонное мурчание ночью)
		draw_arc(head_center + Vector2(-5, 12), 5.5, 0.15, PI - 0.15, 10, Color("#2D3436"), 2.5, true)
		draw_arc(head_center + Vector2(5, 12), 5.5, 0.15, PI - 0.15, 10, Color("#2D3436"), 2.5, true)

	# 7. Усики
	var whisker_col := Color(0.2, 0.2, 0.2, 0.55)
	draw_line(head_center + Vector2(-26, 6), head_center + Vector2(-52, 2), whisker_col, 2.0)
	draw_line(head_center + Vector2(-26, 11), head_center + Vector2(-52, 13), whisker_col, 2.0)
	draw_line(head_center + Vector2(26, 6), head_center + Vector2(52, 2), whisker_col, 2.0)
	draw_line(head_center + Vector2(26, 11), head_center + Vector2(52, 13), whisker_col, 2.0)

	# 8. Лапки на заборчике
	_draw_ellipse(Vector2(-22, 12), 13.0, 9.5, belly_color)
	_draw_ellipse(Vector2(22, 12), 13.0, 9.5, belly_color)


func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 24
	pts.resize(steps)
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		pts[i] = center + Vector2(cos(a) * rx, sin(a) * ry)
	draw_colored_polygon(pts, color)

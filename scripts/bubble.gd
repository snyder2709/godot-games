class_name SoapBubble
extends Node2D

signal bubble_popped(pos: Vector2, toy_type: int, toy_color: Color)

enum ToyType { FISH, YARN, STAR, HEART }

var radius: float = 52.0
var rise_speed: float = 68.0
var wobble_freq: float = 2.2
var wobble_amp: float = 24.0
var time_alive: float = 0.0
var start_x: float = 0.0
var toy_type: int = ToyType.FISH
var toy_color: Color = Color("#FF7675")
var bubble_tint: Color = Color("#74B9FF")
var is_popped: bool = false

const TOY_COLORS := [
	Color("#FF7675"), # Коралловый
	Color("#FDCB6E"), # Солнечно-жёлтый
	Color("#A29BFE"), # Лавандовый
	Color("#55EFC4"), # Мятный
	Color("#FD79A8")  # Розовый
]


func _ready() -> void:
	start_x = position.x
	time_alive = randf() * 10.0
	radius = randf_range(48.0, 64.0)
	rise_speed = randf_range(55.0, 88.0)
	wobble_freq = randf_range(1.6, 2.8)
	wobble_amp = randf_range(18.0, 34.0)
	toy_type = randi() % 4
	toy_color = TOY_COLORS[randi() % TOY_COLORS.size()]
	bubble_tint = TOY_COLORS[randi() % TOY_COLORS.size()].lightened(0.35)

	# Плавное появление пузыря
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if is_popped:
		return

	time_alive += delta
	position.y -= rise_speed * delta
	position.x = start_x + sin(time_alive * wobble_freq) * wobble_amp

	# Лёгкая деформация мыльного пузыря в полёте
	scale = Vector2(
		1.0 + sin(time_alive * 4.2) * 0.04,
		1.0 - sin(time_alive * 4.2) * 0.04
	)

	# Удаляем, если улетел за верхний край экрана
	if position.y < -100.0:
		queue_free()

	queue_redraw()


func is_point_inside(global_pt: Vector2) -> bool:
	# Щедрый радиус нажатия (+24px) для детских пальчиков
	return not is_popped and global_pt.distance_to(global_position) <= (radius + 24.0)


func pop() -> void:
	if is_popped:
		return
	is_popped = true
	bubble_popped.emit(global_position, toy_type, toy_color)
	queue_free()


func _draw() -> void:
	# 1. Игрушка внутри пузыря
	var toy_rot := sin(time_alive * 2.5) * 0.2
	draw_set_transform(Vector2.ZERO, toy_rot, Vector2.ONE)
	_draw_toy(toy_type, Vector2.ZERO, radius * 0.45, toy_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Полупрозрачная сфера пузыря
	draw_circle(Vector2.ZERO, radius, Color(bubble_tint.r, bubble_tint.g, bubble_tint.b, 0.24))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.78), 3.0, true)
	draw_arc(Vector2.ZERO, radius - 3.0, 0.4, 2.2, 20, Color(bubble_tint.r, bubble_tint.g, bubble_tint.b, 0.55), 2.5, true)

	# 3. Блик на пузыре
	draw_circle(Vector2(-radius * 0.36, -radius * 0.36), radius * 0.16, Color(1.0, 1.0, 1.0, 0.85))
	draw_circle(Vector2(-radius * 0.18, -radius * 0.52), radius * 0.07, Color(1.0, 1.0, 1.0, 0.7))


func _draw_toy(type: int, center: Vector2, sz: float, col: Color) -> void:
	match type:
		ToyType.FISH:
			# Хвостик рыбки
			var tail := PackedVector2Array([
				center + Vector2(-sz * 0.5, 0),
				center + Vector2(-sz * 1.15, -sz * 0.55),
				center + Vector2(-sz * 1.15, sz * 0.55)
			])
			draw_colored_polygon(tail, col.darkened(0.15))
			# Тело рыбки
			draw_circle(center + Vector2(sz * 0.1, 0), sz * 0.65, col)
			# Глазик
			draw_circle(center + Vector2(sz * 0.4, -sz * 0.15), sz * 0.14, Color.WHITE)
			draw_circle(center + Vector2(sz * 0.44, -sz * 0.15), sz * 0.07, Color.BLACK)

		ToyType.YARN:
			# Клубочек ниток
			draw_circle(center, sz * 0.75, col)
			draw_arc(center, sz * 0.5, 0.2, 2.6, 12, col.lightened(0.35), 3.0, true)
			draw_arc(center + Vector2(3, -3), sz * 0.45, 3.3, 5.8, 12, col.darkened(0.2), 3.0, true)
			# Кончик ниточки
			draw_line(center + Vector2(sz * 0.6, sz * 0.4), center + Vector2(sz * 1.1, sz * 0.7), col, 3.0)

		ToyType.STAR:
			# Пятиконечная звёздочка
			var pts := PackedVector2Array()
			for i in range(10):
				var angle := -PI * 0.5 + float(i) * PI / 5.0
				var r := sz * 0.85 if i % 2 == 0 else sz * 0.4
				pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
			draw_colored_polygon(pts, Color("#FFEAA7"))
			draw_polyline(pts, col.darkened(0.2), 2.0, true)

		ToyType.HEART:
			# Сердечко
			var r := sz * 0.45
			draw_circle(center + Vector2(-r * 0.75, -r * 0.3), r, col)
			draw_circle(center + Vector2(r * 0.75, -r * 0.3), r, col)
			var tri := PackedVector2Array([
				center + Vector2(-r * 1.68, 0.0),
				center + Vector2(r * 1.68, 0.0),
				center + Vector2(0, r * 1.65)
			])
			draw_colored_polygon(tri, col)

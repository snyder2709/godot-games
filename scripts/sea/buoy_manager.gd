class_name BuoyManager
extends Node3D

signal buoy_hit(buoy_pos: Vector3, normal: Vector3)
signal buoy_clicked(buoy_pos: Vector3)

var buoys: Array[Dictionary] = []
var _kenney_colormap: Texture2D


func init_buoys(colormap: Texture2D) -> void:
	_kenney_colormap = colormap
	var buoy_positions = [
		{"pos": Vector3(4.5, 0.0, -4.5), "sc": 0.58},
		{"pos": Vector3(-5.2, 0.0, -3.8), "sc": 0.55},
		{"pos": Vector3(1.8, 0.0, -8.0), "sc": 0.55},
		{"pos": Vector3(-7.5, 0.0, 0.6), "sc": 0.58}
	]
	for b in buoy_positions:
		var bnode := Node3D.new()
		bnode.position = b["pos"]
		add_child(bnode)
		_instantiate_model("res://assets/models/buoy.glb", bnode, Vector3(0.0, -0.22, 0.0), Vector3.ZERO, Vector3.ONE * b["sc"], true)
		buoys.append({
			"node": bnode,
			"pos": b["pos"],
			"wobble": Vector2.ZERO,
			"wobble_vel": Vector2.ZERO,
			"radius": 0.95,
			"hit_cooldown": 0.0
		})


func update_buoys(delta: float, world_time: float, water_surface: WaterSurface) -> void:
	for b in buoys:
		var cd: float = float(b.get("hit_cooldown", 0.0))
		if cd > 0.0:
			b["hit_cooldown"] = maxf(0.0, cd - delta)

		var bnode: Node3D = b["node"]
		var bpos: Vector3 = b["pos"]
		var wave_y: float = water_surface.get_wave_height(bpos.x, bpos.z, world_time) if water_surface else 0.0

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


func check_girl_collision(girl_pos: Vector3, girl_vel: Vector3) -> Dictionary:
	for b in buoys:
		var bpos: Vector3 = b["pos"]
		var to_girl := girl_pos - bpos
		to_girl.y = 0.0
		var d := to_girl.length()
		var min_dist := float(b["radius"]) + 1.10
		if d < min_dist and d > 0.01:
			var n := to_girl / d
			var vn := girl_vel.dot(n)

			# Если девочка уже отплывает от буйка, не вызываем повторный удар
			if vn > 0.8 and d >= min_dist - 0.08:
				continue

			var new_pos := bpos + n * (min_dist + 0.28)
			var new_vel := n * 4.8
			b["wobble_vel"] += Vector2(-n.z, n.x) * 45.0

			var cd: float = float(b.get("hit_cooldown", 0.0))
			b["hit_cooldown"] = 0.45

			if cd <= 0.0:
				buoy_hit.emit(bpos, n)

			return {
				"collided": true,
				"new_pos": new_pos,
				"new_vel": new_vel,
				"normal": n,
				"buoy_pos": bpos
			}
	return {"collided": false}


func check_touch(camera: Camera3D, screen_pt: Vector2) -> bool:
	for b in buoys:
		var bnode: Node3D = b["node"]
		if camera.is_position_in_frustum(bnode.global_position):
			var b_screen := camera.unproject_position(bnode.global_position + Vector3(0, 0.3, 0))
			if screen_pt.distance_to(b_screen) <= 75.0:
				b["wobble_vel"] += Vector2(randf_range(-35, 35), randf_range(-35, 35))
				buoy_clicked.emit(bnode.global_position)
				return true
	return false


func _instantiate_model(res_path: String, parent: Node3D, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, sc := Vector3.ONE, apply_kenney_tex: bool = false) -> Node3D:
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

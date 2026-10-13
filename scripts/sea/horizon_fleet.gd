class_name HorizonFleet
extends Node3D

signal boat_clicked(boat_pos: Vector3, boat_type: String)

class BoatData extends RefCounted:
	var node: Node3D
	var x: float
	var z: float
	var dir: float
	var speed: float
	var type: String
	var bounce: float = 0.0

class BirdData extends RefCounted:
	var node: Node3D
	var x: float
	var y: float
	var z: float
	var dir: float
	var speed: float

var boats: Array[BoatData] = []
var birds: Array[BirdData] = []
var clouds: Array[Node3D] = []
var _kenney_colormap: Texture2D


func init_fleet(colormap: Texture2D) -> void:
	_kenney_colormap = colormap
	_build_clouds()
	_build_boats()
	_build_birds()


func _build_clouds() -> void:
	var cloud_configs = [
		{"pos": Vector3(-16.0, 10.5, -27.0), "sc": 3.4, "speed": 0.42},
		{"pos": Vector3(2.0, 12.0, -30.0), "sc": 4.0, "speed": 0.35},
		{"pos": Vector3(18.0, 11.0, -26.0), "sc": 3.2, "speed": 0.48},
		{"pos": Vector3(-8.0, 13.0, -29.0), "sc": 3.6, "speed": 0.38}
	]
	for c in cloud_configs:
		var cnode := Node3D.new()
		cnode.position = c["pos"]
		add_child(cnode)
		_instantiate_model("res://assets/models/cloud.glb", cnode, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * c["sc"], true)
		cnode.set_meta("speed", c["speed"])
		clouds.append(cnode)


func _build_boats() -> void:
	# Океанский круизный лайнер на горизонте
	var liner := Node3D.new()
	liner.position = Vector3(-12.0, 0.0, -18.5)
	add_child(liner)
	_instantiate_model("res://assets/models/ship-ocean-liner.glb", liner, Vector3(0.0, -0.18, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.32, true)
	
	var bd_liner := BoatData.new()
	bd_liner.node = liner
	bd_liner.x = -12.0
	bd_liner.z = -18.5
	bd_liner.dir = 1.0
	bd_liner.speed = 1.4
	bd_liner.type = "liner"
	boats.append(bd_liner)

	# Скоростной катер
	var speedboat := Node3D.new()
	speedboat.position = Vector3(12.0, 0.0, -15.5)
	add_child(speedboat)
	_instantiate_model("res://assets/models/boat-speed-a.glb", speedboat, Vector3(0.0, -0.08, 0.0), Vector3(0.0, -90.0, 0.0), Vector3.ONE * 0.65, true)
	
	var bd_speed := BoatData.new()
	bd_speed.node = speedboat
	bd_speed.x = 12.0
	bd_speed.z = -15.5
	bd_speed.dir = -1.0
	bd_speed.speed = 2.8
	bd_speed.type = "speedboat"
	boats.append(bd_speed)

	# Буксирчик
	var tug := Node3D.new()
	tug.position = Vector3(-6.0, 0.0, -16.8)
	add_child(tug)
	_instantiate_model("res://assets/models/boat-tug-a.glb", tug, Vector3(0.0, -0.12, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.58, true)
	
	var bd_tug := BoatData.new()
	bd_tug.node = tug
	bd_tug.x = -6.0
	bd_tug.z = -16.8
	bd_tug.dir = 1.0
	bd_tug.speed = 1.8
	bd_tug.type = "tug"
	boats.append(bd_tug)


func _build_birds() -> void:
	var flamingo := Node3D.new()
	flamingo.position = Vector3(-11.0, 4.8, -7.5)
	add_child(flamingo)
	var fl_inst := _instantiate_model("res://assets/models/Flamingo.glb", flamingo, Vector3.ZERO, Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.016)
	_play_glb_anim(fl_inst, [&"fly", &"take"])
	
	var br_fl := BirdData.new()
	br_fl.node = flamingo
	br_fl.x = -11.0
	br_fl.y = 4.8
	br_fl.z = -7.5
	br_fl.dir = 1.0
	br_fl.speed = 2.8
	birds.append(br_fl)

	var parrot := Node3D.new()
	parrot.position = Vector3(11.0, 4.2, -6.0)
	add_child(parrot)
	var pr_inst := _instantiate_model("res://assets/models/Parrot.glb", parrot, Vector3.ZERO, Vector3(0.0, -90.0, 0.0), Vector3.ONE * 0.016)
	_play_glb_anim(pr_inst, [&"fly", &"take"])
	
	var br_pr := BirdData.new()
	br_pr.node = parrot
	br_pr.x = 11.0
	br_pr.y = 4.2
	br_pr.z = -6.0
	br_pr.dir = -1.0
	br_pr.speed = 3.2
	birds.append(br_pr)

	var stork := Node3D.new()
	stork.position = Vector3(0.0, 5.4, -9.5)
	add_child(stork)
	var st_inst := _instantiate_model("res://assets/models/Stork.glb", stork, Vector3.ZERO, Vector3(0.0, 90.0, 0.0), Vector3.ONE * 0.016)
	_play_glb_anim(st_inst, [&"storkFly_B_", &"fly"])
	
	var br_st := BirdData.new()
	br_st.node = stork
	br_st.x = 0.0
	br_st.y = 5.4
	br_st.z = -9.5
	br_st.dir = 1.0
	br_st.speed = 2.6
	birds.append(br_st)


func update_fleet(delta: float, world_time: float, water_surface: WaterSurface) -> void:
	# Облака
	for c in clouds:
		var spd: float = float(c.get_meta("speed", 0.4))
		c.position.x += spd * delta
		if c.position.x > 26.0:
			c.position.x = -26.0

	# Корабли
	for b in boats:
		b.x += b.dir * b.speed * delta
		if b.dir > 0.0 and b.x > 22.0:
			b.x = -22.0
		elif b.dir < 0.0 and b.x < -22.0:
			b.x = 22.0
		if b.bounce > 0.0:
			b.bounce = maxf(0.0, b.bounce - delta * 2.5)

		var bx := b.x
		var bz := b.z
		var wave_y: float = water_surface.get_wave_height(bx, bz, world_time) if water_surface else 0.0
		b.node.position = Vector3(
			bx,
			wave_y + b.bounce * 0.35,
			bz
		)
		b.node.rotation.z = sin(world_time * 2.6 + bx) * 0.07

	# Птицы
	for br in birds:
		br.x += br.dir * br.speed * delta
		if br.dir > 0.0 and br.x > 24.0:
			br.x = -24.0
		elif br.dir < 0.0 and br.x < -24.0:
			br.x = 24.0
		br.node.position = Vector3(
			br.x,
			br.y + sin(world_time * 2.5 + br.x) * 0.25,
			br.z
		)


func check_touch(camera: Camera3D, screen_pt: Vector2) -> bool:
	for b in boats:
		if camera.is_position_in_frustum(b.node.global_position):
			var b_screen := camera.unproject_position(b.node.global_position + Vector3(0.0, 0.5, 0.0))
			if screen_pt.distance_to(b_screen) <= 85.0:
				b.bounce = 1.0
				boat_clicked.emit(b.node.global_position, b.type)
				return true
	return false


func _play_glb_anim(node: Node3D, preferred_names: Array[StringName]) -> AnimationPlayer:
	if node == null:
		return null
	for child in node.find_children("*", "AnimationPlayer", true, false):
		var ap: AnimationPlayer = child
		var list := ap.get_animation_list()
		for pref in preferred_names:
			for anim_name in list:
				if StringName(anim_name.to_lower()) == pref or anim_name.to_lower().contains(String(pref).to_lower()):
					var anim := ap.get_animation(anim_name)
					if anim:
						anim.loop_mode = Animation.LOOP_LINEAR
					ap.play(anim_name)
					return ap
		if list.size() > 0:
			var first_anim := ap.get_animation(list[0])
			if first_anim:
				first_anim.loop_mode = Animation.LOOP_LINEAR
			ap.play(list[0])
			return ap
	return null


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

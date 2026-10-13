class_name MarineFauna
extends Node3D

signal crab_clicked(crab_pos: Vector3)
signal fish_clicked(fish_pos: Vector3)
signal fish_jumped(fish_pos: Vector3)

const SEA_MIN_X := -16.5
const SEA_MAX_X := 16.5
const SEA_MIN_Z := -13.5
const SEA_MAX_Z := 6.5

class FishData extends RefCounted:
	var node: Node3D
	var pos: Vector3
	var dir: Vector3
	var speed: float
	var anim: AnimationPlayer
	var jump_t: float = 0.0

var _island_crab: Node3D
var _crab_anim: AnimationPlayer
var _crab_bounce: float = 0.0

var fishes: Array[FishData] = []
var _kenney_colormap: Texture2D


func init_fauna(colormap: Texture2D) -> void:
	_kenney_colormap = colormap
	_build_island_crab()
	_build_fish_schools()


func _build_island_crab() -> void:
	_island_crab = Node3D.new()
	_island_crab.position = Vector3(-9.2, 0.32, -5.6)
	add_child(_island_crab)
	var crab_inst := _instantiate_model("res://assets/models/animal-crab.glb", _island_crab, Vector3.ZERO, Vector3(0.0, 35.0, 0.0), Vector3.ONE * 0.38, true)
	_crab_anim = _play_glb_anim(crab_inst, [&"idle", &"walk"])


func _build_fish_schools() -> void:
	var fish_spawns = [
		{"pos": Vector3(-4.5, 0.0, -1.0), "dir": Vector3(1.0, 0.0, 0.2).normalized(), "speed": 1.4},
		{"pos": Vector3(5.2, 0.0, -1.5), "dir": Vector3(-1.0, 0.0, -0.1).normalized(), "speed": 1.6},
		{"pos": Vector3(0.5, 0.0, -5.5), "dir": Vector3(0.4, 0.0, 1.0).normalized(), "speed": 1.5}
	]
	for sp in fish_spawns:
		var fnode := Node3D.new()
		fnode.position = sp["pos"]
		add_child(fnode)
		var finst := _instantiate_model("res://assets/models/animal-fish.glb", fnode, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 0.32, true)
		var anim := _play_glb_anim(finst, [&"run", &"walk", &"idle"])
		
		var fd := FishData.new()
		fd.node = fnode
		fd.pos = sp["pos"]
		fd.dir = sp["dir"]
		fd.speed = sp["speed"]
		fd.anim = anim
		fishes.append(fd)


func update_fauna(delta: float, world_time: float, water_surface: WaterSurface, girl_pos: Vector3) -> void:
	if _crab_bounce > 0.0:
		_crab_bounce = maxf(0.0, _crab_bounce - delta * 3.5)
	if _island_crab != null:
		_island_crab.position.y = 0.32 + sin(_crab_bounce * PI) * 0.65
		var crab_sy := 0.45 * (1.0 + sin(_crab_bounce * PI) * 0.5)
		var crab_sxz := 0.45 * (1.0 - sin(_crab_bounce * PI) * 0.25)
		_island_crab.scale = Vector3(crab_sxz, crab_sy, crab_sxz)


	for f in fishes:
		var fpos := f.pos
		var fdir := f.dir
		fpos += fdir * f.speed * delta

		if fpos.x < SEA_MIN_X + 2.0 or fpos.x > SEA_MAX_X - 2.0:
			fdir.x = -fdir.x
		if fpos.z < SEA_MIN_Z + 2.0 or fpos.z > SEA_MAX_Z - 2.0:
			fdir.z = -fdir.z

		f.dir = fdir
		f.pos = fpos

		var wave_y: float = water_surface.get_wave_height(fpos.x, fpos.z, world_time) if water_surface else 0.0
		if f.jump_t > 0.0:
			f.jump_t = maxf(0.0, f.jump_t - delta * 1.8)
			f.node.position = Vector3(fpos.x, wave_y + sin(f.jump_t * PI) * 1.25, fpos.z)
			f.node.rotation.x = (f.jump_t - 0.5) * 1.8
		else:
			f.node.position = Vector3(fpos.x, wave_y - 0.06, fpos.z)
			f.node.rotation.x = 0.0

		f.node.rotation.y = atan2(fdir.x, fdir.z)

		if girl_pos.distance_to(fpos) < 2.5 and f.jump_t <= 0.0:
			f.jump_t = 1.0
			fish_jumped.emit(fpos)


func check_touch(camera: Camera3D, screen_pt: Vector2) -> bool:
	if _island_crab != null and camera.is_position_in_frustum(_island_crab.global_position):
		var crab_screen := camera.unproject_position(_island_crab.global_position + Vector3(0.0, 0.3, 0.0))
		if screen_pt.distance_to(crab_screen) <= 75.0:
			_crab_bounce = 1.0
			if _crab_anim != null and _crab_anim.has_animation(&"dance"):
				_crab_anim.play(&"dance")
			crab_clicked.emit(_island_crab.global_position)
			return true

	for f in fishes:
		if camera.is_position_in_frustum(f.node.global_position):
			var f_screen := camera.unproject_position(f.node.global_position)
			if screen_pt.distance_to(f_screen) <= 75.0:
				f.jump_t = 1.0
				if f.anim != null and f.anim.has_animation(&"dance"):
					f.anim.play(&"dance")
				fish_clicked.emit(f.node.global_position)
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

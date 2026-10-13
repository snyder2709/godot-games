class_name SkyController
extends Node

signal time_changed(time_of_day: int)

enum TimeOfDay { DAY, SUNSET, NIGHT }

var current_time: int = TimeOfDay.DAY

var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _water_surface: WaterSurface

var _transition_tween: Tween

# Цветовые палитры для трёх времён суток
const DAY_PALETTE := {
	"sky_top": Color("#29B6F6"),
	"sky_horizon": Color("#B3E5FC"),
	"ground_bottom": Color("#0288D1"),
	"ground_horizon": Color("#81D4FA"),
	"sun_color": Color("#FFF9E6"),
	"sun_energy": 1.25,
	"ambient_color": Color("#FFFDF7"),
	"water_shallow": Color(0.10, 0.76, 0.90, 1.0),
	"water_deep": Color(0.03, 0.44, 0.82, 1.0)
}

const SUNSET_PALETTE := {
	"sky_top": Color("#7D3C98"),
	"sky_horizon": Color("#FF7675"),
	"ground_bottom": Color("#D63031"),
	"ground_horizon": Color("#F39C12"),
	"sun_color": Color("#FFA502"),
	"sun_energy": 1.40,
	"ambient_color": Color("#FFEAA7"),
	"water_shallow": Color(0.95, 0.48, 0.48, 1.0),
	"water_deep": Color(0.42, 0.36, 0.90, 1.0)
}

const NIGHT_PALETTE := {
	"sky_top": Color("#0F1423"),
	"sky_horizon": Color("#243342"),
	"ground_bottom": Color("#0A0F1D"),
	"ground_horizon": Color("#182C3F"),
	"sun_color": Color("#CED6E0"),
	"sun_energy": 0.70,
	"ambient_color": Color("#747D8C"),
	"water_shallow": Color(0.0, 0.81, 0.79, 1.0),
	"water_deep": Color(0.10, 0.08, 0.39, 1.0)
}


func init_sky(env: Environment, sky_mat: ProceduralSkyMaterial, sun: DirectionalLight3D, water_surface: WaterSurface) -> void:
	_env = env
	_sky_mat = sky_mat
	_sun = sun
	_water_surface = water_surface
	_apply_palette(DAY_PALETTE, true)


func cycle_time() -> int:
	current_time = (current_time + 1) % 3
	var pal: Dictionary
	match current_time:
		TimeOfDay.DAY:
			pal = DAY_PALETTE
		TimeOfDay.SUNSET:
			pal = SUNSET_PALETTE
		TimeOfDay.NIGHT:
			pal = NIGHT_PALETTE
	_apply_palette(pal, false)
	time_changed.emit(current_time)
	return current_time


func _apply_palette(pal: Dictionary, instant: bool) -> void:
	if instant:
		if _sky_mat:
			_sky_mat.sky_top_color = pal["sky_top"]
			_sky_mat.sky_horizon_color = pal["sky_horizon"]
			_sky_mat.ground_bottom_color = pal["ground_bottom"]
			_sky_mat.ground_horizon_color = pal["ground_horizon"]
		if _env:
			_env.ambient_light_color = pal["ambient_color"]
		if _sun:
			_sun.light_color = pal["sun_color"]
			_sun.light_energy = pal["sun_energy"]
		if _water_surface and _water_surface.get_material():
			var sm: ShaderMaterial = _water_surface.get_material()
			sm.set_shader_parameter("shallow_color", pal["water_shallow"])
			sm.set_shader_parameter("deep_color", pal["water_deep"])
		return

	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	_transition_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _sky_mat:
		_transition_tween.tween_property(_sky_mat, "sky_top_color", pal["sky_top"], 1.1)
		_transition_tween.tween_property(_sky_mat, "sky_horizon_color", pal["sky_horizon"], 1.1)
		_transition_tween.tween_property(_sky_mat, "ground_bottom_color", pal["ground_bottom"], 1.1)
		_transition_tween.tween_property(_sky_mat, "ground_horizon_color", pal["ground_horizon"], 1.1)
	if _env:
		_transition_tween.tween_property(_env, "ambient_light_color", pal["ambient_color"], 1.1)
	if _sun:
		_transition_tween.tween_property(_sun, "light_color", pal["sun_color"], 1.1)
		_transition_tween.tween_property(_sun, "light_energy", pal["sun_energy"], 1.1)
	if _water_surface and _water_surface.get_material():
		var sm: ShaderMaterial = _water_surface.get_material()
		_transition_tween.tween_method(func(c: Color): sm.set_shader_parameter("shallow_color", c), sm.get_shader_parameter("shallow_color"), pal["water_shallow"], 1.1)
		_transition_tween.tween_method(func(c: Color): sm.set_shader_parameter("deep_color", c), sm.get_shader_parameter("deep_color"), pal["water_deep"], 1.1)


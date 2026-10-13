class_name SoundGen
extends RefCounted

const MIX_RATE := 22050

## Возвращает живой звук котёнка ("meow.wav" или "meow2.wav")
static func get_meow_stream(variant: int = 0) -> AudioStream:
	if variant == 1 and ResourceLoader.exists("res://assets/meow2.wav"):
		return load("res://assets/meow2.wav")
	if ResourceLoader.exists("res://assets/meow.wav"):
		return load("res://assets/meow.wav")
	return _generate_synth_meow()


static func get_pop_stream() -> AudioStream:
	if ResourceLoader.exists("res://assets/pop.wav"):
		return load("res://assets/pop.wav")
	return _generate_synth_pop()


static func get_toy_stream() -> AudioStream:
	if ResourceLoader.exists("res://assets/chime.wav"):
		return load("res://assets/chime.wav")
	return _generate_synth_chime()


static func get_purr_stream() -> AudioStream:
	if ResourceLoader.exists("res://assets/purr.wav"):
		return load("res://assets/purr.wav")
	return _generate_synth_purr()


static func get_splash_stream() -> AudioStream:
	if ResourceLoader.exists("res://assets/splash.wav"):
		return load("res://assets/splash.wav")
	return get_pop_stream()


static func get_squeak_stream() -> AudioStream:
	if ResourceLoader.exists("res://assets/squeak.wav"):
		return load("res://assets/squeak.wav")
	return get_pop_stream()


static func get_laugh_stream() -> AudioStream:
	if ResourceLoader.exists("res://assets/baby_laugh.ogg"):
		return load("res://assets/baby_laugh.ogg")
	if ResourceLoader.exists("res://assets/laugh.wav"):
		return load("res://assets/laugh.wav")
	return get_toy_stream()


static func get_boat_horn_stream() -> AudioStream:
	if ResourceLoader.exists("res://assets/boat_horn.wav"):
		return load("res://assets/boat_horn.wav")
	return get_toy_stream()


static func get_slide_up_stream() -> AudioStream:
	if ResourceLoader.exists("res://assets/slide_up.wav"):
		return load("res://assets/slide_up.wav")
	return get_toy_stream()


static func get_glug_stream() -> AudioStream:
	if ResourceLoader.exists("res://assets/glug.wav"):
		return load("res://assets/glug.wav")
	return get_pop_stream()


## Процедурный синтез певучего кошачьего "Мя-а-у" (формантная огибающая)
static func _generate_synth_meow() -> AudioStreamWAV:
	var duration := 0.42
	var samples := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)

	var phase := 0.0
	var f1_phase := 0.0
	var f2_phase := 0.0

	for i in range(samples):
		var t := float(i) / float(samples) # 0.0 .. 1.0
		# Огибающая высоты тона: плавный подъём "Мя-" и спад "-у"
		var pitch_curve := sin(t * PI)
		var base_freq := 380.0 + pitch_curve * 160.0 + sin(t * 28.0) * 6.0

		# Форманты (переход гласной Я -> У)
		var formant1 := lerpf(750.0, 420.0, t)
		var formant2 := lerpf(1600.0, 900.0, t)

		phase += TAU * base_freq / MIX_RATE
		f1_phase += TAU * formant1 / MIX_RATE
		f2_phase += TAU * formant2 / MIX_RATE

		# Основной тон + мягкие гармоники + формантный окрас
		var raw := (
			sin(phase) * 0.50
			+ sin(phase * 2.0) * 0.25
			+ sin(f1_phase) * 0.16
			+ sin(f2_phase) * 0.09
		)

		# Плавная атака и затухание без щелчков
		var env := 1.0
		if t < 0.08:
			env = t / 0.08
		elif t > 0.65:
			env = (1.0 - t) / 0.35

		var sample := clampf(raw * env * 0.75, -1.0, 1.0)
		var pcm := int(sample * 32767.0)
		bytes[i * 2] = pcm & 0xFF
		bytes[i * 2 + 1] = (pcm >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


## Сочный звук "Чпок!" для лопания мыльного пузыря
static func _generate_synth_pop() -> AudioStreamWAV:
	var duration := 0.09
	var samples := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)

	var phase := 0.0
	for i in range(samples):
		var t := float(i) / float(samples)
		# Быстрый взлёт частоты (эффект капли/пузыря)
		var freq := lerpf(280.0, 1150.0, t * t)
		phase += TAU * freq / MIX_RATE
		var env := sin(t * PI) * (1.0 - t * 0.5)
		var sample := clampf(sin(phase) * env * 0.85, -1.0, 1.0)
		var pcm := int(sample * 32767.0)
		bytes[i * 2] = pcm & 0xFF
		bytes[i * 2 + 1] = (pcm >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


## Весёлый колокольчик при получении игрушки
static func _generate_synth_chime() -> AudioStreamWAV:
	var duration := 0.25
	var samples := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)

	var phase1 := 0.0
	var phase2 := 0.0
	for i in range(samples):
		var t := float(i) / float(samples)
		var freq := 880.0 if t < 0.45 else 1174.66
		phase1 += TAU * freq / MIX_RATE
		phase2 += TAU * (freq * 2.0) / MIX_RATE
		var env := (1.0 - t) * (1.0 - t)
		var sample := clampf((sin(phase1) * 0.65 + sin(phase2) * 0.25) * env, -1.0, 1.0)
		var pcm := int(sample * 32767.0)
		bytes[i * 2] = pcm & 0xFF
		bytes[i * 2 + 1] = (pcm >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


## Мягкое уютное мурчание "Мурр-р-р" для спящих котиков ночью
static func _generate_synth_purr() -> AudioStreamWAV:
	var duration := 0.75
	var samples := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)

	var lp1 := 0.0
	var lp2 := 0.0
	var sub_phase := 0.0

	for i in range(samples):
		var t := float(i) / float(samples)
		# Настоящее кошачье мурчание — это мягкое дыхание, модулированное частотой ~24 Гц
		var pulse := pow(0.5 + 0.5 * sin(t * duration * TAU * 23.5), 1.6)
		var white := randf_range(-1.0, 1.0)
		# Двойной фильтр низких частот (срез ~240 Гц), чтобы убрать резкость
		lp1 += (white - lp1) * 0.065
		lp2 += (lp1 - lp2) * 0.065

		sub_phase += TAU * 56.0 / MIX_RATE
		var raw := (lp2 * 2.2 + sin(sub_phase) * 0.25) * pulse
		var env := sin(t * PI)
		var sample := clampf(raw * env * 0.85, -1.0, 1.0)
		var pcm := int(sample * 32767.0)
		bytes[i * 2] = pcm & 0xFF
		bytes[i * 2 + 1] = (pcm >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


class_name AudioManager
extends Node
## All sound is synthesised at startup (no audio files): dry, retro,
## electrical. Different materials sound different, rule changes each have a
## signature, and everything bends with time scale.

const RATE := 22050
const POOL_3D := 18
const POOL_UI := 10

var ctx: Node
var streams: Dictionary = {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _poolui: Array[AudioStreamPlayer] = []
var _last_play: Dictionary = {}
var _hum: AudioStreamPlayer
var _drone: AudioStreamPlayer
var master_volume: float = 0.8
var _rng := RandomNumberGenerator.new()


func setup(c: Node) -> void:
	ctx = c
	_rng.seed = 1234
	_build_all()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 5.0
		p.max_distance = 30.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool3d.append(p)
	for i in POOL_UI:
		var u := AudioStreamPlayer.new()
		add_child(u)
		_poolui.append(u)
	_hum = AudioStreamPlayer.new()
	_hum.stream = streams["hum_loop"]
	_hum.volume_db = -20.0
	add_child(_hum)
	_drone = AudioStreamPlayer.new()
	_drone.stream = streams["drone_loop"]
	_drone.volume_db = -60.0
	add_child(_drone)
	ctx.events.prop_impact.connect(_on_impact)
	ctx.events.prop_broken.connect(_on_broken)


func set_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))


func start_ambience() -> void:
	if not _hum.playing:
		_hum.play()
	if not _drone.playing:
		_drone.play()


func stop_ambience() -> void:
	_hum.stop()
	_drone.stop()


func get_stream(n: String) -> AudioStream:
	return streams.get(n)


func play_3d(n: String, pos: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(n):
		return
	var now := GameClock.ms
	var key := "%s%d%d" % [n, int(pos.x), int(pos.z)]
	if now - int(_last_play.get(key, -1000)) < 45:
		return
	_last_play[key] = now
	var best: AudioStreamPlayer3D = null
	for p in _pool3d:
		if not p.playing:
			best = p
			break
	if best == null:
		best = _pool3d[_rng.randi() % _pool3d.size()]
	best.stream = streams[n]
	best.global_position = pos
	best.volume_db = db
	best.pitch_scale = clampf(pitch * _time_pitch(), 0.3, 3.0)
	best.play()


func play_ui(n: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(n):
		return
	var now := GameClock.ms
	if now - int(_last_play.get(n, -1000)) < 40:
		return
	_last_play[n] = now
	var best: AudioStreamPlayer = null
	for p in _poolui:
		if not p.playing:
			best = p
			break
	if best == null:
		best = _poolui[0]
	best.stream = streams[n]
	best.volume_db = db
	best.pitch_scale = pitch
	best.play()


func play_rule(rule: int, level: int) -> void:
	var n := "rule_%d" % rule
	if level == 0:
		play_ui("restore", -4.0)
		return
	play_ui(n, -2.0, 0.85 + level * 0.15)


func _time_pitch() -> float:
	return clampf(sqrt(Engine.time_scale), 0.55, 1.4)


func _process(delta: float) -> void:
	if ctx == null:
		return
	var tp := _time_pitch()
	_hum.pitch_scale = lerpf(_hum.pitch_scale, tp, clampf(delta * 6.0, 0.0, 1.0))
	var tier: int = ctx.deviation.tier if ctx.deviation else 0
	var want := -60.0 if tier == 0 else -26.0 + tier * 3.5
	_drone.volume_db = lerpf(_drone.volume_db, want, clampf(delta * 1.5, 0.0, 1.0))
	_drone.pitch_scale = tp * (1.0 + tier * 0.03)


func _on_impact(striker: Node, victim: Node, speed: float) -> void:
	var a := striker as Prop
	if a == null:
		return
	var mat := a.mat_type
	if a.is_debris:
		mat = "debris"
	var db := clampf(-26.0 + speed * 2.6, -26.0, 2.0)
	var pitch := _rng.randf_range(0.88, 1.12) / clampf(sqrt(a.size_factor), 0.6, 1.5)
	var n := "hit_%s_%d" % [mat, _rng.randi() % 2]
	if not streams.has(n):
		n = "hit_wood_0"
	play_3d(n, a.global_position, db, pitch)
	var b := victim as Prop
	if b and b.mat_type != mat and speed > 3.0:
		var n2 := "hit_%s_%d" % [b.mat_type, _rng.randi() % 2]
		if streams.has(n2):
			play_3d(n2, b.global_position, db - 6.0, pitch)
	if ctx.rules.levels[RuleDefs.BOUNCE] in [RuleDefs.BOUNCE_HIGH, RuleDefs.BOUNCE_EXTREME] and speed > 3.0:
		play_3d("boing", a.global_position, db - 4.0, _rng.randf_range(0.8, 1.3))


func _on_broken(p: Node, _cid: int) -> void:
	var pr := p as Prop
	if pr == null or pr.is_debris:
		return
	var n := "break_wood"
	match pr.mat_type:
		"ceramic", "glass":
			n = "glass_break"
		"fruit":
			n = "splat"
		"cardboard", "paper":
			n = "crumple"
		"plastic":
			n = "break_plastic"
	play_3d(n, pr.global_position, 0.0, _rng.randf_range(0.9, 1.1))


# ------------------------------------------------------------------ synthesis
func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Filtered noise burst. cutoff 0..1 (one-pole lowpass coefficient).
func _noise(seconds: float, cutoff: float, decay: float, gain: float = 0.8, attack: float = 0.002) -> PackedFloat32Array:
	var b := _buf(seconds)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := (minf(1.0, t / attack)) * exp(-t * decay)
		y += cutoff * (_rng.randf_range(-1.0, 1.0) - y)
		b[i] = y * env * gain
	return b


## Pitched tone with sweep and decay. wave: 0 sine, 1 square-ish, 2 saw.
func _tone(seconds: float, f0: float, f1: float, decay: float, gain: float = 0.6, wave: int = 0) -> PackedFloat32Array:
	var b := _buf(seconds)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / seconds
		var f := f0 * pow(f1 / f0, k)
		ph += f / RATE
		var s := sin(ph * TAU)
		if wave == 1:
			s = clampf(s * 3.0, -1.0, 1.0)
		elif wave == 2:
			s = fmod(ph, 1.0) * 2.0 - 1.0
		var env := minf(1.0, t / 0.003) * exp(-t * decay)
		b[i] = s * env * gain
	return b


## Inharmonic partials (metal / glass / ceramic).
func _bell(seconds: float, f: float, ratios: Array, decay: float, gain: float = 0.5) -> PackedFloat32Array:
	var b := _buf(seconds)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		for j in ratios.size():
			s += sin(t * f * float(ratios[j]) * TAU) * exp(-t * decay * (1.0 + j * 0.6)) / (1.0 + j)
		b[i] = s * gain * minf(1.0, t / 0.001)
	return b


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gb: float = 1.0) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var va := a[i] if i < a.size() else 0.0
		var vb := b[i] if i < b.size() else 0.0
		out[i] = va + vb * gb
	return out


func _build_all() -> void:
	var S := streams
	# Material impacts (two variants each).
	for v in 2:
		var r := 1.0 + v * 0.12
		S["hit_wood_%d" % v] = _wav(_mix(_noise(0.18, 0.25, 32.0, 0.7), _tone(0.18, 180.0 * r, 120.0 * r, 28.0, 0.45)))
		S["hit_metal_%d" % v] = _wav(_mix(_bell(0.6, 310.0 * r, [1.0, 2.76, 5.4, 8.9], 7.0, 0.35), _noise(0.05, 0.6, 80.0, 0.4)))
		S["hit_ceramic_%d" % v] = _wav(_bell(0.25, 1250.0 * r, [1.0, 2.3, 3.9], 20.0, 0.35))
		S["hit_glass_%d" % v] = _wav(_bell(0.35, 1800.0 * r, [1.0, 1.7, 2.9, 4.4], 14.0, 0.3))
		S["hit_rubber_%d" % v] = _wav(_tone(0.16, 160.0 * r, 90.0 * r, 22.0, 0.6))
		S["hit_fruit_%d" % v] = _wav(_noise(0.12, 0.08, 40.0, 0.9))
		S["hit_cardboard_%d" % v] = _wav(_noise(0.14, 0.12, 30.0, 0.8))
		S["hit_plastic_%d" % v] = _wav(_mix(_noise(0.08, 0.7, 60.0, 0.5), _tone(0.08, 700.0 * r, 500.0 * r, 50.0, 0.3, 1)))
		S["hit_paper_%d" % v] = _wav(_noise(0.06, 0.9, 70.0, 0.25))
		S["hit_debris_%d" % v] = _wav(_noise(0.05, 0.5, 90.0, 0.35))
	S["boing"] = _wav(_tone(0.35, 220.0, 520.0, 7.0, 0.45, 0))
	S["break_wood"] = _wav(_mix(_noise(0.45, 0.3, 9.0, 0.9), _noise(0.2, 0.7, 25.0, 0.5)))
	S["break_plastic"] = _wav(_mix(_noise(0.3, 0.6, 14.0, 0.8), _tone(0.2, 900.0, 300.0, 18.0, 0.25, 1)))
	S["glass_break"] = _wav(_mix(_noise(0.6, 0.85, 7.0, 0.7), _bell(0.6, 2300.0, [1.0, 1.43, 2.1, 3.3, 4.7], 6.0, 0.25)))
	S["glass_tap"] = _wav(_bell(0.25, 2100.0, [1.0, 2.2], 18.0, 0.3))
	S["splat"] = _wav(_noise(0.25, 0.06, 14.0, 1.0))
	S["crumple"] = _wav(_noise(0.3, 0.45, 10.0, 0.6))
	S["button"] = _wav(_mix(_tone(0.12, 900.0, 880.0, 30.0, 0.3, 1), _noise(0.03, 0.8, 120.0, 0.4)))
	S["spring"] = _wav(_tone(0.45, 140.0, 700.0, 5.0, 0.5, 0))
	S["zap"] = _wav(_mix(_tone(0.25, 1200.0, 200.0, 10.0, 0.3, 2), _noise(0.25, 0.9, 12.0, 0.3)))
	S["printer"] = _wav(_mix(_tone(0.18, 420.0, 440.0, 8.0, 0.2, 1), _noise(0.18, 0.4, 10.0, 0.3)))
	S["hatch"] = _wav(_tone(0.3, 300.0, 150.0, 9.0, 0.3, 1))
	S["jump"] = _wav(_noise(0.08, 0.2, 40.0, 0.4))
	S["step"] = _wav(_noise(0.06, 0.15, 60.0, 0.5))
	S["grab"] = _wav(_tone(0.08, 500.0, 700.0, 30.0, 0.3))
	S["throw"] = _wav(_noise(0.2, 0.35, 14.0, 0.5, 0.05))
	S["pulse"] = _wav(_mix(_tone(0.4, 90.0, 40.0, 7.0, 0.7), _noise(0.3, 0.3, 10.0, 0.4, 0.02)))
	S["deny"] = _wav(_tone(0.18, 160.0, 150.0, 8.0, 0.35, 1))
	S["hurt"] = _wav(_mix(_tone(0.25, 200.0, 80.0, 10.0, 0.6, 1), _noise(0.2, 0.3, 14.0, 0.4)))
	S["alarm"] = _wav(_alarm())
	S["mutation"] = _wav(_mix(_tone(1.2, 60.0, 30.0, 2.2, 0.6, 2), _tone(1.2, 61.5, 33.0, 2.0, 0.4, 2)))
	S["combo"] = _wav(_arp([523.0, 659.0, 784.0, 1047.0], 0.08, 0.35))
	S["success"] = _wav(_arp([392.0, 523.0, 659.0, 784.0, 1047.0], 0.11, 0.4))
	S["fail"] = _wav(_arp([311.0, 262.0, 196.0], 0.22, 0.4, 1))
	S["tier_up"] = _wav(_tone(0.5, 110.0, 220.0, 3.5, 0.5, 2))
	S["tier_down"] = _wav(_tone(0.4, 220.0, 130.0, 5.0, 0.3, 0))
	S["observer"] = _wav(_observer())
	S["resist"] = _wav(_mix(_tone(1.0, 70.0, 66.0, 1.5, 0.5, 2), _noise(1.0, 0.05, 2.0, 0.4)))
	S["gust"] = _wav(_noise(1.0, 0.06, 2.5, 0.6, 0.3))
	S["creak"] = _wav(_tone(0.9, 95.0, 70.0, 2.5, 0.4, 2))
	S["quake"] = _wav(_noise(1.2, 0.03, 2.5, 1.0, 0.05))
	S["card"] = _wav(_noise(0.12, 0.6, 30.0, 0.4, 0.01))
	S["click"] = _wav(_tone(0.04, 1500.0, 1400.0, 80.0, 0.25, 1))
	S["restore"] = _wav(_arp([660.0, 440.0], 0.07, 0.25))
	S["rule_0"] = _wav(_tone(0.6, 600.0, 90.0, 4.0, 0.5, 0))
	S["rule_1"] = _wav(_mix(_tone(0.45, 200.0, 600.0, 5.0, 0.4), _tone(0.45, 300.0, 900.0, 5.0, 0.2)))
	S["rule_2"] = _wav(_mix(_tone(0.5, 120.0, 122.0, 4.0, 0.35, 2), _tone(0.5, 180.0, 183.0, 4.0, 0.25, 2)))
	S["rule_3"] = _wav(_tone(0.5, 2400.0, 800.0, 6.0, 0.25, 0))
	S["rule_4"] = _wav(_tone(0.7, 400.0, 60.0, 3.0, 0.5, 2))
	S["discovery"] = _wav(_mix(_arp([392.0, 494.0, 587.0, 740.0, 988.0], 0.07, 0.3, 0), _bell(1.2, 1480.0, [1.0, 2.0, 3.01], 3.0, 0.15)))
	S["knock"] = _wav(_mix(_tone(0.12, 95.0, 70.0, 26.0, 0.8), _noise(0.06, 0.15, 60.0, 0.5)))
	S["stamp"] = _wav(_mix(_tone(0.15, 120.0, 60.0, 30.0, 0.7), _noise(0.1, 0.3, 45.0, 0.7)))
	S["power_down"] = _wav(_tone(1.1, 240.0, 30.0, 2.2, 0.5, 2))
	S["power_up"] = _wav(_tone(0.6, 60.0, 260.0, 4.0, 0.35, 2))
	S["ding"] = _wav(_bell(0.8, 1320.0, [1.0, 2.4, 3.8], 5.0, 0.3))
	S["singularity"] = _wav(_mix(_tone(1.4, 40.0, 220.0, 1.6, 0.6, 2), _noise(1.0, 0.1, 3.0, 0.6, 0.4)))
	S["hum_loop"] = _wav(_hum_loop(), true)
	S["drone_loop"] = _wav(_drone_loop(), true)
	S["fan_loop"] = _wav(_fan_loop(), true)
	S["static_loop"] = _wav(_noise_loop(1.0, 0.95, 0.25), true)
	S["rain_loop"] = _wav(_noise_loop(2.0, 0.5, 0.35), true)
	S["wind_loop"] = _wav(_noise_loop(2.0, 0.04, 0.6), true)


func _arp(notes: Array, step: float, gain: float, wave: int = 0) -> PackedFloat32Array:
	var out := _buf(step * notes.size() + 0.3)
	for n in notes.size():
		var t := _tone(0.3, float(notes[n]), float(notes[n]), 9.0, gain, wave)
		var off := int(n * step * RATE)
		for i in t.size():
			if off + i < out.size():
				out[off + i] += t[i]
	return out


func _alarm() -> PackedFloat32Array:
	var b := _buf(1.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 520.0 if fmod(t, 0.25) < 0.125 else 390.0
		ph += f / RATE
		b[i] = clampf(sin(ph * TAU) * 2.0, -1.0, 1.0) * 0.25 * (1.0 - t)
	return b


func _observer() -> PackedFloat32Array:
	# A breathy, slightly detuned whisper over a sub tone: the room "notices".
	var b := _buf(1.8)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := sin(clampf(t / 1.8, 0.0, 1.0) * PI)
		y += 0.12 * (_rng.randf_range(-1, 1) - y)
		var formant := sin(t * TAU * (700.0 + sin(t * 3.0) * 120.0))
		b[i] = (y * formant * 0.8 + sin(t * TAU * 55.0) * 0.35 + sin(t * TAU * 55.7) * 0.2) * env * 0.6
	return b


func _hum_loop() -> PackedFloat32Array:
	var b := _buf(1.0)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		y += 0.02 * (_rng.randf_range(-1, 1) - y)
		b[i] = sin(t * TAU * 120.0) * 0.18 + sin(t * TAU * 240.0) * 0.08 + sin(t * TAU * 360.0) * 0.05 + y * 0.6
	return b


func _drone_loop() -> PackedFloat32Array:
	var b := _buf(2.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(t * TAU * 41.0) * 0.4 + sin(t * TAU * 61.5) * 0.25 + sin(t * TAU * 82.0) * 0.15) * (0.75 + 0.25 * sin(t * TAU * 0.5))
	return b


func _fan_loop() -> PackedFloat32Array:
	var b := _buf(1.0)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		y += 0.1 * (_rng.randf_range(-1, 1) - y)
		b[i] = y * (0.7 + 0.3 * sin(t * TAU * 18.0)) * 0.7 + sin(t * TAU * 90.0) * 0.06
	return b


func _noise_loop(seconds: float, cutoff: float, gain: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var y := 0.0
	for i in b.size():
		y += cutoff * (_rng.randf_range(-1, 1) - y)
		b[i] = y * gain
	# Short crossfade at the seam.
	var fade := 400
	for i in fade:
		var k := float(i) / fade
		b[i] = b[i] * k + b[b.size() - fade + i] * (1.0 - k)
	return b

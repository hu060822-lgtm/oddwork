class_name EnvEffects
extends Node
## Room-wide weather and structure effects driven by anomalies and mutations:
## rain (+ puddles), wind (+ gusts), structural failure.

var ctx: Node
var rain_on: bool = false
var wind_on: bool = false
var structure_on: bool = false
var wind_boost: float = 0.0  # set by GALE mutation
var wind_dir: Vector3 = Vector3(1, 0, 0)
var _wind_t: float = 0.0
var _struct_t: float = 6.0
var _tick: int = 0
var _rain: CPUParticles3D
var _wind_fx: CPUParticles3D
var _rain_loop: AudioStreamPlayer
var _wind_loop: AudioStreamPlayer
var _puddles: Array[StaticBody3D] = []
var _puddle_meshes: Array[MeshInstance3D] = []


func setup(c: Node) -> void:
	ctx = c
	_rain = CPUParticles3D.new()
	_rain.amount = 900
	_rain.lifetime = 1.1
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(8, 0.1, 6)
	_rain.position = Vector3(0, 4.4, 0)
	_rain.direction = Vector3.DOWN
	_rain.spread = 3.0
	_rain.gravity = Vector3(0, -2, 0)
	_rain.initial_velocity_min = 7.0
	_rain.initial_velocity_max = 9.0
	var dm := BoxMesh.new()
	dm.size = Vector3(0.012, 0.25, 0.012)
	dm.material = Mats.ghost(Color(0.7, 0.85, 1.0, 0.45))
	_rain.mesh = dm
	_rain.emitting = false
	_rain.visible = false
	add_child(_rain)
	_wind_fx = CPUParticles3D.new()
	_wind_fx.amount = 140
	_wind_fx.lifetime = 1.6
	_wind_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_wind_fx.emission_box_extents = Vector3(8, 2, 6)
	_wind_fx.position = Vector3(0, 2.0, 0)
	_wind_fx.gravity = Vector3.ZERO
	_wind_fx.initial_velocity_min = 6.0
	_wind_fx.initial_velocity_max = 10.0
	_wind_fx.spread = 8.0
	var wm := BoxMesh.new()
	wm.size = Vector3(0.6, 0.01, 0.01)
	wm.material = Mats.ghost(Color(0.9, 0.95, 0.9, 0.35))
	_wind_fx.mesh = wm
	_wind_fx.particle_flag_align_y = false
	_wind_fx.emitting = false
	_wind_fx.visible = false
	add_child(_wind_fx)
	_rain_loop = AudioStreamPlayer.new()
	_rain_loop.stream = ctx.audio.get_stream("rain_loop")
	_rain_loop.volume_db = -10.0
	add_child(_rain_loop)
	_wind_loop = AudioStreamPlayer.new()
	_wind_loop.stream = ctx.audio.get_stream("wind_loop")
	_wind_loop.volume_db = -12.0
	add_child(_wind_loop)


func reset() -> void:
	rain_on = false
	wind_on = false
	structure_on = false
	wind_boost = 0.0
	_rain.emitting = false
	_rain.visible = false
	_rain_loop.stop()
	_update_wind_fx()
	_puddles.clear()
	for m in _puddle_meshes:
		m.queue_free()
	_puddle_meshes.clear()


func enable(effect: String) -> void:
	match effect:
		"rain":
			rain_on = true
			_rain.visible = true
			_rain.emitting = true
			_rain_loop.play()
			_make_puddles()
		"wind":
			wind_on = true
			_update_wind_fx()
		"structure":
			structure_on = true
			_struct_t = 5.0


func is_puddle_tile(tile: StaticBody3D) -> bool:
	return _puddles.has(tile)


func _make_puddles() -> void:
	var tiles: Array = ctx.room.floor_tiles.duplicate()
	tiles.shuffle()
	for i in 4:
		var t: StaticBody3D = tiles[i]
		_puddles.append(t)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.2, 0.01, 3.2)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.35, 0.5, 0.65, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.02
		m.metallic_specular = 1.0
		mi.material_override = m
		mi.position = t.position + Vector3(0, 0.105, 0)
		ctx.room.add_child(mi)
		_puddle_meshes.append(mi)
	ctx.rules.refresh_floor()


func wind_strength() -> float:
	return (5.5 if wind_on else 0.0) + wind_boost


func _update_wind_fx() -> void:
	var on := wind_strength() > 0.0
	_wind_fx.emitting = on
	_wind_fx.visible = on
	_wind_fx.direction = wind_dir
	if on and not _wind_loop.playing:
		_wind_loop.play()
	elif not on:
		_wind_loop.stop()


func _physics_process(delta: float) -> void:
	if ctx == null or not ctx.is_playing():
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	var ws := wind_strength()
	if ws > 0.0:
		_wind_t -= real_dt
		if _wind_t <= 0.0:
			_wind_t = randf_range(6.0, 10.0)
			var ang := randf() * TAU
			wind_dir = Vector3(cos(ang), 0, sin(ang))
			_update_wind_fx()
			ctx.audio.play_ui("gust", -6.0)
			ctx.events.notify.emit("風向改變了", Color(0.8, 0.95, 0.9), false)
		_tick += 1
		if _tick % 2 == 0:
			var gust := 1.0 + 0.6 * sin(GameClock.ms * 0.0015)
			for p: Prop in ctx.room.live_props():
				if p.held:
					continue
				var area_f := 1.0 / maxf(p.mass, 0.3)
				p.apply_central_impulse(wind_dir * ws * gust * clampf(area_f, 0.15, 3.0) * p.mass * delta * 2.0 * 0.6)
			ctx.player.external_push(wind_dir * ws * 0.12 * delta * 2.0)
	if structure_on:
		_struct_t -= real_dt
		if _struct_t <= 0.0:
			_struct_t = randf_range(5.0, 9.0)
			drop_ceiling(1 + randi() % 2)
			if randf() < 0.4:
				quake(0.7)


func drop_ceiling(n: int) -> void:
	for i in n:
		var pos := Vector3(randf_range(-7, 7), 4.3, randf_range(-5, 5))
		var p: Prop = ctx.room.spawn("ceiling", Transform3D(Basis.IDENTITY, pos))
		p.linear_velocity = Vector3(0, -1.0, 0)
		ctx.chains.start_chain("天花板掉落", [p])
	ctx.audio.play_ui("creak", -4.0)


func quake(strength: float) -> void:
	for p: Prop in ctx.room.live_props():
		if not p.held:
			p.apply_central_impulse(Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1)) * strength * minf(p.mass, 6.0))
	ctx.player.shake = 1.0
	ctx.audio.play_ui("quake", 0.0)

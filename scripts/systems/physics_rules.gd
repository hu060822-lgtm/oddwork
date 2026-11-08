class_name PhysicsRuleManager
extends Node
## Holds the current level of each of the five rules and pushes them into the
## physics server, props, floor tiles and the player.

var ctx: Node
var levels: Array[int] = [0, 0, 0, 0, 0]
const MAG_MAX_SPEED := 3.5
var magnet_strength: int = 1  # 0 low, 1 medium, 2 high
var resisted_rule: int = -1   # set by RoomObserver
var pending: Array = []       # [rule, level, real_time_left]
var sideways_dir: Vector3 = Vector3(1, 0, 0)
var _cooldown: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _tick: int = 0
var _time_phase: float = 0.0
var _patch_seed: int = 0
var magnet_lines: Array = []


func setup(c: Node) -> void:
	ctx = c


func reset() -> void:
	levels = [0, 0, 0, 0, 0]
	magnet_strength = 1
	pending.clear()
	resisted_rule = -1
	for r in RuleDefs.COUNT:
		_apply(r)


## Player-facing change. Returns a status string for the UI.
func request(rule: int, level: int) -> String:
	if level == levels[rule]:
		return ""
	if _cooldown[rule] > 0.0:
		return "cooldown"
	for p in pending:
		if int(p[0]) == rule:
			p[1] = level
			return "pending"
	if rule == resisted_rule:
		pending.append([rule, level, 2.5])
		ctx.audio.play_ui("resist", -2.0)
		ctx.events.notify.emit("房間在抵抗你的%s修改……（2.5 秒）" % RuleDefs.NAMES_ZH[rule], Color(1, 0.35, 0.3), false)
		return "pending"
	set_level(rule, level, true)
	return "ok"


func set_level(rule: int, level: int, by_player: bool) -> void:
	level = clampi(level, 0, RuleDefs.level_count(rule) - 1)
	if level == levels[rule]:
		return
	levels[rule] = level
	if by_player:
		_cooldown[rule] = 0.6
	if rule == RuleDefs.GRAVITY and level == RuleDefs.GRAVITY_SIDEWAYS:
		var dirs := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
		sideways_dir = dirs[randi() % dirs.size()]
	_apply(rule)
	if ctx:
		ctx.audio.play_rule(rule, level)
		ctx.events.rule_changed.emit(rule, level, by_player)
		var affected: Array = ctx.room.live_props()
		if rule != RuleDefs.TIME:
			ctx.chains.start_chain("%s→%s" % [RuleDefs.NAMES_ZH[rule], RuleDefs.level_name_zh(rule, level)], affected, true)


func gravity_strength() -> float:
	match levels[RuleDefs.GRAVITY]:
		RuleDefs.GRAVITY_LOW:
			return 2.4
		RuleDefs.GRAVITY_HIGH:
			return 26.0
		RuleDefs.GRAVITY_ANTI:
			return -3.4
		RuleDefs.GRAVITY_SIDEWAYS:
			return 6.0
	return 9.8


func is_normal(rule: int) -> bool:
	return levels[rule] == 0


func non_normal_count() -> int:
	var n := 0
	for l in levels:
		if l != 0:
			n += 1
	return n


func _apply(rule: int) -> void:
	if ctx == null:
		return
	match rule:
		RuleDefs.GRAVITY:
			_apply_gravity()
		RuleDefs.BOUNCE, RuleDefs.FRICTION:
			for p: Prop in ctx.room.live_props(true):
				apply_to_prop(p)
			if rule == RuleDefs.FRICTION:
				_apply_floor()
		RuleDefs.TIME:
			ctx.room.set_pockets(levels[RuleDefs.TIME] == RuleDefs.TIME_POCKETS)
			_apply_time_scale(0.0)
		RuleDefs.MAGNETISM:
			magnet_lines.clear()
	ctx.fx.on_rules_changed(levels)


func _apply_gravity() -> void:
	var space: RID = ctx.room.get_world_3d().space
	var lvl := levels[RuleDefs.GRAVITY]
	var vec := Vector3.DOWN
	var mag := gravity_strength()
	if lvl == RuleDefs.GRAVITY_ANTI:
		vec = Vector3.UP
		mag = 3.4
	elif lvl == RuleDefs.GRAVITY_SIDEWAYS:
		vec = sideways_dir
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, vec)
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, mag)
	for p: Prop in ctx.room.live_props(true):
		p.sleeping = false
	match lvl:
		RuleDefs.GRAVITY_LOW:
			ctx.player.gravity_mult = 0.33
		RuleDefs.GRAVITY_HIGH:
			ctx.player.gravity_mult = 1.7
		_:
			ctx.player.gravity_mult = 1.0


func apply_to_prop(p: Prop) -> void:
	var b := levels[RuleDefs.BOUNCE]
	match b:
		RuleDefs.BOUNCE_HIGH:
			p.pmat.bounce = maxf(p.base_bounce, 0.78)
			p.pmat.absorbent = false
		RuleDefs.BOUNCE_EXTREME:
			p.pmat.bounce = 1.0
			p.pmat.absorbent = false
		RuleDefs.BOUNCE_DEAD:
			p.pmat.bounce = 0.0
			p.pmat.absorbent = true
		_:
			p.pmat.bounce = p.base_bounce
			p.pmat.absorbent = false
	var f := levels[RuleDefs.FRICTION]
	var wet_mult := 0.35 if p.wet else 1.0
	match f:
		RuleDefs.FRICTION_SLICK:
			p.pmat.friction = 0.01
			p.set_damp(-0.04, -0.3)
		RuleDefs.FRICTION_STICKY:
			p.pmat.friction = 1.0
			p.set_damp(1.4, 2.5)
		_:
			p.pmat.friction = p.base_friction * wet_mult
			p.set_damp(2.2 if p.kind == "paper" else 0.0, 2.0 if p.kind == "paper" else 0.0)


func _apply_floor() -> void:
	var f := levels[RuleDefs.FRICTION]
	_patch_seed += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = _patch_seed * 7919
	for t in ctx.room.floor_tiles:
		var tile: StaticBody3D = t
		var base: Color = tile.get_meta("base_color")
		var fr := 0.8
		var col := base
		var rough := 0.8
		match f:
			RuleDefs.FRICTION_SLICK:
				fr = 0.0
				col = base.lerp(Color(0.55, 0.8, 0.95), 0.45)
				rough = 0.05
			RuleDefs.FRICTION_STICKY:
				fr = 1.0
				col = base.lerp(Color(0.62, 0.5, 0.15), 0.55)
				rough = 1.0
			RuleDefs.FRICTION_PATCH:
				var roll := rng.randi() % 3
				if roll == 0:
					fr = 0.0
					col = base.lerp(Color(0.55, 0.8, 0.95), 0.6)
					rough = 0.05
				elif roll == 1:
					fr = 1.0
					col = base.lerp(Color(0.62, 0.5, 0.15), 0.65)
					rough = 1.0
		if ctx.env_fx and ctx.env_fx.is_puddle_tile(tile) and fr > 0.2:
			fr = 0.15
			col = col.lerp(Color(0.3, 0.45, 0.6), 0.4)
			rough = 0.1
		tile.physics_material_override.friction = fr
		tile.set_meta("friction", fr)
		var mi: MeshInstance3D = tile.get_child(0)
		var m: StandardMaterial3D = mi.material_override
		m.albedo_color = col
		m.roughness = rough
		m.metallic_specular = 0.9 if rough < 0.2 else 0.5
	for w in ctx.room.wall_bodies:
		(w as StaticBody3D).physics_material_override.friction = 0.0 if f == RuleDefs.FRICTION_SLICK else 0.5


func refresh_floor() -> void:
	_patch_seed -= 1
	_apply_floor()


func _apply_time_scale(_dt: float) -> void:
	var lvl := levels[RuleDefs.TIME]
	var ts := 1.0
	match lvl:
		RuleDefs.TIME_SLOW:
			ts = 0.35
		RuleDefs.TIME_FAST:
			ts = 1.75
		RuleDefs.TIME_UNSTABLE:
			var s := sin(_time_phase * 0.9) * 0.6 + sin(_time_phase * 2.3) * 0.3
			ts = clampf(1.0 + s, 0.25, 1.8)
	if ctx.paused_for_menu:
		return
	Engine.time_scale = ts


func current_time_scale() -> float:
	return Engine.time_scale


func _process(delta: float) -> void:
	if ctx == null or not ctx.is_playing():
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	for r in RuleDefs.COUNT:
		_cooldown[r] = maxf(0.0, _cooldown[r] - real_dt)
	for i in range(pending.size() - 1, -1, -1):
		pending[i][2] = float(pending[i][2]) - real_dt
		if float(pending[i][2]) <= 0.0:
			var e: Array = pending[i]
			pending.remove_at(i)
			set_level(int(e[0]), int(e[1]), true)
	if levels[RuleDefs.TIME] == RuleDefs.TIME_UNSTABLE:
		_time_phase += real_dt
		_apply_time_scale(real_dt)


func _physics_process(delta: float) -> void:
	if ctx == null or not ctx.is_playing():
		return
	if levels[RuleDefs.MAGNETISM] == RuleDefs.MAG_OFF:
		return
	_tick += 1
	if _tick % 2 != 0:
		return
	_magnetism(delta * 2.0)


func _magnetism(dt: float) -> void:
	var mode := levels[RuleDefs.MAGNETISM]
	var k := [4.0, 7.0, 11.0][magnet_strength] as float
	if mode == RuleDefs.MAG_REPEL:
		k *= -1.0
	elif mode == RuleDefs.MAG_METAL:
		k *= 2.2
	var list: Array[Prop] = []
	for p: Prop in ctx.room.live_props():
		if p.held or p.mass > 60.0 or p.kind == "paper":
			continue
		if mode == RuleDefs.MAG_METAL and not p.magnetic:
			continue
		list.append(p)
	var lines: Array = []
	var n := list.size()
	var accs: Array[Vector3] = []
	accs.resize(n)
	var clump: Array[bool] = []
	clump.resize(n)
	for i in n:
		accs[i] = Vector3.ZERO
		clump[i] = false
	for i in n:
		var a := list[i]
		var pa := a.global_position
		for j in range(i + 1, n):
			var b := list[j]
			var d := b.global_position - pa
			var dist2 := d.length_squared()
			if dist2 > 42.0 or dist2 < 0.0001:
				continue
			var dist := sqrt(dist2)
			if k > 0.0 and dist < 0.95:
				# Close partners settle into a clump instead of bouncing apart
				# and getting pulled back in again (rubber + magnet shredder).
				clump[i] = true
				clump[j] = true
				if dist < 0.55:
					continue
			var dirn := d / dist
			# Do not keep accelerating props that are already rushing at each
			# other: magnetism should gather things, not shotgun them.
			var closing := (a.linear_velocity - b.linear_velocity).dot(dirn)
			if k > 0.0 and closing > 2.0:
				continue
			if k < 0.0 and closing < -3.0:
				continue
			var f := k / (dist2 + 0.8)
			accs[i] += dirn * f * clampf(b.mass * 0.5, 0.3, 2.0)
			accs[j] -= dirn * f * clampf(a.mass * 0.5, 0.3, 2.0)
			if f > 1.0 and lines.size() < 14:
				lines.append([pa, b.global_position])
	# Sum per prop, then cap: a prop surrounded by many partners must not get
	# many times the push, and nothing magnetism moves may exceed MAG_MAX_SPEED.
	for i in n:
		var p := list[i]
		if clump[i]:
			p.linear_velocity *= 0.9
			p.angular_velocity *= 0.9
		var dv := (accs[i] * dt).limit_length(0.9)
		if dv == Vector3.ZERO:
			continue
		var v := p.linear_velocity
		var along := v.dot(dv.normalized())
		if along > MAG_MAX_SPEED:
			dv = Vector3.ZERO
		p.apply_central_impulse(dv * p.mass)
		var hv := Vector3(v.x, 0.0, v.z)
		if dv.length() > 0.05 and hv.length() > MAG_MAX_SPEED:
			p.linear_velocity = Vector3(v.x * 0.94, v.y, v.z * 0.94)
	magnet_lines = lines

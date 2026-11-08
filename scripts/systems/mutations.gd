class_name MutationManager
extends Node
## World mutations triggered when Deviation climbs into a new tier.
## Each is announced 2 s ahead so the player can react, lasts a while, then
## reverts (a rule is only restored if the player has not changed it since).

const WARN_TIME := 2.0

var ctx: Node
var defs: Array[Dictionary] = []
var active: Array[Dictionary] = []   # {def, left, restore: {rule: [from, to]}}
var seen_this_run: Array[String] = []
var count_this_shift: int = 0
var _warning: Dictionary = {}
var _warn_left: float = 0.0
var _cooldown: float = 0.0
var _cata_t: float = 0.0
var _recent: Array[String] = []
var _lights_bad: bool = false
var _sized: Array = []
var _brittle: Array = []
var _pairs: Array = []


func setup(c: Node) -> void:
	ctx = c
	defs = MutationData.all()
	ctx.events.deviation_tier_changed.connect(_on_tier)


func reset() -> void:
	for a in active.duplicate():
		_end(a)
	active.clear()
	seen_this_run.clear()
	_warning = {}
	_warn_left = 0.0
	_cooldown = 0.0
	_recent.clear()


func _on_tier(tier: int, up: bool) -> void:
	if not up or not ctx.is_playing():
		return
	if tier == 1:
		trigger_id("WRONG_LIGHTS")
	elif tier >= 2:
		trigger_random(tier)


func trigger_random(tier: int) -> void:
	if _cooldown > 0.0 or not _warning.is_empty():
		return
	var pool: Array[Dictionary] = []
	for d in defs:
		if int(d["tier"]) <= tier and not _is_active(str(d["id"])) and not _recent.has(str(d["id"])) and str(d["id"]) != "WRONG_LIGHTS":
			pool.append(d)
	if pool.is_empty():
		return
	trigger(pool[randi() % pool.size()])


func trigger_id(id: String) -> void:
	for d in defs:
		if str(d["id"]) == id and not _is_active(id) and _warning.is_empty():
			trigger(d)
			return


func trigger(d: Dictionary) -> void:
	_warning = d
	_warn_left = WARN_TIME
	_cooldown = 10.0
	ctx.audio.play_ui("alarm", -2.0)
	ctx.events.mutation_warning.emit(d)


func _is_active(id: String) -> bool:
	for a in active:
		if str((a["def"] as Dictionary)["id"]) == id:
			return true
	return false


func _start(d: Dictionary) -> void:
	var entry := {"def": d, "left": float(d["dur"]), "restore": {}}
	var id := str(d["id"])
	match id:
		"GRAVITY_FLIP":
			var g: int = ctx.rules.levels[RuleDefs.GRAVITY]
			_force(entry, RuleDefs.GRAVITY, RuleDefs.GRAVITY_NORMAL if g == RuleDefs.GRAVITY_ANTI else RuleDefs.GRAVITY_ANTI)
		"BOUNCE_SURGE":
			_force(entry, RuleDefs.BOUNCE, RuleDefs.BOUNCE_EXTREME)
		"ICE_FLOOR":
			_force(entry, RuleDefs.FRICTION, RuleDefs.FRICTION_SLICK)
		"TIME_STUTTER":
			_force(entry, RuleDefs.TIME, RuleDefs.TIME_UNSTABLE)
		"GALE":
			ctx.env_fx.wind_boost += 9.0
			ctx.env_fx._wind_t = 0.0
		"SIZE_SHIFT":
			_sized.clear()
			var list: Array = ctx.room.live_props()
			list.shuffle()
			for i in mini(10, list.size()):
				var p: Prop = list[i]
				_sized.append([p, p.size_factor])
				p.set_size(p.size_factor * randf_range(0.5, 1.8))
		"BRITTLE":
			_brittle.clear()
			var list2: Array = ctx.room.live_props()
			list2.shuffle()
			for i in mini(14, list2.size()):
				var p2: Prop = list2[i]
				_brittle.append([p2, p2.damage_mult])
				p2.damage_mult *= 4.0
				p2.hp = minf(p2.hp, p2.max_hp * 0.4)
		"MAGNET_PAIRS":
			_pairs.clear()
			var list3: Array = ctx.room.live_props()
			list3.shuffle()
			for i in range(0, mini(8, list3.size() - 1), 2):
				_pairs.append([list3[i], list3[i + 1]])
		"WRONG_LIGHTS":
			_lights_bad = true
		"COLLAPSE":
			ctx.env_fx.drop_ceiling(4)
			ctx.env_fx.quake(1.2)
	active.append(entry)
	count_this_shift += 1
	if not seen_this_run.has(id):
		seen_this_run.append(id)
	_recent.append(id)
	if _recent.size() > 3:
		_recent.pop_front()
	ctx.audio.play_ui("mutation", 0.0)
	ctx.events.mutation_started.emit(d)
	ctx.chains.start_chain("突變：%s" % str(d["zh"]), ctx.room.live_props(), true)


func _force(entry: Dictionary, rule: int, level: int) -> void:
	var from: int = ctx.rules.levels[rule]
	(entry["restore"] as Dictionary)[rule] = [from, level]
	ctx.rules.set_level(rule, level, false)


func _end(entry: Dictionary) -> void:
	var d: Dictionary = entry["def"]
	var restore: Dictionary = entry["restore"]
	for rule: int in restore:
		var pair: Array = restore[rule]
		if ctx.rules.levels[rule] == int(pair[1]):
			ctx.rules.set_level(rule, int(pair[0]), false)
	match str(d["id"]):
		"GALE":
			ctx.env_fx.wind_boost = maxf(0.0, ctx.env_fx.wind_boost - 9.0)
			ctx.env_fx._update_wind_fx()
		"SIZE_SHIFT":
			for e in _sized:
				if is_instance_valid(e[0]):
					(e[0] as Prop).set_size(float(e[1]))
			_sized.clear()
		"BRITTLE":
			for e in _brittle:
				if is_instance_valid(e[0]):
					(e[0] as Prop).damage_mult = float(e[1])
			_brittle.clear()
		"MAGNET_PAIRS":
			_pairs.clear()
			ctx.fx.set_pair_lines([])
		"WRONG_LIGHTS":
			_lights_bad = false
			ctx.fx.set_lights_wrong(false)
	ctx.events.mutation_ended.emit(d)


func _process(delta: float) -> void:
	if ctx == null or not ctx.is_playing():
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	_cooldown = maxf(0.0, _cooldown - real_dt)
	if not _warning.is_empty():
		_warn_left -= real_dt
		if _warn_left <= 0.0:
			var d := _warning
			_warning = {}
			_start(d)
	for i in range(active.size() - 1, -1, -1):
		var a: Dictionary = active[i]
		a["left"] = float(a["left"]) - real_dt
		if float(a["left"]) <= 0.0:
			active.remove_at(i)
			_end(a)
	if ctx.deviation.tier == 4:
		_cata_t += real_dt
		if _cata_t > 22.0:
			_cata_t = 0.0
			trigger_random(4)
	else:
		_cata_t = 0.0
	if _lights_bad:
		ctx.fx.set_lights_wrong(true)


func _physics_process(delta: float) -> void:
	if _pairs.is_empty() or ctx == null or not ctx.is_playing():
		return
	var lines: Array = []
	for pr in _pairs:
		if not is_instance_valid(pr[0]) or not is_instance_valid(pr[1]):
			continue
		var a: Prop = pr[0]
		var b: Prop = pr[1]
		var d := b.global_position - a.global_position
		var dist := d.length()
		if dist > 0.5:
			var imp := d / dist * clampf(40.0 / (dist + 1.0), 2.0, 25.0) * delta
			if not a.held:
				a.apply_central_impulse(imp * minf(a.mass, 6.0) * 0.5)
			if not b.held:
				b.apply_central_impulse(-imp * minf(b.mass, 6.0) * 0.5)
		lines.append([a.global_position, b.global_position])
	ctx.fx.set_pair_lines(lines)


func warning_text() -> String:
	if _warning.is_empty():
		return ""
	return "突變來襲：%s（%.1f）" % [str(_warning["zh"]), maxf(0.0, _warn_left)]


func active_text() -> Array[String]:
	var out: Array[String] = []
	for a in active:
		var d: Dictionary = a["def"]
		out.append("%s  %ds" % [str(d["zh"]), int(ceil(float(a["left"])))])
	return out

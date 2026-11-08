class_name ComboManager
extends Node
## Rule combinations with real physical effects (see ComboData).
## Several combos can run at once. A combo that holds for ARM_TIME counts as
## "activated" for the shift; the first activation ever is a Discovery
## (codex entry, big notice, its own sound).

const ARM_TIME := 2.5
const BH_CENTER := Vector3(0.0, 2.3, 0.0)
const BH_POP_TIME := 9.0

var ctx: Node
var defs: Array[Dictionary] = []
var active: Dictionary = {}          # id -> seconds held
var activated_this_shift: Array[String] = []
var discovered_this_run: Array[String] = []
var _bh_t: float = 0.0
var _bh_cooldown: float = 0.0
var _breakfast_cd: Dictionary = {}   # prop uid -> ms
var _tick: int = 0


func setup(c: Node) -> void:
	ctx = c
	defs = ComboData.all()
	ctx.events.prop_impact.connect(_on_impact)


func reset_shift() -> void:
	active.clear()
	activated_this_shift.clear()
	_bh_t = 0.0
	_bh_cooldown = 0.0
	_breakfast_cd.clear()


func reset_run() -> void:
	reset_shift()
	discovered_this_run.clear()


func is_active(id: String) -> bool:
	return float(active.get(id, -1.0)) >= ARM_TIME


func def_of(id: String) -> Dictionary:
	for d in defs:
		if str(d["id"]) == id:
			return d
	return {}


func active_names() -> Array[String]:
	var out: Array[String] = []
	for id: String in active:
		if is_active(id):
			out.append(str(def_of(id)["zh"]))
	return out


func _process(delta: float) -> void:
	if ctx == null or not ctx.is_playing():
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	_bh_cooldown = maxf(0.0, _bh_cooldown - real_dt)
	var levels: Array = ctx.rules.levels
	for d in defs:
		var id := str(d["id"])
		if ComboData.matches(d, levels):
			var before := float(active.get(id, 0.0))
			active[id] = before + real_dt
			if before < ARM_TIME and before + real_dt >= ARM_TIME:
				_on_activated(d)
		elif active.has(id):
			active.erase(id)
			if id == "BLACK_HOLE":
				_bh_t = 0.0


func _on_activated(d: Dictionary) -> void:
	var id := str(d["id"])
	var first_ever: bool = ctx.progression.record("rcombo:" + id, str(d["title"]), str(d["desc"]))
	if not activated_this_shift.has(id):
		activated_this_shift.append(id)
		ctx.deviation.add(4.0, "combo")
	if first_ever:
		discovered_this_run.append(id)
		ctx.audio.play_ui("discovery", 0.0)
		ctx.events.notify.emit("發現組合：%s（%s）" % [str(d["title"]), str(d["zh"])], d["color"], true)
	else:
		ctx.audio.play_ui("discovery", -10.0, 1.2)
		ctx.events.notify.emit("組合：%s" % str(d["zh"]), d["color"], false)
	ctx.chains.start_chain("組合：%s" % str(d["zh"]), [], true)


func _physics_process(delta: float) -> void:
	if ctx == null or not ctx.is_playing() or active.is_empty():
		return
	_tick += 1
	if _tick % 2 != 0:
		return
	var dt := delta * 2.0
	if is_active("PING_PONG"):
		_ping_pong()
	if is_active("METAL_SOUP"):
		_metal_soup(dt)
	if is_active("GRAVITY_OPTIONAL"):
		_hover(dt)
	if is_active("BLACK_HOLE"):
		_black_hole(dt)


func _movable() -> Array[Prop]:
	var out: Array[Prop] = []
	for p: Prop in ctx.room.live_props():
		if p.held or p.mass > 60.0 or p.kind == "paper" or p.freeze:
			continue
		out.append(p)
	return out


# Ceiling acts like a trampoline: anything resting against it is kicked back
# down hard enough to reach the floor, where anti-gravity sends it up again.
func _ping_pong() -> void:
	var top := Room.HEIGHT - 0.6
	for p in _movable():
		if p.global_position.y > top and p.linear_velocity.y > -1.5:
			p.linear_velocity.y = -randf_range(5.5, 7.5)
			if randf() < 0.15:
				ctx.audio.play_3d("boing", p.global_position, -14.0, 1.4)


# Magnetic clumps on a slick floor start to orbit their common centre.
func _metal_soup(dt: float) -> void:
	var metal_only: bool = ctx.rules.levels[RuleDefs.MAGNETISM] == RuleDefs.MAG_METAL
	var list: Array[Prop] = []
	var c := Vector3.ZERO
	for p in _movable():
		if metal_only and not p.magnetic:
			continue
		if p.global_position.y > 1.5:
			continue
		list.append(p)
		c += p.global_position
	if list.size() < 3:
		return
	c /= float(list.size())
	for p in list:
		var r := p.global_position - c
		r.y = 0.0
		var dist := r.length()
		if dist < 0.3 or dist > 6.0:
			continue
		var tangent := Vector3(-r.z, 0.0, r.x) / dist
		var v := Vector3(p.linear_velocity.x, 0.0, p.linear_velocity.z)
		if v.dot(tangent) < 3.0:
			p.apply_central_impulse(tangent * 4.0 * dt * p.mass)


# Repel + low gravity: things settle into a hovering layer around 1.1 m.
func _hover(dt: float) -> void:
	var g: float = ctx.rules.gravity_strength()
	for p in _movable():
		var y := p.global_position.y
		if y < 1.2:
			var acc := g + (1.2 - y) * 6.0 - p.linear_velocity.y * 2.0
			p.apply_central_impulse(Vector3(0.0, maxf(acc, 0.0) * dt * p.mass, 0.0))


# A vortex in the middle of the room. After BH_POP_TIME it bursts outwards.
func _black_hole(dt: float) -> void:
	if _bh_cooldown > 0.0:
		return
	_bh_t += dt / maxf(Engine.time_scale, 0.05)
	var list := _movable()
	if _bh_t >= BH_POP_TIME:
		_bh_t = 0.0
		_bh_cooldown = 12.0
		ctx.audio.play_3d("singularity", BH_CENTER, 0.0)
		ctx.env_fx.quake(0.6)
		var moved: Array = []
		for p in list:
			var d := p.global_position - BH_CENTER
			if d.length() < 5.0:
				p.apply_central_impulse(d.normalized() * 7.0 * p.mass)
				moved.append(p)
		ctx.chains.start_chain("黑洞爆開", moved, true)
		ctx.events.notify.emit("黑洞爆開了。", Color(0.8, 0.4, 1.0), true)
		return
	var strength := 7.0 + _bh_t * 1.2
	for p in list:
		var d := BH_CENTER - p.global_position
		var dist := d.length()
		if dist > 7.0 or dist < 0.2:
			continue
		var dirn := d / dist
		var swirl := Vector3(-dirn.z, 0.0, dirn.x)
		var acc := (dirn * strength + swirl * 3.0) / (1.0 + dist * 0.15)
		if p.linear_velocity.dot(dirn) < 4.0:
			p.apply_central_impulse(acc * dt * p.mass)
		if dist < 1.2:
			p.linear_velocity *= 0.92


func black_hole_progress() -> float:
	return clampf(_bh_t / BH_POP_TIME, 0.0, 1.0) if is_active("BLACK_HOLE") else 0.0


# Fast time + bounce: impacts pump extra energy into the victim.
func _on_impact(striker: Node, victim: Node, speed: float) -> void:
	if not is_active("TEMPORAL_BREAKFAST") or speed < 2.5:
		return
	var a := striker as Prop
	var b := victim as Prop
	if a == null or b == null or b.held or b.mass > 40.0:
		return
	var now := GameClock.ms
	if now - int(_breakfast_cd.get(b.uid, -10000)) < 600:
		return
	_breakfast_cd[b.uid] = now
	if _breakfast_cd.size() > 300:
		_breakfast_cd.clear()
	var dir := (b.global_position - a.global_position).normalized()
	b.apply_central_impulse(dir * minf(speed * 0.35, 4.0) * b.mass)

class_name MissionManager
extends Node
## Generates, validates and tracks missions. Each shift has a primary mission
## (ends the shift) and an optional secondary mission (bonus).

const TIME_LIMIT := 150.0
## Deviation needed for END OF THE WORLD. Room-driven chaos is soft-capped,
## so this asks for several bent rules plus active play, not 100.
const SURVIVE_DEV := 84.0
const DELIVER_KINDS: Array[String] = ["cup", "apple", "ball", "box", "battery", "chair", "plate"]
const PUSHABLE_KINDS: Array[String] = ["ball", "box", "apple", "battery", "cup"]
const HIT_KINDS: Array[String] = ["ball", "box", "barrel", "battery", "plate"]
const BALANCE_KINDS: Array[String] = ["apple", "ball", "cup", "battery", "box"]

var ctx: Node
var defs: Array[Dictionary] = []
var primary: Mission
var secondary: Mission
var time_left: float = TIME_LIMIT
var _tick: float = 0.0
var _markers: Array[Node] = []


class Mission:
	extends RefCounted
	var type: String = ""
	var title: String = ""
	var text: String = ""
	var hint: String = ""
	var difficulty: float = 1.0
	var primary: bool = true
	var target: Prop
	var target_kind: String = ""
	var device: Node
	var zone: TargetZone
	var zone_name: String = ""
	var required: int = 1
	var seconds: float = 0.0
	var hold_t: float = 0.0
	var count: int = 0
	var phase: int = 0
	var state: String = "active"
	var target_grabbed: bool = false
	var carried: bool = false
	var completed_at: float = 0.0
	var _last_hit_ms: int = 0

	func progress() -> float:
		match type:
			"COLLISIONS":
				return float(count) / float(required)
			"FLOAT", "BALANCE":
				return hold_t / seconds
			"SURVIVE":
				return 0.5 * float(phase) + (hold_t / seconds) * 0.5
			"DELIVER", "NO_TOUCH", "ANTIGRAV":
				return hold_t
		return 1.0 if state == "done" else 0.0

	func status_line() -> String:
		match type:
			"COLLISIONS":
				return "%d / %d" % [count, required]
			"FLOAT":
				return "漂浮中：%d / %d   %.1f / %.0f 秒" % [count, required, hold_t, seconds]
			"BALANCE":
				return "%.1f / %.0f 秒" % [hold_t, seconds]
			"SURVIVE":
				return "Deviation 達到 %d（災難）" % int(MissionManager.SURVIVE_DEV) if phase == 0 else "存活 %.0f / %.0f 秒" % [hold_t, seconds]
			"CHAIN_ACTIVATE":
				return "需要 %d 段以上連鎖" % required
		return ""


func setup(c: Node) -> void:
	ctx = c
	defs = MissionData.all()
	ctx.events.prop_impact.connect(_on_impact)
	ctx.events.device_activated.connect(_on_device)
	ctx.events.prop_grabbed.connect(_on_grab)


func clear() -> void:
	for m in [primary, secondary]:
		if m:
			_cleanup(m)
	primary = null
	secondary = null
	for n in _markers:
		if is_instance_valid(n):
			n.queue_free()
	_markers.clear()


func start_shift(stage: int) -> void:
	clear()
	time_left = TIME_LIMIT
	primary = generate(stage, true, null)
	secondary = generate(maxi(1, stage - 1), false, primary)
	for m in [primary, secondary]:
		if m:
			_present(m)


# ---------------------------------------------------------------- generation
func generate(stage: int, is_primary: bool, other: Mission) -> Mission:
	var want := 1.0 + stage * 0.9
	var best: Mission = null
	var best_err := 999.0
	var pool := defs.duplicate()
	pool.shuffle()
	for d: Dictionary in pool:
		if not (d["stages"] as Array).has(stage):
			continue
		if not is_primary and str(d["type"]) in ["SURVIVE", "ANTIGRAV"]:
			continue
		if other and other.type == str(d["type"]):
			continue
		for attempt in 4:
			var m := _build(d, stage, is_primary)
			if m == null:
				continue
			var why := validate(m, other)
			if why != "":
				continue
			var err := absf(m.difficulty - want) + randf() * 0.6
			if err < best_err:
				best_err = err
				best = m
			break
	if best == null:
		best = _fallback(is_primary)
	return best


func _candidates(kinds: Array[String]) -> Array[Prop]:
	var out: Array[Prop] = []
	for p: Prop in ctx.room.live_props():
		if p.kind in kinds and not p.held:
			out.append(p)
	return out


func _zone_names(tags: Array) -> Array[String]:
	var out: Array[String] = []
	for n: String in ctx.room.zone_spots:
		for t in (ctx.room.zone_spots[n]["tags"] as Array):
			if tags.has(t):
				out.append(n)
				break
	return out


func _pick_far_zone(names: Array[String], from: Vector3, min_d: float) -> String:
	names.shuffle()
	for n in names:
		var pos: Vector3 = ctx.room.zone_spots[n]["pos"]
		if Vector2(pos.x - from.x, pos.z - from.z).length() >= min_d:
			return n
	return ""


func _build(d: Dictionary, stage: int, is_primary: bool) -> Mission:
	var m := Mission.new()
	m.type = str(d["type"])
	m.title = str(d["title"])
	m.hint = str(d["hint"])
	m.primary = is_primary
	m.difficulty = float(d["difficulty"])
	var fmt := str(d["text"])
	match m.type:
		"DELIVER", "NO_TOUCH", "ANTIGRAV":
			var kinds: Array[String] = DELIVER_KINDS if m.type != "NO_TOUCH" else PUSHABLE_KINDS
			var cands := _candidates(kinds)
			if cands.is_empty():
				return null
			m.target = cands[randi() % cands.size()]
			var tags := ["floor", "table", "high"] if m.type == "DELIVER" else (["floor"] if m.type == "NO_TOUCH" else ["ceiling"])
			if stage == 1 and m.type == "DELIVER":
				tags = ["floor", "table"]
			m.zone_name = _pick_far_zone(_zone_names(tags), m.target.global_position, 4.0 if m.type != "ANTIGRAV" else 2.0)
			if m.zone_name == "":
				return null
			var zpos: Vector3 = ctx.room.zone_spots[m.zone_name]["pos"]
			var dist := zpos.distance_to(m.target.global_position)
			m.difficulty += dist / 8.0
			var ztags: Array = ctx.room.zone_spots[m.zone_name]["tags"]
			if ztags.has("high") or ztags.has("behind_glass"):
				m.difficulty += 0.8
			if m.target.mass > 4.0:
				m.difficulty += 0.5
			m.text = fmt % [m.target.describe(), str(ctx.room.zone_spots[m.zone_name]["zh"])]
		"COLLISIONS":
			var cands2 := _candidates(HIT_KINDS)
			if cands2.is_empty():
				return null
			m.target = cands2[randi() % cands2.size()]
			m.required = 6 + stage * 3
			m.difficulty += m.required / 10.0 + (0.8 if m.target.mass > 10.0 else 0.0)
			m.text = fmt % [m.target.describe(), m.required]
		"FLOAT":
			m.required = [5, 6, 8][clampi(stage - 1, 0, 2)]
			m.seconds = [3.0, 4.0, 5.0][clampi(stage - 1, 0, 2)]
			m.difficulty += m.required * 0.12
			m.text = fmt % [m.required, int(m.seconds)]
		"CHAIN_ACTIVATE":
			var opts: Array = [ctx.room.buttons["A"], ctx.room.buttons["B"], ctx.room.tripwire]
			m.device = opts[randi() % opts.size()]
			m.required = 2 if stage <= 2 else 3
			m.difficulty += m.required * 0.4 + (0.5 if m.device == ctx.room.buttons["B"] else 0.0)
			m.text = fmt % [m.required, str(m.device.get("device_label_zh"))]
		"BALANCE":
			var cands3 := _candidates(BALANCE_KINDS)
			if cands3.is_empty():
				return null
			m.target = cands3[randi() % cands3.size()]
			m.zone_name = "pedestal"
			m.seconds = [6.0, 8.0, 10.0][clampi(stage - 1, 0, 2)]
			m.difficulty += m.seconds * 0.1 + (0.8 if m.target.kind == "ball" else 0.0)
			m.text = fmt % [m.target.describe(), str(ctx.room.zone_spots["pedestal"]["zh"]), int(m.seconds)]
		"SURVIVE":
			m.seconds = 25.0
			m.difficulty += 0.5
			m.text = fmt % [int(m.seconds)]
	if m.target:
		m.target_kind = m.target.kind
	# Anomalies that make missions harder or easier.
	if m.type == "BALANCE" and ctx.env_fx.wind_strength() > 0.0:
		m.difficulty += 1.0
	if m.type == "FLOAT" and ctx.anomalies.has_active("ANTI_GRAVITY"):
		m.difficulty -= 1.0
	if m.type == "ANTIGRAV" and ctx.anomalies.has_active("ANTI_GRAVITY"):
		m.difficulty -= 0.8
	return m


## Returns "" when valid, otherwise a reason. Guards against impossible or
## contradictory missions.
func validate(m: Mission, other: Mission) -> String:
	if m.type in ["DELIVER", "NO_TOUCH", "ANTIGRAV", "COLLISIONS", "BALANCE"]:
		if m.target == null or not is_instance_valid(m.target):
			return "no target"
		if m.target.is_device:
			return "device target"
	if m.zone_name != "":
		var spot: Dictionary = ctx.room.zone_spots.get(m.zone_name, {})
		if spot.is_empty():
			return "no zone"
		var size: Vector3 = spot["size"]
		var pos: Vector3 = spot["pos"]
		if m.target and _inside(m.target.center(), pos, size):
			return "already inside"
		if m.type == "BALANCE" and m.target and m.target.size_factor * 0.5 > 0.62:
			return "too big for pedestal"
	if m.type == "NO_TOUCH" and m.target and m.target.mass > 8.0:
		return "too heavy to push"
	if m.type == "CHAIN_ACTIVATE":
		if m.device == null:
			return "no device"
		if m.device.get("linked") == null and not (m.device is RedButton):
			return "device unlinked"
	if other:
		if m.target and other.target == m.target:
			return "shared target"
		if m.zone_name != "" and m.zone_name == other.zone_name:
			return "shared zone"
		if m.type == other.type:
			return "same type"
	if m.difficulty * 22.0 > TIME_LIMIT:
		return "too slow"
	return ""


static func _inside(p: Vector3, center: Vector3, size: Vector3) -> bool:
	var d := (p - center).abs()
	return d.x <= size.x / 2.0 and d.y <= size.y / 2.0 and d.z <= size.z / 2.0


func _fallback(is_primary: bool) -> Mission:
	var m := Mission.new()
	m.type = "FLOAT"
	m.title = "LEVITATION"
	m.primary = is_primary
	m.required = 5
	m.seconds = 3.0
	m.text = "讓 5 個物件同時漂浮在空中 3 秒"
	m.hint = "反重力、低重力、彈簧、時間氣泡。"
	return m


func _present(m: Mission) -> void:
	var col := Mats.GREEN_FL if m.primary else Mats.YELLOW
	if m.zone_name != "":
		var spot: Dictionary = ctx.room.zone_spots[m.zone_name]
		var z := TargetZone.new()
		ctx.room.add_child(z)
		z.global_position = spot["pos"]
		z.setup(spot["size"], "目標區" if m.primary else "加分目標區", col)
		m.zone = z
		_markers.append(z)
	if m.target:
		_attach_marker(m, col)
		if m.type == "NO_TOUCH":
			m.target.no_touch = true
		if ctx.observer.slippery_targets and m.type in ["DELIVER", "ANTIGRAV", "BALANCE"]:
			m.target.slippery_grip = true
	if m.type == "BALANCE":
		ctx.room.pedestal.wobble = 0.06 + 0.04 * ctx.stage
	if m.device:
		var lbl := Label3D.new()
		lbl.text = "▼ 用連鎖反應觸發"
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.fixed_size = true
		lbl.font_size = 40
		lbl.pixel_size = 0.0011
		lbl.modulate = col
		lbl.outline_size = 8
		lbl.font = UiKit.font()
		(m.device as Node3D).add_child(lbl)
		lbl.position = Vector3(0, 1.6, 0)
		_markers.append(lbl)


func _attach_marker(m: Mission, col: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = ("▼ 目標" if m.primary else "▼ 加分") + ("（禁止用手）" if m.type == "NO_TOUCH" else "")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true
	lbl.font_size = 36
	lbl.pixel_size = 0.0011
	lbl.modulate = col
	lbl.outline_size = 8
	lbl.font = UiKit.font()
	lbl.top_level = true
	m.target.add_child(lbl)
	lbl.set_meta("follow", m.target)
	_markers.append(lbl)


func _cleanup(m: Mission) -> void:
	if m.target and is_instance_valid(m.target):
		m.target.no_touch = false
		m.target.slippery_grip = false


# ---------------------------------------------------------------- tracking
func _on_impact(striker: Node, victim: Node, speed: float) -> void:
	for m in [primary, secondary]:
		if m == null or m.state != "active" or m.type != "COLLISIONS":
			continue
		if speed < 2.5 or (striker != m.target and victim != m.target):
			continue
		var now := GameClock.ms
		if now - m._last_hit_ms < 250:
			continue
		m._last_hit_ms = now
		m.count += 1
		ctx.events.mission_progress.emit(m)
		if m.count >= m.required:
			_complete(m)


func _on_device(device: Node, _source: Node, by_player: bool, links: int) -> void:
	for m in [primary, secondary]:
		if m == null or m.state != "active" or m.type != "CHAIN_ACTIVATE" or device != m.device:
			continue
		if by_player:
			ctx.events.notify.emit("直接按不算——要讓別的東西觸發它。", Color(1, 0.6, 0.4), false)
		elif links >= m.required:
			_complete(m)
		else:
			ctx.events.notify.emit("觸發了，但連鎖只有 %d 段（需要 %d 段）" % [links, m.required], Color(1, 0.8, 0.4), false)


func _on_grab(p: Node) -> void:
	for m in [primary, secondary]:
		if m and m.target == p:
			m.target_grabbed = true


func _retarget(m: Mission) -> void:
	var cands := _candidates([m.target_kind])
	if cands.is_empty():
		cands = _candidates(PUSHABLE_KINDS)
	if cands.is_empty():
		_fail(m)
		return
	m.target = cands[randi() % cands.size()]
	m.target_kind = m.target.kind
	m.target_grabbed = false
	_attach_marker(m, Mats.GREEN_FL if m.primary else Mats.YELLOW)
	if m.type == "NO_TOUCH":
		m.target.no_touch = true
	ctx.events.notify.emit("目標被毀了。房間指定了新的目標：%s" % m.target.describe(), Color(1, 0.7, 0.4), false)


func _complete(m: Mission) -> void:
	if m.state != "active":
		return
	m.state = "done"
	m.completed_at = TIME_LIMIT - time_left
	if m.target and is_instance_valid(m.target):
		m.carried = m.target_grabbed
	_cleanup(m)
	ctx.events.mission_completed.emit(m)


func _fail(m: Mission) -> void:
	if m.state != "active":
		return
	m.state = "failed"
	_cleanup(m)
	ctx.events.mission_failed.emit(m)


func force_complete_primary() -> void:
	if primary:
		_complete(primary)


func _process(delta: float) -> void:
	for n in _markers:
		if is_instance_valid(n) and n is Label3D and n.has_meta("follow"):
			var t: Variant = n.get_meta("follow")
			if is_instance_valid(t):
				(n as Label3D).global_position = (t as Node3D).global_position + Vector3(0, 0.7, 0)
			else:
				(n as Label3D).visible = false
	if ctx == null or not ctx.is_playing() or primary == null:
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	time_left -= real_dt
	_tick += real_dt
	if _tick >= 0.1:
		var dt := _tick
		_tick = 0.0
		for m in [primary, secondary]:
			if m and m.state == "active":
				_update(m, dt)
	if time_left <= 0.0:
		time_left = 0.0
		for m in [secondary, primary]:
			if m and m.state == "active":
				_fail(m)


func _update(m: Mission, dt: float) -> void:
	if m.target_kind != "" and not is_instance_valid(m.target):
		_retarget(m)
		return
	match m.type:
		"DELIVER", "NO_TOUCH", "ANTIGRAV":
			var ok := m.zone.contains(m.target.center()) and not m.target.held
			if m.type == "ANTIGRAV" and ctx.rules.levels[RuleDefs.GRAVITY] != RuleDefs.GRAVITY_ANTI:
				ok = false
			m.hold_t = minf(1.0, m.hold_t + dt) if ok else 0.0
			if m.hold_t >= 1.0:
				_complete(m)
		"FLOAT":
			var n := 0
			for p: Prop in ctx.room.live_props():
				if p.held or p.kind == "paper" or p.kind == "ceiling":
					continue
				var pos := p.center()
				if pos.y < 1.5:
					continue
				if pos.x < -1.9 and pos.z < -4.1 and pos.y < 3.0:
					continue  # resting on the mezzanine is not floating
				if pos.y < 2.2 and p.linear_velocity.length() < 0.05 and ctx.rules.levels[RuleDefs.GRAVITY] != RuleDefs.GRAVITY_ANTI:
					continue  # sitting on top of something
				n += 1
			m.count = n
			if n >= m.required:
				m.hold_t += dt
			else:
				m.hold_t = maxf(0.0, m.hold_t - dt * 2.0)
			if m.hold_t >= m.seconds:
				_complete(m)
		"BALANCE":
			var spot: Dictionary = ctx.room.zone_spots["pedestal"]
			var ok2 := _inside(m.target.center(), spot["pos"], spot["size"]) and not m.target.held
			m.hold_t = m.hold_t + dt if ok2 else 0.0
			if m.hold_t >= m.seconds:
				_complete(m)
		"SURVIVE":
			if m.phase == 0 and ctx.deviation.value >= SURVIVE_DEV:
				m.phase = 1
				ctx.events.notify.emit("房間進入災難等級！撐過 %d 秒！" % int(m.seconds), Color(1, 0.2, 0.4), true)
			elif m.phase == 1:
				m.hold_t += dt
				if m.hold_t >= m.seconds:
					_complete(m)
	ctx.events.mission_progress.emit(m)

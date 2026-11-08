class_name IncidentManager
extends Node
## Special incidents with explicit triggers (no pure dice rolls):
##   ROOM_SERVICE      player barely moved for IDLE_TIME
##   POWER_OUTAGE      OUTAGE_DEVICES device activations within 12 s
##   DUPLICATION_ERROR printer activated 3 times this shift
##   THE_NEIGHBOR      tier >= 3 for 8 s, and the room has reacted to you before
##   THE_INSPECTION    Deviation >= INSPECT_DEV; bring it under INSPECT_GOAL in time
## At most MAX_PER_SHIFT per shift, each at most once, GAP seconds apart,
## none in the first QUIET_START seconds.

const MAX_PER_SHIFT := 2
const GAP := 30.0
const QUIET_START := 15.0
const IDLE_TIME := 14.0
const OUTAGE_DEVICES := 5
const OUTAGE_TIME := 9.0
const INSPECT_DEV := 82.0
const INSPECT_GOAL := 50.0
const INSPECT_TIME := 30.0
const INSPECTOR_POS := Vector3(-3.0, 0.0, 5.25)  # in front of the door that never opens

var ctx: Node
## Tests switch automatic triggers off so incidents cannot disturb other checks.
var enabled: bool = true
var copies_made: int = 0
var delivered: int = 0
var happened: Array[String] = []     # this shift
var results: Dictionary = {}         # id -> "ok"/"fail"/"" this shift
var run_log: Array[Dictionary] = []  # {id, stage, result}
var active_id: String = ""
var _t_shift: float = 0.0
var _since_last: float = 999.0
var _idle_t: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _device_ms: Array[int] = []
var _printer_uses: int = 0
var _hot_t: float = 0.0
var _left: float = 0.0
var _saved_devices: Dictionary = {}
var _inspector: Node3D
var _dup_left: int = 0
var _dup_t: float = 0.0
var _dup_kind: String = ""
var _knocks: Array = []              # [delay, pos]


func setup(c: Node) -> void:
	ctx = c
	ctx.events.device_activated.connect(_on_device)


func reset_shift() -> void:
	_finish_active(false, true)
	happened.clear()
	results.clear()
	_t_shift = 0.0
	_since_last = 999.0
	_idle_t = 0.0
	_device_ms.clear()
	_printer_uses = 0
	_hot_t = 0.0
	_dup_left = 0
	_knocks.clear()
	if ctx and ctx.player:
		_last_pos = ctx.player.global_position


func reset_run() -> void:
	reset_shift()
	run_log.clear()


func _on_device(device: Node, _source: Node, _by_player: bool, _links: int) -> void:
	if not ctx.is_playing():
		return
	_device_ms.append(GameClock.ms)
	if device is PrinterProp:
		_printer_uses += 1


func can_trigger(id: String) -> bool:
	# The inspection answers the player's own chaos, so it is not crowded out
	# by the minor incidents' per-shift cap.
	var room_left := happened.size() < MAX_PER_SHIFT or (id == "THE_INSPECTION")
	return active_id == "" and not happened.has(id) and room_left \
		and _since_last >= GAP and _t_shift >= QUIET_START


func trigger(id: String) -> void:
	var d := IncidentData.get_def(id)
	if d.is_empty():
		return
	happened.append(id)
	results[id] = ""
	_since_last = 0.0
	ctx.progression.record("incident:" + id, str(d["title"]), str(d["desc"]))
	ctx.events.notify.emit(str(d["notice"]), Color(0.95, 0.85, 0.55), true)
	ctx.events.incident_started.emit(d)
	match id:
		"ROOM_SERVICE":
			_room_service()
			_log(id, "ok")
		"POWER_OUTAGE":
			active_id = id
			_left = OUTAGE_TIME
			_power(false)
		"DUPLICATION_ERROR":
			_start_duplication()
			_log(id, "ok")
		"THE_NEIGHBOR":
			_start_knocking()
			_log(id, "ok")
		"THE_INSPECTION":
			active_id = id
			_left = INSPECT_TIME
			_spawn_inspector()
			ctx.audio.play_ui("ding", 0.0, 0.8)


func _log(id: String, result: String) -> void:
	results[id] = result
	run_log.append({"id": id, "stage": int(ctx.stage), "result": result})


func _process(delta: float) -> void:
	if ctx == null or not ctx.is_playing():
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	_t_shift += real_dt
	_since_last += real_dt
	_tick_active(real_dt)
	_tick_duplication(real_dt)
	_tick_knocks(real_dt)
	if not enabled:
		return
	# --- triggers
	var pl: PlayerController = ctx.player
	var moved := Vector2(pl.global_position.x - _last_pos.x, pl.global_position.z - _last_pos.z).length()
	if moved > 0.6:
		_last_pos = pl.global_position
		_idle_t = 0.0
	elif not ctx.ui.rules_menu.visible:
		_idle_t += real_dt
	if _idle_t >= IDLE_TIME and can_trigger("ROOM_SERVICE"):
		_idle_t = 0.0
		trigger("ROOM_SERVICE")
	var now := GameClock.ms
	while _device_ms.size() > 0 and now - _device_ms[0] > 12000:
		_device_ms.pop_front()
	if _device_ms.size() >= OUTAGE_DEVICES and can_trigger("POWER_OUTAGE"):
		trigger("POWER_OUTAGE")
	if _printer_uses >= 3 and can_trigger("DUPLICATION_ERROR"):
		trigger("DUPLICATION_ERROR")
	if ctx.deviation.tier >= 3:
		_hot_t += real_dt
	var known: bool = int(ctx.observer.mem.get("reactions_seen", 0)) > 0 or ctx.observer.reactions.size() > 0
	if _hot_t >= 8.0 and known and can_trigger("THE_NEIGHBOR"):
		trigger("THE_NEIGHBOR")
	if ctx.deviation.value >= INSPECT_DEV and can_trigger("THE_INSPECTION"):
		trigger("THE_INSPECTION")


func _tick_active(dt: float) -> void:
	if active_id == "":
		return
	_left -= dt
	match active_id:
		"POWER_OUTAGE":
			if _left <= 0.0:
				_power(true)
				_log("POWER_OUTAGE", "ok")
				active_id = ""
		"THE_INSPECTION":
			if is_instance_valid(_inspector):
				var to: Vector3 = ctx.player.global_position - _inspector.global_position
				to.y = 0.0
				if to.length() > 0.1:
					_inspector.rotation.y = lerp_angle(_inspector.rotation.y, atan2(to.x, to.z), minf(1.0, dt * 3.0))
			if ctx.deviation.value < INSPECT_GOAL:
				_finish_active(true)
			elif _left <= 0.0:
				_finish_active(false)


func _finish_active(success: bool, silent: bool = false) -> void:
	if active_id == "":
		return
	var id := active_id
	active_id = ""
	match id:
		"POWER_OUTAGE":
			_power(true)
		"THE_INSPECTION":
			if is_instance_valid(_inspector):
				_inspector.queue_free()
			_inspector = null
	if silent:
		return
	if id == "THE_INSPECTION":
		_log(id, "ok" if success else "fail")
		if success:
			ctx.audio.play_ui("stamp", 0.0)
			ctx.events.notify.emit("檢查通過。官方紀錄：這個房間從來沒有發生過異常。", UiKit.GREEN, true)
			ctx.progression.record("incident:INSPECTION_PASSED", "INSPECTION PASSED", "在檢查員面前把房間恢復正常。")
		else:
			ctx.audio.play_ui("stamp", 0.0, 0.7)
			ctx.events.notify.emit("檢查員在報告上寫了很多字，然後離開了。", UiKit.RED, true)
	ctx.events.incident_ended.emit(IncidentData.get_def(id), success)


## Shift is over: an inspection still running counts as failed.
func end_shift() -> void:
	if active_id == "THE_INSPECTION":
		_log("THE_INSPECTION", "fail")
	_finish_active(false, true)


func status_text() -> String:
	if active_id == "THE_INSPECTION":
		return "檢查中：讓 Deviation 降到 %d 以下（%.0f 秒）" % [int(INSPECT_GOAL), maxf(0.0, _left)]
	if active_id == "POWER_OUTAGE":
		return "停電中（%.0f 秒）" % maxf(0.0, _left)
	return ""


# ---------------------------------------------------------------- effects
func _room_service() -> void:
	if ctx.room.live_props().size() > 110:
		return
	ctx.audio.play_3d("hatch", Room.HATCH, 0.0)
	var kinds := ["ball", "box", "battery", "apple", "cup", "plate", "barrel"]
	kinds.shuffle()
	var spawned: Array = []
	for i in 3:
		var pos := Room.HATCH + Vector3(randf_range(-0.5, 0.5), -0.3 - i * 0.3, randf_range(-0.5, 0.5))
		var p: Prop = ctx.room.spawn(str(kinds[i]), Transform3D(Basis.IDENTITY, pos))
		p.set_meta("no_respawn", true)
		p.linear_velocity = Vector3(randf_range(-1.5, 1.5), -1.0, randf_range(-1.5, 1.5))
		spawned.append(p)
		delivered += 1
	ctx.chains.start_chain("客房服務", spawned)


func _power(on: bool) -> void:
	if not on:
		ctx.audio.play_ui("power_down", 0.0)
		ctx.fx.set_power_out(true)
		_saved_devices.clear()
		for k: String in ctx.room.devices:
			var dev = ctx.room.devices[k]
			if is_instance_valid(dev) and dev is DeviceProp and k != "printer":
				_saved_devices[k] = bool(dev.on)
				if dev.on:
					dev.set_on(false)
	else:
		if not ctx.fx.power_out:
			return
		ctx.audio.play_ui("power_up", -2.0)
		ctx.fx.set_power_out(false)
		for k: String in _saved_devices:
			var dev = ctx.room.devices.get(k)
			if dev != null and is_instance_valid(dev) and bool(_saved_devices[k]):
				dev.set_on(true)
		_saved_devices.clear()


func _start_duplication() -> void:
	var small: Array[String] = []
	for p: Prop in ctx.room.live_props():
		if p.mass < 15.0 and not (p is DeviceProp) and p.kind not in ["paper", "ceiling", "debris"]:
			small.append(p.kind)
	_dup_kind = small[randi() % small.size()] if small.size() > 0 else "box"
	_dup_left = 3
	_dup_t = 0.4


func _tick_duplication(dt: float) -> void:
	if _dup_left <= 0:
		return
	var printer = ctx.room.devices.get("printer")
	if printer == null or not is_instance_valid(printer) or ctx.room.live_props().size() > 110:
		_dup_left = 0
		return
	_dup_t -= dt
	if _dup_t > 0.0:
		return
	_dup_t = 0.9
	_dup_left -= 1
	var pr := printer as Prop
	var front := pr.global_basis.z.normalized()
	var p: Prop = ctx.room.spawn(_dup_kind, Transform3D(Basis.IDENTITY, pr.global_position + Vector3(0, 0.8 * pr.size_factor, 0) + front * 0.6))
	p.set_meta("no_respawn", true)
	p.display_name = "%s（副本）" % p.display_name
	copies_made += 1
	p.set_size(p.size_factor * randf_range(0.7, 1.3))
	p.linear_velocity = front * randf_range(3.0, 5.0) + Vector3(0, 2.0, 0)
	ctx.audio.play_3d("printer", pr.global_position, 0.0, 0.7)
	ctx.chains.start_chain("印表機印出%s" % p.display_name, [p])


func _start_knocking() -> void:
	var walls := [
		Vector3(-Room.HALF_X + 0.05, 1.4, randf_range(-4.0, 4.0)),
		Vector3(Room.HALF_X - 0.05, 1.4, randf_range(-4.0, 4.0)),
		Vector3(randf_range(-6.0, 6.0), 1.4, -Room.HALF_Z + 0.05),
	]
	var pos: Vector3 = walls[randi() % walls.size()]
	var delays := [0.0, 0.35, 0.7, 2.2, 2.55, 2.9]
	for d in delays:
		_knocks.append([float(d), pos])


func _tick_knocks(dt: float) -> void:
	if _knocks.is_empty():
		return
	for k in _knocks:
		k[0] = float(k[0]) - dt
	while _knocks.size() > 0 and float(_knocks[0][0]) <= 0.0:
		var pos: Vector3 = _knocks.pop_front()[1]
		ctx.audio.play_3d("knock", pos, 4.0, randf_range(0.9, 1.05))
		# The wall really is being hit: things leaning on it get nudged.
		var inward := -Vector3(signf(pos.x) if absf(pos.x) > 7.0 else 0.0, 0.0, signf(pos.z) if absf(pos.z) > 5.0 else 0.0)
		for p: Prop in ctx.room.live_props():
			if p.held or p.mass > 40.0:
				continue
			if p.global_position.distance_to(pos) < 2.2:
				p.apply_central_impulse((inward * 1.6 + Vector3(0, 0.8, 0)) * p.mass)


func _spawn_inspector() -> void:
	var root := Node3D.new()
	root.name = "Inspector"
	ctx.room.add_child(root)
	root.global_position = INSPECTOR_POS
	var grey := Mats.solid(Color(0.55, 0.55, 0.53))
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.5
	body.mesh = cm
	body.position = Vector3(0, 0.85, 0)
	body.material_override = Mats.solid(Color(0.22, 0.23, 0.26))
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.44
	head.mesh = sm
	head.position = Vector3(0, 1.82, 0)
	head.material_override = grey
	root.add_child(head)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.42, 0.03)
	board.mesh = bm
	board.position = Vector3(0.18, 1.05, 0.3)
	board.rotation.x = -0.6
	board.material_override = Mats.solid(Color(0.85, 0.82, 0.7))
	root.add_child(board)
	var tag := Label3D.new()
	tag.font = UiKit.font()
	tag.text = "正常事務部 · 檢查員"
	tag.font_size = 30
	tag.pixel_size = 0.0011
	tag.fixed_size = true
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.95, 0.9, 0.7)
	tag.outline_size = 8
	tag.position = Vector3(0, 2.25, 0)
	root.add_child(tag)
	_inspector = root
	ctx.audio.play_3d("stamp", INSPECTOR_POS + Vector3(0, 1, 0), 0.0)

class_name RoomObserver
extends Node
## "The room is watching you." Counts the player's habits (persisted across
## runs) and, at the start of each shift, may answer one habit with a visible,
## explained counter-move. No hidden cheating: every reaction is announced and
## listed in the Tab screen.

var ctx: Node
var mem: Dictionary = {}          # persisted in progression.data["observer"]
var reactions: Array[String] = [] # active this shift, human-readable
var slippery_targets: bool = false
var _first_rule_this_shift: int = -1
var _attention: float = 0.0
var _cctv_t: float = 0.0
var _whisper_cd: float = 0.0


func setup(c: Node) -> void:
	ctx = c
	mem = ctx.progression.data["observer"]
	for k in ["rule_counts", "first_rule"]:
		if not mem.has(k):
			mem[k] = {}
	for k in ["fan_uses", "carry_wins", "throws", "shifts", "first_rule_streak", "last_first_rule", "reactions_seen"]:
		if not mem.has(k):
			mem[k] = 0 if k != "last_first_rule" else -1
	ctx.events.rule_changed.connect(_on_rule)
	ctx.events.device_activated.connect(_on_device)
	ctx.events.prop_thrown.connect(func(_p: Node) -> void: mem["throws"] = int(mem["throws"]) + 1; _attend(0.3))
	ctx.events.mission_completed.connect(_on_mission)


func _attend(v: float) -> void:
	_attention = minf(1.0, _attention + v)


func _on_rule(rule: int, level: int, by_player: bool) -> void:
	if not by_player or level == 0:
		return
	var rc: Dictionary = mem["rule_counts"]
	rc[str(rule)] = int(rc.get(str(rule), 0)) + 1
	if _first_rule_this_shift < 0:
		_first_rule_this_shift = rule
	_attend(0.4)
	if rule == ctx.rules.resisted_rule:
		_whisper()


func _on_device(device: Node, _src: Node, by_player: bool, _links: int) -> void:
	if device is FanProp and by_player or device == ctx.room.buttons.get("A"):
		mem["fan_uses"] = int(mem["fan_uses"]) + 1
		_attend(0.3)


func _on_mission(m: RefCounted) -> void:
	if m.get("carried") and str(m.get("type")) in ["DELIVER", "ANTIGRAV", "BALANCE"]:
		mem["carry_wins"] = int(mem["carry_wins"]) + 1


func favorite_rule() -> int:
	var rc: Dictionary = mem["rule_counts"]
	var total := 0
	var best := -1
	var bv := 0
	for k: String in rc:
		total += int(rc[k])
		if int(rc[k]) > bv:
			bv = int(rc[k])
			best = int(k)
	if total >= 6 and float(bv) / float(total) >= 0.45:
		return best
	return -1


## Called at the start of each shift. Picks at most two reactions.
func begin_shift() -> void:
	# Close out the previous shift's "first rule" habit.
	if _first_rule_this_shift >= 0:
		if _first_rule_this_shift == int(mem["last_first_rule"]):
			mem["first_rule_streak"] = int(mem["first_rule_streak"]) + 1
		else:
			mem["first_rule_streak"] = 1
		mem["last_first_rule"] = _first_rule_this_shift
	_first_rule_this_shift = -1
	mem["shifts"] = int(mem["shifts"]) + 1
	reactions.clear()
	slippery_targets = false
	ctx.rules.resisted_rule = -1
	var options: Array[Callable] = []
	var fav := favorite_rule()
	if fav >= 0:
		options.append(func() -> void:
			ctx.rules.resisted_rule = fav
			_announce("房間記住了你最愛的%s。這個班次修改%s會延遲 2.5 秒。" % [RuleDefs.NAMES_ZH[fav], RuleDefs.NAMES_ZH[fav]]))
	if int(mem["fan_uses"]) >= 4:
		options.append(func() -> void:
			ctx.room.move_fan_to_new_spot()
			mem["fan_uses"] = 2
			_announce("房間注意到你很愛用風扇。風扇被搬走了。"))
	if int(mem["carry_wins"]) >= 2:
		options.append(func() -> void:
			slippery_targets = true
			mem["carry_wins"] = 0
			_announce("你總是親手搬運目標。這個班次，目標拿在手上 2.5 秒就會滑掉。"))
	if int(mem["throws"]) >= 30:
		options.append(func() -> void:
			ctx.room.add_obstacle_glass()
			mem["throws"] = 10
			_announce("你丟了太多東西。房間在你常丟的路線上裝了玻璃。"))
	var streak_rule := int(mem["last_first_rule"])
	if int(mem["first_rule_streak"]) >= 3 and streak_rule >= 0 and ctx.rules.levels[streak_rule] == 0:
		options.append(func() -> void:
			var lvl := 1
			ctx.rules.set_level(streak_rule, lvl, false)
			mem["first_rule_streak"] = 0
			_announce("房間預料到你會先改%s，所以它先幫你改好了：%s。" % [RuleDefs.NAMES_ZH[streak_rule], RuleDefs.level_name_zh(streak_rule, lvl)]))
	options.shuffle()
	for i in mini(2, options.size()):
		options[i].call()


func _announce(text: String) -> void:
	reactions.append(text)
	mem["reactions_seen"] = int(mem["reactions_seen"]) + 1
	ctx.progression.record_disaster("WATCHED")
	ctx.events.observer_spoke.emit(text)
	var tv: Node = ctx.room.devices.get("tv")
	if tv and tv.has_method("show_eye"):
		tv.call("show_eye", 6.0)
	_whisper()


func _whisper() -> void:
	if _whisper_cd > 0.0:
		return
	_whisper_cd = 6.0
	ctx.audio.play_ui("observer", -6.0)
	_attention = 1.0


func _process(delta: float) -> void:
	if ctx == null:
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	_whisper_cd = maxf(0.0, _whisper_cd - real_dt)
	_attention = maxf(0.0, _attention - real_dt * 0.08)
	# The CCTV camera always tracks the player; its LED blinks faster when the
	# room is paying attention.
	var cam: Node3D = ctx.room.cctv
	if cam and ctx.player:
		var target: Vector3 = ctx.player.global_position + Vector3(0, 1.5, 0)
		var want := cam.global_transform.looking_at(target, Vector3.UP, true)
		cam.global_transform = cam.global_transform.interpolate_with(want, clampf(real_dt * (1.5 + _attention * 4.0), 0.0, 1.0))
		_cctv_t += real_dt * (1.0 + _attention * 6.0)
		ctx.room.cctv_led.visible = fmod(_cctv_t, 1.0) < 0.5


func attention() -> float:
	return _attention


func summary_lines() -> Array[String]:
	var out: Array[String] = []
	var fav := favorite_rule()
	if fav >= 0:
		out.append("最常修改：%s" % RuleDefs.NAMES_ZH[fav])
	if int(mem["fan_uses"]) >= 2:
		out.append("常用風扇（%d 次）" % int(mem["fan_uses"]))
	if int(mem["carry_wins"]) >= 1:
		out.append("親手搬運完成任務：%d 次" % int(mem["carry_wins"]))
	if int(mem["throws"]) >= 10:
		out.append("投擲次數：%d" % int(mem["throws"]))
	if int(mem["first_rule_streak"]) >= 2:
		out.append("連續 %d 個班次先改%s" % [int(mem["first_rule_streak"]), RuleDefs.NAMES_ZH[maxi(0, int(mem["last_first_rule"]))]])
	return out

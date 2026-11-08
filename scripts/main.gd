extends Node
## GameManager: builds every subsystem, runs the state machine
## (menu -> card pick -> shift -> shift result -> ... -> run result) and keeps
## per-shift statistics for scoring.

const SHIFTS := 3

enum State { MENU, CARDS, PLAYING, SHIFT_END, RESULTS }

var state: State = State.MENU
var events: GameEvents
var audio: AudioManager
var progression: ProgressionManager
var rules: PhysicsRuleManager
var deviation: DeviationManager
var chains: ChainTracker
var mutations: MutationManager
var anomalies: AnomalyManager
var env_fx: EnvEffects
var missions: MissionManager
var observer: RoomObserver
var combos: ComboManager
var clauses: ClauseManager
var incidents: IncidentManager
var fx: FxManager
var room: Room
var player: PlayerController
var ui: UIManager

var stage: int = 0
var paused: bool = false
var paused_for_menu: bool = false
var misruled: bool = false
var stats: Dictionary = {}
var run_shifts: Array = []
var run_totals: Dictionary = {}
var run_codex_new: Array[String] = []
var run_stats: Array[Dictionary] = []
var last_report: Dictionary = {}
var test_mode: bool = false
var save_path: String = ""
var _cards: Array[AnomalyDef] = []
var _end_pending: float = -1.0
var _end_success: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	if has_meta("test_mode"):
		test_mode = true
		save_path = str(get_meta("save_path", ""))
	build()
	goto_menu()


# ---------------------------------------------------------------- build
func _sys(n: Node, nm: String) -> void:
	n.name = nm
	n.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(n)


func build() -> void:
	events = GameEvents.new()
	_sys(events, "Events")
	audio = AudioManager.new()
	_sys(audio, "Audio")
	progression = ProgressionManager.new()
	_sys(progression, "Progression")
	progression.setup(self, save_path)
	rules = PhysicsRuleManager.new()
	_sys(rules, "Rules")
	rules.setup(self)
	deviation = DeviationManager.new()
	_sys(deviation, "Deviation")
	chains = ChainTracker.new()
	_sys(chains, "Chains")
	mutations = MutationManager.new()
	_sys(mutations, "Mutations")
	anomalies = AnomalyManager.new()
	_sys(anomalies, "Anomalies")
	env_fx = EnvEffects.new()
	_sys(env_fx, "EnvFx")
	missions = MissionManager.new()
	_sys(missions, "Missions")
	fx = FxManager.new()
	_sys(fx, "Fx")
	observer = RoomObserver.new()
	_sys(observer, "Observer")
	combos = ComboManager.new()
	_sys(combos, "Combos")
	clauses = ClauseManager.new()
	_sys(clauses, "Clauses")
	incidents = IncidentManager.new()
	_sys(incidents, "Incidents")
	audio.setup(self)
	deviation.setup(self)
	chains.setup(self)
	mutations.setup(self)
	anomalies.setup(self)
	env_fx.setup(self)
	missions.setup(self)
	fx.setup(self)
	_build_room()
	player = PlayerController.new()
	_sys(player, "Player")
	player.setup(self)
	observer.setup(self)
	combos.setup(self)
	clauses.setup(self)
	incidents.setup(self)
	ui = UIManager.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup(self)
	_connect_stats()
	var st: Dictionary = progression.data["settings"]
	set_sensitivity(float(st.get("sensitivity", 1.0)))
	set_volume(float(st.get("volume", 0.8)))


func _build_room() -> void:
	if room:
		room.name = "OldRoom"
		room.queue_free()
		# Make sure nothing still points at the old props.
		room.props.clear()
	room = Room.new()
	_sys(room, "Room")
	room.build(self)


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "interact": [KEY_E],
		"rules_menu": [KEY_Q], "status": [KEY_TAB], "pause": [KEY_ESCAPE],
		"rule_1": [KEY_1], "rule_2": [KEY_2], "rule_3": [KEY_3], "rule_4": [KEY_4], "rule_5": [KEY_5],
		"fullscreen": [KEY_F11],
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k: int in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k as Key
			InputMap.action_add_event(action, ev)


func _connect_stats() -> void:
	events.prop_thrown.connect(func(_p: Node) -> void: stats_add("throws", 1))
	events.prop_grabbed.connect(func(_p: Node) -> void: stats_add("grabs", 1))
	events.pulse_fired.connect(func(_o: Vector3, _n: int) -> void: stats_add("pulses", 1))
	events.rule_changed.connect(_on_rule_changed)
	events.prop_broken.connect(_on_prop_broken)
	events.device_activated.connect(func(d: Node, _s: Node, _b: bool, _l: int) -> void:
		if state == State.PLAYING:
			(stats["devices_used"] as Dictionary)[str(d.get("device_label"))] = true)
	events.chain_finished.connect(_on_chain_finished)
	events.mutation_started.connect(func(d: Dictionary) -> void:
		stats_add("mutations", 1)
		progression.record("mutation:" + str(d["id"]), str(d["title"]), str(d["zh"])))
	events.deviation_tier_changed.connect(func(t: int, up: bool) -> void:
		if up and t == 4:
			progression.record_disaster("CATASTROPHIC"))
	events.mission_completed.connect(_on_mission_completed)
	events.mission_failed.connect(_on_mission_failed)
	events.player_damaged.connect(_on_player_damaged)
	events.codex_unlocked.connect(func(t: String) -> void:
		if not run_codex_new.has(t):
			run_codex_new.append(t))


# ---------------------------------------------------------------- helpers
func is_playing() -> bool:
	return state == State.PLAYING and not paused


func stats_add(key: String, n: int) -> void:
	if state != State.PLAYING:
		return
	stats[key] = int(stats.get(key, 0)) + n


func on_prop_spawned(p: Prop) -> void:
	rules.apply_to_prop(p)
	anomalies.on_prop_spawned(p)


func set_sensitivity(v: float) -> void:
	progression.data["settings"]["sensitivity"] = v
	if player:
		player.look_sens = 0.0024 * v


func set_volume(v: float) -> void:
	progression.data["settings"]["volume"] = v
	audio.set_volume(v)


func _set_mouse(captured: bool) -> void:
	if test_mode:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------------- flow
func goto_menu() -> void:
	state = State.MENU
	paused = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	player.input_enabled = false
	ui.set_hud_visible(false)
	ui.screens.show_menu()
	audio.stop_ambience()
	_set_mouse(false)


func _reset_world() -> void:
	Engine.time_scale = 1.0
	missions.clear()
	mutations.reset()
	env_fx.reset()
	anomalies.reset()
	_build_room()
	rules.reset()
	deviation.reset()
	chains.reset_shift()
	fx.reset()
	combos.reset_shift()
	incidents.reset_shift()
	clauses.clear()
	player.respawn()
	player.pulse_power = 1.6 if progression.has_unlock("overcharged_pulse") else 1.0
	ui.hud.clear_feed()


func start_run() -> void:
	get_tree().paused = false
	paused = false
	_reset_world()
	misruled = false
	stage = 0
	run_shifts.clear()
	run_stats.clear()
	run_codex_new.clear()
	combos.reset_run()
	incidents.reset_run()
	run_totals = {"throws": 0, "pulses": 0, "grabs": 0, "breaks": 0, "rule_changes": 0, "rules_used": {}, "best_chain": 0, "mutations": 0, "cata_time": 0.0, "completed": 0, "indirect": 0, "efficiency": 0.0, "chaos": 0.0}
	progression.data["runs_started"] = int(progression.data["runs_started"]) + 1
	audio.play_ui("click", -4.0)
	next_stage()


func next_stage() -> void:
	stage += 1
	state = State.CARDS
	player.input_enabled = false
	ui.set_hud_visible(false)
	_cards = anomalies.draw(3, progression.unlocks())
	if _cards.is_empty():
		begin_shift()
		return
	ui.screens.show_cards(stage, _cards)
	audio.play_ui("card", -2.0)
	_set_mouse(false)


func pick_card(d: AnomalyDef) -> void:
	if state != State.CARDS:
		return
	get_tree().paused = false
	audio.play_ui("card", 0.0)
	var applied := anomalies.play(d, progression.unlocks())
	for a in applied:
		progression.record("anomaly:" + a.id, a.title, a.desc)
	if d.effects.has("double"):
		var names: Array[String] = []
		for a in applied:
			names.append(a.title)
		events.notify.emit("DOUBLE ANOMALY → " + " + ".join(names), Color.WHITE, true)
	begin_shift()


func begin_shift() -> void:
	state = State.PLAYING
	paused = false
	get_tree().paused = false
	stats = {"throws": 0, "pulses": 0, "grabs": 0, "breaks": 0, "rule_changes": 0, "rules_used": {}, "devices_used": {},
		"chains": 0, "chain_links": 0, "best_chain": 0, "best_chain_text": "", "mutations": 0, "peak_deviation": 0.0}
	deviation.peak = deviation.value
	deviation.time_in_tier = [0, 0, 0, 0, 0]
	chains.reset_shift()
	mutations.count_this_shift = 0
	if stage > 1:
		room.restock()
	observer.begin_shift()
	combos.reset_shift()
	incidents.reset_shift()
	missions.start_shift(stage)
	clauses.assign(missions.primary, stage)
	_room_remembers()
	ui.screens.hide_all()
	ui.set_hud_visible(true)
	player.input_enabled = true
	_set_mouse(true)
	audio.start_ambience()
	_end_pending = -1.0
	events.notify.emit("SHIFT %d：%s" % [stage, missions.primary.text], UiKit.GREEN, true)


## The room remembers: the TV replays an old incident at the start of a run,
## and this run's previous shift afterwards.
func _room_remembers() -> void:
	var tv = room.devices.get("tv")
	if tv == null or not is_instance_valid(tv):
		return
	var text := ""
	if stage == 1:
		var li: Dictionary = progression.data.get("last_incident", {})
		if not li.is_empty():
			text = "重播 INCIDENT #%05d\n%s" % [int(li["number"]), str(li.get("case_zh", li.get("case", "")))]
	elif run_stats.size() > 0:
		var prev: Dictionary = run_stats[run_stats.size() - 1]
		var bc := str(prev.get("best_chain_text", ""))
		if bc != "":
			text = "上一班次：\n" + (bc if bc.length() <= 40 else bc.substr(0, 38) + "…")
	if text != "":
		(tv as TvProp).show_message(text, 16.0)


func _on_mission_completed(m: RefCounted) -> void:
	if state != State.PLAYING:
		return
	if m == missions.primary:
		audio.play_ui("success", 0.0)
		events.notify.emit("任務完成！", UiKit.GREEN, true)
		if m.get("type") == "NO_TOUCH" or not bool(m.get("target_grabbed")):
			if m.get("target") != null and progression.record_disaster("HANDS_FREE"):
				pass
		_end_success = true
		_end_pending = 1.6
		player.input_enabled = false
	else:
		audio.play_ui("combo", 0.0)
		events.notify.emit("加分任務完成！", UiKit.ACCENT, true)


func _on_mission_failed(m: RefCounted) -> void:
	if state != State.PLAYING:
		return
	if m == missions.primary:
		audio.play_ui("fail", 0.0)
		events.notify.emit("時間到。", UiKit.RED, true)
		stats["fail_reason"] = "時間到了，主要任務沒有完成。"
		_end_success = false
		_end_pending = 1.6
		player.input_enabled = false


func _on_player_damaged(_amount: float) -> void:
	if state == State.PLAYING and player.health <= 0.0 and _end_pending < 0.0:
		misruled = true
		progression.record_disaster("MISRULED")
		audio.play_ui("fail", 0.0)
		events.notify.emit("你被自己製造的混亂擊倒了。", UiKit.RED, true)
		stats["fail_reason"] = "穩定度歸零。"
		_end_success = false
		_end_pending = 1.6
		player.input_enabled = false


func _on_rule_changed(rule: int, level: int, by_player: bool) -> void:
	if not by_player or state != State.PLAYING:
		return
	stats_add("rule_changes", 1)
	var rc: Dictionary = stats.get("rule_counts", {})
	rc[rule] = int(rc.get(rule, 0)) + 1
	stats["rule_counts"] = rc
	if level != 0:
		(stats["rules_used"] as Dictionary)[rule] = true


func _on_prop_broken(p: Node, _cid: int) -> void:
	var pr := p as Prop
	room.on_prop_broken(pr)
	if pr.is_debris or pr.kind in ["paper", "ceiling"]:
		return
	stats_add("breaks", 1)
	if state == State.PLAYING:
		var bk: Dictionary = stats.get("broken_kinds", {})
		bk[pr.kind] = int(bk.get(pr.kind, 0)) + 1
		stats["broken_kinds"] = bk
		progression.data["total_breaks"] = int(progression.data["total_breaks"]) + 1


func _on_chain_finished(ch: Dictionary) -> void:
	if state != State.PLAYING:
		return
	var links := int(ch["links"])
	stats_add("chains", 1)
	stats_add("chain_links", links)
	stats["best_depth"] = maxi(int(stats.get("best_depth", 0)), int(ch.get("depth", 0)) + int(ch.get("devices", 0)))
	if links > int(stats["best_chain"]):
		stats["best_chain"] = links
		stats["best_chain_text"] = ChainTracker.describe(ch)
	progression.record_chain(ch)
	if links >= 3:
		audio.play_ui("combo", -6.0, 0.8 + minf(links, 10) * 0.05)


func _end_shift() -> void:
	state = State.SHIFT_END
	player.release(false)
	player.input_enabled = false
	ui.rules_menu.visible = false
	var p := missions.primary
	var s := missions.secondary
	stats["primary_done"] = p != null and p.state == "done"
	stats["secondary_done"] = s != null and s.state == "done"
	stats["time_limit"] = MissionManager.TIME_LIMIT
	stats["time_used"] = p.completed_at if p and p.state == "done" else MissionManager.TIME_LIMIT
	stats["target_grabbed"] = p.target_grabbed if p else true
	stats["peak_deviation"] = deviation.peak
	stats["combos"] = anomalies.combos_found.size() + combos.activated_this_shift.size()
	stats["combo_names"] = combos.activated_this_shift.duplicate()
	incidents.end_shift()
	stats["incidents"] = incidents.results.duplicate()
	var cl := clauses.finalize(bool(stats["primary_done"]))
	stats["clauses"] = cl
	var dims := ScoringManager.score_shift(stats)
	if bool(stats["primary_done"]) and bool(stats["secondary_done"]):
		progression.record_disaster("PERFECT_SHIFT")
	if int(stats["breaks"]) >= 10:
		progression.record_disaster("DEMOLITION")
	var all_glass := room.glass.size() > 0
	for g in room.glass:
		if not g.broken:
			all_glass = false
	if all_glass:
		progression.record_disaster("GLASS_HOUSE")
	run_stats.append(stats.duplicate(true))
	run_shifts.append({"done": stats["primary_done"], "points": dims["points"], "efficiency": dims["efficiency"], "creativity": dims["creativity"], "chaos": dims["chaos"], "completion": dims["completion"]})
	var t := run_totals
	for k in ["throws", "pulses", "grabs", "breaks", "rule_changes", "mutations"]:
		t[k] = int(t[k]) + int(stats.get(k, 0))
	for r in (stats["rules_used"] as Dictionary):
		(t["rules_used"] as Dictionary)[r] = true
	t["best_chain"] = maxi(int(t["best_chain"]), int(stats["best_chain"]))
	t["cata_time"] = float(t["cata_time"]) + deviation.time_in_tier[4]
	t["efficiency"] = float(t["efficiency"]) + float(dims["efficiency"])
	t["chaos"] = float(t["chaos"]) + float(dims["chaos"])
	if bool(stats["primary_done"]):
		t["completed"] = int(t["completed"]) + 1
		if not bool(stats["target_grabbed"]):
			t["indirect"] = int(t["indirect"]) + 1
	Engine.time_scale = 1.0
	_set_mouse(false)
	ui.set_hud_visible(false)
	ui.screens.show_shift_result(stage, stats, dims, stage >= SHIFTS or misruled)
	progression.save()


func continue_after_shift() -> void:
	if state != State.SHIFT_END:
		return
	if stage >= SHIFTS or misruled:
		finish_run()
	else:
		missions.clear()
		next_stage()


func finish_run() -> void:
	state = State.RESULTS
	Engine.time_scale = 1.0
	missions.clear()
	var points := 0
	for s in run_shifts:
		points += int(s["points"])
	var avg := float(points) / maxf(1.0, float(SHIFTS))
	var grade := ScoringManager.grade(avg)
	var t := run_totals.duplicate()
	t["rules_used"] = (run_totals["rules_used"] as Dictionary).size()
	var pers := ScoringManager.personality(t)
	var d := progression.data
	if not misruled:
		d["runs_completed"] = int(d["runs_completed"]) + 1
	if points > int(d["best_points"]):
		d["best_points"] = points
		d["best_grade"] = grade
	var pc: Dictionary = d["personalities"]
	pc[pers["title"]] = int(pc.get(pers["title"], 0)) + 1
	d["last_personality"] = pers["title"]
	var unl := progression.evaluate_unlocks()
	last_report = IncidentReport.build(self, points, grade, pers)
	d["incident_counter"] = int(last_report["number"])
	d["last_incident"] = {"number": last_report["number"], "case": last_report["case"], "case_zh": last_report["case_zh"], "summary": last_report["summary"]}
	var ok := progression.save()
	if not ok:
		events.notify.emit("存檔失敗：%s" % progression.saver.last_error, UiKit.RED, true)
	ui.screens.show_run_result({"points": points, "grade": grade, "personality": pers, "shifts": run_shifts, "unlocks": unl, "codex": run_codex_new, "misruled": misruled, "report": last_report})
	_set_mouse(false)


func restart_run() -> void:
	start_run()


func quit_to_menu() -> void:
	progression.save()
	_reset_world()
	goto_menu()


func quit_game() -> void:
	progression.save()
	get_tree().quit()


func toggle_pause() -> void:
	if state != State.PLAYING:
		return
	paused = not paused
	get_tree().paused = paused
	if paused:
		ui.rules_menu.visible = false
		ui.screens.show_pause()
		_set_mouse(false)
	else:
		ui.screens.hide_all()
		_set_mouse(true)


# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	if not get_tree().paused:
		GameClock.advance(delta / maxf(Engine.time_scale, 0.05))
	if state == State.PLAYING and not paused:
		var real_dt := delta / maxf(Engine.time_scale, 0.05)
		if _end_pending >= 0.0:
			_end_pending -= real_dt
			Engine.time_scale = 0.4 if _end_success else 0.6
			if _end_pending < 0.0:
				Engine.time_scale = 1.0
				call_deferred("_end_shift")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if state == State.CARDS:
		for i in 3:
			if event.is_action_pressed("rule_%d" % (i + 1)) and i < _cards.size():
				pick_card(_cards[i])
				return
		return
	if state != State.PLAYING:
		return
	if event.is_action_pressed("pause"):
		if ui.rules_menu.visible:
			ui.rules_menu.visible = false
			_set_mouse(true)
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if paused or _end_pending >= 0.0:
		return
	if event.is_action_pressed("rules_menu"):
		if ui.rules_menu.visible:
			ui.rules_menu.visible = false
			_set_mouse(true)
		else:
			ui.rules_menu.open()
			_set_mouse(false)
		return
	for r in RuleDefs.COUNT:
		if event.is_action_pressed("rule_%d" % (r + 1)):
			_cycle_rule(r)
			return
	if event is InputEventMouseButton and event.is_pressed() and not ui.rules_menu.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_set_mouse(true)


func _cycle_rule(r: int) -> void:
	var n := RuleDefs.level_count(r)
	var lvl := rules.levels[r]
	for i in n:
		lvl = (lvl + 1) % n
		if not RuleDefs.is_locked(r, lvl, progression.unlocks()):
			break
	var res := rules.request(r, lvl)
	if res == "ok":
		events.notify.emit("%s → %s" % [RuleDefs.NAMES_ZH[r], RuleDefs.level_name_zh(r, lvl)], RuleDefs.COLORS[r], false)
	if ui.rules_menu.visible:
		ui.rules_menu.refresh()

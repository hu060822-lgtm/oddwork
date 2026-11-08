extends SceneTree
## Integration tests. Run:
##   godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
## Boots the real main scene and drives every core system through it.

const SAVE := "user://test_save.json"

var main: Node
var passed: int = 0
var failed: int = 0
var _log: Array[String] = []


func _initialize() -> void:
	_run()


func check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  PASS  ", name)
	else:
		failed += 1
		print("  FAIL  ", name, "  ", detail)
		_log.append(name)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func secs(s: float) -> void:
	await frames(int(s * 60.0))


func _fresh_main() -> void:
	if main:
		main.queue_free()
		await process_frame
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.set_meta("test_mode", true)
	main.set_meta("save_path", SAVE)
	root.add_child(main)
	await frames(5)


func _untag_all() -> void:
	for p in main.room.live_props(true):
		(p as Prop).chain_id = -1


## Missions only tick while a primary mission exists; give tests a harmless one.
func _dummy_primary() -> void:
	var d := MissionManager.Mission.new()
	d.type = "SURVIVE"
	d.seconds = 999.0
	d.text = "dummy"
	main.missions.primary = d
	main.missions.time_left = 999.0


func _pick_card_by_id(id: String) -> void:
	var d: AnomalyDef = main.anomalies.get_def(id)
	main.pick_card(d)
	await frames(3)


func _run() -> void:
	print("MISRULE integration tests")
	await _fresh_main()
	await t_boot()
	await t_data()
	await t_mission_generation()
	await t_rules()
	await t_magnetism()
	await t_deviation_antifarm()
	await t_chain_tracker()
	await t_real_chain_physics()
	await t_button_chain_mission()
	await t_delivery_mission()
	await t_float_mission()
	await t_mutation()
	await t_observer()
	await t_full_run_and_save()
	await t_save_corruption()
	await t_soak_and_perf()
	print("")
	print("RESULT: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		print("FAILED: ", ", ".join(_log))
	Engine.time_scale = 1.0
	quit(1 if failed > 0 else 0)


# ------------------------------------------------------------------ tests
func t_boot() -> void:
	print("[boot]")
	check(main.state == main.State.MENU, "starts at main menu")
	var props: Array = main.room.live_props()
	check(props.size() >= 40, "room spawns props", str(props.size()))
	var kinds := {}
	for p in props:
		kinds[(p as Prop).kind] = true
	for k in ["cup", "chair", "table", "apple", "ball", "box", "barrel", "fan", "battery", "printer", "plate", "tv", "lamp"]:
		check(kinds.has(k), "has prop kind " + k)
	check(main.room.spring != null and main.room.tripwire != null, "spring + wire fixtures exist")
	check(main.room.glass.size() == 2, "glass panes exist")
	check(main.room.buttons["A"].linked == main.room.devices["fan"], "button A wired to fan")
	check(main.audio.streams.size() > 50, "audio synthesised", str(main.audio.streams.size()))
	await frames(30)
	var moving := 0
	for p in main.room.live_props():
		if (p as Prop).linear_velocity.length() > 0.5:
			moving += 1
	check(moving <= 3, "room settles at rest (no jitter explosion)", "%d moving" % moving)


func t_data() -> void:
	print("[data]")
	var ids := {}
	for d in AnomalyData.all():
		check(not ids.has(d.id), "unique anomaly id " + d.id)
		ids[d.id] = true
		for r: int in d.rules:
			check(int(d.rules[r]) < RuleDefs.level_count(r), "anomaly %s rule level valid" % d.id)
	check(ids.size() == 12, "12 anomaly cards", str(ids.size()))
	for c in AnomalyData.combos():
		check(ids.has(c["a"]) and ids.has(c["b"]), "combo %s references real cards" % c["name"])
	var unlocks: Dictionary = main.progression.unlocks()
	var draw: Array[AnomalyDef] = main.anomalies.draw(3, unlocks)
	check(draw.size() == 3, "draws three cards on a fresh save")
	for d in draw:
		check(d.unlock_key == "", "fresh save only draws unlocked cards (%s)" % d.id)
	check(MutationData.all().size() == 10, "10 mutations")


func t_mission_generation() -> void:
	print("[mission generation]")
	main.start_run()
	await frames(2)
	await _pick_card_by_id("RUBBER_WORLD")
	var mm: MissionManager = main.missions
	var bad := 0
	var types := {}
	var reasons := {}
	for stage in [1, 2, 3]:
		for i in 60:
			var m: MissionManager.Mission = mm.generate(stage, true, null)
			var s: MissionManager.Mission = mm.generate(maxi(1, stage - 1), false, m)
			types[m.type] = true
			var why := mm.validate(m, null)
			var why2 := mm.validate(s, m)
			if why != "" or why2 != "":
				bad += 1
				reasons[why + "|" + why2] = true
			if m.text == "" or s.text == "":
				bad += 1
	check(bad == 0, "180 generated mission pairs are valid", str(reasons.keys()))
	check(types.size() >= 6, "mission variety", str(types.keys()))
	main.missions.clear()


func t_rules() -> void:
	print("[rules]")
	var rules: PhysicsRuleManager = main.rules
	var balls: Array = main.room.props_of("ball")
	var apples: Array = main.room.props_of("apple")
	var sample: Array = balls + apples
	var y0 := 0.0
	for p in sample:
		y0 += (p as Prop).global_position.y
	rules.set_level(RuleDefs.GRAVITY, RuleDefs.GRAVITY_ANTI, true)
	await secs(2.5)
	var y1 := 0.0
	for p in sample:
		if is_instance_valid(p):
			y1 += (p as Prop).global_position.y
	check(y1 > y0 + sample.size() * 1.0, "anti-gravity lifts light props", "%.1f -> %.1f" % [y0, y1])
	rules.set_level(RuleDefs.GRAVITY, RuleDefs.GRAVITY_NORMAL, true)
	await secs(2.0)
	rules.set_level(RuleDefs.BOUNCE, RuleDefs.BOUNCE_EXTREME, true)
	var b: Prop = balls[0]
	check(is_equal_approx(b.pmat.bounce, 1.0), "extreme bounce sets restitution 1.0")
	rules.set_level(RuleDefs.BOUNCE, RuleDefs.BOUNCE_DEAD, true)
	check(b.pmat.bounce == 0.0 and b.pmat.absorbent, "dead bounce absorbs")
	rules.set_level(RuleDefs.BOUNCE, RuleDefs.BOUNCE_NORMAL, true)
	rules.set_level(RuleDefs.FRICTION, RuleDefs.FRICTION_SLICK, true)
	var tile: StaticBody3D = main.room.floor_tiles[0]
	check(tile.physics_material_override.friction == 0.0, "slick floor friction 0")
	check(float(tile.get_meta("friction")) == 0.0, "player sees slick floor")
	rules.set_level(RuleDefs.FRICTION, RuleDefs.FRICTION_PATCH, true)
	var kinds := {}
	for t in main.room.floor_tiles:
		kinds[float((t as StaticBody3D).get_meta("friction"))] = true
	check(kinds.size() >= 2, "patchwork floor mixes frictions", str(kinds.keys()))
	rules.set_level(RuleDefs.FRICTION, RuleDefs.FRICTION_NORMAL, true)
	rules.set_level(RuleDefs.TIME, RuleDefs.TIME_SLOW, true)
	await frames(2)
	check(is_equal_approx(Engine.time_scale, 0.35), "slow time sets time scale", str(Engine.time_scale))
	rules.set_level(RuleDefs.TIME, RuleDefs.TIME_UNSTABLE, true)
	var seen := {}
	for i in 40:
		await frames(6)
		seen[snappedf(Engine.time_scale, 0.1)] = true
	check(seen.size() >= 4, "unstable time varies", str(seen.keys()))
	rules.set_level(RuleDefs.TIME, RuleDefs.TIME_POCKETS, true)
	check(main.room.pockets[0].visible, "time pockets appear")
	rules.set_level(RuleDefs.TIME, RuleDefs.TIME_NORMAL, true)
	check(is_equal_approx(Engine.time_scale, 1.0), "normal time restores scale")
	check(not main.room.pockets[0].visible, "time pockets hide")


func t_magnetism() -> void:
	print("[magnetism]")
	var rules: PhysicsRuleManager = main.rules
	var a: Prop = main.room.spawn("barrel", Transform3D(Basis.IDENTITY, Vector3(-1.4, 0.0, 0.6)))
	var b: Prop = main.room.spawn("barrel", Transform3D(Basis.IDENTITY, Vector3(0.2, 0.0, 0.6)))
	await frames(10)
	var d0 := a.global_position.distance_to(b.global_position)
	rules.set_level(RuleDefs.MAGNETISM, RuleDefs.MAG_METAL, true)
	await secs(1.5)
	var d1 := a.global_position.distance_to(b.global_position)
	check(d1 < d0 - 0.4, "metal magnetism pulls barrels together", "%.2f -> %.2f" % [d0, d1])
	check(rules.magnet_lines.size() > 0, "magnet arcs drawn")
	rules.set_level(RuleDefs.MAGNETISM, RuleDefs.MAG_REPEL, true)
	await secs(1.5)
	var d2 := a.global_position.distance_to(b.global_position)
	check(d2 > d1 + 0.3, "repel pushes props apart", "%.2f -> %.2f" % [d1, d2])
	rules.set_level(RuleDefs.MAGNETISM, RuleDefs.MAG_OFF, true)
	a.queue_free()
	b.queue_free()
	await frames(2)


func t_deviation_antifarm() -> void:
	print("[deviation]")
	var dv: DeviationManager = main.deviation
	_untag_all()
	dv.value = 0.0
	dv.budget = 8.0
	var a: Prop = main.room.props_of("barrel")[0]
	var b: Prop = main.room.props_of("box")[0]
	for i in 200:
		main.events.prop_impact.emit(a, b, 9.0)
	check(dv.value < 3.0, "same pair spam is capped", "%.2f" % dv.value)
	var many: Array = main.room.live_props()
	_untag_all()
	dv.value = 0.0
	dv.budget = 8.0
	dv.chain_budget = 0.0
	dv.break_budget = 0.0
	for i in many.size():
		for j in 3:
			main.events.prop_impact.emit(many[i], many[(i + j + 1) % many.size()], 12.0)
	check(dv.value <= 8.5, "impact budget caps bursts", "%.2f" % dv.value)
	# Room-driven chaos alone stalls at the soft cap.
	var cap := dv.soft_cap()
	dv.value = minf(cap + 12.0, 99.0)
	dv.budget = 5.0
	dv.chain_budget = 0.0
	var before := dv.value
	for i in many.size():
		main.events.prop_impact.emit(many[i], many[(i + 5) % many.size()], 12.0)
	check(dv.value - before < 0.5, "passive chaos stalls above the soft cap", "cap %.1f  %.2f -> %.2f" % [cap, before, dv.value])
	check(DeviationManager.tier_of(15) == 0 and DeviationManager.tier_of(30) == 1 and DeviationManager.tier_of(55) == 2 and DeviationManager.tier_of(75) == 3 and DeviationManager.tier_of(95) == 4, "tier bands")
	dv.value = 50.0
	dv._last_gain_ms = GameClock.ms - 5000
	for i in 8:
		dv._process(0.5 * Engine.time_scale)
	check(dv.value < 50.0 and dv.value >= dv.floor_value(), "deviation decays toward floor", "%.1f (floor %.1f)" % [dv.value, dv.floor_value()])
	dv.value = 0.0
	dv.tier = 0
	main.mutations.reset()


func t_chain_tracker() -> void:
	print("[chain tracker]")
	var ct: ChainTracker = main.chains
	var got: Array = []
	var cb := func(ch: Dictionary) -> void: got.append(ch)
	main.events.chain_finished.connect(cb)
	var a: Prop = main.room.spawn("box", Transform3D(Basis.IDENTITY, Vector3(-5, 0, -1)))
	var b: Prop = main.room.spawn("box", Transform3D(Basis.IDENTITY, Vector3(-5, 0, 0)))
	var c: Prop = main.room.spawn("box", Transform3D(Basis.IDENTITY, Vector3(-5, 0, 1)))
	await frames(10)
	ct.start_chain("你丟出測試", [a])
	main.events.prop_impact.emit(a, b, 5.0)
	main.events.prop_impact.emit(a, b, 5.0)  # duplicate pair: ignored
	main.events.prop_impact.emit(b, c, 4.0)
	var live: Dictionary = ct.live_chain()
	check(int(live.get("links", 0)) == 2, "chain links A->B->C, duplicates ignored", str(live.get("links")))
	check(c.chain_depth == 2, "depth propagates")
	await secs(4.0)
	var mine: Dictionary = {}
	for ch in got:
		if (ch["steps"] as Array)[0] == "你丟出測試":
			mine = ch
	check(not mine.is_empty() and int(mine["links"]) == 2, "chain closes after idle and reports")
	check(ChainTracker.describe(mine).contains("→"), "chain text readable: " + ChainTracker.describe(mine))
	main.events.chain_finished.disconnect(cb)
	for x in [a, b, c]:
		x.queue_free()


func t_real_chain_physics() -> void:
	print("[physics chain]")
	# A real collision: launch a ball at a box and see the tracker follow it.
	var ball: Prop = main.room.spawn("ball", Transform3D(Basis.IDENTITY, Vector3(-0.8, 0.0, 4.2)))
	var box: Prop = main.room.spawn("box", Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 4.2)))
	await frames(20)
	main.mutations.reset()
	main.mutations._cooldown = 999.0
	main.chains.start_chain("你丟出球", [ball])
	ball.linear_velocity = Vector3(10, 0.5, 0)
	await secs(1.0)
	print("    ball ", ball.global_position, " box ", box.global_position)
	check(box.chain_id == ball.chain_id and box.chain_depth == 1, "physical impact passes the chain", "box chain %d ball chain %d" % [box.chain_id, ball.chain_id])
	ball.queue_free()
	box.queue_free()
	await frames(2)


func t_button_chain_mission() -> void:
	print("[button / chain mission]")
	var mm: MissionManager = main.missions
	var m := MissionManager.Mission.new()
	m.type = "CHAIN_ACTIVATE"
	m.device = main.room.buttons["A"]
	m.required = 2
	m.primary = false
	m.text = "test"
	mm.secondary = m
	var fan: FanProp = main.room.devices["fan"]
	fan.set_on(false)
	var a: Prop = main.room.spawn("apple", Transform3D(Basis.IDENTITY, Vector3(-6, 0.1, 2)))
	var b: Prop = main.room.spawn("apple", Transform3D(Basis.IDENTITY, Vector3(-6, 0.1, 2.5)))
	var c: Prop = main.room.spawn("ball", Transform3D(Basis.IDENTITY, Vector3(-6, 0.1, 3)))
	await frames(5)
	main.chains.start_chain("你的衝擊波", [a])
	main.events.prop_impact.emit(a, b, 5.0)
	main.events.prop_impact.emit(b, c, 5.0)
	m.device.press(c, false)
	await frames(2)
	check(fan.on, "button press by chained prop turns the fan on")
	check(m.state == "done", "chain-activate mission completes with 2+ links", m.state)
	# Earlier chaos may have knocked the fan over; stand it up somewhere clear.
	fan.global_transform = Transform3D(Basis.IDENTITY, Vector3(-3.0, 0.05, -2.0))
	fan.linear_velocity = Vector3.ZERO
	fan.angular_velocity = Vector3.ZERO
	await frames(10)
	var start := fan.global_position + fan.global_basis.z * 2.0 + Vector3(0, 0.3, 0)
	var box: Prop = main.room.spawn("box", Transform3D(Basis.IDENTITY, start))
	await secs(0.6)
	var push := (box.global_position - start).dot(fan.global_basis.z)
	print("    fan ", fan.global_position, " dir ", fan.global_basis.z, " start ", start, " box ", box.global_position, " on ", fan.on)
	check(push > 0.3, "fan wind pushes props", "%.2f" % push)
	box.queue_free()
	fan.set_on(false)
	mm.secondary = null


func t_delivery_mission() -> void:
	print("[delivery mission]")
	var mm: MissionManager = main.missions
	mm.clear()
	_dummy_primary()
	var m := MissionManager.Mission.new()
	m.type = "DELIVER"
	m.primary = false
	m.target = main.room.props_of("box")[0]
	m.target_kind = "box"
	m.zone_name = "center"
	m.text = "test"
	mm.secondary = m
	mm._present(m)
	m.target.global_position = m.zone.global_position
	m.target.linear_velocity = Vector3.ZERO
	await secs(1.6)
	check(m.state == "done", "delivering target into zone completes", m.state)
	mm.clear()


func t_float_mission() -> void:
	print("[float mission]")
	var mm: MissionManager = main.missions
	_dummy_primary()
	var m := MissionManager.Mission.new()
	m.type = "FLOAT"
	m.primary = false
	m.required = 5
	m.seconds = 2.0
	m.text = "test"
	mm.secondary = m
	main.rules.set_level(RuleDefs.GRAVITY, RuleDefs.GRAVITY_ANTI, true)
	await secs(6.0)
	check(m.state == "done", "anti-gravity completes the float mission", "%s count %d" % [m.state, m.count])
	main.rules.set_level(RuleDefs.GRAVITY, RuleDefs.GRAVITY_NORMAL, true)
	await secs(3.0)
	mm.secondary = null


func t_mutation() -> void:
	print("[mutation]")
	var mu: MutationManager = main.mutations
	mu.reset()
	for r in RuleDefs.COUNT:
		main.rules.set_level(r, 0, false)
	var started: Array = []
	var cb := func(d: Dictionary) -> void: started.append(d["id"])
	main.events.mutation_started.connect(cb)
	mu._cooldown = 0.0
	main.deviation.tier = 1
	main.deviation.value = 45.0
	main.deviation._check_tier()
	check(mu.warning_text() != "", "tier rise warns before mutating")
	await secs(2.4)
	check(started.size() == 1, "mutation starts after warning", str(started))
	check(mu.active.size() == 1, "mutation is active", str(mu.active.size()))
	var dur := float((mu.active[0]["def"] as Dictionary)["dur"])
	await secs(dur + 0.6)
	check(mu.active.size() == 0, "mutation ends and reverts")
	for r in RuleDefs.COUNT:
		check(main.rules.levels[r] == 0, "rule %d restored after mutation" % r, str(main.rules.levels))
	main.events.mutation_started.disconnect(cb)
	main.deviation.value = 0.0
	main.deviation.tier = 0


func t_observer() -> void:
	print("[room observer]")
	var obs: RoomObserver = main.observer
	obs.mem["rule_counts"] = {"0": 12, "1": 2}
	obs.mem["fan_uses"] = 0
	obs.mem["carry_wins"] = 0
	obs.mem["throws"] = 0
	obs.mem["first_rule_streak"] = 0
	obs.begin_shift()
	check(main.rules.resisted_rule == RuleDefs.GRAVITY, "room resists the favourite rule")
	check(obs.reactions.size() >= 1, "reaction is announced", str(obs.reactions))
	var res: String = main.rules.request(RuleDefs.GRAVITY, RuleDefs.GRAVITY_LOW)
	check(res == "pending", "resisted change is delayed, not refused")
	await secs(2.8)
	check(main.rules.levels[RuleDefs.GRAVITY] == RuleDefs.GRAVITY_LOW, "delayed change applies")
	main.rules.set_level(RuleDefs.GRAVITY, 0, false)
	main.rules.resisted_rule = -1
	obs.mem["rule_counts"] = {}


func t_full_run_and_save() -> void:
	print("[full run]")
	main.start_run()
	await frames(2)
	check(main.state == main.State.CARDS, "run starts with card pick")
	for stage in [1, 2, 3]:
		var cards: Array = main._cards
		check(cards.size() == 3, "stage %d offers 3 cards" % stage)
		main.pick_card(cards[0])
		await frames(3)
		check(main.state == main.State.PLAYING and main.stage == stage, "stage %d playing" % stage)
		check(main.missions.primary != null and main.missions.primary.text != "", "stage %d has a mission: %s" % [stage, main.missions.primary.text if main.missions.primary else ""])
		main.player.pulse()
		main.rules.request(RuleDefs.BOUNCE, RuleDefs.BOUNCE_HIGH)
		await secs(1.0)
		main.missions.force_complete_primary()
		await secs(2.0)
		check(main.state == main.State.SHIFT_END, "stage %d ends on completion" % stage)
		main.continue_after_shift()
		await frames(3)
	check(main.state == main.State.RESULTS, "run ends with results")
	check(int(main.progression.data["runs_completed"]) == 1, "run counted")
	check((main.progression.unlocks() as Dictionary).has("runs_1"), "unlock after first run")
	check(FileAccess.file_exists(SAVE), "save file written")
	var sm := SaveManager.new(SAVE)
	var loaded := sm.load_data(ProgressionManager.defaults())
	check(int(loaded["runs_completed"]) == 1 and sm.last_error == "", "save reloads")
	check(str(loaded["last_personality"]).begins_with("THE "), "personality stored: " + str(loaded["last_personality"]))
	main.quit_to_menu()
	await frames(5)
	check(main.state == main.State.MENU and not paused, "back to menu, tree unpaused")
	# Health 0 ends the run as MISRULED.
	main.start_run()
	await frames(2)
	main.pick_card(main._cards[0])
	await frames(3)
	main.player.health = 0.0
	main.events.player_damaged.emit(10.0)
	await secs(2.0)
	check(main.state == main.State.SHIFT_END and main.misruled, "health 0 ends the shift (MISRULED)")
	main.continue_after_shift()
	await frames(3)
	check(main.state == main.State.RESULTS, "misruled run goes to results")
	main.quit_to_menu()
	await frames(5)


func t_save_corruption() -> void:
	print("[save safety]")
	var path := "user://corrupt_test.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var sm := SaveManager.new(path)
	var d := sm.load_data(ProgressionManager.defaults())
	check(d.has("unlocks") and sm.last_error != "", "corrupt save falls back to defaults")
	check(FileAccess.file_exists(path + ".corrupt"), "corrupt file kept aside")
	check(sm.save_data(d), "can save after corruption")
	var d2 := sm.load_data(ProgressionManager.defaults())
	check(sm.last_error == "" and d2.has("codex"), "re-load clean")
	var old := {"runs_completed": 4, "unlocks": {"runs_1": true}}
	var merged := SaveManager._merge(ProgressionManager.defaults(), old)
	check(int(merged["runs_completed"]) == 4 and merged.has("chains_hall") and (merged["unlocks"] as Dictionary).has("runs_1"), "old saves gain new keys")
	for s in ["", ".corrupt", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + s):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + s))


func t_soak_and_perf() -> void:
	print("[soak + performance]")
	main.start_run()
	await frames(2)
	main.pick_card(main.anomalies.get_def("STRONG_WIND"))
	await frames(3)
	for i in 30:
		main.room.spawn("ball", Transform3D(Basis.IDENTITY, Vector3(randf_range(-6, 6), 2.5, randf_range(-4, 4))))
	main.rules.set_level(RuleDefs.BOUNCE, RuleDefs.BOUNCE_EXTREME, true)
	main.rules.set_level(RuleDefs.MAGNETISM, RuleDefs.MAG_ATTRACT, true)
	main.rules.set_level(RuleDefs.GRAVITY, RuleDefs.GRAVITY_LOW, true)
	var t0 := Time.get_ticks_usec()
	var n := 0
	for k in 12:
		main.rules.request(randi() % 4, randi() % 3)
		main.player.pulse()
		main.player._pulse_cd = 0.0
		await frames(30)
		n += 30
	var per := float(Time.get_ticks_usec() - t0) / n / 1000.0
	var count: int = main.room.live_props(true).size()
	print("  info  %d props, %.2f ms per physics frame (headless, this machine)" % [count, per])
	check(per < 16.0, "frame budget under chaos", "%.2f ms" % per)
	check(main.room._debris.size() <= Room.MAX_DEBRIS, "debris capped")
	check(main.deviation.value > 5.0, "chaos raised deviation", "%.1f" % main.deviation.value)
	check(main.chains.total_links > 0, "chains happened during soak", str(main.chains.total_links))
	main.quit_to_menu()
	await frames(5)
	check(Engine.time_scale == 1.0, "time scale reset at menu")

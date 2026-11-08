class_name Hud
extends Control
## In-game heads-up display.

var ctx: Node
var dev_label: Label
var dev_fill: ColorRect
var dev_marks: Control
var rules_box: VBoxContainer
var rule_labels: Array[Label] = []
var anomaly_label: Label
var mutation_label: Label
var combo_label: Label
var incident_label: Label
var clause_label: Label
var warning_label: Label
var mission_box: VBoxContainer
var shift_label: Label
var timer_label: Label
var p_title: Label
var p_text: Label
var p_status: Label
var p_fill: ColorRect
var s_title: Label
var s_text: Label
var s_status: Label
var chain_live: Label
var chain_feed: VBoxContainer
var prompt: Label
var crosshair: Label
var health_fill: ColorRect
var health_root: Control
var toasts: VBoxContainer
var observer_box: VBoxContainer
var help_line: Label
var status_panel: PanelContainer
var status_text: Label
var _warn_t: float = 0.0

const DEV_W := 320.0


func setup(c: Node) -> void:
	ctx = c
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# --- top-left: deviation + rules
	var tl := UiKit.panel()
	tl.position = Vector2(16, 16)
	add_child(tl)
	var v := UiKit.vbox(4)
	tl.add_child(v)
	dev_label = UiKit.label("DEVIATION 0 · 正常", 18, UiKit.TEXT)
	v.add_child(dev_label)
	var b := UiKit.bar(DEV_W, 14, DeviationManager.TIER_COLORS[0])
	dev_fill = b[1]
	v.add_child(b[0])
	for i in range(1, 5):
		var tick := ColorRect.new()
		tick.color = Color(1, 1, 1, 0.35)
		tick.size = Vector2(2, 14)
		tick.position = Vector2(DEV_W * i * 0.2, 0)
		(b[0] as Control).add_child(tick)
	rules_box = UiKit.vbox(0)
	v.add_child(rules_box)
	for r in RuleDefs.COUNT:
		var l := UiKit.label("", 16)
		rules_box.add_child(l)
		rule_labels.append(l)
	anomaly_label = UiKit.wrap_label("", 15, UiKit.DIM, DEV_W)
	v.add_child(anomaly_label)
	mutation_label = UiKit.wrap_label("", 16, Color(1, 0.5, 0.45), DEV_W)
	v.add_child(mutation_label)
	combo_label = UiKit.wrap_label("", 16, Color(0.6, 0.85, 1.0), DEV_W)
	v.add_child(combo_label)
	# --- top-center: mutation warning
	warning_label = UiKit.label("", 30, Color(1, 0.3, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.anchor(warning_label, Vector2(0.5, 0), Vector2(-300, 90))
	warning_label.custom_minimum_size = Vector2(600, 40)
	add_child(warning_label)
	incident_label = UiKit.label("", 22, Color(0.95, 0.85, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.anchor(incident_label, Vector2(0.5, 0), Vector2(-300, 56))
	incident_label.custom_minimum_size = Vector2(600, 30)
	add_child(incident_label)
	# --- top-right: mission panel
	var tr := UiKit.panel()
	UiKit.anchor(tr, Vector2(1, 0), Vector2(-436, 16))
	tr.custom_minimum_size = Vector2(420, 0)
	add_child(tr)
	mission_box = UiKit.vbox(3)
	tr.add_child(mission_box)
	var top := UiKit.hbox(8)
	mission_box.add_child(top)
	shift_label = UiKit.label("SHIFT 1/3", 16, UiKit.ACCENT)
	shift_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(shift_label)
	timer_label = UiKit.label("2:30", 22, UiKit.TEXT)
	top.add_child(timer_label)
	p_title = UiKit.label("", 15, UiKit.GREEN)
	mission_box.add_child(p_title)
	p_text = UiKit.wrap_label("", 19, UiKit.TEXT, 396)
	mission_box.add_child(p_text)
	p_status = UiKit.label("", 15, UiKit.DIM)
	mission_box.add_child(p_status)
	var pb := UiKit.bar(396, 6, UiKit.GREEN)
	p_fill = pb[1]
	mission_box.add_child(pb[0])
	clause_label = UiKit.wrap_label("", 14, Color(0.85, 0.8, 0.65), 396)
	mission_box.add_child(clause_label)
	s_title = UiKit.label("", 14, UiKit.ACCENT)
	mission_box.add_child(s_title)
	s_text = UiKit.wrap_label("", 16, UiKit.DIM, 396)
	mission_box.add_child(s_text)
	s_status = UiKit.label("", 14, UiKit.DIM)
	mission_box.add_child(s_status)
	# --- right-middle: chain feed
	chain_live = UiKit.wrap_label("", 18, UiKit.ACCENT, 520)
	UiKit.anchor(chain_live, Vector2(1, 0.5), Vector2(-540, -40))
	chain_live.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(chain_live)
	chain_feed = UiKit.vbox(2)
	UiKit.anchor(chain_feed, Vector2(1, 0.5), Vector2(-540, 20))
	chain_feed.custom_minimum_size = Vector2(520, 0)
	add_child(chain_feed)
	# --- centre: crosshair + prompt
	crosshair = UiKit.label("·", 34, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.anchor(crosshair, Vector2(0.5, 0.5), Vector2(-20, -26))
	crosshair.custom_minimum_size = Vector2(40, 40)
	add_child(crosshair)
	prompt = UiKit.label("", 18, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.anchor(prompt, Vector2(0.5, 0.5), Vector2(-400, 40))
	prompt.custom_minimum_size = Vector2(800, 30)
	add_child(prompt)
	# --- centre-top: toasts
	toasts = UiKit.vbox(4)
	UiKit.anchor(toasts, Vector2(0.5, 0), Vector2(-380, 140))
	toasts.custom_minimum_size = Vector2(760, 0)
	add_child(toasts)
	# --- bottom-left: health
	var bl := UiKit.vbox(2)
	UiKit.anchor(bl, Vector2(0, 1), Vector2(18, -64))
	add_child(bl)
	bl.add_child(UiKit.label("穩定度", 14, UiKit.DIM))
	var hb := UiKit.bar(220, 10, Color(0.85, 0.85, 0.75))
	health_root = hb[0]
	health_fill = hb[1]
	bl.add_child(health_root)
	# --- bottom-centre: observer + help
	observer_box = UiKit.vbox(2)
	UiKit.anchor(observer_box, Vector2(0.5, 1), Vector2(-420, -150))
	observer_box.custom_minimum_size = Vector2(840, 0)
	add_child(observer_box)
	help_line = UiKit.label("WASD 移動 · 空白 跳 · 左鍵 抓/丟 · 右鍵 衝擊波 · E 互動 · Q 規則選單 · 1-5 快速切換規則 · Tab 狀態 · Esc 暫停", 14, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.anchor(help_line, Vector2(0.5, 1), Vector2(-600, -28))
	help_line.custom_minimum_size = Vector2(1200, 20)
	add_child(help_line)
	# --- Tab status panel
	status_panel = UiKit.panel(UiKit.BG_SOLID, UiKit.ACCENT)
	status_panel.custom_minimum_size = Vector2(760, 0)
	status_text = UiKit.wrap_label("", 17, UiKit.TEXT, 730)
	status_panel.add_child(status_text)
	var cc := UiKit.center_wrap(status_panel)
	add_child(cc)
	status_panel.visible = false
	ctx.events.notify.connect(toast)
	ctx.events.chain_finished.connect(_on_chain_finished)
	ctx.events.observer_spoke.connect(_on_observer)
	ctx.events.mutation_warning.connect(func(_d: Dictionary) -> void: _warn_t = 2.0)
	ctx.events.mutation_started.connect(func(d: Dictionary) -> void: toast("世界突變：%s" % str(d["zh"]), Color(1, 0.45, 0.35), true))
	ctx.events.deviation_tier_changed.connect(_on_tier)
	ctx.events.codex_unlocked.connect(func(t: String) -> void: toast("圖鑑新增：%s" % t, Color(0.7, 0.9, 1.0), false))


func clear_feed() -> void:
	UiKit.clear(chain_feed)
	UiKit.clear(toasts)
	UiKit.clear(observer_box)


func toast(text: String, color: Color = UiKit.TEXT, big: bool = false) -> void:
	var l := UiKit.label(text, 26 if big else 19, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size.x = 760
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toasts.add_child(l)
	while toasts.get_child_count() > 4:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	l.set_meta("life", 4.5 if big else 3.2)


func _on_chain_finished(ch: Dictionary) -> void:
	var links := int(ch["links"])
	var col := UiKit.ACCENT if links < 5 else Color(1.0, 0.5, 0.2)
	var l := UiKit.wrap_label("連鎖 ×%d   %s" % [links, ChainTracker.describe(ch)], 15, col, 520)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.set_meta("life", 7.0)
	chain_feed.add_child(l)
	while chain_feed.get_child_count() > 4:
		var old := chain_feed.get_child(0)
		chain_feed.remove_child(old)
		old.queue_free()
	if links >= 4:
		toast("連鎖反應 ×%d！" % links, col, true)


func _on_observer(text: String) -> void:
	var l := UiKit.wrap_label("◉ 房間：%s" % text, 19, Color(1.0, 0.35, 0.3), 840)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_meta("life", 9.0)
	observer_box.add_child(l)


func _on_tier(tier: int, up: bool) -> void:
	if up:
		toast("DEVIATION：%s" % DeviationManager.TIER_ZH[tier], DeviationManager.TIER_COLORS[tier], tier >= 3)
		ctx.audio.play_ui("tier_up", -6.0 + tier)
	else:
		ctx.audio.play_ui("tier_down", -10.0)


func _fade_children(box: Node, dt: float) -> void:
	for c in box.get_children():
		if not c.has_meta("life"):
			continue
		var life := float(c.get_meta("life")) - dt
		c.set_meta("life", life)
		(c as CanvasItem).modulate.a = clampf(life, 0.0, 1.0)
		if life <= 0.0:
			c.queue_free()


func _process(delta: float) -> void:
	if ctx == null or not visible:
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	_fade_children(toasts, real_dt)
	_fade_children(chain_feed, real_dt)
	_fade_children(observer_box, real_dt)
	var dv: DeviationManager = ctx.deviation
	var t := dv.tier
	dev_label.text = "DEVIATION %d · %s" % [int(dv.value), DeviationManager.TIER_ZH[t]]
	dev_label.add_theme_color_override("font_color", DeviationManager.TIER_COLORS[t])
	dev_fill.size.x = DEV_W * dv.value / 100.0
	dev_fill.color = DeviationManager.TIER_COLORS[t]
	var rules: PhysicsRuleManager = ctx.rules
	for r in RuleDefs.COUNT:
		var lvl := rules.levels[r]
		var extra := ""
		for p in rules.pending:
			if int(p[0]) == r:
				extra = "  ← 抵抗中 %.1f" % float(p[2])
		if r == rules.resisted_rule and extra == "":
			extra = "  ◉"
		if r == RuleDefs.MAGNETISM and lvl != 0:
			extra += "  強度%s" % ["弱", "中", "強"][rules.magnet_strength]
		rule_labels[r].text = "%d %s  %s%s" % [r + 1, RuleDefs.NAMES_ZH[r], RuleDefs.level_name_zh(r, lvl), extra]
		rule_labels[r].add_theme_color_override("font_color", RuleDefs.COLORS[r] if lvl != 0 else UiKit.DIM)
	var an: Array[String] = []
	for d in ctx.anomalies.active:
		an.append((d as AnomalyDef).title)
	anomaly_label.text = ("異常：" + ", ".join(an)) if an.size() > 0 else ""
	var mt: Array[String] = ctx.mutations.active_text()
	mutation_label.text = ("突變中：" + "；".join(mt)) if mt.size() > 0 else ""
	var cn: Array[String] = ctx.combos.active_names()
	var bh: float = ctx.combos.black_hole_progress()
	combo_label.text = ("組合：" + "、".join(cn) + ("  黑洞 %d%%" % int(bh * 100.0) if bh > 0.0 else "")) if cn.size() > 0 else ""
	incident_label.text = ctx.incidents.status_text()
	var wt: String = ctx.mutations.warning_text()
	warning_label.text = wt
	warning_label.visible = wt != "" and fmod(GameClock.ms / 1000.0, 0.4) < 0.28
	_update_mission()
	var live: Dictionary = ctx.chains.live_chain()
	chain_live.text = ("連鎖中 ×%d   %s" % [int(live["links"]), ChainTracker.describe(live)]) if not live.is_empty() else ""
	var pl: PlayerController = ctx.player
	prompt.text = pl.prompt_text()
	crosshair.add_theme_color_override("font_color", UiKit.ACCENT if pl.focus != null else Color(1, 1, 1, 0.7))
	health_fill.size.x = 220.0 * pl.health / 100.0
	health_fill.color = Color(0.85, 0.85, 0.75) if pl.health > 40 else UiKit.RED
	status_panel.visible = Input.is_action_pressed("status") and ctx.is_playing()
	if status_panel.visible:
		status_text.text = _status_text()


func _update_mission() -> void:
	var mm: MissionManager = ctx.missions
	shift_label.text = "SHIFT %d / %d" % [ctx.stage, ctx.SHIFTS]
	var tl := maxf(0.0, mm.time_left)
	timer_label.text = "%d:%02d" % [int(tl) / 60, int(tl) % 60]
	timer_label.add_theme_color_override("font_color", UiKit.RED if tl < 20.0 else UiKit.TEXT)
	var p = mm.primary
	if p:
		p_title.text = "主要任務 · %s%s" % [p.title, "  ✓" if p.state == "done" else ""]
		p_text.text = p.text
		p_status.text = p.status_line()
		p_fill.size.x = 396.0 * clampf(p.progress(), 0.0, 1.0)
	var cls: Array[String] = ctx.clauses.lines()
	clause_label.text = "\n".join(cls)
	clause_label.visible = cls.size() > 0
	var s = mm.secondary
	s_title.visible = s != null
	s_text.visible = s != null
	s_status.visible = s != null
	if s:
		var mark := ""
		if s.state == "done":
			mark = "  ✓ 完成"
		elif s.state == "failed":
			mark = "  ✗"
		s_title.text = "加分任務 · %s%s" % [s.title, mark]
		s_text.text = s.text
		s_status.text = s.status_line()


func _status_text() -> String:
	var lines: Array[String] = []
	var mm: MissionManager = ctx.missions
	if mm.primary:
		lines.append("【主要任務】%s\n  提示：%s" % [mm.primary.text, mm.primary.hint])
	if mm.secondary:
		lines.append("【加分任務】%s\n  提示：%s" % [mm.secondary.text, mm.secondary.hint])
	var cls: Array[String] = ctx.clauses.lines()
	if cls.size() > 0:
		lines.append("【附加條款】不影響任務能否完成，但遵守會加創意分、違反會扣效率分")
		for c in cls:
			lines.append("  " + c)
	lines.append("")
	lines.append("【物理規則】按 Q 開選單，或直接按 1-5 循環切換")
	for r in RuleDefs.COUNT:
		lines.append("  %d %s：%s" % [r + 1, RuleDefs.NAMES_ZH[r], RuleDefs.level_name_zh(r, ctx.rules.levels[r])])
	lines.append("")
	if ctx.anomalies.active.size() > 0:
		for d in ctx.anomalies.active:
			lines.append("【異常】%s：%s" % [(d as AnomalyDef).title, (d as AnomalyDef).desc])
	if ctx.anomalies.combos_found.size() > 0:
		lines.append("【異常組合】" + ", ".join(ctx.anomalies.combos_found))
	var rc: Array[String] = ctx.combos.active_names()
	if rc.size() > 0:
		lines.append("【物理組合生效中】" + "、".join(rc))
	lines.append("")
	lines.append("【房間觀察到的習慣】")
	var obs: Array[String] = ctx.observer.summary_lines()
	if obs.is_empty():
		lines.append("  （還沒有）")
	for o in obs:
		lines.append("  " + o)
	for r in ctx.observer.reactions:
		lines.append("  ◉ " + r)
	lines.append("")
	lines.append("Deviation 來源：碰撞、破壞、連鎖、修改規則。同一對物件反覆碰撞不會一直加分。")
	return "\n".join(lines)

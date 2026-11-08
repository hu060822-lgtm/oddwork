class_name Screens
extends Control
## Full-screen menus: title, anomaly card pick, shift/run results, codex,
## pause, help. Rebuilt on demand; only one is visible at a time.

var ctx: Node
var dim: ColorRect
var holder: Control
var current: String = ""


func setup(c: Node) -> void:
	ctx = c
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim = ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.025, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	holder = Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	visible = false


func hide_all() -> void:
	visible = false
	current = ""
	UiKit.clear(holder)


func _begin(n: String, dim_alpha: float = 0.82) -> VBoxContainer:
	UiKit.clear(holder)
	visible = true
	current = n
	dim.color.a = dim_alpha
	var v := UiKit.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_child(UiKit.center_wrap(v))
	return v


# ---------------------------------------------------------------- title
func show_menu() -> void:
	var v := _begin("menu", 0.55)
	var t := UiKit.label("MISRULE", 96, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_constant_override("outline_size", 10)
	v.add_child(t)
	v.add_child(UiKit.label("讓一切都出錯。", 24, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label(" ", 10))
	var data: Dictionary = ctx.progression.data
	v.add_child(UiKit.label("已完成值班 %d 次 · 最高分 %d（%s）· 最長連鎖 %d" % [int(data["runs_completed"]), int(data["best_points"]), str(data["best_grade"]), int(data["best_chain"])], 16, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if str(data["last_personality"]) != "":
		v.add_child(UiKit.label("上次的你：%s" % str(data["last_personality"]), 16, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label(" ", 10))
	var col := UiKit.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var row := UiKit.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	v.add_child(row)
	var start := UiKit.button("開始值班  START SHIFT", ctx.start_run, 22, 340)
	col.add_child(start)
	col.add_child(UiKit.button("操作說明  HOW TO PLAY", show_help.bind("menu"), 20, 340))
	col.add_child(UiKit.button("災難圖鑑  CODEX", show_codex, 20, 340))
	col.add_child(UiKit.button("離開  QUIT", ctx.quit_game, 20, 340))
	start.call_deferred("grab_focus")


# ---------------------------------------------------------------- help
func show_help(back: String) -> void:
	var v := _begin("help")
	var p := UiKit.panel(UiKit.BG_SOLID, UiKit.ACCENT)
	v.add_child(p)
	var inner := UiKit.vbox(6)
	p.add_child(inner)
	inner.add_child(UiKit.label("怎麼玩", 30, UiKit.ACCENT))
	var lines := [
		"每次值班有 3 個班次。每個班次開始前選一張異常卡（會累積），然後在 2:30 內完成主要任務。",
		"加分任務是額外的，完成會加分。主要任務完成就進入下一班次。",
		"你可以隨時篡改五種物理規則：重力、彈性、磁性、摩擦、時間。按 Q 開選單，或直接按 1-5 循環切換。",
		"Deviation 是世界偏離正常的程度。碰撞、破壞、連鎖反應、改規則都會提高它。越過門檻會發生「世界突變」——突變前 2 秒會警告。",
		"連鎖反應：你引發的事件撞到東西、東西再撞到東西、觸發按鈕或風扇……右側會顯示整條因果鏈。",
		"評分有四項：效率、創意、混亂、完成度。單純亂砸東西拿不到高分。",
		"房間會觀察你的習慣，並在新班次開始時做出回應。它做了什麼都會告訴你（Tab 可以看）。",
		"",
		"WASD 移動 · Shift 跑 · 空白 跳 · 滑鼠 看",
		"左鍵 抓取 / 投擲 · 滾輪 調整距離 · E 互動（開風扇、按按鈕）或放下",
		"右鍵 衝擊波（推開前方物件）",
		"Q 規則選單 · 1-5 快速切換規則 · Tab 任務與狀態 · Esc 暫停",
	]
	for l in lines:
		inner.add_child(UiKit.wrap_label(l, 18, UiKit.TEXT if l != "" else UiKit.DIM, 820))
	v.add_child(UiKit.button("返回", _back.bind(back), 20, 240))


func _back(to: String) -> void:
	if to == "pause":
		show_pause()
	else:
		show_menu()


# ---------------------------------------------------------------- cards
func show_cards(stage: int, cards: Array[AnomalyDef]) -> void:
	var v := _begin("cards")
	v.add_child(UiKit.label("SHIFT %d / %d" % [stage, ctx.SHIFTS], 22, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label("選一張異常卡", 36, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if ctx.anomalies.active.size() > 0:
		var names: Array[String] = []
		for d in ctx.anomalies.active:
			names.append((d as AnomalyDef).title)
		v.add_child(UiKit.label("已生效：" + ", ".join(names), 16, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UiKit.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in cards.size():
		row.add_child(_card(cards[i], i))
	v.add_child(UiKit.label("按 1 / 2 / 3 或點擊選擇", 15, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _card(d: AnomalyDef, idx: int) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 330)
	b.add_theme_stylebox_override("normal", UiKit._box(Color(0.11, 0.11, 0.1, 0.97), d.color.darkened(0.3), 3))
	b.add_theme_stylebox_override("hover", UiKit._box(Color(0.16, 0.15, 0.12, 1.0), d.color, 4))
	b.pressed.connect(ctx.pick_card.bind(d))
	var v := UiKit.vbox(10)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	v.offset_top = 18
	v.offset_bottom = -18
	b.add_child(v)
	v.add_child(UiKit.label(str(idx + 1), 20, UiKit.DIM))
	var strip := ColorRect.new()
	strip.color = d.color
	strip.custom_minimum_size = Vector2(0, 6)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(strip)
	var t := UiKit.wrap_label(d.title, 26, d.color, 260)
	v.add_child(t)
	v.add_child(UiKit.wrap_label(d.desc, 18, UiKit.TEXT, 260))
	for c in AnomalyData.combos():
		var other := ""
		if str(c["a"]) == d.id:
			other = str(c["b"])
		elif str(c["b"]) == d.id:
			other = str(c["a"])
		if other != "" and ctx.anomalies.has_active(other):
			v.add_child(UiKit.wrap_label("★ 與已生效的卡組成 %s" % str(c["name"]), 16, UiKit.ACCENT, 260))
	return b


# ---------------------------------------------------------------- shift result
func show_shift_result(stage: int, s: Dictionary, dims: Dictionary, last: bool) -> void:
	var v := _begin("shift")
	var done := bool(s.get("primary_done", false))
	v.add_child(UiKit.label("SHIFT %d %s" % [stage, "完成" if done else "失敗"], 40, UiKit.GREEN if done else UiKit.RED, HORIZONTAL_ALIGNMENT_CENTER))
	if not done:
		v.add_child(UiKit.label(str(s.get("fail_reason", "時間到了。")), 18, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var p := UiKit.panel(UiKit.BG_SOLID)
	v.add_child(p)
	var inner := UiKit.vbox(8)
	p.add_child(inner)
	_dim_row(inner, "效率 EFFICIENCY", float(dims["efficiency"]), Color(0.45, 0.85, 1.0))
	_dim_row(inner, "創意 CREATIVITY", float(dims["creativity"]), UiKit.ACCENT)
	_dim_row(inner, "混亂 CHAOS", float(dims["chaos"]), Color(1.0, 0.45, 0.35))
	_dim_row(inner, "完成 COMPLETION", float(dims["completion"]), UiKit.GREEN)
	inner.add_child(UiKit.label("本班次得分  %d" % int(dims["points"]), 26, UiKit.TEXT))
	var facts := "連鎖 %d 次（最長 %d）· 破壞 %d · 突變 %d · 用到 %d 種規則 · Deviation 峰值 %d" % [
		int(s.get("chains", 0)), int(s.get("best_chain", 0)), int(s.get("breaks", 0)), int(s.get("mutations", 0)),
		(s.get("rules_used", {}) as Dictionary).size(), int(s.get("peak_deviation", 0))]
	inner.add_child(UiKit.wrap_label(facts, 15, UiKit.DIM, 560))
	if str(s.get("best_chain_text", "")) != "":
		inner.add_child(UiKit.wrap_label("最佳連鎖：" + str(s["best_chain_text"]), 15, UiKit.ACCENT, 560))
	var cl: Dictionary = s.get("clauses", {})
	if not cl.is_empty():
		for line in cl.get("lines", []):
			var good := str(line).begins_with("✓") or str(line).begins_with("○") or str(line).begins_with("★")
			inner.add_child(UiKit.wrap_label(str(line), 15, UiKit.GREEN if good else UiKit.DIM, 560))
	var cn: Array = s.get("combo_names", [])
	if cn.size() > 0:
		var names: Array[String] = []
		for id in cn:
			names.append(str(ctx.combos.def_of(str(id)).get("zh", id)))
		inner.add_child(UiKit.wrap_label("物理組合：" + "、".join(names), 15, Color(0.7, 0.9, 1.0), 560))
	var inc: Dictionary = s.get("incidents", {})
	if inc.size() > 0:
		var iz: Array[String] = []
		for id: String in inc:
			iz.append(str(IncidentData.get_def(id).get("zh", id)) + {"ok": "", "fail": "（未通過）", "": ""}.get(str(inc[id]), ""))
		inner.add_child(UiKit.wrap_label("特殊事故：" + "、".join(iz), 15, Color(0.95, 0.85, 0.55), 560))
	var b := UiKit.button("查看總結" if last else "下一班次", ctx.continue_after_shift, 22, 300)
	v.add_child(b)
	b.call_deferred("grab_focus")


func _dim_row(parent: Control, name: String, value: float, col: Color) -> void:
	var h := UiKit.hbox(10)
	parent.add_child(h)
	var l := UiKit.label(name, 17, UiKit.TEXT)
	l.custom_minimum_size.x = 190
	h.add_child(l)
	var b := UiKit.bar(300, 14, col)
	(b[1] as ColorRect).size.x = 300.0 * clampf(value / 100.0, 0.0, 1.0)
	h.add_child(b[0])
	h.add_child(UiKit.label("%d" % int(value), 17, col))


# ---------------------------------------------------------------- run result
func show_run_result(r: Dictionary) -> void:
	var v := _begin("run")
	v.add_child(UiKit.label("值班結束" if not bool(r.get("misruled", false)) else "MISRULED — 你被混亂擊倒了", 34, UiKit.TEXT if not bool(r.get("misruled", false)) else UiKit.RED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label("總分 %d   評價 %s" % [int(r["points"]), str(r["grade"])], 44, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var pers: Dictionary = r["personality"]
	v.add_child(UiKit.label("混亂人格：%s" % str(pers["title"]), 28, Color(1.0, 0.5, 0.4), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label(str(pers["desc"]), 18, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var cols := UiKit.hbox(18)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)
	var p := UiKit.panel(UiKit.BG_SOLID)
	cols.add_child(p)
	var inner := UiKit.vbox(6)
	inner.custom_minimum_size.x = 640
	p.add_child(inner)
	var rep: Dictionary = r.get("report", {})
	if not rep.is_empty():
		cols.add_child(_report_panel(rep))
	var shifts: Array = r["shifts"]
	for i in shifts.size():
		var sh: Dictionary = shifts[i]
		inner.add_child(UiKit.wrap_label("SHIFT %d  %s  %d 分  · 效率 %d / 創意 %d / 混亂 %d / 完成 %d" % [i + 1, "✓" if bool(sh["done"]) else "✗", int(sh["points"]), int(sh["efficiency"]), int(sh["creativity"]), int(sh["chaos"]), int(sh["completion"])], 16, UiKit.TEXT, 620))
	var unl: Array = r.get("unlocks", [])
	if unl.size() > 0:
		inner.add_child(UiKit.label(" ", 6))
		inner.add_child(UiKit.label("新解鎖", 20, UiKit.GREEN))
		for u in unl:
			inner.add_child(UiKit.label("  ✦ " + str(u), 17, UiKit.GREEN))
	var cod: Array = r.get("codex", [])
	if cod.size() > 0:
		inner.add_child(UiKit.wrap_label("圖鑑新增：" + "、".join(PackedStringArray(cod)), 16, Color(0.7, 0.9, 1.0), 620))
	var row := UiKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var again := UiKit.button("再值一次班", ctx.start_run, 22, 260)
	row.add_child(again)
	row.add_child(UiKit.button("主選單", ctx.quit_to_menu, 20, 200))
	again.call_deferred("grab_focus")


## The Department of Normality's incident report, styled as an old memo.
func _report_panel(rep: Dictionary) -> Control:
	var ink := Color(0.16, 0.14, 0.11)
	var paper := UiKit.panel(Color(0.86, 0.83, 0.72), Color(0.45, 0.4, 0.3))
	var col := UiKit.vbox(5)
	col.custom_minimum_size.x = 520
	paper.add_child(col)
	var add := func(text: String, size: int, color: Color, wrap: bool = true) -> Label:
		var l := UiKit.wrap_label(text, size, color, 500) if wrap else UiKit.label(text, size, color)
		l.add_theme_constant_override("outline_size", 0)
		col.add_child(l)
		return l
	add.call("DEPARTMENT OF NORMALITY · 正常事務部", 15, Color(0.4, 0.35, 0.28))
	add.call("INCIDENT #%05d" % int(rep["number"]), 26, ink)
	add.call(str(rep["case"]), 17, ink)
	add.call("案件名稱：%s" % str(rep["case_zh"]), 17, ink)
	add.call("事故摘要：%s" % str(rep["summary"]), 15, ink)
	for line in rep["lines"]:
		add.call("· " + str(line), 15, ink)
	add.call("主管評語：", 16, Color(0.55, 0.12, 0.1))
	for c in rep["comments"]:
		add.call(str(c), 16, Color(0.55, 0.12, 0.1))
	var stamp: Label = add.call("【%s】" % str(rep["stamp"]), 34, Color(0.75, 0.12, 0.1, 0.85), false)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.rotation_degrees = -6.0
	return paper


# ---------------------------------------------------------------- codex
func show_codex() -> void:
	var v := _begin("codex")
	v.add_child(UiKit.label("災難圖鑑  DISASTER CODEX", 32, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var inner := UiKit.vbox(4)
	inner.custom_minimum_size.x = 880
	scroll.add_child(inner)
	var prog: ProgressionManager = ctx.progression
	var codex: Dictionary = prog.data["codex"]
	inner.add_child(UiKit.label("災難", 22, UiKit.RED))
	for k: String in ProgressionManager.DISASTERS:
		var d: Array = ProgressionManager.DISASTERS[k]
		var id := "disaster:" + k
		if codex.has(id):
			inner.add_child(UiKit.wrap_label("  ■ %s — %s（%d 次）" % [str(d[0]), str(d[1]), int(codex[id]["count"])], 17, UiKit.TEXT, 860))
		else:
			inner.add_child(UiKit.label("  □ ？？？", 17, UiKit.DIM))
	inner.add_child(UiKit.label("世界突變", 22, Color(1, 0.5, 0.4)))
	for m in MutationData.all():
		var id2 := "mutation:" + str(m["id"])
		if codex.has(id2):
			inner.add_child(UiKit.label("  ■ %s — %s（%d 次）" % [str(m["title"]), str(m["zh"]), int(codex[id2]["count"])], 17, UiKit.TEXT))
		else:
			inner.add_child(UiKit.label("  □ ？？？", 17, UiKit.DIM))
	inner.add_child(UiKit.label("異常卡", 22, UiKit.ACCENT))
	var unlocks: Dictionary = prog.unlocks()
	for d2 in AnomalyData.all():
		var ok := d2.unlock_key == "" or unlocks.has(d2.unlock_key)
		var played := codex.has("anomaly:" + d2.id)
		var tag := "已解鎖" if ok else "未解鎖：" + d2.unlock_hint
		inner.add_child(UiKit.label("  %s %s — %s%s" % ["■" if played else "□", d2.title, tag, "" if not played else "（用過）"], 17, UiKit.TEXT if ok else UiKit.DIM))
	inner.add_child(UiKit.label("異常組合", 22, Color(0.7, 0.9, 1.0)))
	for c in AnomalyData.combos():
		var id3 := "combo:" + str(c["name"])
		inner.add_child(UiKit.label(("  ■ %s（%s）" % [str(c["name"]), str(c["zh"])]) if codex.has(id3) else "  □ ？？？", 17, UiKit.TEXT if codex.has(id3) else UiKit.DIM))
	inner.add_child(UiKit.label("物理組合發現", 22, Color(0.6, 0.85, 1.0)))
	for cd in ComboData.all():
		var id4 := "rcombo:" + str(cd["id"])
		if codex.has(id4):
			inner.add_child(UiKit.wrap_label("  ■ %s（%s）— %s" % [str(cd["title"]), str(cd["zh"]), str(cd["desc"])], 17, UiKit.TEXT, 860))
		else:
			inner.add_child(UiKit.label("  □ ？？？（%d 條規則的組合）" % (cd["needs"] as Dictionary).size(), 17, UiKit.DIM))
	inner.add_child(UiKit.label("特殊事故", 22, Color(0.95, 0.85, 0.55)))
	for idf in IncidentData.all():
		var id5 := "incident:" + str(idf["id"])
		if codex.has(id5):
			inner.add_child(UiKit.wrap_label("  ■ %s（%s）— %s（%d 次）" % [str(idf["title"]), str(idf["zh"]), str(idf["desc"]), int(codex[id5]["count"])], 17, UiKit.TEXT, 860))
		else:
			inner.add_child(UiKit.label("  □ ？？？", 17, UiKit.DIM))
	var li: Dictionary = prog.data.get("last_incident", {})
	if not li.is_empty():
		inner.add_child(UiKit.label("最近的事故報告", 22, UiKit.ACCENT))
		inner.add_child(UiKit.wrap_label("  INCIDENT #%05d · %s（%s）" % [int(li["number"]), str(li.get("case", "")), str(li.get("case_zh", ""))], 17, UiKit.TEXT, 860))
		inner.add_child(UiKit.wrap_label("  " + str(li.get("summary", "")), 15, UiKit.DIM, 860))
	inner.add_child(UiKit.label("最佳連鎖反應", 22, UiKit.GREEN))
	var hall: Array = prog.data["chains_hall"]
	if hall.is_empty():
		inner.add_child(UiKit.label("  （還沒有）", 17, UiKit.DIM))
	for h in hall:
		inner.add_child(UiKit.wrap_label("  ×%d  %s" % [int(h["links"]), str(h["text"])], 16, UiKit.TEXT, 860))
	inner.add_child(UiKit.label("混亂人格紀錄", 22, Color(1, 0.5, 0.4)))
	var pers: Dictionary = prog.data["personalities"]
	if pers.is_empty():
		inner.add_child(UiKit.label("  （還沒有）", 17, UiKit.DIM))
	for k2: String in pers:
		inner.add_child(UiKit.label("  %s × %d" % [k2, int(pers[k2])], 17, UiKit.TEXT))
	v.add_child(UiKit.button("返回", show_menu, 20, 240))


# ---------------------------------------------------------------- pause
func show_pause() -> void:
	var v := _begin("pause", 0.7)
	v.add_child(UiKit.label("暫停", 44, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var col := UiKit.vbox(10)
	var row := UiKit.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	v.add_child(row)
	var res := UiKit.button("繼續", ctx.toggle_pause, 22, 320)
	col.add_child(res)
	col.add_child(UiKit.button("操作說明", show_help.bind("pause"), 20, 320))
	col.add_child(UiKit.button("重新開始這次值班", ctx.restart_run, 20, 320))
	col.add_child(UiKit.button("回主選單（放棄這次值班）", ctx.quit_to_menu, 20, 320))
	col.add_child(UiKit.label("滑鼠靈敏度", 16, UiKit.DIM))
	var sens := HSlider.new()
	sens.min_value = 0.3
	sens.max_value = 2.5
	sens.step = 0.05
	sens.value = float(ctx.progression.data["settings"]["sensitivity"])
	sens.custom_minimum_size.x = 320
	sens.value_changed.connect(ctx.set_sensitivity)
	col.add_child(sens)
	col.add_child(UiKit.label("音量", 16, UiKit.DIM))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = float(ctx.progression.data["settings"]["volume"])
	vol.custom_minimum_size.x = 320
	vol.value_changed.connect(ctx.set_volume)
	col.add_child(vol)
	res.call_deferred("grab_focus")

class_name IncidentReport
extends RefCounted
## Builds the Department of Normality incident report at the end of a run.
## Text comes from hand-written pools filtered by what actually happened, and
## the comments used last time are avoided so reports do not repeat.

# [condition key, comment]
const COMMENTS := [
	["breaks_many", "「本部已收到 %d 件物品的離職申請。」"],
	["breaks_many", "「請員工理解，『清潔』與『拆除』是兩個不同的職務。」"],
	["breaks_none", "「沒有任何物品損壞。這讓我們非常不安。」"],
	["misruled", "「值班人員被一張椅子擊倒。椅子已記一支小過。」"],
	["misruled", "「本部提醒：物理規則不是用來對付自己的。」"],
	["peak_high", "「房間的偏差值超出了本部表格的格子。我們需要更大的表格。」"],
	["peak_high", "「現場曾一度無法分辨上下。報告依然要求以正面朝上繳交。」"],
	["chain_long", "「%d 段的連鎖反應。我們不確定這是意外還是藝術。」"],
	["chain_long", "「請不要再讓物品互相通知彼此。」"],
	["rule_gravity", "「該員工對重力的態度令人擔憂。」"],
	["rule_time", "「該員工把時間當成可以調整的東西。時間方面已提出抗議。」"],
	["rule_magnetism", "「物品之間發展出不恰當的吸引力。」"],
	["rule_bounce", "「我們已經要求這名員工不要再讓東西彈。」"],
	["rule_friction", "「地板的摩擦係數被改了 %d 次。地板要求調職。」"],
	["inspection_fail", "「檢查員報告的第一句是：『我不知道從哪裡開始寫。』」"],
	["inspection_ok", "「檢查員確認現場一切正常。檢查員正在接受心理輔導。」"],
	["room_service", "「客房服務不是本部的業務。我們不知道那些東西是誰送的。」"],
	["outage", "「停電期間的物理行為不在保固範圍內。」"],
	["duplication", "「印表機不應該能列印那種東西。請把副本交回。」"],
	["neighbor", "「本大樓沒有隔壁。請勿回應敲門聲。」"],
	["combo", "「發現新的物理組合並不是員工的職責。但我們會記下來。」"],
	["black_hole", "「房間中央曾短暫出現黑洞。黑洞已被要求填寫訪客登記。」"],
	["hidden", "「員工達成了一項我們沒有告訴他的條款。這很可疑。」"],
	["clauses_broken", "「附加條款不是建議。附加條款是附加的。」"],
	["all_done", "「三個班次全部完成。我們會假裝這很正常。」"],
	["throws", "「員工投擲物品 %d 次。本部不是投擲部。」"],
	["hands_free", "「目標從頭到尾都沒被碰過。員工堅稱自己只是『在旁邊』。」"],
	["default", "「本次值班無特別事項。這句話本身就是特別事項。」"],
	["default", "「報告已歸檔。歸檔處表示檔案在夜裡會自己移動。」"],
]

const CASES := [
	["subject", "CASE: THE %s HAS LEFT THE BUILDING", "「%s」離開了大樓"],
	["subject", "CASE: REGARDING THE %s", "關於%s的第三次申訴"],
	["subject", "CASE: UNAUTHORIZED %s", "未經授權的%s"],
	["misruled", "CASE: STAFF MEMBER REMOVED BY ROOM", "值班人員被房間移除"],
	["black_hole", "CASE: THE ROOM ATE ITSELF", "房間差點把自己吃掉"],
	["inspection_fail", "CASE: INSPECTOR DECLINED TO SIGN", "檢查員拒絕簽名"],
	["peak_high", "CASE: A CATASTROPHIC TUESDAY", "災難等級的星期二"],
	["calm", "CASE: A DISTURBINGLY NORMAL SHIFT", "一次令人不安的正常值班"],
	["default", "CASE: ROUTINE ANOMALY", "例行異常"],
]

const SUBJECT_EN := {
	"cup": "CUP", "apple": "APPLE", "ball": "BALL", "box": "BOX", "chair": "CHAIR",
	"barrel": "BARREL", "battery": "BATTERY", "plate": "PLATE", "tv": "TELEVISION",
	"lamp": "LAMP", "fan": "FAN", "printer": "PRINTER",
}


static func build(ctx: Node, points: int, grade: String, pers: Dictionary) -> Dictionary:
	var shifts: Array = ctx.run_stats
	var breaks := 0
	var throws := 0
	var peak := 0.0
	var best_chain := 0
	var best_text := ""
	var kinds: Dictionary = {}
	var rule_counts: Dictionary = {}
	var done_count := 0
	var hidden_met := 0
	var broken_clauses := 0
	var kept_clauses := 0
	var hands_free := false
	var incident_ids: Dictionary = {}
	var inspection := ""
	for s: Dictionary in shifts:
		breaks += int(s.get("breaks", 0))
		throws += int(s.get("throws", 0))
		peak = maxf(peak, float(s.get("peak_deviation", 0.0)))
		if int(s.get("best_chain", 0)) > best_chain:
			best_chain = int(s.get("best_chain", 0))
			best_text = str(s.get("best_chain_text", ""))
		for k: String in s.get("broken_kinds", {}):
			kinds[k] = int(kinds.get(k, 0)) + int(s["broken_kinds"][k])
		for r in s.get("rule_counts", {}):
			rule_counts[int(r)] = int(rule_counts.get(int(r), 0)) + int(s["rule_counts"][r])
		if bool(s.get("primary_done", false)):
			done_count += 1
			if not bool(s.get("target_grabbed", true)):
				hands_free = true
		var cl: Dictionary = s.get("clauses", {})
		if bool(cl.get("hidden", false)):
			hidden_met += 1
		broken_clauses += int(cl.get("broken", 0))
		kept_clauses += int(cl.get("kept", 0))
		for id: String in s.get("incidents", {}):
			incident_ids[id] = true
			if id == "THE_INSPECTION":
				inspection = str(s["incidents"][id])
	var top_rule := -1
	var top_n := 0
	for r: int in rule_counts:
		if int(rule_counts[r]) > top_n:
			top_n = int(rule_counts[r])
			top_rule = r
	var subject := ""
	var subject_n := 0
	for k: String in kinds:
		if int(kinds[k]) > subject_n and SUBJECT_EN.has(k):
			subject_n = int(kinds[k])
			subject = k
	if subject == "" and best_text != "":
		for k: String in SUBJECT_EN:
			if best_text.find(str(PropFactory.NAMES_ZH.get(k, "?"))) >= 0:
				subject = k
				break
	var combos_found: Array = ctx.combos.discovered_this_run
	var black_hole := false
	for s: Dictionary in shifts:
		if (s.get("combo_names", []) as Array).has("BLACK_HOLE"):
			black_hole = true
	var flags := {
		"breaks_many": breaks >= 10, "breaks_none": breaks == 0 and done_count > 0,
		"misruled": bool(ctx.misruled), "peak_high": peak >= 80.0, "chain_long": best_chain >= 6,
		"rule_gravity": top_rule == RuleDefs.GRAVITY, "rule_time": top_rule == RuleDefs.TIME,
		"rule_magnetism": top_rule == RuleDefs.MAGNETISM, "rule_bounce": top_rule == RuleDefs.BOUNCE,
		"rule_friction": top_rule == RuleDefs.FRICTION,
		"inspection_fail": inspection == "fail", "inspection_ok": inspection == "ok",
		"room_service": incident_ids.has("ROOM_SERVICE"), "outage": incident_ids.has("POWER_OUTAGE"),
		"duplication": incident_ids.has("DUPLICATION_ERROR"), "neighbor": incident_ids.has("THE_NEIGHBOR"),
		"combo": combos_found.size() > 0, "black_hole": black_hole, "hidden": hidden_met > 0,
		"clauses_broken": broken_clauses >= 2, "all_done": done_count >= 3, "throws": throws >= 30,
		"hands_free": hands_free, "subject": subject != "", "calm": peak < 40.0 and breaks <= 1,
		"default": true,
	}
	# --- case title
	var case_opts: Array = []
	for c in CASES:
		if bool(flags.get(str(c[0]), false)):
			case_opts.append(c)
	# Prefer the most specific case: anything but subject/default first.
	var special: Array = case_opts.filter(func(c: Array) -> bool: return str(c[0]) != "subject" and str(c[0]) != "default")
	var pick: Array = special[randi() % special.size()] if special.size() > 0 and randf() < 0.6 else case_opts[randi() % case_opts.size()]
	var case_en := str(pick[1])
	var case_zh := str(pick[2])
	if str(pick[0]) == "subject":
		case_en = case_en % str(SUBJECT_EN[subject])
		case_zh = case_zh % str(PropFactory.NAMES_ZH.get(subject, subject))
	# --- comments
	var last: Array = ctx.progression.data.get("last_comments", [])
	var pool: Array[int] = []
	var fallback: Array[int] = []
	for i in COMMENTS.size():
		var key := str(COMMENTS[i][0])
		if key == "default" or not bool(flags.get(key, false)):
			continue
		if last.has(i):
			fallback.append(i)
		else:
			pool.append(i)
	pool.shuffle()
	fallback.shuffle()
	pool.append_array(fallback)
	var chosen: Array[int] = []
	var used_keys: Dictionary = {}
	for i in pool:
		if chosen.size() >= 2:
			break
		if used_keys.has(str(COMMENTS[i][0])):
			continue
		used_keys[str(COMMENTS[i][0])] = true
		chosen.append(i)
	if chosen.is_empty():
		for i in COMMENTS.size():
			if str(COMMENTS[i][0]) == "default" and not last.has(i):
				chosen.append(i)
				break
	if chosen.is_empty():
		chosen.append(COMMENTS.size() - 1)
	ctx.progression.data["last_comments"] = chosen.duplicate()
	var comments: Array[String] = []
	for i in chosen:
		var text := str(COMMENTS[i][1])
		match str(COMMENTS[i][0]):
			"breaks_many":
				if text.find("%d") >= 0:
					text = text % breaks
			"chain_long":
				if text.find("%d") >= 0:
					text = text % best_chain
			"rule_friction":
				text = text % top_n
			"throws":
				text = text % throws
		comments.append(text)
	# --- body
	var number := int(ctx.progression.data.get("incident_counter", 830)) + 1
	var summary := best_text if best_text != "" else "本次值班未記錄到值得一提的連鎖反應。"
	var lines: Array[String] = []
	lines.append("任務結果：%d / %d 個班次完成%s" % [done_count, shifts.size(), "（值班人員倒下）" if ctx.misruled else ""])
	lines.append("Deviation 最高：%d" % int(peak))
	lines.append("物件破壞：%d　最長連鎖：%d 段" % [breaks, best_chain])
	lines.append("最常使用的規則：%s" % (RuleDefs.NAMES_ZH[top_rule] if top_rule >= 0 else "（無）"))
	lines.append("附加條款：遵守 %d、違反 %d　隱藏條款：%d" % [kept_clauses, broken_clauses, hidden_met])
	if incident_ids.size() > 0:
		var names: Array[String] = []
		for id: String in incident_ids:
			names.append(str(IncidentData.get_def(id).get("zh", id)))
		lines.append("特殊事故：" + "、".join(names) + ("（檢查未通過）" if inspection == "fail" else ("（檢查通過）" if inspection == "ok" else "")))
	if combos_found.size() > 0:
		var cn: Array[String] = []
		for id in combos_found:
			cn.append(str(ctx.combos.def_of(str(id)).get("zh", id)))
		lines.append("新發現的物理組合：" + "、".join(cn))
	var react: Array = ctx.observer.reactions
	if react.size() > 0:
		lines.append("房間的反應：" + str(react[0]))
	var stamp := "已歸檔"
	if ctx.misruled:
		stamp = "MISRULED"
	elif peak >= 80.0 or inspection == "fail":
		stamp = "待調查"
	elif done_count >= 3 and breaks == 0:
		stamp = "可疑地正常"
	return {
		"number": number, "case": case_en, "case_zh": case_zh, "summary": summary,
		"lines": lines, "comments": comments, "stamp": stamp,
		"personality": str(pers.get("title", "")), "grade": grade, "points": points,
	}

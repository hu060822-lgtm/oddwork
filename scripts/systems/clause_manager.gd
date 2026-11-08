class_name ClauseManager
extends Node
## Attaches 1-2 clauses and one hidden objective to the primary mission and
## tracks them. Clauses never block the mission itself: they only change the
## score (kept clauses raise Creativity, broken ones cost Efficiency) and the
## incident report. That keeps every mission completable while still giving
## the player a reason to solve it a specific way.

const FURNITURE := ["chair", "tv", "lamp", "printer", "fan"]

var ctx: Node
var list: Array[Dictionary] = []    # {def, state: kept|broken|met|unmet}
var hidden_obj: Dictionary = {}     # {def, state: unmet|met|failed, revealed}
var _bumped: Dictionary = {}
var _rule_changes: int = 0
var _cup_broke: bool = false


func setup(c: Node) -> void:
	ctx = c
	ctx.events.rule_changed.connect(_on_rule)
	ctx.events.player_jumped.connect(func() -> void: _break("NO_JUMP"))
	ctx.events.prop_broken.connect(_on_broken)
	ctx.events.prop_grabbed.connect(_on_grab)
	ctx.events.mutation_started.connect(func(_d: Dictionary) -> void: _meet("NEED_MUTATION"))
	ctx.events.mission_completed.connect(_on_mission_completed)
	ctx.events.prop_impact.connect(_on_impact)


func clear() -> void:
	list.clear()
	hidden_obj = {}
	_bumped.clear()
	_rule_changes = 0
	_cup_broke = false


## Pick clauses that fit the mission. Returns the chosen ids.
func assign(m: RefCounted, stage: int) -> Array[String]:
	clear()
	var ids: Array[String] = []
	if m == null:
		return ids
	var want := 1 if stage <= 1 else 2
	var pool := ClauseData.clauses()
	pool.shuffle()
	for d in pool:
		if ids.size() >= want:
			break
		if not fits(d, m):
			continue
		var clash := false
		for other in ids:
			if (d["excl"] as Array).has(other):
				clash = true
		if clash:
			continue
		list.append({"def": d, "state": "kept" if str(d["mode"]) == "forbid" else "unmet"})
		ids.append(str(d["id"]))
	var hp := ClauseData.hidden()
	hp.shuffle()
	for h in hp:
		if fits(h, m):
			hidden_obj = {"def": h, "state": "unmet", "revealed": false}
			break
	return ids


static func fits(d: Dictionary, m: RefCounted) -> bool:
	if (d.get("excl_types", []) as Array).has(str(m.get("type"))):
		return false
	if bool(d.get("needs_target", false)) and m.get("target") == null:
		return false
	return true


func has(id: String) -> bool:
	for c in list:
		if str(c["def"]["id"]) == id:
			return true
	return false


func _entry(id: String) -> Dictionary:
	for c in list:
		if str(c["def"]["id"]) == id:
			return c
	return {}


func _break(id: String) -> void:
	if not ctx.is_playing():
		return
	var c := _entry(id)
	if c.is_empty() or str(c["state"]) != "kept":
		return
	c["state"] = "broken"
	ctx.audio.play_ui("stamp", -2.0)
	ctx.events.notify.emit("違反條款：%s" % str(c["def"]["zh"]), UiKit.RED, false)


func _meet(id: String) -> void:
	if not ctx.is_playing():
		return
	var c := _entry(id)
	if c.is_empty() or str(c["state"]) != "unmet":
		return
	c["state"] = "met"
	ctx.audio.play_ui("stamp", -6.0, 1.3)
	ctx.events.notify.emit("條款達成：%s" % str(c["def"]["zh"]), UiKit.GREEN, false)


func _on_rule(rule: int, level: int, by_player: bool) -> void:
	if not by_player or not ctx.is_playing():
		return
	_rule_changes += 1
	if rule == RuleDefs.GRAVITY:
		_break("NO_GRAVITY")
	if level != 0:
		var used: Dictionary = ctx.stats.get("rules_used", {})
		# main records rules_used in its own handler; count this one too.
		var n := used.size() + (0 if used.has(rule) else 1)
		if n >= 3:
			_meet("THREE_RULES")


func _on_broken(p: Node, _cid: int) -> void:
	var pr := p as Prop
	if pr == null or pr.is_debris:
		return
	if FURNITURE.has(pr.kind):
		_break("NO_FURNITURE")
	if pr.kind == "cup":
		_cup_broke = true


func _on_grab(p: Node) -> void:
	var m = ctx.missions.primary
	if m and m.target == p:
		_break("NO_GRAB_TARGET")


func _on_impact(striker: Node, victim: Node, speed: float) -> void:
	if hidden_obj.is_empty() or str(hidden_obj["def"]["id"]) != "H_TARGET_BUMPS" or speed < 1.5:
		return
	var m = ctx.missions.primary
	if m == null or m.target == null:
		return
	var other: Node = null
	if striker == m.target:
		other = victim
	elif victim == m.target:
		other = striker
	if other is Prop and not (other as Prop).is_debris:
		_bumped[(other as Prop).uid] = true
		if _bumped.size() >= 3:
			_hidden_met()


func _on_mission_completed(m: RefCounted) -> void:
	if m != ctx.missions.primary:
		return
	if has("VIA_CHAIN"):
		var t = m.get("target")
		if t != null and is_instance_valid(t) and (t as Prop).chain_active(GameClock.ms):
			_meet("VIA_CHAIN")
	if not hidden_obj.is_empty() and str(hidden_obj["def"]["id"]) == "H_TV_ON":
		var tv = ctx.room.devices.get("tv")
		if tv != null and is_instance_valid(tv) and bool(tv.on):
			_hidden_met()


func _hidden_met() -> void:
	if hidden_obj.is_empty() or str(hidden_obj["state"]) != "unmet":
		return
	hidden_obj["state"] = "met"
	hidden_obj["revealed"] = true
	ctx.audio.play_ui("discovery", -6.0, 0.9)
	ctx.events.notify.emit("★ " + str(hidden_obj["def"]["zh"]), UiKit.ACCENT, true)


## Called at shift end. Resolves end-of-shift clauses and returns a summary.
func finalize(primary_done: bool) -> Dictionary:
	if not hidden_obj.is_empty() and str(hidden_obj["state"]) == "unmet":
		match str(hidden_obj["def"]["id"]):
			"H_NO_CUP":
				if primary_done and not _cup_broke:
					_hidden_met()
			"H_FEW_RULES":
				if primary_done and _rule_changes <= 3:
					_hidden_met()
		if str(hidden_obj["state"]) == "unmet":
			hidden_obj["state"] = "failed"
	var kept := 0
	var broken := 0
	for c in list:
		var st := str(c["state"])
		if st == "kept" and not primary_done:
			# A forbid clause only counts if the job was actually done.
			continue
		if st == "kept" or st == "met":
			kept += 1
		elif st == "broken":
			broken += 1
	return {
		"kept": kept, "broken": broken, "total": list.size(),
		"hidden": str(hidden_obj.get("state", "")) == "met",
		"hidden_text": str(hidden_obj["def"]["zh"]) if not hidden_obj.is_empty() else "",
		"lines": lines(true),
	}


## Human readable lines. reveal: show the hidden objective even if unmet.
func lines(reveal: bool = false) -> Array[String]:
	var out: Array[String] = []
	for c in list:
		var mark := ""
		match str(c["state"]):
			"kept":
				mark = "○"
			"met":
				mark = "✓"
			"broken":
				mark = "✗"
			"unmet":
				mark = "□"
		out.append("%s %s" % [mark, str(c["def"]["zh"])])
	if not hidden_obj.is_empty():
		if bool(hidden_obj["revealed"]) or reveal:
			var hm := "★" if str(hidden_obj["state"]) == "met" else "☆"
			out.append("%s %s" % [hm, str(hidden_obj["def"]["zh"])])
		else:
			out.append("☆ 隱藏條款：???")
	return out

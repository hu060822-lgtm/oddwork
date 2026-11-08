class_name AnomalyManager
extends Node
## Draws and applies Anomaly Deck cards. Cards stack across the three shifts
## of a run.

var ctx: Node
var defs: Array[AnomalyDef] = []
var active: Array[AnomalyDef] = []
var combos_found: Array[String] = []


func setup(c: Node) -> void:
	ctx = c
	defs = AnomalyData.all()


func reset() -> void:
	active.clear()
	combos_found.clear()


func get_def(id: String) -> AnomalyDef:
	for d in defs:
		if d.id == id:
			return d
	return null


func is_unlocked(d: AnomalyDef, unlocks: Dictionary) -> bool:
	return d.unlock_key == "" or unlocks.has(d.unlock_key)


func has_active(id: String) -> bool:
	for d in active:
		if d.id == id:
			return true
	return false


func compatible(d: AnomalyDef) -> bool:
	if has_active(d.id):
		return false
	for a in active:
		if a.incompatible.has(d.id) or d.incompatible.has(a.id):
			return false
	return true


func draw(n: int, unlocks: Dictionary) -> Array[AnomalyDef]:
	var pool: Array[AnomalyDef] = []
	for d in defs:
		if is_unlocked(d, unlocks) and compatible(d):
			pool.append(d)
	pool.shuffle()
	var out: Array[AnomalyDef] = []
	for d in pool:
		if out.size() >= n:
			break
		out.append(d)
	return out


func play(d: AnomalyDef, unlocks: Dictionary) -> Array[AnomalyDef]:
	var applied: Array[AnomalyDef] = []
	if d.effects.has("double"):
		var extra := draw(6, unlocks)
		var picked := 0
		for e in extra:
			if picked >= 2:
				break
			if e.effects.has("double") or not compatible(e):
				continue
			_apply(e)
			applied.append(e)
			picked += 1
	else:
		_apply(d)
		applied.append(d)
	_check_combos()
	return applied


func _apply(d: AnomalyDef) -> void:
	active.append(d)
	for r: int in d.rules:
		ctx.rules.set_level(r, int(d.rules[r]), false)
	for e in d.effects:
		if e == "rain" or e == "wind" or e == "structure":
			ctx.env_fx.enable(e)
	for p: Prop in ctx.room.live_props():
		on_prop_spawned(p)


func damage_mult() -> float:
	return 3.0 if has_active("FRAGILE_WORLD") else 1.0


func size_mult() -> float:
	var s := 1.0
	for d in active:
		for e in d.effects:
			if e.begins_with("size:"):
				s *= float(e.substr(5))
	return s


func on_prop_spawned(p: Prop) -> void:
	if p.is_debris:
		return
	p.damage_mult = damage_mult()
	var s := size_mult()
	if not is_equal_approx(s, p.size_factor) and p.kind != "table":
		p.set_size(s)
	p.wet = has_active("HEAVY_RAIN")


func _check_combos() -> void:
	for c in AnomalyData.combos():
		var n := str(c["name"])
		if combos_found.has(n):
			continue
		if has_active(str(c["a"])) and has_active(str(c["b"])):
			combos_found.append(n)
			ctx.progression.record("combo:" + n, n, str(c["zh"]))
			ctx.events.notify.emit("COMBO：%s（%s）" % [n, str(c["zh"])], Color(1, 0.9, 0.3), true)
			ctx.audio.play_ui("combo", 0.0)
			ctx.deviation.add(6.0, "combo")

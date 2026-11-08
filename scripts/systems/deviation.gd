class_name DeviationManager
extends Node
## How far the world has drifted from normal (0-100).
## Anti-farming: impacts draw from a refilling budget, each prop gets bored of
## being hit, the same pair cannot score twice within 2 s, and the value decays
## toward a floor set by how many rules are currently bent.

const TIER_NAMES: Array[String] = ["NORMAL", "UNSTABLE", "DISTORTED", "CRITICAL", "CATASTROPHIC"]
const TIER_ZH: Array[String] = ["正常", "不穩定", "扭曲", "危急", "災難"]
const TIER_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.78), Color(0.95, 0.85, 0.3), Color(1.0, 0.6, 0.2),
	Color(1.0, 0.3, 0.2), Color(0.85, 0.1, 0.35)]

var ctx: Node
var value: float = 0.0
var tier: int = 0
var peak: float = 0.0
var budget: float = 5.0
var chain_budget: float = 6.0
var break_budget: float = 6.0
var time_in_tier: Array[float] = [0, 0, 0, 0, 0]
var _pairs: Dictionary = {}
var _last_gain_ms: int = 0
var _recent_rule_changes: Array[int] = []
var sources: Dictionary = {}
var _last_player_ms: int = -100000


func setup(c: Node) -> void:
	ctx = c
	ctx.events.prop_impact.connect(_on_impact)
	ctx.events.rule_changed.connect(_on_rule)
	ctx.events.prop_broken.connect(_on_broken)
	ctx.events.chain_step.connect(_on_chain_step)
	ctx.events.mutation_started.connect(func(_d: Dictionary) -> void: add(5.0, "mutation"))
	ctx.events.prop_thrown.connect(func(_p: Node) -> void: _last_player_ms = GameClock.ms)
	ctx.events.pulse_fired.connect(func(_o: Vector3, _n: int) -> void: _last_player_ms = GameClock.ms)
	ctx.events.device_activated.connect(func(_d: Node, _s: Node, by_player: bool, _l: int) -> void:
		if by_player:
			_last_player_ms = GameClock.ms)


func reset() -> void:
	value = 0.0
	tier = 0
	peak = 0.0
	budget = 5.0
	chain_budget = 6.0
	break_budget = 6.0
	time_in_tier = [0, 0, 0, 0, 0]
	_pairs.clear()
	sources.clear()
	_last_player_ms = -100000


static func tier_of(v: float) -> int:
	if v > 80.0:
		return 4
	if v > 60.0:
		return 3
	if v > 40.0:
		return 2
	if v > 20.0:
		return 1
	return 0


func add(amount: float, source: String) -> void:
	if amount <= 0.0:
		return
	value = clampf(value + amount, 0.0, 100.0)
	peak = maxf(peak, value)
	sources[source] = float(sources.get(source, 0.0)) + amount
	if amount >= 0.1:
		_last_gain_ms = GameClock.ms
	_check_tier()


func floor_value() -> float:
	var f := 0.0
	if ctx:
		f += ctx.rules.non_normal_count() * 6.0
		f += ctx.anomalies.active.size() * 5.0
		f += ctx.mutations.active.size() * 8.0
	return minf(f, 60.0)


## Room-driven chaos (collisions, chains, breaks) can only carry Deviation up
## to a soft cap. The cap rises with every bent rule (mutations that force a rule count) and recent
## player action, so a single rule left running (e.g. magnetism) settles around
## DISTORTED instead of snowballing to CATASTROPHIC on its own.
func soft_cap() -> float:
	var c := 32.0
	if ctx:
		c += ctx.rules.non_normal_count() * 7.0
		if GameClock.ms - _last_player_ms < 4000:
			c += 14.0
	return minf(c, 100.0)


func passive_factor() -> float:
	var over := value - soft_cap()
	if over <= 0.0:
		return 1.0
	return clampf(1.0 - over / 12.0, 0.0, 1.0)


func _check_tier() -> void:
	var t := tier_of(value)
	if t != tier:
		var up := t > tier
		tier = t
		ctx.events.deviation_tier_changed.emit(t, up)


func _on_rule(_rule: int, level: int, by_player: bool) -> void:
	if not by_player:
		return
	var now := GameClock.ms
	_recent_rule_changes.append(now)
	_last_player_ms = now
	while _recent_rule_changes.size() > 0 and now - _recent_rule_changes[0] > 20000:
		_recent_rule_changes.pop_front()
	var fatigue := 1.0 / (1.0 + (_recent_rule_changes.size() - 1) * 0.5)
	add((5.0 if level != 0 else 1.5) * fatigue, "rules")


func _on_impact(striker: Node, victim: Node, speed: float) -> void:
	if speed < 2.5:
		return
	var a := striker as Prop
	if a == null or a.is_debris:
		return
	var now := GameClock.ms
	var key := "%d:%d" % [a.get_instance_id(), victim.get_instance_id()]
	if now - int(_pairs.get(key, -100000)) < 2000:
		return
	_pairs[key] = now
	if _pairs.size() > 400:
		_pairs.clear()
	var gain := clampf((speed - 2.0) * 0.18, 0.05, 1.6) * sqrt(clampf(a.mass, 0.2, 10.0)) / (1.0 + a.boredom)
	a.boredom += 1.0
	if victim is Prop:
		(victim as Prop).boredom += 0.5
	gain = minf(gain, budget) * passive_factor()
	if gain <= 0.01:
		return
	budget -= gain
	add(gain, "impacts")


func _on_broken(p: Node, _cid: int) -> void:
	var pr := p as Prop
	if pr and not pr.is_debris and pr.kind != "paper" and pr.kind != "ceiling":
		var gain := minf(3.0, break_budget)
		break_budget -= gain
		add(gain * passive_factor(), "breaks")


func _on_chain_step(chain: Dictionary) -> void:
	# Longer chains are worth more per link, but chains share a budget too.
	var depth := int(chain.get("links", 1))
	var gain := minf(0.5 + minf(depth, 8) * 0.3, chain_budget)
	if gain <= 0.01:
		return
	chain_budget -= gain
	add(gain * passive_factor(), "chains")


func _process(delta: float) -> void:
	if ctx == null or not ctx.is_playing():
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	budget = minf(5.0, budget + real_dt * 1.2)
	chain_budget = minf(6.0, chain_budget + real_dt * 0.75)
	break_budget = minf(6.0, break_budget + real_dt * 0.4)
	time_in_tier[tier] += real_dt
	var since := GameClock.ms - _last_gain_ms
	if since > 3000:
		var fl := floor_value()
		if value > fl:
			value = maxf(fl, value - real_dt * (1.2 + value * 0.02))
			_check_tier()
		elif value < fl:
			value = minf(fl, value + real_dt * 2.0)
			peak = maxf(peak, value)
			_check_tier()

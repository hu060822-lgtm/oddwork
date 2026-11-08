class_name ChainTracker
extends Node
## Follows cause -> effect through the room.
## A chain starts from a player action, a rule change or a mutation. A prop
## that carries a live chain and hits another prop / device passes the chain
## on. Each pair counts once per chain, each prop at most twice, and a chain
## closes after 3.5 s with no new link.

const IDLE_MS := 3500
const MAX_LINKS := 30

var ctx: Node
var chains: Dictionary = {}
var finished: Array[Dictionary] = []  # this shift
var best_links: int = 0
var best_depth: int = 0
var total_links: int = 0
var _next_id: int = 1
var _live_id: int = -1
var _env_id: int = -1
var _env_until: int = 0


func setup(c: Node) -> void:
	ctx = c
	ctx.events.prop_impact.connect(_on_impact)
	ctx.events.prop_broken.connect(_on_broken)


func reset_shift() -> void:
	chains.clear()
	finished.clear()
	best_links = 0
	total_links = 0
	_live_id = -1


## env: environmental causes (rule changes, mutations, falling ceiling) do not
## tag every prop at once. Instead, for 2.5 s any prop that is not already in
## a chain and hits something becomes a root of this chain. That keeps
## "gravity flipped -> chair hit table -> cup flew" readable, instead of
## crediting every simultaneous collision in the room.
func start_chain(origin: String, props: Array, env: bool = false) -> int:
	var id := _next_id
	_next_id += 1
	var now := GameClock.ms
	chains[id] = {
		"id": id, "origin": origin, "steps": [origin], "links": 0,
		"pairs": {}, "counts": {}, "last_ms": now, "start_ms": now, "devices": 0,
		"breaks": 0, "depth": 0, "player_origin": origin.begins_with("你"),
	}
	if env:
		_env_id = id
		_env_until = now + 2500
		return id
	for p in props:
		var pr := p as Prop
		if pr:
			(chains[id]["counts"] as Dictionary)[pr.uid] = 1
		tag(pr, id, 0)
	return id


func tag(p: Prop, id: int, depth: int) -> void:
	if p == null or not chains.has(id):
		return
	p.chain_id = id
	p.chain_depth = depth
	p.chain_ms = GameClock.ms


func _add_step(ch: Dictionary, text: String) -> void:
	if int(ch["links"]) >= MAX_LINKS:
		return
	(ch["steps"] as Array).append(text)
	ch["links"] = int(ch["links"]) + 1
	ch["last_ms"] = GameClock.ms
	_live_id = int(ch["id"])
	total_links += 1
	ctx.events.chain_step.emit(ch)


func _on_impact(striker: Node, victim: Node, speed: float) -> void:
	var a := striker as Prop
	if a == null or speed < 2.0:
		return
	var now := GameClock.ms
	var b := victim as Prop
	if b == null or b.is_debris:
		return
	if not a.chain_active(now) or not chains.has(a.chain_id):
		if _env_id >= 0 and now < _env_until and chains.has(_env_id) and not (b.chain_active(now) and b.chain_id == _env_id):
			tag(a, _env_id, 0)
			(chains[_env_id]["counts"] as Dictionary)[a.uid] = 1
		else:
			return
	var ch: Dictionary = chains[a.chain_id]
	if b.chain_active(now) and b.chain_id == a.chain_id:
		return
	var key := "%d>%d" % [a.uid, b.uid]
	var pairs: Dictionary = ch["pairs"]
	if pairs.has(key) or pairs.has("%d>%d" % [b.uid, a.uid]):
		return
	var counts: Dictionary = ch["counts"]
	if int(counts.get(b.uid, 0)) >= 1:
		return
	pairs[key] = true
	counts[b.uid] = int(counts.get(b.uid, 0)) + 1
	tag(b, a.chain_id, a.chain_depth + 1)
	ch["depth"] = maxi(int(ch["depth"]), b.chain_depth)
	a.chain_ms = now
	_add_step(ch, b.describe())


func _on_broken(p: Node, cid: int) -> void:
	if cid < 0 or not chains.has(cid):
		return
	var ch: Dictionary = chains[cid]
	ch["breaks"] = int(ch["breaks"]) + 1
	_add_step(ch, "%s碎了" % (p as Prop).describe())


## A device (button, wire, glass, fan...) was triggered by `source`.
## Returns {id, depth, links} so the device can pass the chain on.
func on_device(device: Node, source: Node, by_player: bool, cid: int = -1, depth: int = 0) -> Dictionary:
	var now := GameClock.ms
	var label := "[%s]" % str(device.get("device_label_zh") if device.get("device_label_zh") != null else device.get("device_label"))
	var ch: Dictionary = {}
	if cid >= 0 and chains.has(cid):
		ch = chains[cid]
	elif source is Prop and (source as Prop).chain_active(now) and chains.has((source as Prop).chain_id):
		ch = chains[(source as Prop).chain_id]
		depth = (source as Prop).chain_depth + 1
	if ch.is_empty():
		var origin := "你啟動" if by_player else ("%s撞到" % (source as Prop).describe() if source is Prop else "")
		var id := start_chain(origin + label, [])
		ch = chains[id]
		ch["devices"] = 1
		return {"id": id, "depth": 0, "links": 0}
	var pairs: Dictionary = ch["pairs"]
	var key := "dev%d" % device.get_instance_id()
	if not pairs.has(key):
		pairs[key] = true
		ch["devices"] = int(ch["devices"]) + 1
		ch["depth"] = maxi(int(ch["depth"]), depth + 1)
		_add_step(ch, label)
	return {"id": int(ch["id"]), "depth": depth, "links": int(ch["links"])}


func on_spring(p: Prop) -> void:
	var now := GameClock.ms
	if p.chain_active(now) and chains.has(p.chain_id):
		var ch: Dictionary = chains[p.chain_id]
		var key := "spring%d" % p.uid
		if not (ch["pairs"] as Dictionary).has(key):
			(ch["pairs"] as Dictionary)[key] = true
			p.chain_ms = now
			_add_step(ch, "[彈簧]")


func live_chain() -> Dictionary:
	if _live_id >= 0 and chains.has(_live_id):
		var ch: Dictionary = chains[_live_id]
		if int(ch["links"]) > 0:
			return ch
	return {}


func _process(_delta: float) -> void:
	if ctx == null:
		return
	var now := GameClock.ms
	var done: Array[int] = []
	for id: int in chains:
		var ch: Dictionary = chains[id]
		if now - int(ch["last_ms"]) > IDLE_MS:
			done.append(id)
	for id in done:
		var ch: Dictionary = chains[id]
		chains.erase(id)
		if id == _live_id:
			_live_id = -1
		var links := int(ch["links"])
		if links >= 2:
			finished.append(ch)
			best_links = maxi(best_links, links)
			best_depth = maxi(best_depth, int(ch["depth"]))
			ctx.events.chain_finished.emit(ch)


static func describe(ch: Dictionary) -> String:
	var steps := PackedStringArray(ch.get("steps", []))
	var shown := steps
	if steps.size() > 9:
		shown = steps.slice(0, 4)
		shown.append("…")
		shown.append_array(steps.slice(steps.size() - 4))
	return " → ".join(shown)

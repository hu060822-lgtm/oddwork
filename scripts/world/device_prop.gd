class_name DeviceProp
extends Prop
## A movable prop that can be switched on: fan, TV, lamp, printer.
## Activation by a prop that is part of a chain continues that chain.

var on: bool = false
var device_label: String = "DEVICE"
var device_label_zh: String = "裝置"
var last_toggle_ms: int = -10000
var activations: int = 0
var out_chain_id: int = -1
var out_chain_depth: int = 0
var out_chain_ms: int = 0


func _init() -> void:
	super()
	is_device = true


func activate(source: Node, by_player: bool, cid: int = -1, depth: int = 0) -> void:
	var now := GameClock.ms
	if now - last_toggle_ms < 700:
		return
	last_toggle_ms = now
	set_on(not on if (by_player or not (source is Prop)) else true)
	activations += 1
	var links := 0
	if ctx:
		var res: Dictionary = ctx.chains.on_device(self, source, by_player, cid, depth)
		links = int(res.get("links", 0))
		out_chain_id = int(res.get("id", -1))
		out_chain_depth = int(res.get("depth", 0))
		out_chain_ms = now
		ctx.events.device_activated.emit(self, source, by_player, links)


func set_on(v: bool) -> void:
	on = v
	_apply_state()


func _apply_state() -> void:
	pass


func interact_text() -> String:
	return "%s %s" % ["關閉" if on else "開啟", device_label_zh]


## Tag a prop that this device affected so the chain continues through it.
func pass_chain(p: Prop) -> void:
	if out_chain_id < 0 or ctx == null:
		return
	var now := GameClock.ms
	if now - out_chain_ms > 12000:
		return
	if p.chain_active(now) and p.chain_id == out_chain_id:
		return
	ctx.chains.tag(p, out_chain_id, out_chain_depth + 1)

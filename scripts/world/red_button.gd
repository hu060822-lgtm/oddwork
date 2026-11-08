class_name RedButton
extends StaticBody3D
## Big red button on a podium. Pressed by the player (E) or by any prop that
## hits it. Wired to a device; the visible cable glows when it fires.

var ctx: Node
var linked: Node
var device_label: String = "BUTTON"
var device_label_zh: String = "紅色按鈕"
var cap: MeshInstance3D
var wire_mat: StandardMaterial3D
var last_press_ms: int = -10000
var presses: int = 0
var _glow: float = 0.0


func setup(c: Node, label: String) -> void:
	ctx = c
	device_label = label
	collision_layer = Prop.LAYER_WORLD
	collision_mask = 0
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 1.0, 0.5)
	base.mesh = bm
	base.position.y = 0.5
	base.material_override = Mats.solid(Mats.GREY_DARK, 0.6, 0.4)
	add_child(base)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.52, 0.08, 0.52)
	stripe.mesh = sm
	stripe.position.y = 0.85
	stripe.material_override = Mats.solid(Mats.YELLOW)
	add_child(stripe)
	cap = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.18
	cm.height = 0.1
	cm.radial_segments = 10
	cap.mesh = cm
	cap.position.y = 1.05
	cap.material_override = Mats.glow(Color(0.85, 0.08, 0.06), 0.6)
	add_child(cap)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.5, 1.1, 0.5)
	cs.shape = sh
	cs.position.y = 0.55
	add_child(cs)


func button_hit(speed: float, source: Node) -> void:
	if speed > 1.6:
		press(source, false)


func press(source: Node, by_player: bool) -> void:
	var now := GameClock.ms
	if now - last_press_ms < 1200:
		return
	last_press_ms = now
	presses += 1
	_glow = 1.0
	cap.position.y = 0.99
	if ctx == null:
		return
	ctx.audio.play_3d("button", global_position + Vector3.UP, 0.0)
	var res: Dictionary = ctx.chains.on_device(self, source, by_player)
	var links := int(res.get("links", 0))
	ctx.events.device_activated.emit(self, source, by_player, links)
	if is_instance_valid(linked) and linked.has_method("activate"):
		linked.call("activate", self, false, int(res.get("id", -1)), int(res.get("depth", 0)) + 1)


func interact_text() -> String:
	return "按下 %s" % device_label_zh


func _process(delta: float) -> void:
	if _glow > 0.0:
		_glow = maxf(0.0, _glow - delta * 1.2)
		if wire_mat:
			wire_mat.emission_energy_multiplier = 0.2 + _glow * 3.0
		if _glow < 0.7:
			cap.position.y = 1.05

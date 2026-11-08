class_name Tripwire
extends Area3D
## A taut yellow wire between two posts. Anything (except the player) that
## crosses it triggers the linked device.

var ctx: Node
var linked: Node
var device_label: String = "WIRE"
var device_label_zh: String = "電線絆線"
var wire_mat: StandardMaterial3D
var last_ms: int = -10000
var _glow: float = 0.0


func setup(c: Node, length: float) -> void:
	ctx = c
	collision_layer = 0
	collision_mask = Prop.LAYER_PROPS
	for x in [-length / 2.0, length / 2.0]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.08, 0.5, 0.08)
		post.mesh = pm
		post.position = Vector3(x, 0.25, 0)
		post.material_override = Mats.solid(Mats.GREY_DARK)
		add_child(post)
	var wire := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(length, 0.02, 0.02)
	wire.mesh = wm
	wire.position.y = 0.32
	wire_mat = StandardMaterial3D.new()
	wire_mat.albedo_color = Mats.YELLOW
	wire_mat.emission_enabled = true
	wire_mat.emission = Mats.YELLOW
	wire_mat.emission_energy_multiplier = 0.3
	wire.material_override = wire_mat
	add_child(wire)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(length, 0.3, 0.25)
	cs.shape = sh
	cs.position.y = 0.32
	add_child(cs)
	body_entered.connect(_on_enter)


func _on_enter(body: Node) -> void:
	if not body is Prop:
		return
	var p: Prop = body
	if p.held or p.is_debris or p.linear_velocity.length() < 0.8:
		return
	var now := GameClock.ms
	if now - last_ms < 2500:
		return
	last_ms = now
	_glow = 1.0
	if ctx == null:
		return
	ctx.audio.play_3d("zap", global_position, -2.0)
	var res: Dictionary = ctx.chains.on_device(self, p, false)
	ctx.events.device_activated.emit(self, p, false, int(res.get("links", 0)))
	if is_instance_valid(linked) and linked.has_method("activate"):
		linked.call("activate", self, false, int(res.get("id", -1)), int(res.get("depth", 0)) + 1)


func _process(delta: float) -> void:
	if _glow > 0.0:
		_glow = maxf(0.0, _glow - delta)
		wire_mat.emission_energy_multiplier = 0.3 + _glow * 4.0

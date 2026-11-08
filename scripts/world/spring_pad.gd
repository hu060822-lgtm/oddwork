class_name SpringPad
extends StaticBody3D
## Floor spring. Launches props and the player upward.

var ctx: Node
var top: MeshInstance3D
var _cool: Dictionary = {}
var _anim: float = 0.0


func setup(c: Node) -> void:
	ctx = c
	collision_layer = Prop.LAYER_WORLD
	collision_mask = 0
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.12, 1.2)
	base.mesh = bm
	base.position.y = 0.06
	base.material_override = Mats.solid(Mats.GREY_DARK, 0.5, 0.5)
	add_child(base)
	for i in 4:
		var coil := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.3
		tm.outer_radius = 0.36
		tm.rings = 10
		tm.ring_segments = 6
		coil.mesh = tm
		coil.position.y = 0.16 + i * 0.07
		coil.material_override = Mats.solid(Mats.METAL, 0.3, 0.9)
		add_child(coil)
	top = MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(1.0, 0.06, 1.0)
	top.mesh = tb
	top.position.y = 0.45
	top.material_override = Mats.solid(Mats.YELLOW)
	add_child(top)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.2, 0.12, 1.2)
	cs.shape = sh
	cs.position.y = 0.06
	add_child(cs)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Prop.LAYER_PROPS | Prop.LAYER_PLAYER
	var acs := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = Vector3(1.0, 0.5, 1.0)
	acs.shape = ash
	acs.position.y = 0.4
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_enter)


func _on_enter(body: Node) -> void:
	var now := GameClock.ms
	var key := body.get_instance_id()
	if now - int(_cool.get(key, -10000)) < 500:
		return
	_cool[key] = now
	_anim = 1.0
	if body is Prop:
		var p: Prop = body
		if p.held:
			return
		var up := 7.5 if ctx == null else 7.5 * clampf(sqrt(9.8 / maxf(absf(ctx.rules.gravity_strength()), 1.0)), 0.6, 1.6)
		p.linear_velocity = Vector3(p.linear_velocity.x * 0.6, up, p.linear_velocity.z * 0.6)
		if ctx:
			ctx.chains.on_spring(p)
			ctx.audio.play_3d("spring", global_position, 0.0)
	elif body.has_method("launch"):
		body.call("launch", 11.0)
		if ctx:
			ctx.audio.play_3d("spring", global_position, 0.0)


func _process(delta: float) -> void:
	if _anim > 0.0:
		_anim = maxf(0.0, _anim - delta * 3.0)
		top.position.y = 0.45 + sin(_anim * PI) * 0.18

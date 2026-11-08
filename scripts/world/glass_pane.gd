class_name GlassPane
extends StaticBody3D
## A breakable glass window set into a partition.

var ctx: Node
var size: Vector3
var device_label: String = "GLASS"
var broken: bool = false
var mesh: MeshInstance3D


func setup(c: Node, s: Vector3) -> void:
	ctx = c
	size = s
	collision_layer = Prop.LAYER_WORLD
	collision_mask = 0
	mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mesh.mesh = bm
	mesh.material_override = Mats.ghost(Color(0.6, 0.85, 0.8, 0.28))
	add_child(mesh)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = s
	cs.shape = sh
	add_child(cs)


func glass_hit(speed: float, source: Node) -> void:
	if broken:
		return
	var mult := 1.0
	if ctx:
		mult = ctx.anomalies.damage_mult()
	if speed * mult < 5.5:
		if ctx and speed > 2.5:
			ctx.audio.play_3d("glass_tap", global_position, -4.0)
		return
	shatter(source)


func shatter(source: Node) -> void:
	if broken:
		return
	broken = true
	visible = false
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	if ctx == null:
		return
	ctx.audio.play_3d("glass_break", global_position, 2.0)
	ctx.room.spawn_shards(global_position, size, Color(0.7, 0.9, 0.85))
	var res: Dictionary = ctx.chains.on_device(self, source, false)
	ctx.events.device_activated.emit(self, source, false, int(res.get("links", 0)))
	ctx.deviation.add(4.0, "glass")
	ctx.stats_add("breaks", 1)


func restore() -> void:
	broken = false
	visible = true
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", false)

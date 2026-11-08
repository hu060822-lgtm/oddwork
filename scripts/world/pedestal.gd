class_name Pedestal
extends AnimatableBody3D
## Narrow wobbling pillar used by balance missions.

var wobble: float = 0.12
var speed: float = 1.0
var _t: float = 0.0


func setup() -> void:
	collision_layer = Prop.LAYER_WORLD
	collision_mask = 0
	sync_to_physics = true
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.2
	cm.height = 1.2
	cm.radial_segments = 8
	col.mesh = cm
	col.position.y = 0.6
	col.material_override = Mats.solid(Mats.GREY, 0.5, 0.4)
	add_child(col)
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.3
	tm.bottom_radius = 0.3
	tm.height = 0.05
	tm.radial_segments = 10
	top.mesh = tm
	top.position.y = 1.22
	top.material_override = Mats.solid(Mats.RED_DARK)
	add_child(top)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.3
	sh.height = 0.05
	cs.shape = sh
	cs.position.y = 1.22
	add_child(cs)
	var cs2 := CollisionShape3D.new()
	var sh2 := CylinderShape3D.new()
	sh2.radius = 0.15
	sh2.height = 1.2
	cs2.shape = sh2
	cs2.position.y = 0.6
	add_child(cs2)


func _physics_process(delta: float) -> void:
	_t += delta * speed
	rotation = Vector3(sin(_t * 1.3) * wobble, 0.0, sin(_t * 0.9 + 1.0) * wobble)

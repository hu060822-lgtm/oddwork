class_name TargetZone
extends Node3D
## Visual + AABB used by delivery-style missions.

var size: Vector3 = Vector3.ONE
var label: Label3D
var mat: StandardMaterial3D
var _t: float = 0.0


func setup(s: Vector3, text: String, color: Color) -> void:
	size = s
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(s.x, 0.02, s.z)
	edge.mesh = em
	edge.position.y = -s.y / 2.0 + 0.01
	edge.material_override = Mats.glow(color, 1.5)
	add_child(edge)
	label = Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.font_size = 48
	label.pixel_size = 0.0011
	label.modulate = color
	label.outline_size = 8
	label.position.y = s.y / 2.0 + 0.35
	add_child(label)


func contains(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) <= size.x / 2.0 and absf(l.y) <= size.y / 2.0 and absf(l.z) <= size.z / 2.0


func _process(delta: float) -> void:
	_t += delta
	if mat:
		mat.albedo_color.a = 0.12 + sin(_t * 3.0) * 0.05

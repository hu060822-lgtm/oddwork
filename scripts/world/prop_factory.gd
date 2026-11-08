class_name PropFactory
extends RefCounted
## Builds low-poly props out of primitive meshes. Each recipe sets the
## material type, mass, breakability and display names.

const NAMES_ZH := {
	"cup": "杯子", "chair": "椅子", "table": "桌子", "apple": "蘋果", "ball": "球",
	"box": "箱子", "barrel": "桶子", "fan": "風扇", "battery": "電池", "printer": "印表機",
	"plate": "金屬板", "tv": "電視", "lamp": "燈", "paper": "紙張", "debris": "碎片",
	"ceiling": "天花板碎塊",
}


static func make(kind: String, ctx: Node) -> Prop:
	var p: Prop
	match kind:
		"fan":
			p = _fan()
		"tv":
			p = _tv()
		"lamp":
			p = _lamp()
		"printer":
			p = _printer()
		_:
			p = Prop.new()
			_build_plain(p, kind)
	p.kind = kind
	p.ctx = ctx
	p.name = "%s_%d" % [kind, p.uid]
	if p.display_name == "":
		p.display_name = str(NAMES_ZH.get(kind, kind))
	p.finish_setup()
	return p


static func _build_plain(p: Prop, kind: String) -> void:
	match kind:
		"cup":
			var cols := [Mats.WHITE, Mats.YELLOW, Color(0.75, 0.25, 0.2)]
			var c: Color = cols[randi() % cols.size()]
			p.add_cyl(0.075, 0.13, Vector3(0, 0.065, 0), c, true, 8, 0.3)
			p.add_box(Vector3(0.025, 0.07, 0.06), Vector3(0.09, 0.07, 0), c, false, 0.3)
			_cfg(p, "ceramic", 0.3, 0.12, 0.5, 5.6, 40.0)
			p.continuous_cd = true
		"chair":
			var w := Mats.WOOD if randf() < 0.6 else Mats.RED_DARK
			p.add_box(Vector3(0.46, 0.06, 0.46), Vector3(0, 0.46, 0), w)
			p.add_box(Vector3(0.46, 0.5, 0.05), Vector3(0, 0.74, -0.2), w)
			for x in [-0.2, 0.2]:
				for z in [-0.2, 0.2]:
					p.add_box(Vector3(0.05, 0.44, 0.05), Vector3(x, 0.22, z), Mats.GREY_DARK, true, 0.5, 0.6)
			_cfg(p, "wood", 5.0, 0.15, 0.6, 13.0, 140.0)
		"table":
			p.add_box(Vector3(1.6, 0.07, 0.9), Vector3(0, 0.75, 0), Mats.BEIGE_DARK)
			for x in [-0.72, 0.72]:
				for z in [-0.38, 0.38]:
					p.add_box(Vector3(0.07, 0.72, 0.07), Vector3(x, 0.36, z), Mats.GREY_DARK, true, 0.5, 0.6)
			_cfg(p, "wood", 26.0, 0.1, 0.7, 17.0, 260.0)
		"apple":
			p.add_sphere(0.075, Vector3(0, 0.075, 0), Color(0.78, 0.12, 0.1), true, 0.4)
			p.add_box(Vector3(0.012, 0.04, 0.012), Vector3(0, 0.16, 0), Mats.WOOD_DARK, false)
			_cfg(p, "fruit", 0.2, 0.1, 0.8, 10.0, 30.0)
			p.continuous_cd = true
		"ball":
			var bc: Color = [Mats.YELLOW, Color(0.85, 0.2, 0.15), Mats.GREEN_FL.darkened(0.3)][randi() % 3]
			p.add_sphere(0.16, Vector3(0, 0.16, 0), bc, true, 0.45)
			_cfg(p, "rubber", 0.45, 0.78, 0.7, 999.0, 100.0)
			p.continuous_cd = true
		"box":
			p.add_box(Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), Mats.CARDBOARD)
			p.add_box(Vector3(0.51, 0.06, 0.12), Vector3(0, 0.5, 0), Color(0.82, 0.74, 0.5), false)
			_cfg(p, "cardboard", 1.6, 0.12, 0.7, 8.0, 100.0)
		"barrel":
			p.add_cyl(0.3, 0.9, Vector3(0, 0.45, 0), Mats.RED_DARK, true, 10, 0.5, 0.5)
			p.add_cyl(0.305, 0.08, Vector3(0, 0.62, 0), Mats.YELLOW, false, 10)
			p.add_cyl(0.305, 0.08, Vector3(0, 0.28, 0), Mats.YELLOW, false, 10)
			_cfg(p, "metal", 16.0, 0.12, 0.5, 999.0, 400.0)
			p.magnetic = true
		"battery":
			p.add_cyl(0.06, 0.2, Vector3(0, 0.1, 0), Mats.YELLOW, true, 8, 0.4)
			p.add_cyl(0.062, 0.07, Vector3(0, 0.035, 0), Color(0.08, 0.08, 0.08), false, 8)
			p.add_cyl(0.02, 0.03, Vector3(0, 0.215, 0), Mats.METAL, false, 6, 0.3, 0.8)
			_cfg(p, "metal", 0.6, 0.2, 0.5, 999.0, 100.0)
			p.magnetic = true
			p.continuous_cd = true
			p.display_name = "電池"
		"plate":
			p.add_box(Vector3(0.8, 0.04, 0.6), Vector3(0, 0.02, 0), Mats.METAL, true, 0.35, 0.8)
			_cfg(p, "metal", 5.0, 0.15, 0.4, 999.0, 400.0)
			p.magnetic = true
		"paper":
			p.add_box(Vector3(0.21, 0.01, 0.29), Vector3.ZERO, Mats.WHITE, true, 0.9)
			_cfg(p, "paper", 0.05, 0.05, 0.8, 999.0, 10.0)
			p.set_damp(2.2, 2.0)
			p.lifetime = 30.0
		"debris":
			var s := Vector3(randf_range(0.06, 0.16), randf_range(0.04, 0.12), randf_range(0.06, 0.16))
			p.add_box(s, Vector3.ZERO, Mats.GREY)
			_cfg(p, "debris", 0.1, 0.2, 0.6, 999.0, 10.0)
			p.is_debris = true
			p.lifetime = 5.0
			p.grabbable = false
		"ceiling":
			p.add_box(Vector3(1.0, 0.06, 1.0), Vector3.ZERO, Mats.WHITE.darkened(0.08))
			_cfg(p, "cardboard", 1.2, 0.1, 0.7, 6.0, 40.0)
			p.lifetime = 14.0
		_:
			p.add_box(Vector3(0.3, 0.3, 0.3), Vector3(0, 0.15, 0), Color.MAGENTA)
			_cfg(p, "wood", 1.0, 0.2, 0.6, 99.0, 100.0)


static func _cfg(p: Prop, mat: String, m: float, bounce: float, fric: float, brk: float, hp: float) -> void:
	p.mat_type = mat
	p.base_mass = m
	p.base_bounce = bounce
	p.base_friction = fric
	p.break_speed = brk
	p.max_hp = hp


static func _fan() -> Prop:
	var p := FanProp.new()
	p.add_box(Vector3(0.5, 0.08, 0.5), Vector3(0, 0.04, 0), Mats.GREY_DARK, true, 0.5, 0.5)
	p.add_box(Vector3(0.06, 0.55, 0.06), Vector3(0, 0.33, 0), Mats.METAL, true, 0.4, 0.7)
	var head := p.add_cyl(0.38, 0.18, Vector3(0, 0.75, 0), Mats.YELLOW, false, 10, 0.5, 0.3)
	head.rotation.x = PI / 2.0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.78, 0.78, 0.22)
	cs.shape = sh
	cs.position = Vector3(0, 0.75, 0)
	p.add_child(cs)
	p.blades = Node3D.new()
	p.blades.position = Vector3(0, 0.75, 0.1)
	p.visual.add_child(p.blades)
	for i in 3:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, 0.62, 0.02)
		b.mesh = bm
		b.material_override = Mats.solid(Mats.GREY_DARK)
		b.rotation.z = TAU * i / 3.0
		p.blades.add_child(b)
	_cfg(p, "metal", 9.0, 0.1, 0.6, 15.0, 160.0)
	p.magnetic = true
	return p


static func _tv() -> Prop:
	var p := TvProp.new()
	p.add_box(Vector3(0.62, 0.5, 0.5), Vector3(0, 0.25, 0), Color(0.36, 0.33, 0.28), true, 0.6)
	p.screen = p.add_box(Vector3(0.48, 0.36, 0.02), Vector3(0, 0.27, 0.255), Color(0.08, 0.1, 0.09), false, 0.2)
	p.add_box(Vector3(0.02, 0.3, 0.02), Vector3(0.12, 0.62, 0), Mats.METAL, false)
	p.add_box(Vector3(0.02, 0.3, 0.02), Vector3(-0.12, 0.62, 0), Mats.METAL, false)
	var eye := Node3D.new()
	eye.position = Vector3(0, 0.27, 0.27)
	eye.visible = false
	p.visual.add_child(eye)
	var white := MeshInstance3D.new()
	var wm := SphereMesh.new()
	wm.radius = 0.13
	wm.height = 0.1
	white.mesh = wm
	white.material_override = Mats.glow(Color(1, 0.95, 0.9), 1.2)
	eye.add_child(white)
	var pupil := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.05
	pm.height = 0.06
	pupil.mesh = pm
	pupil.position = Vector3(0, 0, 0.04)
	pupil.material_override = Mats.solid(Color.BLACK)
	eye.add_child(pupil)
	p.eye = eye
	_cfg(p, "glass", 12.0, 0.1, 0.6, 12.0, 140.0)
	p.call_deferred("set_on", false)
	return p


static func _lamp() -> Prop:
	var p := LampProp.new()
	p.add_cyl(0.18, 0.05, Vector3(0, 0.025, 0), Mats.GREY_DARK, true, 8)
	p.add_cyl(0.025, 1.3, Vector3(0, 0.68, 0), Mats.METAL, true, 6)
	var shade := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.24
	cm.height = 0.25
	cm.radial_segments = 8
	shade.mesh = cm
	shade.material_override = Mats.solid(Mats.YELLOW.lightened(0.2))
	shade.position = Vector3(0, 1.38, 0)
	p.visual.add_child(shade)
	p.bulb = p.add_sphere(0.06, Vector3(0, 1.3, 0), Color(0.7, 0.68, 0.6), false)
	p.light = OmniLight3D.new()
	p.light.position = Vector3(0, 1.2, 0)
	p.light.light_color = Color(1.0, 0.85, 0.55)
	p.light.omni_range = 4.5
	p.light.light_energy = 1.3
	p.visual.add_child(p.light)
	_cfg(p, "glass", 3.5, 0.1, 0.6, 8.5, 60.0)
	p.call_deferred("set_on", true)
	return p


static func _printer() -> Prop:
	var p := PrinterProp.new()
	p.add_box(Vector3(0.62, 0.36, 0.5), Vector3(0, 0.18, 0), Color(0.82, 0.8, 0.74), true, 0.5)
	p.add_box(Vector3(0.5, 0.03, 0.2), Vector3(0, 0.3, 0.3), Mats.GREY, false)
	p.add_box(Vector3(0.1, 0.03, 0.03), Vector3(0.2, 0.37, 0.15), Mats.GREEN_FL, false)
	_cfg(p, "plastic", 13.0, 0.1, 0.6, 14.0, 160.0)
	return p

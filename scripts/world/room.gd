class_name Room
extends Node3D
## Builds the main room: an over-lit, slightly wrong office/workshop.
## Owns every prop, fixture, mission zone spot and the debris pool.

const HALF_X := 8.0
const HALF_Z := 6.0
const HEIGHT := 4.5
const HATCH := Vector3(0.0, 4.0, 0.0)
const MAX_DEBRIS := 40
const MAX_PAPER := 16

var ctx: Node
var props: Array[Prop] = []
var props_root: Node3D
var floor_tiles: Array[StaticBody3D] = []
var wall_bodies: Array[StaticBody3D] = []
var ceiling_lights: Array[OmniLight3D] = []
var light_panels: Array[MeshInstance3D] = []
var sun: DirectionalLight3D
var env: Environment
var buttons: Dictionary = {}
var devices: Dictionary = {}
var glass: Array[GlassPane] = []
var spring: SpringPad
var tripwire: Tripwire
var pedestal: Pedestal
var cctv: Node3D
var cctv_led: MeshInstance3D
var pockets: Array[Area3D] = []
var zone_spots: Dictionary = {}
var fan_spots: Array = []
var _layout: Array = []  # [kind, Transform3D]
var _debris: Array[Prop] = []
var _papers: Array[Prop] = []
var _respawn_queue: Array = []
var _respawn_t: float = 0.0
var _oob_t: float = 0.0
var _extra_glass: Array[GlassPane] = []


func build(c: Node) -> void:
	ctx = c
	_build_environment()
	_build_shell()
	_build_mezzanine()
	_build_partition()
	_build_decor()
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	_build_fixtures()
	_define_layout()
	_define_zones()
	_build_pockets()
	for entry in _layout:
		spawn(str(entry[0]), entry[1])
	_wire_fixtures()


# ---------------------------------------------------------------- shell
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.86, 0.78)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.76, 0.66)
	env.fog_density = 0.012
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-72, 25, 0)
	sun.light_energy = 0.55
	sun.light_color = Color(1.0, 0.98, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)


func _static_box(size: Vector3, pos: Vector3, color: Color, friction: float = 0.7, parent: Node = null, rough: float = 0.9) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = Prop.LAYER_WORLD
	sb.collision_mask = 0
	sb.position = pos
	var pm := PhysicsMaterial.new()
	pm.friction = friction
	pm.bounce = 0.0
	sb.physics_material_override = pm
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Mats.solid(color, rough)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	(parent if parent else self).add_child(sb)
	return sb


func _deco_box(size: Vector3, pos: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func _build_shell() -> void:
	# Floor: 4 x 3 tiles of 4 m. Each tile owns its physics + render material so
	# FRICTION / PATCHWORK can change them one by one.
	for ix in 4:
		for iz in 3:
			var pos := Vector3(-6.0 + ix * 4.0, -0.1, -4.0 + iz * 4.0)
			var shade := 0.47 if (ix + iz) % 2 == 0 else 0.42
			var tile := _static_box(Vector3(4.0, 0.2, 4.0), pos, Color(shade, shade, shade * 0.96), 0.8)
			var mi: MeshInstance3D = tile.get_child(0)
			mi.material_override = Mats.unique(Color(shade, shade, shade * 0.96), 0.8)
			tile.set_meta("base_color", Color(shade, shade, shade * 0.96))
			tile.set_meta("friction", 0.8)
			floor_tiles.append(tile)
	var wall_c := Mats.BEIGE
	wall_bodies.append(_static_box(Vector3(16.8, HEIGHT, 0.4), Vector3(0, HEIGHT / 2.0, -HALF_Z - 0.2), wall_c, 0.5))
	wall_bodies.append(_static_box(Vector3(16.8, HEIGHT, 0.4), Vector3(0, HEIGHT / 2.0, HALF_Z + 0.2), wall_c, 0.5))
	wall_bodies.append(_static_box(Vector3(0.4, HEIGHT, 12.8), Vector3(-HALF_X - 0.2, HEIGHT / 2.0, 0), wall_c, 0.5))
	wall_bodies.append(_static_box(Vector3(0.4, HEIGHT, 12.8), Vector3(HALF_X + 0.2, HEIGHT / 2.0, 0), wall_c, 0.5))
	var ceil := _static_box(Vector3(16.8, 0.3, 12.8), Vector3(0, HEIGHT + 0.15, 0), Mats.WHITE.darkened(0.05), 0.5)
	(ceil.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall_bodies.append(ceil)
	# Baseboard, dado stripe.
	var red := Mats.solid(Mats.RED_DARK)
	var stripe := Mats.solid(Mats.YELLOW)
	for z in [-HALF_Z + 0.01, HALF_Z - 0.01]:
		_deco_box(Vector3(16.0, 0.18, 0.04), Vector3(0, 0.09, z), red)
		_deco_box(Vector3(16.0, 0.06, 0.03), Vector3(0, 1.1, z), stripe)
	for x in [-HALF_X + 0.01, HALF_X - 0.01]:
		_deco_box(Vector3(0.04, 0.18, 12.0), Vector3(x, 0.09, 0), red)
		_deco_box(Vector3(0.03, 0.06, 12.0), Vector3(x, 1.1, 0), stripe)
	# Ceiling grid + fluorescent panels.
	var grid := Mats.solid(Mats.GREY)
	for i in 9:
		_deco_box(Vector3(0.04, 0.03, 12.0), Vector3(-8.0 + i * 2.0, HEIGHT - 0.01, 0), grid)
	for i in 7:
		_deco_box(Vector3(16.0, 0.03, 0.04), Vector3(0, HEIGHT - 0.01, -6.0 + i * 2.0), grid)
	var panel_mat := Mats.glow(Color(0.97, 1.0, 0.9), 2.4)
	for x in [-5.0, 0.0, 5.0]:
		for z in [-3.0, 3.0]:
			light_panels.append(_deco_box(Vector3(1.6, 0.04, 0.5), Vector3(x, HEIGHT - 0.03, z), panel_mat))
	for x in [-4.0, 4.0]:
		for z in [-2.5, 2.5]:
			var l := OmniLight3D.new()
			l.position = Vector3(x, HEIGHT - 0.4, z)
			l.omni_range = 9.0
			l.light_energy = 0.75
			l.light_color = Color(0.95, 1.0, 0.88)
			add_child(l)
			ceiling_lights.append(l)
	# Ceiling hatch (where restocked objects drop from).
	_deco_box(Vector3(1.2, 0.02, 1.2), Vector3(HATCH.x, HEIGHT - 0.02, HATCH.z), Mats.solid(Color(0.05, 0.05, 0.05)))
	_deco_box(Vector3(1.3, 0.025, 0.06), Vector3(HATCH.x, HEIGHT - 0.025, HATCH.z - 0.62), stripe)
	_deco_box(Vector3(1.3, 0.025, 0.06), Vector3(HATCH.x, HEIGHT - 0.025, HATCH.z + 0.62), stripe)


func _build_mezzanine() -> void:
	# Raised storage shelf along the north-west wall, reached by a ramp.
	_static_box(Vector3(5.9, 0.2, 1.8), Vector3(-4.95, 1.9, -5.1), Mats.GREY_DARK, 0.8, null, 0.6)
	_static_box(Vector3(5.9, 0.12, 0.06), Vector3(-4.95, 2.06, -4.2), Mats.YELLOW, 0.6)
	for x in [-7.6, -5.0, -2.3]:
		_static_box(Vector3(0.15, 1.8, 0.15), Vector3(x, 0.9, -4.3), Mats.GREY_DARK, 0.5, null, 0.5)
	var ramp := _static_box(Vector3(3.7, 0.2, 1.4), Vector3(-0.35, 0.92, -5.25), Mats.GREY, 0.9)
	ramp.rotation.z = -atan2(2.0, 3.1)
	# Hazard chevrons on the ramp.
	for i in 5:
		var m := _deco_box(Vector3(0.12, 0.01, 1.35), Vector3(-1.5 + i * 0.6, 0.11, 0.0), Mats.solid(Mats.YELLOW), ramp)
		m.position.y = 0.105


func _build_partition() -> void:
	# Low wall with glass panes splitting off the "office" in the south-east.
	_static_box(Vector3(0.3, 1.0, 5.0), Vector3(2.2, 0.5, 3.5), Mats.BEIGE_DARK, 0.6)
	_static_box(Vector3(0.34, 0.1, 5.0), Vector3(2.2, 2.65, 3.5), Mats.GREY_DARK, 0.5)
	for z in [1.05, 5.95]:
		_static_box(Vector3(0.3, 2.7, 0.1), Vector3(2.2, 1.35, z), Mats.GREY_DARK, 0.5)
	for z in [2.25, 4.75]:
		var g := GlassPane.new()
		g.position = Vector3(2.2, 1.8, z)
		add_child(g)
		g.setup(ctx, Vector3(0.05, 1.6, 2.35))
		glass.append(g)


func _build_decor() -> void:
	# Door (never opens), exit sign, wall clock, pipes, cabinet, CCTV.
	_deco_box(Vector3(1.2, 2.2, 0.08), Vector3(-3.0, 1.1, HALF_Z - 0.04), Mats.solid(Mats.RED_DARK, 0.6))
	_deco_box(Vector3(0.06, 0.06, 0.06), Vector3(-2.55, 1.05, HALF_Z - 0.1), Mats.solid(Mats.METAL, 0.3, 0.9))
	_deco_box(Vector3(0.6, 0.2, 0.05), Vector3(-3.0, 2.5, HALF_Z - 0.04), Mats.glow(Mats.GREEN_FL, 2.5))
	var exit := Label3D.new()
	exit.text = "EXIT"
	exit.font_size = 40
	exit.pixel_size = 0.005
	exit.modulate = Color(0.02, 0.15, 0.04)
	exit.position = Vector3(-3.0, 2.5, HALF_Z - 0.075)
	exit.rotation.y = PI
	add_child(exit)
	var sign := Label3D.new()
	sign.text = "ROOM 0  —  PLEASE BEHAVE NORMALLY"
	sign.font_size = 56
	sign.pixel_size = 0.006
	sign.modulate = Mats.RED_DARK
	sign.position = Vector3(2.0, 3.4, -HALF_Z + 0.03)
	add_child(sign)
	var pipe := Mats.solid(Mats.METAL.darkened(0.2), 0.4, 0.8)
	_deco_box(Vector3(16.0, 0.14, 0.14), Vector3(0, 4.05, -HALF_Z + 0.25), pipe)
	_deco_box(Vector3(0.14, 0.14, 12.0), Vector3(HALF_X - 0.25, 3.85, 0), pipe)
	_deco_box(Vector3(0.14, 4.0, 0.14), Vector3(HALF_X - 0.25, 2.0, -HALF_Z + 0.25), pipe)
	# Caution floor stripes in the machinery corner.
	for i in 6:
		_deco_box(Vector3(0.18, 0.012, 2.2), Vector3(5.6 + i * 0.42, 0.006, -4.6), Mats.solid(Mats.YELLOW if i % 2 == 0 else Color(0.08, 0.08, 0.08)))
	# TV cabinet.
	_static_box(Vector3(0.8, 0.7, 1.3), Vector3(7.45, 0.35, 3.0), Mats.WOOD_DARK, 0.7)
	# Desk-side filing cabinet.
	_static_box(Vector3(0.6, 1.3, 0.6), Vector3(7.5, 0.65, -2.6), Mats.GREY, 0.6, null, 0.5)
	# CCTV camera in the corner. It turns to watch the player.
	cctv = Node3D.new()
	cctv.position = Vector3(-7.6, 4.15, 5.6)
	add_child(cctv)
	var body := _deco_box(Vector3(0.18, 0.18, 0.42), Vector3(0, 0, 0.12), Mats.solid(Mats.WHITE.darkened(0.15), 0.5), cctv)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_deco_box(Vector3(0.12, 0.12, 0.04), Vector3(0, 0, 0.34), Mats.solid(Color(0.05, 0.05, 0.05)), cctv)
	cctv_led = _deco_box(Vector3(0.04, 0.04, 0.02), Vector3(0.06, 0.07, 0.34), Mats.glow(Color(1.0, 0.1, 0.05), 3.0), cctv)
	_deco_box(Vector3(0.06, 0.3, 0.06), Vector3(-7.75, 4.35, 5.75), Mats.solid(Mats.GREY_DARK))


func _build_fixtures() -> void:
	var a := RedButton.new()
	a.position = Vector3(3.0, 0, -0.8)
	add_child(a)
	a.setup(ctx, "BUTTON A")
	a.device_label_zh = "紅色按鈕 A"
	buttons["A"] = a
	var b := RedButton.new()
	b.position = Vector3(-6.6, 2.0, -5.5)
	add_child(b)
	b.setup(ctx, "BUTTON B")
	b.device_label_zh = "紅色按鈕 B"
	buttons["B"] = b
	spring = SpringPad.new()
	spring.position = Vector3(-0.2, 0, 2.6)
	add_child(spring)
	spring.setup(ctx)
	tripwire = Tripwire.new()
	tripwire.position = Vector3(-0.8, 0, -3.0)
	add_child(tripwire)
	tripwire.setup(ctx, 2.4)
	pedestal = Pedestal.new()
	pedestal.position = Vector3(-6.5, 0, 4.0)
	add_child(pedestal)
	pedestal.setup()


func _wire_fixtures() -> void:
	buttons["A"].linked = devices.get("fan")
	buttons["B"].linked = devices.get("printer")
	tripwire.linked = devices.get("tv")
	_draw_cable(buttons["A"].global_position + Vector3(0, 0.02, 0), devices["fan"].global_position + Vector3(0, 0.02, 0), buttons["A"])
	_draw_cable(buttons["B"].global_position + Vector3(0, 0.02, 0), Vector3(-2.0, 2.02, -5.5), buttons["B"])
	_draw_cable(tripwire.global_position + Vector3(1.2, 0.02, 0), Vector3(7.0, 0.02, 3.0), tripwire)


func _draw_cable(from: Vector3, to: Vector3, owner_node: Node) -> void:
	# A floor-hugging cable: two straight segments (x then z).
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Mats.YELLOW.darkened(0.2)
	mat.emission_enabled = true
	mat.emission = Mats.YELLOW
	mat.emission_energy_multiplier = 0.2
	owner_node.set("wire_mat", mat)
	var mid := Vector3(to.x, from.y, from.z)
	for seg in [[from, mid], [mid, to]]:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var seg_len := a.distance_to(b)
		if seg_len < 0.05:
			continue
		var c := (a + b) / 2.0
		var size := Vector3(seg_len + 0.04, 0.03, 0.04) if absf(a.x - b.x) > absf(a.z - b.z) else Vector3(0.04, 0.03, seg_len + 0.04)
		_deco_box(size, c, mat)


func _build_pockets() -> void:
	for pos in [Vector3(-3.0, 1.4, -1.5), Vector3(4.6, 1.4, 1.8), Vector3(-5.5, 2.4, 3.6)]:
		var a := Area3D.new()
		a.position = pos
		a.collision_layer = 0
		a.collision_mask = Prop.LAYER_PROPS
		a.monitoring = false
		a.visible = false
		a.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		a.gravity = 1.2
		a.linear_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		a.linear_damp = 5.0
		a.angular_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		a.angular_damp = 5.0
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 1.6
		cs.shape = sh
		a.add_child(cs)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.6
		sm.height = 3.2
		sm.radial_segments = 16
		sm.rings = 8
		mi.mesh = sm
		mi.material_override = Mats.ghost(Color(0.5, 0.75, 1.0, 0.12))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.add_child(mi)
		add_child(a)
		pockets.append(a)


func set_pockets(enabled: bool) -> void:
	for a in pockets:
		a.monitoring = enabled
		a.visible = enabled
		a.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE if enabled else Area3D.SPACE_OVERRIDE_DISABLED
		a.linear_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE if enabled else Area3D.SPACE_OVERRIDE_DISABLED
		a.angular_damp_space_override = Area3D.SPACE_OVERRIDE_REPLACE if enabled else Area3D.SPACE_OVERRIDE_DISABLED


# ---------------------------------------------------------------- layout
func _t(pos: Vector3, yaw_deg: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)


func _define_layout() -> void:
	var L := _layout
	# Break area.
	L.append(["table", _t(Vector3(-3.5, 0, 1.5))])
	L.append(["chair", _t(Vector3(-4.6, 0, 1.5), 90)])
	L.append(["chair", _t(Vector3(-2.4, 0, 1.5), -90)])
	L.append(["chair", _t(Vector3(-3.5, 0, 0.5), 0)])
	L.append(["chair", _t(Vector3(-3.5, 0, 2.5), 180)])
	for x in [-4.1, -3.6, -3.0]:
		L.append(["cup", _t(Vector3(x, 0.8, 1.35))])
	for x in [-3.9, -3.3, -2.9]:
		L.append(["apple", _t(Vector3(x, 0.8, 1.75))])
	L.append(["apple", _t(Vector3(-1.8, 0.05, 3.6))])
	# Desk area.
	L.append(["table", _t(Vector3(5.0, 0, -2.6))])
	L.append(["printer", _t(Vector3(5.3, 0.8, -2.65), 0)])
	L.append(["battery", _t(Vector3(4.5, 0.82, -2.4))])
	L.append(["battery", _t(Vector3(4.3, 0.82, -2.8))])
	L.append(["cup", _t(Vector3(4.6, 0.8, -2.2))])
	L.append(["chair", _t(Vector3(5.0, 0, -1.6), 180)])
	# Machinery corner.
	L.append(["fan", _t(Vector3(7.1, 0, -4.6), -90)])
	L.append(["barrel", _t(Vector3(6.6, 0, -5.4))])
	L.append(["plate", _t(Vector3(5.6, 0.05, -5.2))])
	# Office behind the glass.
	L.append(["tv", _t(Vector3(7.4, 0.72, 3.0), -90)])
	L.append(["lamp", _t(Vector3(6.6, 0, 0.6))])
	for pos in [Vector3(4.6, 0, 5.2), Vector3(5.2, 0, 5.2), Vector3(4.9, 0.5, 5.2), Vector3(5.8, 0, 5.3), Vector3(4.7, 0, 4.6), Vector3(3.1, 0, 3.0)]:
		L.append(["box", _t(pos, randf_range(-20, 20))])
	L.append(["barrel", _t(Vector3(3.3, 0, 5.3))])
	L.append(["barrel", _t(Vector3(3.3, 0, 4.5))])
	L.append(["plate", _t(Vector3(6.6, 0.05, 5.0))])
	L.append(["ball", _t(Vector3(4.4, 0.1, 1.8))])
	# Open floor.
	L.append(["ball", _t(Vector3(0.6, 0.1, 0.4))])
	L.append(["ball", _t(Vector3(-1.4, 0.1, 4.8))])
	L.append(["lamp", _t(Vector3(-7.3, 0, -0.2))])
	L.append(["box", _t(Vector3(-7.2, 0, -3.4))])
	L.append(["box", _t(Vector3(-6.6, 0, -3.5), 30)])
	L.append(["chair", _t(Vector3(1.0, 0, -1.8), 40)])
	# Mezzanine.
	L.append(["box", _t(Vector3(-7.3, 2.05, -5.3))])
	L.append(["box", _t(Vector3(-5.0, 2.05, -5.4), 15)])
	L.append(["battery", _t(Vector3(-4.2, 2.05, -5.2))])
	L.append(["plate", _t(Vector3(-3.0, 2.06, -5.2))])
	L.append(["barrel", _t(Vector3(-5.9, 2.0, -5.5))])
	fan_spots = [_t(Vector3(7.1, 0, -4.6), -90), _t(Vector3(-7.3, 0, 3.0), 90), _t(Vector3(0.5, 0, 5.4), 180), _t(Vector3(-2.6, 2.0, -5.4), 90), _t(Vector3(1.0, 0, -5.4), 0)]


func _define_zones() -> void:
	# name -> {pos, size, tags}
	zone_spots = {
		"mezzanine": {"pos": Vector3(-4.6, 2.5, -5.1), "size": Vector3(2.2, 1.0, 1.5), "tags": ["high", "floorish"], "zh": "高架平台"},
		"desk": {"pos": Vector3(4.6, 1.15, -2.6), "size": Vector3(1.3, 0.7, 0.85), "tags": ["table"], "zh": "辦公桌上"},
		"corner_sw": {"pos": Vector3(-6.9, 0.5, 5.0), "size": Vector3(1.8, 1.0, 1.6), "tags": ["floor"], "zh": "西南角落"},
		"east_floor": {"pos": Vector3(6.6, 0.5, -0.9), "size": Vector3(1.6, 1.0, 1.6), "tags": ["floor"], "zh": "東側地板"},
		"center": {"pos": Vector3(-1.2, 0.5, -0.6), "size": Vector3(1.6, 1.0, 1.6), "tags": ["floor"], "zh": "房間中央"},
		"office": {"pos": Vector3(5.6, 0.5, 2.6), "size": Vector3(1.6, 1.0, 1.6), "tags": ["floor", "behind_glass"], "zh": "玻璃後的辦公區"},
		"break_table": {"pos": Vector3(-3.5, 1.1, 1.5), "size": Vector3(1.5, 0.6, 0.85), "tags": ["table"], "zh": "休息區桌上"},
		"ceiling_w": {"pos": Vector3(-5.0, 3.85, 1.8), "size": Vector3(2.2, 1.2, 2.2), "tags": ["ceiling"], "zh": "西側天花板"},
		"ceiling_e": {"pos": Vector3(5.2, 3.85, -0.6), "size": Vector3(2.2, 1.2, 2.2), "tags": ["ceiling"], "zh": "東側天花板"},
		"ceiling_n": {"pos": Vector3(1.0, 3.85, -3.8), "size": Vector3(2.2, 1.2, 2.2), "tags": ["ceiling"], "zh": "北側天花板"},
		"pedestal": {"pos": Vector3(-6.5, 1.5, 4.0), "size": Vector3(0.65, 0.5, 0.65), "tags": ["pedestal"], "zh": "搖晃的展示台"},
	}


# ---------------------------------------------------------------- spawning
func spawn(kind: String, xform: Transform3D) -> Prop:
	var p := PropFactory.make(kind, ctx)
	p.transform = xform
	p.home = xform
	props_root.add_child(p)
	props.append(p)
	p.tree_exiting.connect(_on_prop_exit.bind(p))
	if p is DeviceProp:
		devices[kind] = p
	if ctx and ctx.has_method("on_prop_spawned"):
		ctx.on_prop_spawned(p)
	return p


func _on_prop_exit(p: Prop) -> void:
	props.erase(p)
	_debris.erase(p)
	_papers.erase(p)
	if p is DeviceProp and devices.get(p.kind) == p:
		devices.erase(p.kind)


func spawn_paper(pos: Vector3) -> Prop:
	if _papers.size() >= MAX_PAPER:
		var old: Prop = _papers.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var p := spawn("paper", Transform3D(Basis.from_euler(Vector3(randf(), randf(), randf())), pos))
	_papers.append(p)
	return p


func spawn_debris(pos: Vector3, color: Color, count: int, spread: float = 0.3) -> void:
	for i in count:
		if _debris.size() >= MAX_DEBRIS:
			var old: Prop = _debris.pop_front()
			if is_instance_valid(old):
				old.queue_free()
		var d := PropFactory.make("debris", ctx)
		var mi: MeshInstance3D = d.visual.get_child(0)
		mi.material_override = Mats.solid(color)
		d.transform = Transform3D(Basis.from_euler(Vector3(randf() * 3, randf() * 3, randf() * 3)), pos + Vector3(randf_range(-spread, spread), randf_range(0, spread), randf_range(-spread, spread)))
		props_root.add_child(d)
		d.linear_velocity = Vector3(randf_range(-3, 3), randf_range(1, 4), randf_range(-3, 3))
		_debris.append(d)
		d.tree_exiting.connect(_on_prop_exit.bind(d))


func spawn_shards(pos: Vector3, size: Vector3, color: Color) -> void:
	spawn_debris(pos, color, 8, maxf(size.y, size.z) * 0.4)


func on_prop_broken(p: Prop) -> void:
	var c := Mats.GREY
	var mi := p.visual.get_child(0) as MeshInstance3D if p.visual.get_child_count() > 0 else null
	if mi and mi.material_override is StandardMaterial3D:
		c = (mi.material_override as StandardMaterial3D).albedo_color
	spawn_debris(p.global_position + Vector3(0, 0.2, 0), c, 5 if p.mass < 3.0 else 8)
	if p.kind != "paper" and p.kind != "ceiling" and not p.is_debris:
		_respawn_queue.append([p.kind, p.home, 20.0])


## Bring back objects that broke, so later shifts still have material.
func restock() -> void:
	for i in _respawn_queue.size():
		_respawn_queue[i][2] = minf(float(_respawn_queue[i][2]), 0.3 + i * 0.35)
	for g in glass:
		g.restore()


func live_props(include_debris: bool = false) -> Array[Prop]:
	var out: Array[Prop] = []
	for p in props:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and (include_debris or not p.is_debris):
			out.append(p)
	return out


func props_of(kind: String) -> Array[Prop]:
	var out: Array[Prop] = []
	for p in live_props():
		if p.kind == kind:
			out.append(p)
	return out


func move_fan_to_new_spot() -> void:
	var fan: Prop = devices.get("fan")
	if fan == null:
		return
	var best: Transform3D = fan_spots[0]
	var tries := 0
	while tries < 10:
		best = fan_spots[randi() % fan_spots.size()]
		if best.origin.distance_to(fan.global_position) > 2.0:
			break
		tries += 1
	fan.global_transform = best
	fan.linear_velocity = Vector3.ZERO
	fan.angular_velocity = Vector3.ZERO
	fan.home = best
	var a: RedButton = buttons["A"]
	a.linked = fan


func add_obstacle_glass() -> void:
	if _extra_glass.size() > 0:
		return
	for spec in [[Vector3(-1.0, 1.2, 0.8), 0.0], [Vector3(3.8, 1.2, -4.0), 90.0]]:
		var g := GlassPane.new()
		g.position = spec[0]
		g.rotation.y = deg_to_rad(float(spec[1]))
		add_child(g)
		g.setup(ctx, Vector3(0.05, 2.4, 2.4))
		_extra_glass.append(g)
		glass.append(g)


func _physics_process(delta: float) -> void:
	_oob_t += delta
	if _oob_t > 0.5:
		_oob_t = 0.0
		for p in live_props(true):
			var pos := p.global_position
			if absf(pos.x) > HALF_X + 0.6 or absf(pos.z) > HALF_Z + 0.6 or pos.y < -2.0 or pos.y > HEIGHT + 1.0:
				if p.is_debris or p.kind == "paper":
					p.queue_free()
				else:
					p.global_position = HATCH + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
					p.linear_velocity = Vector3.ZERO
	if _respawn_queue.size() > 0:
		_respawn_t -= delta
		for i in range(_respawn_queue.size() - 1, -1, -1):
			_respawn_queue[i][2] = float(_respawn_queue[i][2]) - delta
			if float(_respawn_queue[i][2]) <= 0.0:
				var e: Array = _respawn_queue[i]
				_respawn_queue.remove_at(i)
				var kind := str(e[0])
				var home_t: Transform3D = e[1]
				var at := home_t if kind in ["fan", "tv", "printer", "lamp", "table"] else Transform3D(home_t.basis, HATCH + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)))
				var np := spawn(kind, at)
				np.home = home_t
				if kind == "fan" or kind == "printer" or kind == "tv":
					_wire_fixtures_soft()
				if ctx:
					ctx.audio.play_3d("hatch", at.origin, -6.0)


func _wire_fixtures_soft() -> void:
	buttons["A"].linked = devices.get("fan")
	buttons["B"].linked = devices.get("printer")
	tripwire.linked = devices.get("tv")


func floor_tile_at(pos: Vector3) -> StaticBody3D:
	var ix := clampi(int(floor((pos.x + 8.0) / 4.0)), 0, 3)
	var iz := clampi(int(floor((pos.z + 6.0) / 4.0)), 0, 2)
	return floor_tiles[ix * 3 + iz]

class_name Prop
extends RigidBody3D
## Every movable object in the room. Holds material data, damage, chain
## bookkeeping and the pre-impact velocity used to judge collisions.

const LAYER_WORLD := 1
const LAYER_PROPS := 2
const LAYER_PLAYER := 4

var ctx: Node  # Main
var kind: String = ""
var display_name: String = ""
var mat_type: String = "wood"
var base_mass: float = 1.0
var base_bounce: float = 0.2
var base_friction: float = 0.6
var size_factor: float = 1.0
var max_hp: float = 100.0
var hp: float = 100.0
var break_speed: float = 99.0
var grabbable: bool = true
var magnetic: bool = false
var is_debris: bool = false
var is_device: bool = false
var held: bool = false
var no_touch: bool = false
var slippery_grip: bool = false
var uid: int = 0
var home: Transform3D
var prev_vel: Vector3 = Vector3.ZERO
var last_impact_ms: int = 0
var _recent_hits: Dictionary = {}
var boredom: float = 0.0
var damage_mult: float = 1.0
var lifetime: float = -1.0
var wet: bool = false
# Chain reaction bookkeeping.
var chain_id: int = -1
var chain_depth: int = 0
var chain_ms: int = 0

var visual: Node3D
var pmat: PhysicsMaterial
var _parts: Array = []  # [[node, base_transform]]
var center_offset: Vector3 = Vector3.ZERO
var _squash: float = 0.0
var _boost_next: bool = false
var _base_ldamp: float = 0.05
var _base_adamp: float = 0.4
static var _next_uid: int = 1


func _init() -> void:
	uid = _next_uid
	_next_uid += 1
	collision_layer = LAYER_PROPS
	collision_mask = LAYER_WORLD | LAYER_PROPS | LAYER_PLAYER
	contact_monitor = true
	max_contacts_reported = 3
	can_sleep = true
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	pmat = PhysicsMaterial.new()
	physics_material_override = pmat
	linear_damp = _base_ldamp
	angular_damp = _base_adamp


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func finish_setup() -> void:
	mass = base_mass
	hp = max_hp
	pmat.bounce = base_bounce
	pmat.friction = base_friction
	for c in get_children():
		if c is CollisionShape3D or c == visual:
			_parts.append([c, (c as Node3D).transform])
	var box := AABB()
	var first := true
	for c in visual.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			var bb := mi.transform * mi.mesh.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
	center_offset = box.get_center()


## World-space centre of the object's visible shape (origin is usually its base).
func center() -> Vector3:
	return global_transform * (center_offset * size_factor)


func add_box(size: Vector3, pos: Vector3, color: Color, collide: bool = true, rough: float = 0.85, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Mats.solid(color, rough, metal)
	mi.position = pos
	visual.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = pos
		add_child(cs)
	return mi


func add_cyl(radius: float, height: float, pos: Vector3, color: Color, collide: bool = true, sides: int = 8, rough: float = 0.85, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = Mats.solid(color, rough, metal)
	mi.position = pos
	visual.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		cs.position = pos
		add_child(cs)
	return mi


func add_sphere(radius: float, pos: Vector3, color: Color, collide: bool = true, rough: float = 0.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = Mats.solid(color, rough)
	mi.position = pos
	visual.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = radius
		cs.shape = sh
		cs.position = pos
		add_child(cs)
	return mi


func set_size(f: float) -> void:
	size_factor = clampf(f, 0.35, 2.2)
	for p in _parts:
		var n: Node3D = p[0]
		var t: Transform3D = p[1]
		n.transform = Transform3D(t.basis.scaled(Vector3.ONE * size_factor), t.origin * size_factor)
	mass = clampf(base_mass * pow(size_factor, 2.2), 0.05, 220.0)
	sleeping = false


func set_damp(lin: float, ang: float) -> void:
	linear_damp = _base_ldamp + lin
	angular_damp = _base_adamp + ang


func chain_active(now: int) -> bool:
	return chain_id >= 0 and now - chain_ms < 4000


func _physics_process(delta: float) -> void:
	if _boost_next:
		_boost_next = false
		if linear_velocity.length() < 18.0:
			linear_velocity *= 1.22
	prev_vel = linear_velocity
	if boredom > 0.0:
		boredom = maxf(0.0, boredom - delta * 0.35)
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime < 0.6:
			visual.scale = Vector3.ONE * maxf(0.05, lifetime / 0.6)
		if lifetime <= 0.0:
			queue_free()


func _process(delta: float) -> void:
	if _squash > 0.0:
		_squash = maxf(0.0, _squash - delta * 4.0)
		var s := sin(_squash * PI) * 0.35 * _squash
		if lifetime <= 0.0 or lifetime >= 0.6:
			visual.scale = Vector3(1.0 + s, 1.0 - s, 1.0 + s)


func _on_body_entered(body: Node) -> void:
	var other_vel := Vector3.ZERO
	var other_prop: Prop = body as Prop
	if other_prop:
		other_vel = other_prop.prev_vel
		# Only the faster body (the striker) reports a prop-prop impact.
		var me := prev_vel.length_squared()
		var them := other_vel.length_squared()
		if them > me or (is_equal_approx(them, me) and other_prop.uid < uid):
			return
	var rel := (prev_vel - other_vel).length()
	if rel < 1.4:
		return
	var now := GameClock.ms
	var bid := body.get_instance_id()
	if now - int(_recent_hits.get(bid, -1000)) < 120:
		return
	_recent_hits[bid] = now
	if _recent_hits.size() > 8:
		_recent_hits.clear()
	last_impact_ms = now
	if ctx == null:
		return
	var rules: Node = ctx.get("rules")
	if rules:
		var bl: int = rules.levels[RuleDefs.BOUNCE]
		if bl == RuleDefs.BOUNCE_EXTREME and rel > 2.5 and not held:
			_boost_next = true
		if bl != RuleDefs.BOUNCE_DEAD and rel > 2.2:
			_squash = 1.0 if bl != RuleDefs.BOUNCE_NORMAL else 0.45
			if other_prop and bl != RuleDefs.BOUNCE_NORMAL:
				other_prop._squash = 1.0
	ctx.events.prop_impact.emit(self, body, rel)
	if body.has_method("glass_hit"):
		body.call("glass_hit", rel, self)
	if body.has_method("button_hit"):
		body.call("button_hit", rel, self)
	take_impact(rel)
	if other_prop:
		other_prop.take_impact(rel * clampf(mass / maxf(other_prop.mass, 0.1), 0.3, 1.6))
	if kind == "battery" and other_prop and other_prop.is_device and rel > 2.0:
		other_prop.call("activate", self, false)


func take_impact(speed: float) -> void:
	if is_debris or hp <= 0.0:
		return
	var threshold := break_speed / maxf(damage_mult, 0.01)
	if speed <= threshold:
		return
	hp -= (speed - threshold) * 34.0 * damage_mult
	if hp <= 0.0:
		break_apart()


func break_apart() -> void:
	if is_queued_for_deletion():
		return
	hp = 0.0
	if ctx:
		var cid := chain_id if chain_active(GameClock.ms) else -1
		ctx.events.prop_broken.emit(self, cid)
	queue_free()


func describe() -> String:
	return display_name if display_name != "" else kind.to_upper()

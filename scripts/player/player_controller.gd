class_name PlayerController
extends CharacterBody3D
## First-person controller: walk, jump, grab/throw, kinetic pulse, interact.
## Movement is partly compensated for Engine.time_scale so slow motion is a
## tool, not a punishment.

const SPAWN := Vector3(-0.6, 0.2, -1.2)
const WALK := 4.6
const SPRINT := 7.2
const JUMP := 6.0
const BASE_GRAVITY := 17.0
const REACH := 3.6
const MAX_GRAB_MASS := 30.0

var ctx: Node
var head: Node3D
var cam: Camera3D
var held: Prop
var hold_dist: float = 2.2
var gravity_mult: float = 1.0
var health: float = 100.0
var input_enabled: bool = false
var pulse_power: float = 1.0
var look_sens: float = 0.0024
var shake: float = 0.0
var focus: Node = null  # what the crosshair points at
var _logical_vel: Vector3 = Vector3.ZERO
var _ext: Vector3 = Vector3.ZERO
var _pulse_cd: float = 0.0
var _hold_t: float = 0.0
var _last_hurt_ms: int = 0
var _hurt_area: Area3D
var _step_t: float = 0.0


func setup(c: Node) -> void:
	ctx = c
	collision_layer = Prop.LAYER_PLAYER
	collision_mask = Prop.LAYER_WORLD | Prop.LAYER_PROPS
	floor_max_angle = deg_to_rad(46)
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 78.0
	cam.near = 0.05
	cam.current = true
	head.add_child(cam)
	_hurt_area = Area3D.new()
	_hurt_area.collision_layer = 0
	_hurt_area.collision_mask = Prop.LAYER_PROPS
	var hcs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.5
	hcap.height = 2.0
	hcs.shape = hcap
	hcs.position.y = 0.95
	_hurt_area.add_child(hcs)
	add_child(_hurt_area)
	_hurt_area.body_entered.connect(_on_hurt_body)
	respawn()


func respawn() -> void:
	global_position = SPAWN
	rotation = Vector3(0, deg_to_rad(200), 0)
	if head:
		head.rotation = Vector3.ZERO
	_logical_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	health = 100.0
	release(false)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		rotate_y(-mm.relative.x * look_sens)
		head.rotate_x(-mm.relative.y * look_sens)
		head.rotation.x = clampf(head.rotation.x, -1.45, 1.45)
	elif event is InputEventMouseButton and event.is_pressed():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not ctx.test_mode:
			return
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			hold_dist = clampf(hold_dist + 0.25, 1.2, 4.2)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hold_dist = clampf(hold_dist - 0.25, 1.2, 4.2)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if held:
				throw()
			else:
				try_grab()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			pulse()
	elif event.is_action_pressed("interact"):
		interact()


func _physics_process(delta: float) -> void:
	var ts := maxf(Engine.time_scale, 0.05)
	var comp := pow(1.0 / ts, 0.8)
	var real_dt := delta / ts
	_pulse_cd = maxf(0.0, _pulse_cd - real_dt)
	var dir := Vector3.ZERO
	var sprinting := false
	if input_enabled:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (global_basis * Vector3(iv.x, 0, iv.y)).normalized()
		sprinting = Input.is_action_pressed("sprint")
	var fric := _floor_friction()
	var speed := SPRINT if sprinting else WALK
	if fric > 0.95:
		speed *= 0.62
	var accel := lerpf(1.3, 42.0, clampf(fric, 0.0, 1.0)) if is_on_floor() else 5.0
	var hv := Vector3(_logical_vel.x, 0, _logical_vel.z)
	hv = hv.move_toward(dir * speed, accel * real_dt)
	_logical_vel.x = hv.x
	_logical_vel.z = hv.z
	if is_on_floor():
		if _logical_vel.y < 0.0:
			_logical_vel.y = -0.5
		if input_enabled and Input.is_action_just_pressed("jump"):
			_logical_vel.y = JUMP * clampf(1.0 / sqrt(gravity_mult), 0.75, 1.9)
			if ctx:
				ctx.audio.play_ui("jump", -14.0)
	else:
		_logical_vel.y -= BASE_GRAVITY * gravity_mult * real_dt
	_logical_vel.y = maxf(_logical_vel.y, -30.0)
	velocity = (_logical_vel + _ext) * comp
	move_and_slide()
	var after := velocity / comp - _ext
	_logical_vel = Vector3(after.x, after.y, after.z)
	_ext = _ext.move_toward(Vector3.ZERO, 12.0 * real_dt)
	_push_props()
	_update_held(delta, real_dt)
	_update_focus()
	if global_position.y < -4.0:
		global_position = SPAWN
		_logical_vel = Vector3.ZERO
	if is_on_floor() and hv.length() > 1.0:
		_step_t -= real_dt * hv.length()
		if _step_t <= 0.0:
			_step_t = 2.1
			if ctx:
				ctx.audio.play_ui("step", -22.0)


func _process(delta: float) -> void:
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.5)
		cam.h_offset = randf_range(-1, 1) * shake * 0.06
		cam.v_offset = randf_range(-1, 1) * shake * 0.06
	elif cam:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	if health < 100.0 and GameClock.ms - _last_hurt_ms > 4000:
		health = minf(100.0, health + delta * 4.0)


func _floor_friction() -> float:
	if ctx == null or global_position.y > 0.4:
		return 0.85
	var tile: StaticBody3D = ctx.room.floor_tile_at(global_position)
	return float(tile.get_meta("friction", 0.8))


func _push_props() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider() as Prop
		if body and body != held:
			var push := -col.get_normal()
			push.y = 0.0
			body.apply_central_impulse(push.normalized() * 0.6 * minf(body.mass, 5.0) * 0.1)


func _update_held(delta: float, real_dt: float) -> void:
	if held == null:
		return
	if not is_instance_valid(held) or held.is_queued_for_deletion():
		held = null
		return
	_hold_t += real_dt
	if held.slippery_grip and _hold_t > 2.5:
		release(false)
		if ctx:
			ctx.events.notify.emit("它從你手中滑走了。房間不喜歡你一直用手搬。", Mats.RED_DARK.lightened(0.4), false)
		return
	var target := cam.global_position - cam.global_basis.z * hold_dist
	var to := target - held.global_position
	if to.length() > 3.2:
		release(false)
		return
	var follow := clampf(6.0 / maxf(held.mass, 0.5), 0.2, 1.0)
	var v := to * 14.0 * follow
	if v.length() > 16.0:
		v = v.normalized() * 16.0
	held.linear_velocity = v
	held.angular_velocity *= 0.6
	held.sleeping = false
	var _u := delta


func _update_focus() -> void:
	focus = null
	if cam == null or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, Prop.LAYER_WORLD | Prop.LAYER_PROPS, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit["collider"]
	if col is Prop and not (col as Prop).is_debris:
		focus = col
	elif col is RedButton:
		focus = col


func prompt_text() -> String:
	if held:
		return "左鍵：投擲   E：放下   滾輪：距離"
	if focus == null:
		return ""
	if focus is RedButton:
		return "E：%s" % (focus as RedButton).interact_text()
	var p := focus as Prop
	var parts: Array[String] = []
	if p.no_touch:
		parts.append("【禁止用手碰】%s" % p.describe())
	elif p.grabbable and p.mass <= MAX_GRAB_MASS:
		parts.append("左鍵：抓取 %s" % p.describe())
	else:
		parts.append("%s（太重了，試試推或改規則）" % p.describe())
	if p is DeviceProp:
		parts.append("E：%s" % (p as DeviceProp).interact_text())
	return "   ".join(parts)


func try_grab() -> void:
	var p := focus as Prop
	if p == null:
		return
	if p.no_touch:
		if ctx:
			ctx.audio.play_ui("deny", -4.0)
			ctx.events.notify.emit("任務規定：這個目標不能用手抓。用推的、撞的，或改物理規則。", Color(1, 0.5, 0.4), false)
		return
	if not p.grabbable or p.mass > MAX_GRAB_MASS:
		if ctx:
			ctx.audio.play_ui("deny", -8.0)
		return
	held = p
	p.held = true
	_hold_t = 0.0
	if ctx:
		ctx.audio.play_ui("grab", -10.0)
		ctx.events.prop_grabbed.emit(p)


func release(apply_throw: bool) -> void:
	if held and is_instance_valid(held):
		held.held = false
		if not apply_throw:
			held.linear_velocity = held.linear_velocity.limit_length(3.0)
	held = null


func throw() -> void:
	if held == null or not is_instance_valid(held):
		held = null
		return
	var p := held
	release(true)
	var fwd := -cam.global_basis.z
	var spd := 13.0 * clampf(sqrt(3.0 / maxf(p.mass, 0.1)), 0.35, 1.3)
	p.linear_velocity = fwd * spd + _logical_vel * 0.4
	p.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	if ctx:
		ctx.audio.play_ui("throw", -8.0)
		ctx.chains.start_chain("你丟出%s" % p.describe(), [p])
		ctx.events.prop_thrown.emit(p)


func pulse() -> void:
	if _pulse_cd > 0.0 or ctx == null:
		return
	_pulse_cd = 1.0
	var origin := cam.global_position
	var fwd := -cam.global_basis.z
	var hits: Array = []
	for p: Prop in ctx.room.live_props():
		if p.held:
			continue
		var d := p.global_position - origin
		var dist := d.length()
		if dist > 5.5 or dist < 0.05:
			continue
		if d.normalized().dot(fwd) < 0.72:
			continue
		var strength := 6.5 * pulse_power * (1.0 - dist / 6.0)
		p.sleeping = false
		p.apply_central_impulse((d.normalized() * 0.6 + fwd * 0.6 + Vector3.UP * 0.25).normalized() * strength * minf(p.mass, 8.0))
		hits.append(p)
	ctx.fx.pulse_ring(origin + fwd * 1.2, fwd)
	ctx.audio.play_ui("pulse", -4.0)
	if hits.size() > 0:
		ctx.chains.start_chain("你的衝擊波", hits)
	ctx.events.pulse_fired.emit(origin, hits.size())


func interact() -> void:
	if held:
		release(false)
		return
	if focus is RedButton:
		(focus as RedButton).press(null, true)
	elif focus is DeviceProp:
		(focus as DeviceProp).activate(null, true)


func launch(v: float) -> void:
	_logical_vel.y = v


func external_push(v: Vector3) -> void:
	_ext += v
	_ext = _ext.limit_length(8.0)


func _on_hurt_body(body: Node) -> void:
	var p := body as Prop
	if p == null or p.held or p.is_debris or p.kind == "paper":
		return
	var rel := (p.prev_vel - _logical_vel).length()
	if rel < 7.5 or p.mass < 1.2:
		return
	var now := GameClock.ms
	if now - _last_hurt_ms < 500:
		return
	_last_hurt_ms = now
	var dmg := clampf((rel - 7.0) * sqrt(p.mass) * 1.6, 4.0, 34.0)
	health -= dmg
	shake = 1.0
	if ctx:
		ctx.audio.play_ui("hurt", -2.0)
		ctx.events.player_damaged.emit(dmg)

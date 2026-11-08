class_name FanProp
extends DeviceProp
## Industrial floor fan. When on, pushes props (and the player) in a cone.

const RANGE := 8.5
const CONE_COS := 0.80
var blades: Node3D
var loop: AudioStreamPlayer3D
var power: float = 1.0
var _tick: int = 0


func _init() -> void:
	super()
	device_label = "FAN"
	device_label_zh = "風扇"


func _apply_state() -> void:
	if loop == null and ctx:
		loop = AudioStreamPlayer3D.new()
		loop.stream = ctx.audio.get_stream("fan_loop")
		loop.unit_size = 4.0
		loop.volume_db = -8.0
		add_child(loop)
	if loop:
		if on and not loop.playing:
			loop.play()
		elif not on:
			loop.stop()


func _process(delta: float) -> void:
	super(delta)
	if on and blades:
		blades.rotate_z(delta * 22.0 * power)


func _physics_process(delta: float) -> void:
	super(delta)
	if not on or ctx == null:
		return
	_tick += 1
	if _tick % 2 != 0:
		return
	var origin := global_position + Vector3(0, 0.55 * size_factor, 0)
	var dir := global_basis.z.normalized()
	for p: Prop in ctx.room.live_props():
		if p == self or not is_instance_valid(p) or p.held:
			continue
		var d := p.global_position - origin
		var dist := d.length()
		if dist > RANGE or dist < 0.2:
			continue
		if d.normalized().dot(dir) < CONE_COS:
			continue
		var f := 20.0 * power * (1.0 - dist / RANGE)
		p.apply_central_impulse(dir * f * minf(p.mass, 6.0) * delta * 2.0)
		pass_chain(p)
	var pd: Vector3 = ctx.player.global_position - origin
	if pd.length() < RANGE and pd.normalized().dot(dir) > CONE_COS:
		ctx.player.external_push(dir * 9.0 * power * (1.0 - pd.length() / RANGE) * delta * 2.0)

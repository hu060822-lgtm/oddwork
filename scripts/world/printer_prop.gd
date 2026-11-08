class_name PrinterProp
extends DeviceProp
## Office printer. When activated it spits paper sheets that carry the chain.

var _to_print: int = 0
var _print_t: float = 0.0


func _init() -> void:
	super()
	device_label = "PRINTER"
	device_label_zh = "印表機"


func _apply_state() -> void:
	if on:
		_to_print = 5
		_print_t = 0.0


func interact_text() -> String:
	return "啟動 印表機"


func _physics_process(delta: float) -> void:
	super(delta)
	if _to_print <= 0 or ctx == null:
		return
	_print_t -= delta
	if _print_t > 0.0:
		return
	_print_t = 0.22
	_to_print -= 1
	var front := global_basis.z.normalized()
	var p: Prop = ctx.room.spawn_paper(global_position + Vector3(0, 0.55 * size_factor, 0) + front * 0.5)
	if p:
		p.linear_velocity = front * randf_range(5.0, 8.0) + Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1))
		pass_chain(p)
		ctx.audio.play_3d("printer", global_position, -6.0)
	if _to_print <= 0:
		on = false

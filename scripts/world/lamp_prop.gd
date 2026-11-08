class_name LampProp
extends DeviceProp
## Floor lamp with a real light. Fragile bulb.

var light: OmniLight3D
var bulb: MeshInstance3D


func _init() -> void:
	super()
	device_label = "LAMP"
	device_label_zh = "燈"


func _apply_state() -> void:
	if light:
		light.visible = on
	if bulb:
		bulb.material_override = Mats.glow(Color(1.0, 0.9, 0.55), 3.0) if on else Mats.solid(Color(0.7, 0.68, 0.6))

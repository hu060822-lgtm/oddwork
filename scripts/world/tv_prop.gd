class_name TvProp
extends DeviceProp
## CRT television. Shows green static when on, and the room's eye when the
## RoomObserver reacts.

var screen: MeshInstance3D
var eye: Node3D
var loop: AudioStreamPlayer3D
var screen_mat: StandardMaterial3D
var _eye_t: float = 0.0
var _flick: float = 0.0


func _init() -> void:
	super()
	device_label = "TV"
	device_label_zh = "電視"
	screen_mat = StandardMaterial3D.new()
	screen_mat.emission_enabled = true


func _apply_state() -> void:
	if screen:
		screen.material_override = screen_mat
	if on:
		screen_mat.albedo_color = Mats.GREEN_FL
		screen_mat.emission = Mats.GREEN_FL
		screen_mat.emission_energy_multiplier = 2.0
	else:
		screen_mat.albedo_color = Color(0.08, 0.1, 0.09)
		screen_mat.emission = Color.BLACK
		screen_mat.emission_energy_multiplier = 0.0
	if loop == null and ctx:
		loop = AudioStreamPlayer3D.new()
		loop.stream = ctx.audio.get_stream("static_loop")
		loop.unit_size = 3.0
		loop.volume_db = -12.0
		add_child(loop)
	if loop:
		if on and not loop.playing:
			loop.play()
		elif not on:
			loop.stop()


func show_eye(seconds: float) -> void:
	_eye_t = seconds
	if eye:
		eye.visible = true
	screen_mat.albedo_color = Color(0.9, 0.1, 0.08)
	screen_mat.emission = Color(0.9, 0.1, 0.08)
	screen_mat.emission_energy_multiplier = 1.8


func _process(delta: float) -> void:
	super(delta)
	if _eye_t > 0.0:
		_eye_t -= delta
		if eye:
			eye.rotation.y = sin(GameClock.ms * 0.002) * 0.4
		if _eye_t <= 0.0:
			if eye:
				eye.visible = false
			_apply_state()
	elif on:
		_flick += delta
		if _flick > 0.07:
			_flick = 0.0
			screen_mat.emission_energy_multiplier = randf_range(1.1, 2.6)

class_name TvProp
extends DeviceProp
## CRT television. Shows green static when on, and the room's eye when the
## RoomObserver reacts.

var screen: MeshInstance3D
var eye: Node3D
var loop: AudioStreamPlayer3D
var screen_mat: StandardMaterial3D
var _eye_t: float = 0.0
var _msg_t: float = 0.0
var _msg: Label3D
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
	if _msg_t > 0.0:
		return
	_eye_t = seconds
	if eye:
		eye.visible = true
	screen_mat.albedo_color = Color(0.9, 0.1, 0.08)
	screen_mat.emission = Color(0.9, 0.1, 0.08)
	screen_mat.emission_energy_multiplier = 1.8


## The room remembers: the screen shows a short text (an old incident) for a while.
func show_message(text: String, seconds: float) -> void:
	if _msg == null:
		_msg = Label3D.new()
		_msg.font = UiKit.font()
		_msg.font_size = 44
		_msg.pixel_size = 0.0008
		_msg.width = 540.0
		_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_msg.modulate = Color(0.75, 1.0, 0.7)
		_msg.outline_size = 0
		_msg.position = Vector3(0, 0.27, 0.268)
		visual.add_child(_msg)
	_msg.text = text
	_msg.visible = true
	_eye_t = 0.0
	if eye:
		eye.visible = false
	_msg_t = seconds
	screen_mat.albedo_color = Color(0.03, 0.08, 0.04)
	screen_mat.emission = Color(0.05, 0.25, 0.08)
	screen_mat.emission_energy_multiplier = 0.8


func showing_message() -> bool:
	return _msg_t > 0.0


func _process(delta: float) -> void:
	super(delta)
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.visible = false
			_apply_state()
		return
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

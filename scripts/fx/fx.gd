class_name FxManager
extends Node
## Visual language for the world's state: floating dust that follows gravity,
## magnet arcs, time tint, pulse rings, impact sparks, failing lights.

const OVERLAY_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.0);
uniform float vignette = 0.25;
uniform float scan = 0.0;
uniform float time_s = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(uv * vec2(1.3, 1.0)));
	float lines = scan * (0.5 + 0.5 * sin(UV.y * 900.0 + time_s * 40.0));
	float a = clamp(tint.a + v * vignette + lines * 0.08, 0.0, 0.85);
	vec3 col = mix(vec3(0.0), tint.rgb, clamp(tint.a * 3.0 + 0.0001, 0.0, 1.0));
	COLOR = vec4(col, a);
}
"""

var ctx: Node
var overlay: ColorRect
var overlay_mat: ShaderMaterial
var dust: CPUParticles3D
var lines_mesh: ImmediateMesh
var lines_inst: MeshInstance3D
var line_mat: StandardMaterial3D
var _pair_lines: Array = []
var _rings: Array = []
var _sparks: Array[CPUParticles3D] = []
var _spark_i: int = 0
var _lights_wrong: bool = false
var power_out: bool = false
var _flicker_t: float = 0.0
var _line_t: float = 0.0
var _tint_target: Color = Color(0, 0, 0, 0)
var _scan_target: float = 0.0
var _t: float = 0.0
var _tint: Color = Color(0, 0, 0, 0)
var _scan: float = 0.0


func setup(c: Node) -> void:
	ctx = c
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = OVERLAY_SHADER
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = sh
	overlay.material = overlay_mat
	layer.add_child(overlay)
	dust = CPUParticles3D.new()
	dust.amount = 220
	dust.lifetime = 7.0
	dust.preprocess = 4.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(7.8, 2.2, 5.8)
	dust.position = Vector3(0, 2.2, 0)
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.1
	dust.gravity = Vector3(0, -0.02, 0)
	var dm := BoxMesh.new()
	dm.size = Vector3(0.025, 0.025, 0.025)
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color(1, 1, 0.9, 0.5)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.vertex_color_use_as_albedo = true
	dm.material = dmat
	dust.mesh = dm
	dust.color = Color(1, 1, 0.92, 0.45)
	add_child(dust)
	lines_mesh = ImmediateMesh.new()
	lines_inst = MeshInstance3D.new()
	lines_inst.mesh = lines_mesh
	lines_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line_mat = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Mats.GREEN_FL
	line_mat.vertex_color_use_as_albedo = true
	add_child(lines_inst)
	for i in 6:
		var sp := CPUParticles3D.new()
		sp.one_shot = true
		sp.emitting = false
		sp.amount = 14
		sp.lifetime = 0.45
		sp.explosiveness = 1.0
		sp.direction = Vector3.UP
		sp.spread = 180.0
		sp.initial_velocity_min = 1.5
		sp.initial_velocity_max = 4.0
		sp.gravity = Vector3(0, -9, 0)
		var sm := BoxMesh.new()
		sm.size = Vector3(0.03, 0.03, 0.03)
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.albedo_color = Color(1.0, 0.9, 0.5)
		sm.material = smat
		sp.mesh = sm
		add_child(sp)
		_sparks.append(sp)
	ctx.events.prop_impact.connect(_on_impact)


func reset() -> void:
	_lights_wrong = false
	set_power_out(false)
	_pair_lines.clear()
	_apply_lights(1.0, Color(0.95, 1.0, 0.88))
	on_rules_changed([0, 0, 0, 0, 0])


func on_rules_changed(levels: Array[int]) -> void:
	if dust == null:
		return
	match levels[RuleDefs.GRAVITY]:
		RuleDefs.GRAVITY_ANTI:
			dust.gravity = Vector3(0, 0.35, 0)
			dust.color = Color(0.8, 0.7, 1.0, 0.7)
		RuleDefs.GRAVITY_LOW:
			dust.gravity = Vector3(0, -0.01, 0)
			dust.color = Color(0.85, 0.8, 1.0, 0.6)
		RuleDefs.GRAVITY_HIGH:
			dust.gravity = Vector3(0, -2.5, 0)
			dust.color = Color(0.7, 0.6, 0.9, 0.6)
		RuleDefs.GRAVITY_SIDEWAYS:
			dust.gravity = ctx.rules.sideways_dir * 0.6
			dust.color = Color(0.8, 0.7, 1.0, 0.7)
		_:
			dust.gravity = Vector3(0, -0.02, 0)
			dust.color = Color(1, 1, 0.92, 0.4)
	match levels[RuleDefs.TIME]:
		RuleDefs.TIME_SLOW:
			_tint_target = Color(0.2, 0.45, 0.9, 0.14)
			_scan_target = 0.4
		RuleDefs.TIME_FAST:
			_tint_target = Color(1.0, 0.6, 0.2, 0.1)
			_scan_target = 0.6
		RuleDefs.TIME_UNSTABLE:
			_tint_target = Color(0.9, 0.3, 0.5, 0.08)
			_scan_target = 1.0
		RuleDefs.TIME_POCKETS:
			_tint_target = Color(0.4, 0.6, 1.0, 0.05)
			_scan_target = 0.2
		_:
			_tint_target = Color(0, 0, 0, 0)
			_scan_target = 0.0
	line_mat.albedo_color = Color(1.0, 0.3, 0.25) if levels[RuleDefs.MAGNETISM] == RuleDefs.MAG_REPEL else Mats.GREEN_FL


func set_pair_lines(l: Array) -> void:
	_pair_lines = l


## Power outage: ceiling lights and panels off, only a dim emergency glow.
func set_power_out(v: bool) -> void:
	power_out = v
	if ctx == null or ctx.room == null:
		return
	if v:
		_apply_lights(0.0, Color(1.0, 0.3, 0.25))
		ctx.room.env.ambient_light_energy = 0.12
	else:
		ctx.room.env.ambient_light_energy = 0.42
		_apply_lights(1.0, Color(0.95, 1.0, 0.88))


func set_lights_wrong(v: bool) -> void:
	if v == _lights_wrong:
		return
	_lights_wrong = v
	if not v and not power_out:
		_apply_lights(1.0, Color(0.95, 1.0, 0.88))


func _apply_lights(energy: float, color: Color) -> void:
	if ctx == null or ctx.room == null:
		return
	for l in ctx.room.ceiling_lights:
		(l as OmniLight3D).light_energy = 0.75 * energy
		(l as OmniLight3D).light_color = color
	for m in ctx.room.light_panels:
		(m as MeshInstance3D).visible = energy > 0.3


func pulse_ring(pos: Vector3, dir: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 0.42
	tm.rings = 16
	tm.ring_segments = 4
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.5, 1.0, 0.6, 0.8)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	if absf(dir.dot(Vector3.UP)) < 0.99:
		mi.look_at(pos + dir, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	_rings.append([mi, 0.0])


func _on_impact(striker: Node, _victim: Node, speed: float) -> void:
	if speed < 6.0:
		return
	var a := striker as Prop
	if a == null:
		return
	var sp := _sparks[_spark_i]
	_spark_i = (_spark_i + 1) % _sparks.size()
	sp.global_position = a.global_position
	sp.restart()
	sp.emitting = true
	if speed > 9.0 and ctx.player.global_position.distance_to(a.global_position) < 5.0:
		ctx.player.shake = maxf(ctx.player.shake, 0.4)


func _process(delta: float) -> void:
	if ctx == null:
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	_t += real_dt
	# Overlay.
	_tint = _tint.lerp(_tint_target, clampf(real_dt * 3.0, 0.0, 1.0))
	var tint := _tint
	var tier: int = ctx.deviation.tier if ctx.deviation else 0
	var vig := 0.22 + tier * 0.07
	if tier == 4:
		vig += 0.08 * sin(_t * 5.0)
		tint = tint.lerp(Color(0.6, 0.0, 0.1, 0.12), 0.3)
	overlay_mat.set_shader_parameter("tint", tint)
	overlay_mat.set_shader_parameter("vignette", vig)
	_scan = lerpf(_scan, _scan_target, clampf(real_dt * 3.0, 0.0, 1.0))
	overlay_mat.set_shader_parameter("scan", _scan)
	overlay_mat.set_shader_parameter("time_s", _t)
	# Rings.
	for i in range(_rings.size() - 1, -1, -1):
		var r: Array = _rings[i]
		r[1] = float(r[1]) + real_dt
		var mi: MeshInstance3D = r[0]
		var k := float(r[1]) / 0.35
		mi.scale = Vector3.ONE * (1.0 + k * 5.0)
		(mi.material_override as StandardMaterial3D).albedo_color.a = maxf(0.0, 0.8 * (1.0 - k))
		if k >= 1.0:
			mi.queue_free()
			_rings.remove_at(i)
	# Lights: wrong-lights mutation and deviation-driven flicker.
	_flicker_t -= real_dt
	if power_out:
		pass
	elif _lights_wrong:
		if _flicker_t <= 0.0:
			_flicker_t = randf_range(0.05, 0.3)
			_apply_lights(randf_range(0.1, 1.2), Color(1.0, randf_range(0.2, 0.5), 0.3))
	elif tier >= 3 and _flicker_t <= 0.0:
		_flicker_t = randf_range(0.6, 2.5) / tier
		_apply_lights(randf_range(0.3, 0.7), Color(0.95, 1.0, 0.88))
		get_tree().create_timer(0.08, true, false, true).timeout.connect(func() -> void:
			if not _lights_wrong and not power_out:
				_apply_lights(1.0, Color(0.95, 1.0, 0.88)))
	# Magnet + pair lines (rebuilt 12x per second, jittered to read as arcs).
	_line_t -= real_dt
	if _line_t <= 0.0:
		_line_t = 0.08
		lines_mesh.clear_surfaces()
		var all: Array = []
		all.append_array(ctx.rules.magnet_lines)
		all.append_array(_pair_lines)
		if all.size() > 0:
			lines_mesh.surface_begin(Mesh.PRIMITIVE_LINES, line_mat)
			for l in all:
				var a: Vector3 = l[0]
				var b: Vector3 = l[1]
				var prev := a
				for s in range(1, 5):
					var k2 := s / 4.0
					var p := a.lerp(b, k2)
					if s < 4:
						p += Vector3(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08), randf_range(-0.08, 0.08))
					lines_mesh.surface_add_vertex(prev)
					lines_mesh.surface_add_vertex(p)
					prev = p
			lines_mesh.surface_end()

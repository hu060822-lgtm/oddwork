extends SceneTree
## Renders a few gameplay moments to PNG (needs a display, e.g. xvfb-run).
##   xvfb-run -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 -s res://tools/screenshot.gd -- <outdir>

var main: Node
var out: String = "user://shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func fr(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set_meta("test_mode", true)
	main.set_meta("save_path", "user://shot_save.json")
	root.add_child(main)
	await fr(30)
	await shot("01_menu")
	main.start_run()
	await fr(10)
	await shot("02_cards")
	main.pick_card(main.anomalies.get_def("RUBBER_WORLD"))
	await fr(90)
	await shot("03_play_start")
	# The room remembers: TV replay of an old incident.
	var tv: Prop = main.room.devices.get("tv")
	if tv:
		(tv as TvProp).show_message("重播 INCIDENT #00831\n「蘋果」離開了大樓", 30.0)
		var front: Vector3 = tv.global_position + tv.global_basis.z.normalized() * 1.6
		main.player.global_position = Vector3(front.x, tv.global_position.y - 1.0, front.z)
		var to: Vector3 = tv.global_position - main.player.global_position
		main.player.rotation.y = atan2(-to.x, -to.z)
		main.player.head.rotation.x = -0.25
		await fr(30)
		await shot("11_tv_memory")
		main.player.global_position = Vector3(0, 0.1, 3.0)
	var real_primary = main.missions.primary
	var d := MissionManager.Mission.new()
	d.type = "SURVIVE"
	d.seconds = 999.0
	d.title = real_primary.title
	d.text = real_primary.text
	main.missions.primary = d
	var pl: PlayerController = main.player
	pl.rotation.y = deg_to_rad(250)
	pl.head.rotation.x = -0.15
	main.player.pulse()
	await fr(20)
	await shot("04_pulse")
	main.rules.set_level(RuleDefs.GRAVITY, RuleDefs.GRAVITY_ANTI, true)
	main.rules.set_level(RuleDefs.MAGNETISM, RuleDefs.MAG_ATTRACT, true)
	await fr(150)
	pl.head.rotation.x = 0.35
	await fr(5)
	await shot("05_antigrav_magnet")
	main.rules.set_level(RuleDefs.TIME, RuleDefs.TIME_SLOW, true)
	main.rules.set_level(RuleDefs.FRICTION, RuleDefs.FRICTION_PATCH, true)
	main.rules.set_level(RuleDefs.GRAVITY, RuleDefs.GRAVITY_NORMAL, true)
	pl.head.rotation.x = -0.45
	await fr(60)
	await shot("06_slow_patch")
	main.ui.rules_menu.open()
	await fr(5)
	await shot("07_rules_menu")
	main.ui.rules_menu.visible = false
	main.rules.set_level(RuleDefs.TIME, 0, true)
	pl.global_position = Vector3(4.0, 0.1, -0.5)
	pl.rotation.y = deg_to_rad(-20)
	pl.head.rotation.x = -0.1
	main.deviation.value = 85.0
	main.deviation._check_tier()
	await fr(200)
	await shot("08_catastrophic")
	Input.action_press("status")
	await fr(5)
	await shot("09_status")
	Input.action_release("status")
	main.deviation.value = 30.0
	main.deviation._check_tier()
	# Inspector.
	main.incidents._t_shift = 100.0
	main.incidents.trigger("THE_INSPECTION")
	var ip := IncidentManager.INSPECTOR_POS
	pl.global_position = ip + Vector3(2.0, 0.1, -3.5)
	var to2: Vector3 = ip + Vector3(0, 1.2, 0) - (pl.global_position + Vector3(0, 1.6, 0))
	pl.rotation.y = atan2(-to2.x, -to2.z)
	pl.head.rotation.x = 0.0
	main.deviation.value = 88.0
	await fr(40)
	await shot("12_inspection")
	main.deviation.value = 20.0
	await fr(10)
	main.missions.primary = real_primary
	main.missions.force_complete_primary()
	await fr(150)
	await shot("10_shift_result")
	main.stage = main.SHIFTS
	main.continue_after_shift()
	await fr(20)
	await shot("13_run_report")
	quit()

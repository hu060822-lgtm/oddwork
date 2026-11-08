extends SceneTree
## Simulates an aggressive player for 90 s and prints how fast Deviation,
## breaks and chains grow. Pacing check, not a pass/fail test.
##   godot --headless --path . --fixed-fps 60 -s res://tools/balance_probe.gd -- [card_id] [verbose] [casual]

var main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set_meta("test_mode", true)
	main.set_meta("save_path", "user://probe.json")
	root.add_child(main)
	for i in 5:
		await physics_frame
	var args := OS.get_cmdline_user_args()
	var card := args[0] if args.size() > 0 else "RUBBER_WORLD"
	main.start_run()
	await physics_frame
	main.pick_card(main.anomalies.get_def(card))
	var d := MissionManager.Mission.new()
	d.type = "SURVIVE"
	d.seconds = 999.0
	d.text = "probe"
	main.missions.primary = d
	main.missions.time_left = 999.0
	var pl: PlayerController = main.player
	var broke := {}
	main.events.prop_broken.connect(func(p: Node, _c: int) -> void:
		var k := str((p as Prop).kind)
		broke[k] = int(broke.get(k, 0)) + 1)
	var casual := args.has("casual")
	var rule_every := 15 if casual else 4
	var pulse_every := 3 if casual else 1
	for sec in 90:
		if args.has("idle"):
			pass
		elif args.has("magnet"):
			if sec == 5:
				main.rules.request(RuleDefs.MAGNETISM, RuleDefs.MAG_ATTRACT)
		elif sec % rule_every == 0:
			var r := randi() % 4
			var l := randi() % 4
			main.rules.request(r, l)
			if OS.get_cmdline_user_args().has("verbose"):
				print("  t=%d rule %s -> %s" % [sec, RuleDefs.NAMES[r], RuleDefs.level_name(r, l)])
		pl.rotation.y = randf() * TAU
		if sec % pulse_every == 0:
			pl._pulse_cd = 0.0
			pl.pulse()
		for f in 60:
			await physics_frame
		if sec % 10 == 9 or (OS.get_cmdline_user_args().has("verbose") and sec % 2 == 1):
			print("t=%2ds  deviation %5.1f  tier %d  breaks %3d  chains %3d  best_depth %d  links %4d  mutations %d  state %d hp %d" % [sec + 1, main.deviation.value, main.deviation.tier, int(main.stats.get("breaks", 0)), int(main.stats.get("chains", 0)), int(main.stats.get("best_depth", 0)), main.chains.total_links, int(main.stats.get("mutations", 0)), main.state, int(pl.health)])
	print("sources ", main.deviation.sources)
	print("broken kinds ", broke)
	print("incidents ", main.incidents.run_log, "  combos this shift ", main.combos.activated_this_shift)
	quit()

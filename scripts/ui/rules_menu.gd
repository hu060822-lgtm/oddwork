class_name RulesMenu
extends Control
## Q menu: pick a level for each of the five rules with the mouse.
## The world keeps running while it is open.

var ctx: Node
var rows: Array[HBoxContainer] = []
var info: Label
var _panel: PanelContainer


func setup(c: Node) -> void:
	ctx = c
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = UiKit.panel(UiKit.BG_SOLID, UiKit.ACCENT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UiKit.vbox(10)
	_panel.add_child(v)
	v.add_child(UiKit.label("篡改物理規則", 26, UiKit.ACCENT))
	v.add_child(UiKit.label("點選等級立即生效 · 世界不會暫停 · 再按 Q 關閉", 15, UiKit.DIM))
	for r in RuleDefs.COUNT:
		var h := UiKit.hbox(6)
		v.add_child(h)
		rows.append(h)
	info = UiKit.wrap_label("", 15, UiKit.DIM, 820)
	v.add_child(info)
	add_child(UiKit.center_wrap(_panel))
	visible = false


func open() -> void:
	visible = true
	refresh()


func refresh() -> void:
	var rules: PhysicsRuleManager = ctx.rules
	var unlocks: Dictionary = ctx.progression.unlocks()
	for r in RuleDefs.COUNT:
		var h := rows[r]
		UiKit.clear(h)
		var name_l := UiKit.label("%d  %s" % [r + 1, RuleDefs.NAMES_ZH[r]], 20, RuleDefs.COLORS[r])
		name_l.custom_minimum_size.x = 110
		h.add_child(name_l)
		for lvl in RuleDefs.level_count(r):
			if RuleDefs.is_locked(r, lvl, unlocks):
				continue
			var b := UiKit.button(RuleDefs.level_name_zh(r, lvl), _pick.bind(r, lvl), 17, 118)
			if rules.levels[r] == lvl:
				b.add_theme_stylebox_override("normal", UiKit._box(RuleDefs.COLORS[r].darkened(0.55), RuleDefs.COLORS[r], 3))
				b.add_theme_color_override("font_color", Color.WHITE)
			h.add_child(b)
		if r == RuleDefs.MAGNETISM:
			h.add_child(UiKit.label("  強度", 15, UiKit.DIM))
			for s in 3:
				var sb := UiKit.button(["弱", "中", "強"][s], _strength.bind(s), 16, 46)
				if rules.magnet_strength == s:
					sb.add_theme_stylebox_override("normal", UiKit._box(RuleDefs.COLORS[r].darkened(0.55), RuleDefs.COLORS[r], 3))
				h.add_child(sb)
		if r == rules.resisted_rule:
			h.add_child(UiKit.label("  ◉ 房間在抵抗", 15, UiKit.RED))
	info.text = "重力：影響所有物件（你有防滑鞋，不會飄走）。彈性：碰撞後反彈多少。磁性：物件之間的吸引/排斥，「只吸金屬」只影響桶子、電池、金屬板、風扇。摩擦：地板與物件有多滑，也會影響你走路。時間：整個世界的速度，任務計時用真實時間——慢動作很好用，但會花掉你的時間。"


func _pick(r: int, lvl: int) -> void:
	ctx.audio.play_ui("click", -6.0)
	var res: String = ctx.rules.request(r, lvl)
	if res == "cooldown":
		ctx.events.notify.emit("規則剛改過，稍等一下", UiKit.DIM, false)
	refresh()


func _strength(s: int) -> void:
	ctx.rules.magnet_strength = s
	ctx.audio.play_ui("click", -6.0)
	refresh()

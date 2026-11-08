class_name UIManager
extends CanvasLayer
## Owns the theme and the three UI layers: HUD, rules menu, screens.

var ctx: Node
var root: Control
var hud: Hud
var rules_menu: RulesMenu
var screens: Screens


func setup(c: Node) -> void:
	ctx = c
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.make_theme()
	add_child(root)
	hud = Hud.new()
	root.add_child(hud)
	hud.setup(c)
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	rules_menu = RulesMenu.new()
	root.add_child(rules_menu)
	rules_menu.setup(c)
	screens = Screens.new()
	root.add_child(screens)
	screens.setup(c)


func set_hud_visible(v: bool) -> void:
	hud.visible = v
	if not v:
		rules_menu.visible = false

class_name UiKit
extends RefCounted
## Small helpers for building the UI in code with one consistent look:
## dark translucent panels, beige text, yellow accents, square corners.

const BG := Color(0.07, 0.07, 0.06, 0.86)
const BG_SOLID := Color(0.09, 0.09, 0.08, 0.97)
const TEXT := Color(0.92, 0.9, 0.82)
const DIM := Color(0.62, 0.6, 0.54)
const ACCENT := Color(0.93, 0.76, 0.16)
const GREEN := Color(0.24, 1.0, 0.42)
const RED := Color(0.85, 0.22, 0.18)


static func make_theme() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "Noto Sans CJK TC", "Noto Sans TC", "PingFang TC", "Microsoft YaHei", "sans-serif"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	t.default_font = f
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Label", 3)
	var normal := _box(Color(0.14, 0.14, 0.12, 0.95), Color(0.45, 0.43, 0.36), 2)
	var hover := _box(Color(0.22, 0.2, 0.12, 0.98), ACCENT, 2)
	var pressed := _box(Color(0.3, 0.26, 0.08, 1.0), ACCENT, 3)
	var disabled := _box(Color(0.1, 0.1, 0.1, 0.8), Color(0.25, 0.25, 0.22), 1)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.38))
	t.set_stylebox("panel", "PanelContainer", _box(BG, Color(0.35, 0.33, 0.28), 1))
	t.set_stylebox("panel", "Panel", _box(BG, Color(0.35, 0.33, 0.28), 1))
	return t


static func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func panel(bg: Color = BG, border: Color = Color(0.35, 0.33, 0.28)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(bg, border, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func label(text: String, size: int = 18, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, size: int = 18, color: Color = TEXT, width: float = 400.0) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func button(text: String, cb: Callable, size: int = 20, min_w: float = 260.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(min_w, 44)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	return b


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func bar(width: float, height: float, color: Color) -> Array:
	## Returns [root Control, fill ColorRect]. Set fill.size.x = width * ratio.
	var root := Control.new()
	root.custom_minimum_size = Vector2(width, height)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.size = Vector2(width, height)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(0, height)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	return [root, fill]


static func center_wrap(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


static func clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()


## Pin a control's top-left at `offset` from an anchor point (0..1 of parent).
static func anchor(c: Control, a: Vector2, offset: Vector2) -> void:
	c.anchor_left = a.x
	c.anchor_right = a.x
	c.anchor_top = a.y
	c.anchor_bottom = a.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x
	c.offset_bottom = offset.y

class_name UITheme
extends RefCounted

## Single source of truth for the game's look: deep-navy panels,
## gold accents, readable outlined text. Applied at runtime so no
## .tscn edits are needed.

const GOLD := Color(1.0, 0.85, 0.35)
const GOLD_DIM := Color(0.85, 0.68, 0.30)
const INK := Color(0.07, 0.09, 0.15, 0.96)
const INK_SOFT := Color(0.10, 0.13, 0.20, 0.92)
const EDGE := Color(0.30, 0.48, 0.70)
const EDGE_GOLD := Color(0.95, 0.72, 0.28)
const TEXT := Color(0.92, 0.94, 0.97)
const TEXT_DIM := Color(0.62, 0.70, 0.80)
const HP_FILL := Color(0.85, 0.25, 0.28)
const STAM_FILL := Color(0.95, 0.78, 0.25)
const EXP_FILL := Color(0.30, 0.70, 1.0)

static func panel_style(border: Color = EDGE_GOLD, bg: Color = INK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 4)
	return s

static func button_styles() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.17, 0.26, 0.98)
	normal.border_color = Color(0.30, 0.48, 0.70)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 7.0
	normal.content_margin_bottom = 7.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.27, 0.40, 1.0)
	hover.border_color = GOLD
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.09, 0.12, 0.19, 1.0)
	pressed.border_color = GOLD_DIM
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.09, 0.13, 0.7)
	disabled.border_color = Color(0.25, 0.28, 0.35, 0.6)
	return {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled}

static func style_button(b: Button) -> void:
	if b == null or not is_instance_valid(b):
		return
	var st := button_styles()
	b.add_theme_stylebox_override("normal", st["normal"])
	b.add_theme_stylebox_override("hover", st["hover"])
	b.add_theme_stylebox_override("pressed", st["pressed"])
	b.add_theme_stylebox_override("disabled", st["disabled"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.55))

static func bar_style(fill: Color, bg: Color = Color(0.05, 0.06, 0.10, 0.9)) -> Dictionary:
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.set_corner_radius_all(5)
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = bg
	bg_s.border_color = Color(0, 0, 0, 0.6)
	bg_s.set_border_width_all(1)
	bg_s.set_corner_radius_all(5)
	return {"fill": f, "background": bg_s}

static func style_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	var st := bar_style(fill)
	bar.add_theme_stylebox_override("fill", st["fill"])
	bar.add_theme_stylebox_override("background", st["background"])
	bar.show_percentage = false

static func outline_text(l: Label, size: int = 16, color: Color = TEXT) -> void:
	if l == null or not is_instance_valid(l):
		return
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)

static func style_recursive(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	_style_recursive_inner(root, 0)

static func _style_recursive_inner(node: Node, depth: int) -> void:
	if depth > 8:
		return
	if node is Button:
		style_button(node as Button)
	elif node is Label:
		var l := node as Label
		if not l.has_theme_color_override("font_color"):
			l.add_theme_color_override("font_color", TEXT)
		if not l.has_theme_constant_override("outline_size"):
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			l.add_theme_constant_override("outline_size", 4)
	for c in node.get_children():
		_style_recursive_inner(c, depth + 1)

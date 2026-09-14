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

const TEX_PANEL_BROWN := "res://assets/ui/9-Slice/Ancient/brown.png"
const TEX_PANEL_TAN := "res://assets/ui/9-Slice/Ancient/tan.png"
const TEX_BTN_BROWN := "res://assets/ui/9-Slice/Ancient/brown.png"
const TEX_BTN_BROWN_PRESSED := "res://assets/ui/9-Slice/Ancient/brown_pressed.png"
const TEX_BTN_TAN := "res://assets/ui/9-Slice/Ancient/tan.png"
const TEX_BTN_TAN_PRESSED := "res://assets/ui/9-Slice/Ancient/tan_pressed.png"
const TEX_BTN_GREY := "res://assets/ui/9-Slice/Ancient/grey.png"
const TEX_BTN_WHITE := "res://assets/ui/9-Slice/Ancient/white.png"

static func make_9slice(tex_path: String, margin: float = 14.0, pad: Vector4 = Vector4(16, 8, 16, 8)) -> StyleBoxTexture:
	if not ResourceLoader.exists(tex_path):
		return null
	var tex := load(tex_path) as Texture2D
	if not tex:
		return null
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = margin
	s.texture_margin_top = margin
	s.texture_margin_right = margin
	s.texture_margin_bottom = margin
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s

static func panel_style(border: Color = EDGE_GOLD, bg: Color = INK) -> StyleBox:
	var tex_sb := make_9slice(TEX_PANEL_BROWN, 14.0, Vector4(18, 18, 18, 18))
	if tex_sb:
		return tex_sb
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
	var normal := make_9slice(TEX_BTN_TAN, 14.0, Vector4(16, 9, 16, 9))
	var hover := make_9slice(TEX_BTN_WHITE, 14.0, Vector4(16, 9, 16, 9))
	var pressed := make_9slice(TEX_BTN_TAN_PRESSED, 14.0, Vector4(16, 9, 16, 9))
	var disabled := make_9slice(TEX_BTN_GREY, 14.0, Vector4(16, 9, 16, 9))
	
	if normal and hover and pressed and disabled:
		return {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled}
	
	var fn := StyleBoxFlat.new()
	fn.bg_color = Color(0.13, 0.17, 0.26, 0.98)
	fn.border_color = Color(0.30, 0.48, 0.70)
	fn.set_border_width_all(1)
	fn.set_corner_radius_all(7)
	fn.content_margin_left = 12.0
	fn.content_margin_right = 12.0
	fn.content_margin_top = 7.0
	fn.content_margin_bottom = 7.0
	var fh := fn.duplicate() as StyleBoxFlat
	fh.bg_color = Color(0.20, 0.27, 0.40, 1.0)
	fh.border_color = GOLD
	var fp := fn.duplicate() as StyleBoxFlat
	fp.bg_color = Color(0.09, 0.12, 0.19, 1.0)
	fp.border_color = GOLD_DIM
	var fd := fn.duplicate() as StyleBoxFlat
	fd.bg_color = Color(0.08, 0.09, 0.13, 0.7)
	fd.border_color = Color(0.25, 0.28, 0.35, 0.6)
	return {"normal": fn, "hover": fh, "pressed": fp, "disabled": fd}

static func style_button(b: Button) -> void:
	if b == null or not is_instance_valid(b):
		return
	var st := button_styles()
	b.add_theme_stylebox_override("normal", st["normal"])
	b.add_theme_stylebox_override("hover", st["hover"])
	b.add_theme_stylebox_override("pressed", st["pressed"])
	b.add_theme_stylebox_override("disabled", st["disabled"])
	var focus := make_9slice(TEX_BTN_WHITE, 14.0, Vector4(16, 9, 16, 9))
	if focus:
		b.add_theme_stylebox_override("focus", focus)
	else:
		var f_box := StyleBoxFlat.new()
		f_box.bg_color = Color.TRANSPARENT
		f_box.border_color = Color("#f3e7ce")
		f_box.set_border_width_all(2)
		f_box.set_corner_radius_all(4)
		b.add_theme_stylebox_override("focus", f_box)
	b.add_theme_color_override("font_color", Color("#2a1808"))
	b.add_theme_color_override("font_hover_color", Color("#0e0802"))
	b.add_theme_color_override("font_pressed_color", Color("#422508"))
	b.add_theme_color_override("font_disabled_color", Color("#7c8894"))
	b.add_theme_color_override("font_outline_color", Color("#f5eedc"))
	b.add_theme_constant_override("outline_size", 2)

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

static func fit_modal(control: Control, design_size: Vector2, viewport_size: Vector2 = Vector2.ZERO) -> void:
	if control == null or not is_instance_valid(control):
		return
	if viewport_size == Vector2.ZERO:
		viewport_size = control.get_viewport_rect().size
	var available := Vector2(
		maxf(1.0, viewport_size.x - 24.0),
		maxf(1.0, viewport_size.y - 24.0)
	)
	var measured_size := control.get_combined_minimum_size()
	var required_size := Vector2(
		maxf(design_size.x, maxf(measured_size.x, control.size.x)),
		maxf(design_size.y, maxf(measured_size.y, control.size.y))
	)
	var width_ratio: float = available.x / maxf(required_size.x, 1.0)
	var height_ratio: float = available.y / maxf(required_size.y, 1.0)
	var scale_factor: float = minf(1.0, minf(width_ratio, height_ratio))
	control.pivot_offset = required_size * 0.5
	control.scale = Vector2.ONE * maxf(0.35, scale_factor)

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

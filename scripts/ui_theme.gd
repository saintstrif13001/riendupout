extends RefCounted
# Thème visuel partagé (menus + HUD) : palette fantasy sombre/or, panneaux à bordure arrondie.
# Accès via: const UiTheme = preload("res://scripts/ui_theme.gd")

static var _body_font: Font = null
static var _title_font: Font = null
static var _panel_tex: Texture2D = null

static func panel_tex() -> Texture2D:
	if _panel_tex == null: _panel_tex = load("res://assets/ui/panel_gold.png")
	return _panel_tex

static func _tex_box(modulate: Color, margin := 8) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = panel_tex()
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.modulate_color = modulate
	return sb

static func body_font() -> Font:
	if _body_font == null: _body_font = load("res://assets/fonts/pixelifysans.ttf")
	return _body_font

static func title_font() -> Font:
	if _title_font == null: _title_font = load("res://assets/fonts/medievalsharp.ttf")
	return _title_font

static func build() -> Theme:
	var t = Theme.new()
	t.default_font = body_font()

	var col_bg = Color(0.09, 0.1, 0.08)
	var col_panel = Color(0.10, 0.12, 0.09, 0.96)
	var col_border = Color(0.29, 0.42, 0.27)
	var col_btn = Color(0.16, 0.2, 0.14)
	var col_btn_hover = Color(0.22, 0.32, 0.19)
	var col_btn_press = Color(0.11, 0.15, 0.10)
	var col_text = Color(0.92, 0.9, 0.8)
	var col_gold = Color(0.88, 0.82, 0.56)

	# Panel — vraie texture parchemin/or (bordure ornée) au lieu d'un rectangle plat
	var panel_box = _tex_box(Color(0.30, 0.26, 0.15, 0.98), 8)
	panel_box.set_content_margin_all(20)
	t.set_stylebox("panel", "PanelContainer", panel_box)

	# Button — même texture, tons plus clairs/dorés au survol et à l'appui
	var btn_normal = _tex_box(Color(0.34, 0.29, 0.16), 8)
	btn_normal.set_content_margin_all(10)
	var btn_hover = _tex_box(Color(0.5, 0.42, 0.2), 8)
	btn_hover.set_content_margin_all(10)
	var btn_press = _tex_box(Color(0.62, 0.5, 0.22), 8)
	btn_press.set_content_margin_all(10)
	var btn_disabled = _tex_box(Color(0.22, 0.22, 0.2, 0.6), 8)
	btn_disabled.set_content_margin_all(10)

	t.set_stylebox("normal", "Button", btn_normal)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_press)
	t.set_stylebox("disabled", "Button", btn_disabled)
	t.set_font("font", "Button", body_font())
	t.set_color("font_color", "Button", col_text)
	t.set_color("font_hover_color", "Button", col_gold)
	t.set_color("font_pressed_color", "Button", col_gold)

	# Toggle-mode "card" buttons reuse Button but get a focus ring for selection
	var btn_focus = StyleBoxFlat.new()
	btn_focus.bg_color = Color(0,0,0,0)
	btn_focus.border_color = col_gold
	btn_focus.set_border_width_all(2)
	btn_focus.set_corner_radius_all(6)
	t.set_stylebox("focus", "Button", btn_focus)

	# LineEdit
	var line_box = StyleBoxFlat.new()
	line_box.bg_color = Color(0.06, 0.07, 0.05)
	line_box.border_color = col_border
	line_box.set_border_width_all(2)
	line_box.set_corner_radius_all(6)
	line_box.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", line_box)
	t.set_color("font_color", "LineEdit", col_text)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5,0.5,0.45))

	# Labels
	t.set_color("font_color", "Label", col_text)

	# ProgressBar
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.05,0.05,0.05, 0.8)
	pb_bg.border_color = col_border
	pb_bg.set_border_width_all(1)
	pb_bg.set_corner_radius_all(4)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	var pb_fill = StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.7,0.2,0.2)
	pb_fill.set_corner_radius_all(4)
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	# ScrollContainer / PanelContainer bg fallback
	t.set_color("font_color", "RichTextLabel", col_text)

	return t

static func gold() -> Color: return Color(0.88, 0.82, 0.56)
static func text() -> Color: return Color(0.92, 0.9, 0.8)
static func good() -> Color: return Color(0.5, 0.85, 0.5)
static func bad() -> Color: return Color(0.85, 0.4, 0.4)
static func info() -> Color: return Color(0.63, 0.82, 1)

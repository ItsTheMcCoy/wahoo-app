class_name WahooResponsiveLayout
extends RefCounted

const MAIN_COMPACT_BREAKPOINT := 980.0
const MAIN_COMPACT_ASPECT_THRESHOLD := 1.12
const MOBILE_LIKE_SHORT_SIDE_MAX := 600.0
const MOBILE_LIKE_LONG_SIDE_MAX := 2200.0
const SHORT_LANDSCAPE_HEIGHT_MAX := 760.0

static func is_mobile_like_layout(viewport_size: Vector2) -> bool:
	var short_side := minf(viewport_size.x, viewport_size.y)
	var long_side := maxf(viewport_size.x, viewport_size.y)
	return short_side <= MOBILE_LIKE_SHORT_SIDE_MAX and long_side <= MOBILE_LIKE_LONG_SIDE_MAX

static func is_main_scene_compact(viewport_size: Vector2) -> bool:
	return viewport_size.x <= MAIN_COMPACT_BREAKPOINT \
		or viewport_size.x < viewport_size.y * MAIN_COMPACT_ASPECT_THRESHOLD \
		or is_mobile_like_layout(viewport_size)

static func is_short_landscape(viewport_size: Vector2) -> bool:
	return viewport_size.x > viewport_size.y and viewport_size.y <= SHORT_LANDSCAPE_HEIGHT_MAX

# Toggles the "menu-mode" class on the web page's <body>. The HTML shell shows
# a "rotate your device" curtain over body.menu-mode while a touch device is
# in landscape, so menu screens stay portrait-only without blocking gameplay.
static func set_menu_mode(active: bool) -> void:
	if not OS.has_feature("web"):
		return
	if active:
		JavaScriptBridge.eval("document.body.classList.add('menu-mode')")
	else:
		JavaScriptBridge.eval("document.body.classList.remove('menu-mode')")

# Registers `callback` as the action to run when the user presses the
# device/browser back button, and pushes a browser history entry so that
# press has something to "undo". Pair with pop_back_handler() so an in-app
# back button keeps the browser history stack balanced.
static func push_back_handler(callback: Callable) -> void:
	if not OS.has_feature("web"):
		return
	var window := JavaScriptBridge.get_interface("window")
	var js_callback := JavaScriptBridge.create_callback(callback)
	window.call("wahuloPushBack", js_callback)

# Consumes the currently registered back handler (if any) and rewinds the
# browser history entry pushed for it. Safe to call even if nothing is
# registered (no-op).
static func pop_back_handler() -> void:
	if not OS.has_feature("web"):
		return
	var window := JavaScriptBridge.get_interface("window")
	window.call("wahuloPopBack")

# Applies a compact, icon-sized button style for navigation controls (e.g.
# back buttons) that float over a screen without affecting panel layout.
static func style_icon_button(btn: Button, font_size: int = 22) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.30, 0.22, 0.15, 0.92)
	normal.border_color = Color(0.73, 0.56, 0.39, 0.92)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.38, 0.28, 0.19, 0.92)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.22, 0.16, 0.11, 0.92)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.97, 0.93, 0.86))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.90))
	btn.add_theme_color_override("font_pressed_color", Color(0.97, 0.93, 0.86))
	btn.add_theme_font_size_override("font_size", font_size)

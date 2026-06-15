class_name WahooResponsiveLayout
extends RefCounted

const BACK_ICON = preload("res://assets/textures/back_chevron.svg")

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
	var window := JavaScriptBridge.get_interface("window")
	window.call("wahuloSetMenuMode", active)

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
	btn.custom_minimum_size = Vector2(44, 44)
	btn.tooltip_text = "Back"
	btn.text = ""
	btn.icon = BACK_ICON

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

static func position_back_button_near_panel(
	btn: Button,
	panel: Control,
	viewport_size: Vector2,
	gap: float = 12.0,
	edge_margin: float = 14.0
) -> void:
	var button_size := btn.size
	if button_size.x <= 0.0 or button_size.y <= 0.0:
		button_size = btn.custom_minimum_size
	if button_size.x <= 0.0 or button_size.y <= 0.0:
		button_size = Vector2(44, 44)

	btn.size = button_size

	var panel_rect := panel.get_global_rect()
	var parent_origin := (btn.get_parent() as Control).get_global_position()
	var max_x := maxf(edge_margin, viewport_size.x - button_size.x - edge_margin)
	var max_y := maxf(edge_margin, viewport_size.y - button_size.y - edge_margin)
	var target_x := panel_rect.position.x - button_size.x - gap
	var target_y := panel_rect.position.y

	btn.position = Vector2(
		clampf(target_x, edge_margin, max_x),
		clampf(target_y, edge_margin, max_y)
	) - parent_origin

static func configure_mobile_text_field(field: LineEdit) -> void:
	if field == null:
		return
	field.focus_mode = Control.FOCUS_ALL
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				_focus_mobile_text_field(field)
		elif event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT and DisplayServer.is_touchscreen_available():
				_focus_mobile_text_field(field)
	)
	field.focus_entered.connect(func() -> void:
		if DisplayServer.is_touchscreen_available():
			_show_virtual_keyboard_for_field(field)
	)

static func _focus_mobile_text_field(field: LineEdit) -> void:
	field.grab_focus()
	_show_virtual_keyboard_for_field(field)

static func _show_virtual_keyboard_for_field(field: LineEdit) -> void:
	if not OS.has_feature("web") and not DisplayServer.is_touchscreen_available():
		return
	var max_length := field.max_length if field.max_length > 0 else -1
	DisplayServer.virtual_keyboard_show(
		field.text,
		field.get_global_rect(),
		DisplayServer.KEYBOARD_TYPE_DEFAULT,
		max_length,
		field.caret_column,
		field.caret_column
	)

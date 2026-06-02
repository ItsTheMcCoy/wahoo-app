extends Control

const WORDMARK_TEXTURE = preload("res://assets/textures/wahulo_wordmark.png")

@onready var _brand_title: TextureRect = $Center/HomePanel/Content/BrandTitle
@onready var _subtitle: Label = $Center/HomePanel/Content/Subtitle
@onready var _play_solo_btn: Button = $Center/HomePanel/Content/PlaySoloButton
@onready var _host_game_btn: Button = $Center/HomePanel/Content/HostGameButton
@onready var _join_btn: Button = $Center/HomePanel/Content/JoinButton

func _ready() -> void:
	_brand_title.texture = WORDMARK_TEXTURE
	_brand_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_brand_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_play_solo_btn.pressed.connect(_on_play_solo)
	_host_game_btn.pressed.connect(_on_host_game)
	_join_btn.pressed.connect(_on_join)
	_apply_theme()
	_check_deep_link()

func _on_play_solo() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_host_game() -> void:
	pass  # Phase 4b: connect to relay and open host lobby

func _on_join() -> void:
	pass  # Phase 4b: prompt for game code and open join lobby

func _check_deep_link() -> void:
	if not OS.has_feature("web"):
		return
	var path: String = JavaScriptBridge.eval("window.location.pathname")
	if path.begins_with("/join/"):
		var code := path.substr(6).strip_edges().to_upper()
		if code.length() == 6:
			_open_join_with_code(code)

func _open_join_with_code(_code: String) -> void:
	pass  # Phase 4b: pre-fill join code and invoke join flow

func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.17, 0.13, 0.10, 0.94)
	panel_style.border_color = Color(0.46, 0.34, 0.24, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	panel_style.shadow_size = 6
	panel_style.content_margin_left = 32
	panel_style.content_margin_top = 32
	panel_style.content_margin_right = 32
	panel_style.content_margin_bottom = 32
	($Center/HomePanel as PanelContainer).add_theme_stylebox_override("panel", panel_style)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.30, 0.22, 0.15, 0.98)
	btn_normal.border_color = Color(0.73, 0.56, 0.39, 0.98)
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 10
	btn_normal.corner_radius_top_right = 10
	btn_normal.corner_radius_bottom_left = 10
	btn_normal.corner_radius_bottom_right = 10

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.38, 0.28, 0.19, 0.98)

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.22, 0.16, 0.11, 0.98)

	for btn: Button in [_play_solo_btn, _host_game_btn, _join_btn]:
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		btn.add_theme_color_override("font_color", Color(0.97, 0.93, 0.86))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.90))
		btn.add_theme_color_override("font_pressed_color", Color(0.97, 0.93, 0.86))
		btn.add_theme_font_size_override("font_size", 26)

	_subtitle.add_theme_color_override("font_color", Color(0.78, 0.71, 0.61))
	_subtitle.add_theme_font_size_override("font_size", 20)

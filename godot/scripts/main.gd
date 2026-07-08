extends Control

const WahooState = preload("res://scripts/wahoo_state.gd")
const WahooRules = preload("res://scripts/wahoo_rules.gd")
const WahooRulesSmoke = preload("res://scripts/wahoo_rules_smoke.gd")
const WahooAI = preload("res://scripts/wahoo_ai.gd")
const WahooResponsiveLayout = preload("res://scripts/wahoo_responsive_layout.gd")
const WORDMARK_TEXTURE = preload("res://assets/textures/wahulo_wordmark.png")
const SEND_ICON = preload("res://assets/textures/send_icon.svg")
const MENU_CHEVRON_ICON = preload("res://assets/textures/menu_chevron_down.svg")

const PLAYER_NAMES := ["Red", "Green", "Yellow", "Blue"]
const PLAYER_COLORS := [
	Color(0.86, 0.20, 0.17),
	Color(0.16, 0.60, 0.27),
	Color(0.93, 0.75, 0.17),
	Color(0.17, 0.34, 0.78),
]
const SAVE_PATH := "user://wahoo_save.json"
const MENU_SAVE_GAME := 0
const MENU_LOAD_GAME := 1
const MENU_RESTART_GAME := 2
const MENU_EXIT_TO_SETUP := 3
const MENU_QUIT_APP := 4
const MENU_HOW_TO_PLAY := 5
# Profile keys in easiest→hardest order for builtin profiles.
const BUILTIN_PROFILE_ORDER := [
	"human", "random", "swarm", "tortoise", "engineer",
	"balanced", "assassin", "gatekeeper", "human_like", "gambler", "sprinter"
]
const BUILTIN_PROFILE_LABELS := {
	"human":      "Human",
	"random":     "Random",
	"swarm":      "Swarm",
	"tortoise":   "Tortoise",
	"engineer":   "Engineer",
	"balanced":   "Balanced",
	"assassin":   "Assassin",
	"gatekeeper": "Gatekeeper",
	"human_like": "Human-Like",
	"gambler":    "Gambler",
	"sprinter":   "Sprinter",
}

@onready var _turn_label: Label = $Root/SidePanel/TurnLabel
@onready var _die_label: Label = $Root/SidePanel/DieFrame/DieLabel
@onready var _game_menu_button: MenuButton = $Root/SidePanel/GameMenuButton
@onready var _board_frame: PanelContainer = $Root/BoardFrame
@onready var _root_container: BoxContainer = $Root
@onready var _side_panel: VBoxContainer = $Root/SidePanel
@onready var _side_spacer: Control = $Root/SidePanel/Spacer
@onready var _die_frame: PanelContainer = $Root/SidePanel/DieFrame
@onready var _board = $Root/BoardFrame/BoardView
@onready var _side_panel_title: TextureRect = $Root/SidePanel/GameTitle
@onready var _status: RichTextLabel = $Root/SidePanel/Status
@onready var _roll_button: Button = $Root/SidePanel/RollButton
@onready var _end_turn_button: Button = $Root/SidePanel/EndTurnButton
@onready var _chat_section: VBoxContainer = $Root/SidePanel/ChatSection
@onready var _chat_log: RichTextLabel = $Root/SidePanel/ChatSection/ChatLog
@onready var _chat_input: LineEdit = $Root/SidePanel/ChatSection/ChatInputRow/ChatInput
@onready var _chat_send_btn: Button = $Root/SidePanel/ChatSection/ChatInputRow/ChatSendBtn
@onready var _win_overlay: ColorRect = $WinOverlay
@onready var _win_brand_title: TextureRect = $WinOverlay/WinPanel/WinContent/BrandTitle
@onready var _win_title: Label = $WinOverlay/WinPanel/WinContent/WinTitle
@onready var _win_subtitle: Label = $WinOverlay/WinPanel/WinContent/WinSubtitle
@onready var _new_game_button: Button = $WinOverlay/WinPanel/WinContent/NewGameButton
@onready var _setup_overlay: ColorRect = $SetupOverlay
@onready var _setup_panel: PanelContainer = $SetupOverlay/SetupCenter/SetupPanel
@onready var _setup_brand_title: TextureRect = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/BrandTitle
@onready var _setup_back_button: Button = $SetupOverlay/SetupBackButton
@onready var _start_button: Button = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/StartButton
@onready var _seat_option_0: OptionButton = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard0/PlayerCard0Inner/Seat0RightCol/Seat0Option
@onready var _seat_option_1: OptionButton = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard1/PlayerCard1Inner/Seat1RightCol/Seat1Option
@onready var _seat_option_2: OptionButton = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard2/PlayerCard2Inner/Seat2RightCol/Seat2Option
@onready var _seat_option_3: OptionButton = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard3/PlayerCard3Inner/Seat3RightCol/Seat3Option
@onready var _seat_name_0: LineEdit = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard0/PlayerCard0Inner/Seat0RightCol/Seat0Name
@onready var _seat_name_1: LineEdit = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard1/PlayerCard1Inner/Seat1RightCol/Seat1Name
@onready var _seat_name_2: LineEdit = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard2/PlayerCard2Inner/Seat2RightCol/Seat2Name
@onready var _seat_name_3: LineEdit = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard3/PlayerCard3Inner/Seat3RightCol/Seat3Name
@onready var _seat_label_0: Control = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard0/PlayerCard0Inner/Seat0Dot
@onready var _seat_label_1: Control = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard1/PlayerCard1Inner/Seat1Dot
@onready var _seat_label_2: Control = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard2/PlayerCard2Inner/Seat2Dot
@onready var _seat_label_3: Control = $SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard3/PlayerCard3Inner/Seat3Dot
@onready var _how_to_play_overlay = $HowToPlayOverlay

signal _opening_roll_pressed

var _rng := RandomNumberGenerator.new()
var _state: WahooState
var _smoke_summary := ""
var _pending_moves: Array = []
var _pending_roll: Variant = null
var _turn_number := 1
var _game_over := false
var _seat_types: Array = ["human", "human", "human", "human"]
var _seat_display_names: Array = PLAYER_NAMES.duplicate(true)
var _profiles: Dictionary = {}
var _profile_order: Array = []
var _profile_labels: Dictionary = {}
var _profile_display_name_overrides: Dictionary = {}
var _ai_busy := false
var _show_smoke_summary := false
var _starting_phase := false
var _awaiting_human_starting_roll := false
var _is_multiplayer := false
var _compact_layout := false
var _mp_role := ""     # "host" | "player" | "spectator"
var _mp_my_seat := -1
var _mp_waiting_for_opening_roll := false

func _ready() -> void:
	_rng.randomize()
	_roll_button.pressed.connect(_on_roll_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_chat_send_btn.pressed.connect(_on_chat_send)
	_chat_input.text_submitted.connect(func(_t): _on_chat_send())
	WahooResponsiveLayout.configure_mobile_text_field(_chat_input)
	_new_game_button.pressed.connect(_on_new_game_from_win)
	_board.move_selected.connect(_on_board_move_selected)
	_start_button.pressed.connect(_on_start_pressed)
	_setup_back_button.pressed.connect(_on_setup_back_pressed)
	_setup_back_button.text = "<"
	WahooResponsiveLayout.style_icon_button(_setup_back_button)
	_smoke_summary = _build_smoke_summary()
	_setup_game_menu()
	_die_label.text = "–"
	_profiles = _make_profiles_with_manager()
	_rebuild_profile_catalog()
	_apply_wordmark_branding()
	_apply_visual_theme()
	_populate_dropdowns()
	_wire_setup_inputs()
	_refresh_setup_name_fields()
	get_viewport().size_changed.connect(_on_viewport_resized)
	call_deferred("_on_viewport_resized")
	_board.modulate = Color(1.0, 1.0, 1.0, 0.96)
	_status.scroll_following = true
	_chat_section.visible = false
	if Network.ctx.has("game_state"):
		_enter_multiplayer_mode()
	else:
		_setup_overlay.visible = true
		WahooResponsiveLayout.set_menu_mode(true)
		WahooResponsiveLayout.push_back_handler(_on_setup_back_pressed)

func _normalize_profile_name(name: String) -> String:
	return name.strip_edges().to_lower()

func _load_profiles_manager_config() -> Dictionary:
	var default_config := {
		"disabled_profiles": [],
		"aliases": {},
		"custom_profiles": {},
	}
	var path_candidates := [
		ProjectSettings.globalize_path("res://profiles_manager.json"),
		ProjectSettings.globalize_path("res://../wahoo/profiles_manager.json"),
		ProjectSettings.globalize_path("res://wahoo/profiles_manager.json"),
		"profiles_manager.json",
		"wahoo/profiles_manager.json",
	]

	for candidate in path_candidates:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			return parsed

	return default_config

func _normalized_weights(weights_raw: Dictionary) -> Dictionary:
	var weights := WahooAI.BALANCED_WEIGHTS.duplicate(true)
	for feature in WahooAI.FEATURE_KEYS:
		if not weights_raw.has(feature):
			continue
		var value = weights_raw[feature]
		if value is int or value is float:
			weights[feature] = max(0.0, float(value))
	return weights

func _make_profiles_with_manager() -> Dictionary:
	var profiles := WahooAI.make_profiles()
	var config := _load_profiles_manager_config()
	_profile_display_name_overrides = {}

	var aliases = config.get("aliases", {})
	if aliases is Dictionary:
		for alias_key in aliases.keys():
			var alias := _normalize_profile_name(String(alias_key))
			var target := _normalize_profile_name(String(aliases[alias_key]))
			if target.is_empty() or not profiles.has(target):
				continue
			profiles[alias] = profiles[target]

	var custom_profiles = config.get("custom_profiles", {})
	if custom_profiles is Dictionary:
		for name_key in custom_profiles.keys():
			var name := _normalize_profile_name(String(name_key))
			if name.is_empty():
				continue
			var payload = custom_profiles[name_key]
			if not (payload is Dictionary):
				continue
			var weights_raw = payload.get("weights", {})
			if not (weights_raw is Dictionary):
				continue
			var display_name := String(payload.get("display_name", name_key)).strip_edges()
			if not display_name.is_empty():
				_profile_display_name_overrides[name] = display_name
			profiles[name] = WahooAI.GreedyPlayer.new(_normalized_weights(weights_raw))

	var disabled = config.get("disabled_profiles", [])
	if disabled is Array:
		for raw in disabled:
			var name := _normalize_profile_name(String(raw))
			if not name.is_empty():
				profiles.erase(name)

	return profiles

func _display_profile_label(profile_key: String) -> String:
	if _profile_display_name_overrides.has(profile_key):
		return String(_profile_display_name_overrides[profile_key])
	if BUILTIN_PROFILE_LABELS.has(profile_key):
		return String(BUILTIN_PROFILE_LABELS[profile_key])
	var words := profile_key.split(" ")
	for i in range(words.size()):
		if words[i].length() > 0:
			words[i] = words[i].substr(0, 1).to_upper() + words[i].substr(1)
	return " ".join(words)

func _rebuild_profile_catalog() -> void:
	_profile_order = ["human"]
	_profile_labels = {"human": "Human"}

	var known_profiles: Array = []
	for key in _profiles.keys():
		var name := _normalize_profile_name(String(key))
		if name.is_empty() or name == "human":
			continue
		if not known_profiles.has(name):
			known_profiles.append(name)

	for key in BUILTIN_PROFILE_ORDER:
		if key == "human":
			continue
		if known_profiles.has(key):
			_profile_order.append(key)

	var extras: Array = []
	for key in known_profiles:
		if not _profile_order.has(key):
			extras.append(key)
	extras.sort()
	for key in extras:
		_profile_order.append(key)

	for key in _profile_order:
		_profile_labels[key] = _display_profile_label(String(key))

func _apply_wordmark_branding() -> void:
	for title in [_side_panel_title, _setup_brand_title, _win_brand_title]:
		title.texture = WORDMARK_TEXTURE
		title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _apply_visual_theme() -> void:
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
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 12

	var die_style := panel_style.duplicate()
	die_style.bg_color = Color(0.25, 0.18, 0.12, 0.96)
	die_style.border_color = Color(0.70, 0.54, 0.38, 0.98)

	var board_style := panel_style.duplicate()
	board_style.bg_color = Color(0.10, 0.08, 0.06, 0.90)
	board_style.border_color = Color(0.42, 0.30, 0.20, 0.98)

	_board_frame.add_theme_stylebox_override("panel", board_style)
	_die_frame.add_theme_stylebox_override("panel", die_style)
	var win_panel := $WinOverlay/WinPanel as PanelContainer
	if win_panel != null:
		win_panel.add_theme_stylebox_override("panel", panel_style)
	var setup_panel := $SetupOverlay/SetupCenter/SetupPanel as PanelContainer
	if setup_panel != null:
		var setup_panel_style := panel_style.duplicate() as StyleBoxFlat
		setup_panel.add_theme_stylebox_override("panel", setup_panel_style)

	var setup_title_label := $SetupOverlay/SetupCenter/SetupPanel/SetupContent/SetupTitle as Label
	if setup_title_label != null:
		setup_title_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
		setup_title_label.add_theme_constant_override("outline_size", 2)
		setup_title_label.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.04, 0.88))

	var card_bg_style := StyleBoxFlat.new()
	card_bg_style.bg_color = Color(0.20, 0.15, 0.11, 0.92)
	card_bg_style.border_width_left = 5
	card_bg_style.border_width_top = 1
	card_bg_style.border_width_right = 1
	card_bg_style.border_width_bottom = 1
	card_bg_style.corner_radius_top_left = 10
	card_bg_style.corner_radius_top_right = 10
	card_bg_style.corner_radius_bottom_left = 10
	card_bg_style.corner_radius_bottom_right = 10
	card_bg_style.content_margin_left = 14
	card_bg_style.content_margin_top = 12
	card_bg_style.content_margin_right = 14
	card_bg_style.content_margin_bottom = 12
	var player_card_paths := [
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard0,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard1,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard2,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard3,
	]
	for i in range(4):
		var cs := card_bg_style.duplicate() as StyleBoxFlat
		cs.border_color = PLAYER_COLORS[i].lerp(Color.WHITE, 0.15)
		player_card_paths[i].add_theme_stylebox_override("panel", cs)

	var status_style := StyleBoxFlat.new()
	status_style.bg_color = Color(0.13, 0.10, 0.08, 0.72)
	status_style.border_color = Color(0.43, 0.32, 0.23, 0.88)
	status_style.border_width_left = 1
	status_style.border_width_top = 1
	status_style.border_width_right = 1
	status_style.border_width_bottom = 1
	status_style.corner_radius_top_left = 10
	status_style.corner_radius_top_right = 10
	status_style.corner_radius_bottom_left = 10
	status_style.corner_radius_bottom_right = 10
	status_style.content_margin_left = 10
	status_style.content_margin_top = 8
	status_style.content_margin_right = 10
	status_style.content_margin_bottom = 8
	_status.add_theme_stylebox_override("normal", status_style)
	_status.add_theme_color_override("default_color", Color(0.97, 0.92, 0.84))
	_status.add_theme_font_size_override("normal_font_size", 24)
	_status.add_theme_constant_override("line_separation", 3)
	_status.add_theme_constant_override("outline_size", 1)
	_status.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.90))

	var chat_style := status_style.duplicate()
	chat_style.content_margin_left = 8
	chat_style.content_margin_top = 6
	chat_style.content_margin_right = 8
	chat_style.content_margin_bottom = 6
	_chat_log.add_theme_stylebox_override("normal", chat_style)
	_chat_log.add_theme_color_override("default_color", Color(0.92, 0.87, 0.78))
	_chat_log.add_theme_font_size_override("normal_font_size", 18)
	_chat_input.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	_chat_input.add_theme_color_override("font_placeholder_color", Color(0.62, 0.58, 0.52))

	_turn_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	_turn_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.92))
	_turn_label.add_theme_constant_override("outline_size", 3)

	_die_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	_die_label.add_theme_color_override("font_outline_color", Color(0.10, 0.07, 0.05, 0.95))
	_die_label.add_theme_constant_override("outline_size", 4)

	var menu_popup := _game_menu_button.get_popup()
	menu_popup.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82))
	menu_popup.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.88))
	menu_popup.add_theme_color_override("font_disabled_color", Color(0.63, 0.58, 0.52))
	menu_popup.add_theme_color_override("font_separator_color", Color(0.58, 0.45, 0.33))

	var button_style_normal := StyleBoxFlat.new()
	button_style_normal.bg_color = Color(0.30, 0.22, 0.15, 0.98)
	button_style_normal.border_color = Color(0.73, 0.56, 0.39, 0.98)
	button_style_normal.border_width_left = 2
	button_style_normal.border_width_top = 2
	button_style_normal.border_width_right = 2
	button_style_normal.border_width_bottom = 2
	button_style_normal.corner_radius_top_left = 10
	button_style_normal.corner_radius_top_right = 10
	button_style_normal.corner_radius_bottom_left = 10
	button_style_normal.corner_radius_bottom_right = 10
	button_style_normal.content_margin_left = 12
	button_style_normal.content_margin_top = 8
	button_style_normal.content_margin_right = 12
	button_style_normal.content_margin_bottom = 8

	var button_style_hover := button_style_normal.duplicate()
	button_style_hover.bg_color = Color(0.38, 0.28, 0.19, 0.98)

	var button_style_pressed := button_style_normal.duplicate()
	button_style_pressed.bg_color = Color(0.22, 0.16, 0.11, 0.98)

	var button_style_disabled := button_style_normal.duplicate()
	button_style_disabled.bg_color = Color(0.19, 0.15, 0.12, 0.74)
	button_style_disabled.border_color = Color(0.41, 0.34, 0.28, 0.74)

	var action_buttons: Array = [
		_roll_button,
		_end_turn_button,
		_chat_send_btn,
		_new_game_button,
		_start_button,
		_game_menu_button,
	]
	for button in action_buttons:
		button.add_theme_stylebox_override("normal", button_style_normal)
		button.add_theme_stylebox_override("hover", button_style_hover)
		button.add_theme_stylebox_override("pressed", button_style_pressed)
		button.add_theme_stylebox_override("disabled", button_style_disabled)
		button.add_theme_color_override("font_color", Color(0.97, 0.93, 0.86))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.90))
		button.add_theme_color_override("font_pressed_color", Color(0.97, 0.93, 0.86))
		button.add_theme_color_override("font_disabled_color", Color(0.67, 0.62, 0.57))

	_game_menu_button.flat = false
	_game_menu_button.icon = MENU_CHEVRON_ICON
	_game_menu_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_chat_send_btn.text = ""
	_chat_send_btn.icon = SEND_ICON
	_chat_send_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chat_send_btn.expand_icon = false
	_chat_send_btn.tooltip_text = "Send"

	for opt in _seat_options():
		var opt_style_normal := StyleBoxFlat.new()
		opt_style_normal.bg_color = Color(0.92, 0.87, 0.78, 0.98)
		opt_style_normal.border_color = Color(0.34, 0.25, 0.17, 0.96)
		opt_style_normal.border_width_left = 1
		opt_style_normal.border_width_top = 1
		opt_style_normal.border_width_right = 1
		opt_style_normal.border_width_bottom = 1
		opt_style_normal.corner_radius_top_left = 6
		opt_style_normal.corner_radius_top_right = 6
		opt_style_normal.corner_radius_bottom_left = 6
		opt_style_normal.corner_radius_bottom_right = 6
		opt_style_normal.content_margin_left = 8
		opt_style_normal.content_margin_right = 8

		var opt_style_hover := opt_style_normal.duplicate()
		opt_style_hover.bg_color = Color(0.96, 0.91, 0.82, 0.98)

		var opt_style_pressed := opt_style_normal.duplicate()
		opt_style_pressed.bg_color = Color(0.84, 0.78, 0.68, 0.98)

		var opt_style_disabled := opt_style_normal.duplicate()
		opt_style_disabled.bg_color = Color(0.76, 0.72, 0.66, 0.70)
		opt_style_disabled.border_color = Color(0.45, 0.38, 0.31, 0.74)

		opt.add_theme_stylebox_override("normal", opt_style_normal)
		opt.add_theme_stylebox_override("hover", opt_style_hover)
		opt.add_theme_stylebox_override("pressed", opt_style_pressed)
		opt.add_theme_stylebox_override("disabled", opt_style_disabled)
		opt.add_theme_color_override("font_color", Color(0.10, 0.08, 0.06))
		opt.add_theme_color_override("font_hover_color", Color(0.10, 0.08, 0.06))
		opt.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.06))
		opt.add_theme_color_override("font_disabled_color", Color(0.34, 0.31, 0.28))
		opt.add_theme_color_override("font_focus_color", Color(0.10, 0.08, 0.06))
		opt.modulate = Color.WHITE
		var opt_popup: PopupMenu = opt.get_popup()
		var popup_panel := StyleBoxFlat.new()
		popup_panel.bg_color = Color(0.94, 0.89, 0.80, 0.99)
		popup_panel.border_color = Color(0.39, 0.30, 0.21, 0.98)
		popup_panel.border_width_left = 1
		popup_panel.border_width_top = 1
		popup_panel.border_width_right = 1
		popup_panel.border_width_bottom = 1
		popup_panel.corner_radius_top_left = 8
		popup_panel.corner_radius_top_right = 8
		popup_panel.corner_radius_bottom_left = 8
		popup_panel.corner_radius_bottom_right = 8
		opt_popup.add_theme_stylebox_override("panel", popup_panel)
		opt_popup.add_theme_color_override("font_color", Color(0.10, 0.08, 0.06))
		opt_popup.add_theme_color_override("font_hover_color", Color(0.10, 0.08, 0.06))
		opt_popup.add_theme_color_override("font_disabled_color", Color(0.36, 0.32, 0.28))
		opt_popup.add_theme_color_override("font_separator_color", Color(0.46, 0.37, 0.29))
		var popup_hover := StyleBoxFlat.new()
		popup_hover.bg_color = Color(0.78, 0.68, 0.54, 0.95)
		popup_hover.corner_radius_top_left = 4
		popup_hover.corner_radius_top_right = 4
		popup_hover.corner_radius_bottom_left = 4
		popup_hover.corner_radius_bottom_right = 4
		opt_popup.add_theme_stylebox_override("hover", popup_hover)

	for field in _seat_name_fields():
		field.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
		field.add_theme_color_override("font_placeholder_color", Color(0.74, 0.69, 0.62))

	var seat_label_colors: Array = [
		Color(0.86, 0.20, 0.17),
		Color(0.16, 0.60, 0.27),
		Color(0.93, 0.75, 0.17),
		Color(0.17, 0.34, 0.78),
	]
	var seat_label_nodes: Array = [_seat_label_0, _seat_label_1, _seat_label_2, _seat_label_3]
	for i in range(4):
		var lbl: Control = seat_label_nodes[i]
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var marble_color: Color = seat_label_colors[i]
		var panel := Panel.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var circle_style := StyleBoxFlat.new()
		circle_style.bg_color = marble_color
		circle_style.corner_radius_top_left = 999
		circle_style.corner_radius_top_right = 999
		circle_style.corner_radius_bottom_left = 999
		circle_style.corner_radius_bottom_right = 999
		var edge_color := marble_color.darkened(0.38)
		circle_style.border_color = edge_color
		circle_style.border_width_left = 2
		circle_style.border_width_top = 2
		circle_style.border_width_right = 2
		circle_style.border_width_bottom = 2
		panel.add_theme_stylebox_override("panel", circle_style)
		lbl.add_child(panel)

	_side_panel.self_modulate = Color(1.0, 1.0, 1.0, 0.98)

func _populate_dropdowns() -> void:
	var opts := [_seat_option_0, _seat_option_1, _seat_option_2, _seat_option_3]
	for opt in opts:
		opt.clear()
		for key in _profile_order:
			opt.add_item(_profile_labels.get(key, key), -1)
		if opt.item_count > 0:
			opt.select(0)
			opt.text = _profile_labels.get(_profile_order[0], _profile_order[0])

func _wire_setup_inputs() -> void:
	var opts := [_seat_option_0, _seat_option_1, _seat_option_2, _seat_option_3]
	for opt in opts:
		opt.item_selected.connect(_on_setup_profile_changed)

func _seat_options() -> Array:
	return [_seat_option_0, _seat_option_1, _seat_option_2, _seat_option_3]

func _seat_name_fields() -> Array:
	return [_seat_name_0, _seat_name_1, _seat_name_2, _seat_name_3]

func _on_setup_profile_changed(_index: int) -> void:
	_refresh_setup_name_fields()

func _refresh_setup_name_fields() -> void:
	var opts := _seat_options()
	var fields := _seat_name_fields()
	for i in range(WahooState.NUM_PLAYERS):
		var selected_idx: int = int(opts[i].selected)
		if selected_idx < 0 or selected_idx >= _profile_order.size():
			selected_idx = 0
			if opts[i].item_count > 0:
				opts[i].select(selected_idx)
		var profile_key: String = _profile_order[selected_idx]
		var field: LineEdit = fields[i]
		if profile_key == "human":
			field.visible = true
			field.placeholder_text = "Enter Name"
			if field.text == PLAYER_NAMES[i]:
				field.text = ""
		else:
			field.visible = false
			field.text = ""

func _on_viewport_resized() -> void:
	var viewport_size := _effective_window_size()
	_compact_layout = WahooResponsiveLayout.is_main_scene_compact(viewport_size)
	_apply_responsive_layout(viewport_size)

func _effective_window_size() -> Vector2:
	# Prefer Godot's own viewport rect: this is always in virtual coordinate space
	# and correctly reflects the actual canvas size the layout renders into.
	# The JS bridge path below is a fallback for the brief startup moment before
	# the Godot viewport has been resized to match the browser window.
	var vp_size := get_viewport_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		return vp_size
	if OS.has_feature("web"):
		var web_width := float(JavaScriptBridge.eval("window.innerWidth || 0"))
		var web_height := float(JavaScriptBridge.eval("window.innerHeight || 0"))
		if web_width > 0.0 and web_height > 0.0:
			return Vector2(web_width, web_height)
	var win_size := Vector2(DisplayServer.window_get_size())
	if win_size.x > 0.0 and win_size.y > 0.0:
		return win_size
	return Vector2(1280, 720)

func _web_window_size() -> Vector2:
	if not OS.has_feature("web"):
		return Vector2.ZERO
	var web_width := float(JavaScriptBridge.eval("window.innerWidth || 0"))
	var web_height := float(JavaScriptBridge.eval("window.innerHeight || 0"))
	if web_width > 0.0 and web_height > 0.0:
		return Vector2(web_width, web_height)
	return Vector2.ZERO

func _apply_responsive_layout(viewport_size: Vector2) -> void:
	var short_landscape := not _compact_layout and WahooResponsiveLayout.is_short_landscape(viewport_size)
	var mobile_like := WahooResponsiveLayout.is_mobile_like_layout(viewport_size)
	var mobile_landscape := mobile_like and viewport_size.x > viewport_size.y
	var mobile_portrait := mobile_like and viewport_size.y > viewport_size.x

	# Mobile browser detection: the Godot canvas runs at physical pixel resolution
	# (CSS pixels × DPR), so is_mobile_like_layout() misses high-DPR mobile devices.
	# Use window.innerWidth/innerHeight (CSS pixels) to reliably detect mobile browser.
	var web_window_size := _web_window_size()
	var mobile_browser_portrait := web_window_size.x > 0.0 \
		and web_window_size.y > web_window_size.x \
		and WahooResponsiveLayout.is_mobile_like_layout(web_window_size)
	var mobile_browser_landscape := web_window_size.x > 0.0 \
		and web_window_size.x >= web_window_size.y \
		and WahooResponsiveLayout.is_mobile_like_layout(web_window_size)
	var frame_margin := 12.0
	if mobile_landscape:
		frame_margin = 6.0
	_root_container.offset_left = frame_margin
	_root_container.offset_top = frame_margin
	_root_container.offset_right = -frame_margin
	_root_container.offset_bottom = -frame_margin
	var portrait_scale := 1.0
	if _compact_layout and mobile_portrait:
		portrait_scale = 1.24
	_root_container.vertical = _compact_layout
	_root_container.add_theme_constant_override("separation", 12 if _compact_layout else 16)
	var desktop_ui_scale := 1.0
	if not _compact_layout:
		desktop_ui_scale = clampf(viewport_size.y / 980.0, 0.72, 1.0)
		if mobile_landscape:
			desktop_ui_scale = minf(desktop_ui_scale, 0.62)

	var desktop_side_width := (320.0 if short_landscape else 350.0) * desktop_ui_scale
	_side_panel.custom_minimum_size = Vector2(0, 0) if _compact_layout else Vector2(desktop_side_width, 0)
	_side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact_layout else Control.SIZE_SHRINK_BEGIN
	_side_panel.size_flags_vertical = Control.SIZE_FILL
	var side_panel_gap := 8 if short_landscape else 10
	_side_panel.add_theme_constant_override("separation", side_panel_gap)

	_board_frame.size_flags_stretch_ratio = 1.0 if _compact_layout else 3.0
	_side_spacer.visible = not _compact_layout
	_side_panel_title.visible = not _compact_layout
	if not _compact_layout:
		var wordmark_aspect := 1400.0 / 520.0
		if WORDMARK_TEXTURE != null:
			var wordmark_size := WORDMARK_TEXTURE.get_size()
			if wordmark_size.y > 0.0:
				wordmark_aspect = wordmark_size.x / wordmark_size.y
		var button_side_padding := 12.0
		var target_wordmark_width := maxf(1.0, desktop_side_width - button_side_padding * 2.0)
		var target_wordmark_height := target_wordmark_width / wordmark_aspect
		_side_panel_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_side_panel_title.custom_minimum_size = Vector2(
			round(target_wordmark_width),
			round(target_wordmark_height)
		)

	_game_menu_button.custom_minimum_size = Vector2(0, round(48.0 * portrait_scale)) if _compact_layout else Vector2(0, round((46.0 if short_landscape else 52.0) * desktop_ui_scale))
	var action_button_font_size: int = round(22.0 * portrait_scale) if _compact_layout else round((20.0 if short_landscape else 26.0) * desktop_ui_scale)
	_game_menu_button.add_theme_font_size_override("font_size", action_button_font_size)

	_status.custom_minimum_size = Vector2(0, round(108.0 * portrait_scale)) if _compact_layout else Vector2(0, round((92.0 if short_landscape else 172.0) * desktop_ui_scale))
	_status.add_theme_font_size_override("normal_font_size", round(18.0 * portrait_scale) if _compact_layout else round((17.0 if short_landscape else 24.0) * desktop_ui_scale))

	_die_frame.custom_minimum_size = Vector2(round(112.0 * portrait_scale), round(112.0 * portrait_scale)) if _compact_layout else Vector2(round((126.0 if short_landscape else 152.0) * desktop_ui_scale), round((126.0 if short_landscape else 152.0) * desktop_ui_scale))
	_die_label.custom_minimum_size = _die_frame.custom_minimum_size
	_die_label.add_theme_font_size_override("font_size", round(74.0 * portrait_scale) if _compact_layout else round((82.0 if short_landscape else 96.0) * desktop_ui_scale))
	_turn_label.add_theme_font_size_override("font_size", round(24.0 * portrait_scale) if _compact_layout else round((22.0 if short_landscape else 30.0) * desktop_ui_scale))

	_roll_button.custom_minimum_size = Vector2(0, round(64.0 * portrait_scale)) if _compact_layout else Vector2(0, round((58.0 if short_landscape else 80.0) * desktop_ui_scale))
	_end_turn_button.custom_minimum_size = Vector2(0, round(64.0 * portrait_scale)) if _compact_layout else Vector2(0, round((58.0 if short_landscape else 80.0) * desktop_ui_scale))
	_roll_button.add_theme_font_size_override("font_size", action_button_font_size)
	_end_turn_button.add_theme_font_size_override("font_size", action_button_font_size)
	if _compact_layout and mobile_portrait:
		var action_width: float = round(clampf(viewport_size.x * 0.46, 140.0, 220.0))
		_roll_button.custom_minimum_size.x = action_width
		_end_turn_button.custom_minimum_size.x = action_width
		_roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_end_turn_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		_roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _chat_section.visible:
		_chat_log.custom_minimum_size = Vector2(0, round(100.0 * portrait_scale)) if _compact_layout else Vector2(0, round(150.0 * desktop_ui_scale))

	_apply_setup_layout(viewport_size)

	var win_panel := $WinOverlay/WinPanel as PanelContainer
	if win_panel != null:
		var win_size := Vector2(
			minf(viewport_size.x * 0.86, 420.0),
			minf(viewport_size.y * 0.56, 320.0)
		)
		win_panel.offset_left = -win_size.x * 0.5
		win_panel.offset_right = win_size.x * 0.5
		win_panel.offset_top = -win_size.y * 0.5
		win_panel.offset_bottom = win_size.y * 0.5

	_win_brand_title.custom_minimum_size = Vector2(0, 112 if _compact_layout else 162)

func _compute_setup_ui_scale(viewport_size: Vector2) -> float:
	if OS.has_feature("web"):
		var w := float(JavaScriptBridge.eval("window.innerWidth || 0"))
		var h := float(JavaScriptBridge.eval("window.innerHeight || 0"))
		if w > 0.0 and h > 0.0:
			# DPR = Godot canvas pixels / CSS logical pixels
			return clampf(viewport_size.x / w, 1.0, 4.0)
	# Native: scale relative to 720p reference height
	return clampf(viewport_size.y / 720.0, 0.8, 1.4)

func _apply_setup_layout(viewport_size: Vector2) -> void:
	var ui_scale := _compute_setup_ui_scale(viewport_size)
	var setup_mobile_like := WahooResponsiveLayout.is_mobile_like_layout(viewport_size)
	var web_window_size := _web_window_size()
	if web_window_size.x > 0.0 and web_window_size.y > 0.0:
		setup_mobile_like = setup_mobile_like or WahooResponsiveLayout.is_mobile_like_layout(web_window_size)

	var panel_w := minf(viewport_size.x * 0.85, 500.0 * ui_scale)

	# Scale the outer panel padding so it's proportional on all screen densities
	var hpad := roundi(20.0 * ui_scale)
	var vpad := roundi(16.0 * ui_scale)
	var sps := _setup_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sps != null:
		sps.content_margin_left   = hpad
		sps.content_margin_right  = hpad
		sps.content_margin_top    = vpad
		sps.content_margin_bottom = vpad

	var setup_content := $SetupOverlay/SetupCenter/SetupPanel/SetupContent as VBoxContainer
	var setup_title   := $SetupOverlay/SetupCenter/SetupPanel/SetupContent/SetupTitle as Label
	if setup_content != null:
		setup_content.add_theme_constant_override("separation", roundi(14.0 * ui_scale))
		setup_content.custom_minimum_size.x = roundi(panel_w - 2 * hpad)
	if setup_title != null:
		setup_title.add_theme_font_size_override("font_size", roundi(26.0 * ui_scale))

	var card_pad      := roundi(14.0 * ui_scale)
	var card_vpad     := roundi(7.0 * ui_scale)
	var card_w        := roundi((panel_w - 2.0 * hpad) * 0.80)
	var wordmark_aspect := 1400.0 / 520.0
	if WORDMARK_TEXTURE != null:
		var wsize := WORDMARK_TEXTURE.get_size()
		if wsize.y > 0.0:
			wordmark_aspect = wsize.x / wsize.y
	_setup_brand_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_setup_brand_title.custom_minimum_size = Vector2(card_w, roundi(float(card_w) / wordmark_aspect))
	_setup_brand_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# name_w derives from the full panel interior so card narrowing doesn't affect field widths
	var name_interior_w := roundi(panel_w) - 2 * hpad - 2 * 14

	var dot_size      := roundi(28.0 * ui_scale)
	var option_height := roundi(32.0 * ui_scale)
	var name_height   := roundi(31.0 * ui_scale)
	var header_sep    := roundi(14.0 * ui_scale)
	var name_w        := maxi(roundi(name_interior_w * 0.42), roundi(68.0 * ui_scale))
	var field_font    := roundi(20.0 * ui_scale)
	var right_col_sep := roundi(8.0 * ui_scale)

	var dots := [_seat_label_0, _seat_label_1, _seat_label_2, _seat_label_3]
	var card_inners := [
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard0/PlayerCard0Inner,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard1/PlayerCard1Inner,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard2/PlayerCard2Inner,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard3/PlayerCard3Inner,
	]
	var right_cols := [
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard0/PlayerCard0Inner/Seat0RightCol,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard1/PlayerCard1Inner/Seat1RightCol,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard2/PlayerCard2Inner/Seat2RightCol,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard3/PlayerCard3Inner/Seat3RightCol,
	]
	var player_cards := [
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard0,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard1,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard2,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard3,
	]
	var right_spacers := [
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard0/PlayerCard0Inner/Seat0RightSpacer,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard1/PlayerCard1Inner/Seat1RightSpacer,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard2/PlayerCard2Inner/Seat2RightSpacer,
		$SetupOverlay/SetupCenter/SetupPanel/SetupContent/PlayerCard3/PlayerCard3Inner/Seat3RightSpacer,
	]
	for i in range(4):
		dots[i].custom_minimum_size = Vector2(dot_size, dot_size)
		card_inners[i].add_theme_constant_override("separation", header_sep)
		right_cols[i].add_theme_constant_override("separation", right_col_sep)
		player_cards[i].custom_minimum_size = Vector2(card_w, 0)
		var cs := player_cards[i].get_theme_stylebox("panel") as StyleBoxFlat
		if cs != null:
			cs.content_margin_left   = card_pad
			cs.content_margin_right  = card_pad
			cs.content_margin_top    = card_vpad
			cs.content_margin_bottom = card_vpad
		right_spacers[i].custom_minimum_size = Vector2.ZERO

	for opt in _seat_options():
		opt.custom_minimum_size = Vector2(name_w, option_height)
		opt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		opt.add_theme_font_size_override("font_size", field_font)
		opt.get_popup().add_theme_font_size_override("font_size", field_font)
	for field in _seat_name_fields():
		field.custom_minimum_size = Vector2(name_w, name_height)
		field.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		field.add_theme_font_size_override("font_size", field_font)

	_start_button.custom_minimum_size = Vector2(card_w, roundi(68.0 * 0.85 * ui_scale))
	_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start_button.add_theme_font_size_override("font_size", roundi(24.0 * ui_scale))
	var back_button_base_width := 22.0 if setup_mobile_like else 20.0
	var back_button_base_height := 56.0 if setup_mobile_like else 50.0
	var back_button_width := maxf(back_button_base_width, back_button_base_width * ui_scale)
	var back_button_height := maxf(back_button_base_height, back_button_base_height * ui_scale)
	_setup_back_button.custom_minimum_size = Vector2(back_button_width, back_button_height)
	call_deferred("_position_setup_back_button")

func _position_setup_back_button() -> void:
	WahooResponsiveLayout.position_back_button_near_panel(
		_setup_back_button,
		_setup_panel,
		get_viewport_rect().size
	)

func _on_start_pressed() -> void:
	var opts := _seat_options()
	var fields := _seat_name_fields()
	for i in range(4):
		var selected_idx: int = int(opts[i].selected)
		if selected_idx < 0 or selected_idx >= _profile_order.size():
			selected_idx = 0
		_seat_types[i] = _profile_order[selected_idx]
		if _seat_types[i] == "human":
			var entered := String(fields[i].text).strip_edges()
			if entered == "Enter Name":
				entered = ""
			_seat_display_names[i] = entered if not entered.is_empty() else PLAYER_NAMES[i]
		else:
			_seat_display_names[i] = _profile_labels.get(_seat_types[i], _seat_types[i])
	_setup_overlay.visible = false
	WahooResponsiveLayout.set_menu_mode(false)
	WahooResponsiveLayout.pop_back_handler()
	_new_game()

func _on_setup_back_pressed() -> void:
	WahooResponsiveLayout.pop_back_handler()
	get_tree().change_scene_to_file("res://scenes/HomeScreen.tscn")

func _on_new_game_from_win() -> void:
	if _is_multiplayer:
		_mp_disconnect_signals()
		Network.disconnect_from_relay()
		Network.ctx = {}
		get_tree().change_scene_to_file("res://scenes/HomeScreen.tscn")
		return
	_win_overlay.visible = false
	_setup_overlay.visible = true
	WahooResponsiveLayout.set_menu_mode(true)
	WahooResponsiveLayout.push_back_handler(_on_setup_back_pressed)
	_refresh_setup_name_fields()

func _new_game() -> void:
	_state = WahooState.new_game()
	_pending_moves = []
	_pending_roll = null
	_turn_number = 1
	_game_over = false
	_ai_busy = false
	_starting_phase = true
	_win_overlay.visible = false
	_board.clear_legal_moves()
	_board.set_state(_state)
	_board.set_seat_labels(_seat_display_names)
	_board.set_turn_focus_enabled(true)
	_die_label.text = "–"
	_die_label.scale = Vector2.ONE
	_set_roll_ready(false)
	_roll_button.text = "Roll"
	_set_status_text("")
	_turn_label.text = ""
	_turn_label.self_modulate = Color.WHITE
	await _run_starting_roll_phase()

func _on_roll_pressed() -> void:
	if _game_over or _ai_busy:
		return
	if _starting_phase:
		if _awaiting_human_starting_roll:
			_awaiting_human_starting_roll = false
			_roll_button.disabled = true
			_opening_roll_pressed.emit()
		return
	if not _pending_moves.is_empty():
		return

	if _is_multiplayer:
		_roll_button.disabled = true
		Network.send_roll_request()
		return

	_roll_button.disabled = true
	_board.clear_legal_moves()
	_pending_moves = []
	_pending_roll = null

	var roll := _rng.randi_range(1, 6)
	await _play_roll_visual(roll)
	var player := _state.current_player
	var legal := WahooRules.legal_moves(_state, player, roll)
	var line := "%s rolled %d" % [_player_label(player), roll]
	if legal.size() > 0:
		_pending_moves = legal.duplicate(true)
		_pending_roll = roll
		_state.pending_roll = roll
		_board.set_legal_moves(_pending_moves, player)
		line += "\nSelect a marble to move"
		_set_roll_ready(false)
	else:
		_state.pending_roll = null
		if roll != 6:
			line += "\nNo legal moves; press End Turn to continue"
			_board.set_state(_state)
			_render_status(line)
			_set_end_turn_ready()
			return
		else:
			line += "\nRolled a 6; %s rolls again" % _player_label(player)
			_turn_number += 1
		_set_roll_ready(true)
	_board.set_state(_state)
	_render_status(line)

func _on_board_move_selected(move: Dictionary) -> void:
	if _game_over or _starting_phase or _pending_moves.is_empty() or _pending_roll == null or _ai_busy:
		return
	if _is_multiplayer:
		_board.clear_legal_moves()
		_pending_moves = []
		_pending_roll = null
		Network.send_submit_move(move)
		_render_status("Move submitted...")
		return
	var player := _state.current_player
	var roll := int(_pending_roll)
	_state.pending_roll = null
	_pending_moves = []
	_pending_roll = null
	await _execute_move(move, player, roll)

# Shared move animation + post-move logic for both human and AI paths.
func _execute_move(move: Dictionary, player: int, roll: int) -> void:
	_roll_button.disabled = true
	_board.clear_legal_moves()

	_render_status("%s moving marble %d..." % [_player_label(player), int(move["marble"]) + 1])
	await _board.animate_move(move, player)

	WahooRules.apply_move(_state, move)
	_board.set_state(_state)

	var line := "%s moved marble %d to %s" % [
		_player_label(player),
		int(move["marble"]) + 1,
		WahooState.format_location(move["dest"]),
	]
	var captures: Variant = move.get("captures", null)
	if captures != null:
		line += "\nCaptured %s marble %d" % [_player_label(int(captures[0])), int(captures[1]) + 1]

	if _state.player_won(player):
		line += "\n%s wins!" % _player_label(player)
		_render_status(line)
		_show_win_screen(player)
	elif roll == 6:
		line += "\nRolled a 6; %s rolls again" % _player_label(player)
		_turn_number += 1
		_render_status(line)
		_set_roll_ready(true)
	elif _seat_types[player] == "human":
		line += "\nPress End Turn to continue"
		_render_status(line)
		_set_end_turn_ready()
	else:
		_advance_to_next_player()
		_board.set_state(_state)
		line += "\n%s is up next" % _player_label(_state.current_player)
		_turn_number += 1
		_render_status(line)
		_set_roll_ready(true)

# Coroutine that handles a full AI turn: wait → roll → wait → choose → execute.
func _ai_take_turn() -> void:
	_ai_busy = true
	_roll_button.disabled = true
	await get_tree().create_timer(0.8).timeout
	if _game_over:
		_ai_busy = false
		return

	var roll := _rng.randi_range(1, 6)
	await _play_roll_visual(roll)
	var player := _state.current_player
	var legal := WahooRules.legal_moves(_state, player, roll)
	var label := _player_label(player) + " (AI)"
	var line := "%s rolled %d" % [label, roll]

	if legal.is_empty():
		if roll != 6:
			_advance_to_next_player()
			line += "\nNo move; %s is up next" % _player_label(_state.current_player)
			_turn_number += 1
		else:
			line += "\nRolled a 6; rolls again"
			_turn_number += 1
		_board.set_state(_state)
		_render_status(line)
		_ai_busy = false
		_set_roll_ready(true)
		return

	_render_status(line + "\nAI choosing...")
	await get_tree().create_timer(1.5).timeout
	if _game_over:
		_ai_busy = false
		return

	var profile_key: String = _seat_types[player]
	var ai_player = _profiles[profile_key]
	var move: Dictionary = ai_player.choose_move(_state, player, roll, legal)

	# Release busy flag before _execute_move so _set_roll_ready can re-trigger AI for next turn.
	_ai_busy = false
	await _execute_move(move, player, roll)

func _render_status(header: String) -> void:
	_turn_label.text = _player_label(_state.current_player)
	_turn_label.self_modulate = PLAYER_COLORS[_state.current_player]
	var lines := [header]
	if _show_smoke_summary:
		lines.append("")
		lines.append(_smoke_summary)
	_set_status_text("\n".join(lines))

func _set_status_text(text: String) -> void:
	_status.text = text
	_status.scroll_following = true
	call_deferred("_scroll_status_to_bottom")

func _scroll_status_to_bottom() -> void:
	if _status == null:
		return
	var last_line: int = maxi(0, _status.get_line_count() - 1)
	_status.scroll_to_line(last_line)

func _turn_announcement(action: String) -> String:
	return "Turn %d: %s\n%s" % [_turn_number, _player_label(_state.current_player), action]

func _player_label(player: int) -> String:
	if _is_multiplayer and player < _seat_display_names.size():
		return _seat_display_names[player]
	return "%s Player" % PLAYER_NAMES[player]

func _advance_to_next_player() -> void:
	_state.current_player = (_state.current_player + 1) % WahooState.NUM_PLAYERS

func _set_roll_ready(ready: bool) -> void:
	_roll_button.disabled = not ready
	_roll_button.text = "Roll"
	_end_turn_button.disabled = true
	if ready and not _game_over and not _ai_busy and not _starting_phase and not _is_multiplayer:
		_maybe_ai_turn()

func _set_end_turn_ready() -> void:
	_roll_button.disabled = true
	_end_turn_button.disabled = false

func _on_end_turn_pressed() -> void:
	if _game_over or _ai_busy:
		return
	_end_turn_button.disabled = true
	_advance_to_next_player()
	_board.set_state(_state)
	_turn_number += 1
	_render_status("%s is up next" % _player_label(_state.current_player))
	_set_roll_ready(true)

func _run_starting_roll_phase() -> void:
	var contenders: Array = [0, 1, 2, 3]
	var status_lines: PackedStringArray = []
	var winning_roll := 0

	_turn_label.text = ""
	_turn_label.self_modulate = Color.WHITE
	status_lines.append("Roll to see who goes first.")
	_set_status_text("\n".join(status_lines))
	await get_tree().create_timer(1.0).timeout

	while contenders.size() > 1:
		if not _starting_phase:
			return
		var round_rolls: Array = []
		var highest := 0

		for player in contenders:
			if not _starting_phase:
				return
			var seat := int(player)
			var name: String = _seat_display_names[seat]
			_state.current_player = seat
			_board.set_state(_state)

			_turn_label.text = name
			_turn_label.self_modulate = PLAYER_COLORS[seat]

			var roll: int
			if _seat_types[seat] == "human":
				_roll_button.text = "Roll"
				_awaiting_human_starting_roll = true
				_roll_button.disabled = false
				await _opening_roll_pressed
				if not _starting_phase:
					return
				roll = _rng.randi_range(1, 6)
			else:
				await get_tree().create_timer(0.4).timeout
				if not _starting_phase:
					return
				roll = _rng.randi_range(1, 6)

			await _play_roll_visual(roll)
			if not _starting_phase:
				return

			round_rolls.append({"player": seat, "roll": roll})
			if roll > highest:
				highest = roll

			status_lines.append("%s rolled %d." % [name, roll])
			_set_status_text("\n".join(status_lines))
			await get_tree().create_timer(0.5).timeout
			if not _starting_phase:
				return

		var tied: Array = []
		for item in round_rolls:
			if int(item["roll"]) == highest:
				tied.append(int(item["player"]))

		if tied.size() > 1:
			var parts := PackedStringArray()
			for p in tied:
				parts.append(_seat_display_names[int(p)])
			_turn_label.text = "Tie!"
			_turn_label.self_modulate = Color.WHITE
			status_lines.append("Tie at %d — %s roll again." % [highest, ", ".join(parts)])
			_set_status_text("\n".join(status_lines))
			await get_tree().create_timer(1.0).timeout
			if not _starting_phase:
				return
		else:
			winning_roll = highest

		contenders = tied

	if not _starting_phase:
		return
	var winner := int(contenders[0])
	_state.current_player = winner
	_starting_phase = false
	_board.set_turn_focus_enabled(true)
	_board.set_state(_state)
	var winner_name: String = _seat_display_names[winner]
	_turn_label.text = winner_name
	_turn_label.self_modulate = PLAYER_COLORS[winner]
	status_lines.append("%s had the highest roll with a %d." % [winner_name, winning_roll])
	status_lines.append("%s goes first!" % winner_name)
	_set_status_text("\n".join(status_lines))
	_set_roll_ready(true)

func _seat_roll_label(player: int) -> String:
	return "%s (%s)" % [PLAYER_NAMES[player], _seat_display_names[player]]

func _maybe_ai_turn() -> void:
	if _seat_types[_state.current_player] != "human":
		_ai_take_turn()

func _show_win_screen(player: int) -> void:
	_game_over = true
	_set_roll_ready(false)
	_roll_button.text = "Game Over"
	_win_title.text = "%s Wins!" % _player_label(player)
	_win_title.self_modulate = PLAYER_COLORS[player]
	_win_subtitle.text = "Game finished on turn %d" % _turn_number
	_win_overlay.visible = true

func _legal_moves_status_text(_legal: Array) -> String:
	return ""

func _build_smoke_summary() -> String:
	var result := WahooRulesSmoke.run()
	var failures: Array = result["failures"]
	if failures.is_empty():
		return "Rule smoke tests: %d/%d passed" % [int(result["passed"]), int(result["total"])]
	return "Rule smoke tests: %d/%d passed\n%s" % [
		int(result["passed"]),
		int(result["total"]),
		"\n".join(failures),
	]

func _setup_game_menu() -> void:
	var popup := _game_menu_button.get_popup()
	popup.clear()
	if not popup.id_pressed.is_connected(_on_game_menu_id_pressed):
		popup.id_pressed.connect(_on_game_menu_id_pressed)
	popup.add_item("How to Play", MENU_HOW_TO_PLAY)
	popup.add_separator()
	if OS.has_feature("web"):
		if _is_multiplayer:
			popup.add_item("Leave Match", MENU_EXIT_TO_SETUP)
		else:
			popup.add_item("New Game", MENU_RESTART_GAME)
			popup.add_item("Return Home", MENU_EXIT_TO_SETUP)
		return

	popup.add_item("Save Game", MENU_SAVE_GAME)
	popup.add_item("Load Saved Game", MENU_LOAD_GAME)
	popup.add_separator()
	popup.add_item("Restart Game", MENU_RESTART_GAME)
	popup.add_item("Exit To Setup", MENU_EXIT_TO_SETUP)
	popup.add_separator()
	popup.add_item("Quit App", MENU_QUIT_APP)

func _on_game_menu_id_pressed(id: int) -> void:
	if _is_multiplayer and id in [MENU_SAVE_GAME, MENU_LOAD_GAME, MENU_RESTART_GAME]:
		return
	match id:
		MENU_HOW_TO_PLAY:
			_how_to_play_overlay.show_overlay()
		MENU_SAVE_GAME:
			_save_game()
		MENU_LOAD_GAME:
			_load_game()
		MENU_RESTART_GAME:
			if not _setup_overlay.visible:
				_new_game()
				_render_status("New game started")
		MENU_EXIT_TO_SETUP:
			_exit_to_setup()
		MENU_QUIT_APP:
			if OS.has_feature("web"):
				_exit_to_setup()
				_render_status("Quit is not supported in web build. Returned to setup.")
			else:
				get_tree().quit()

func _exit_to_setup() -> void:
	_game_over = true
	_starting_phase = false
	_awaiting_human_starting_roll = false
	_pending_moves = []
	_pending_roll = null
	_ai_busy = false
	_opening_roll_pressed.emit()  # unblock any awaiting starting-roll coroutine
	if _is_multiplayer:
		_mp_disconnect_signals()
		Network.disconnect_from_relay()
		Network.ctx = {}
	get_tree().change_scene_to_file("res://scenes/HomeScreen.tscn")

func _save_game() -> void:
	if _state == null or _setup_overlay.visible:
		return
	var payload := {
		"version": 1,
		"turn_number": _turn_number,
		"seat_types": _seat_types.duplicate(true),
		"seat_display_names": _seat_display_names.duplicate(true),
		"state": {
			"marbles": _state.marbles.duplicate(true),
			"current_player": _state.current_player,
			"pending_roll": _state.pending_roll,
			"center_occupant": _state.center_occupant.duplicate(true) if _state.center_occupant != null else null,
			"next_base_exit_marble": _state.next_base_exit_marble.duplicate(true),
		},
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_render_status("Save failed: unable to open save file")
		return
	file.store_string(JSON.stringify(payload))
	_render_status("Game saved")

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_render_status("No saved game found")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_render_status("Load failed: unable to open save file")
		return
	var content := file.get_as_text()
	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		_render_status("Load failed: invalid save format")
		return
	var data: Dictionary = parsed
	if not data.has("state"):
		_render_status("Load failed: missing game state")
		return
	var state_data: Dictionary = data["state"]
	if not state_data.has("marbles") or not state_data.has("current_player"):
		_render_status("Load failed: incomplete game state")
		return

	var loaded := WahooState.new()
	loaded.marbles = state_data.get("marbles", []).duplicate(true)
	loaded.current_player = int(state_data.get("current_player", 0))
	loaded.pending_roll = state_data.get("pending_roll", null)
	loaded.center_occupant = state_data.get("center_occupant", null)
	loaded.next_base_exit_marble = state_data.get("next_base_exit_marble", [0, 0, 0, 0]).duplicate(true)

	_state = loaded
	_turn_number = int(data.get("turn_number", 1))
	_seat_types = data.get("seat_types", ["human", "human", "human", "human"]).duplicate(true)
	_seat_display_names = data.get("seat_display_names", PLAYER_NAMES.duplicate(true)).duplicate(true)
	_game_over = false
	_starting_phase = false
	_ai_busy = false
	_pending_moves = []
	_pending_roll = null
	_win_overlay.visible = false
	_setup_overlay.visible = false
	WahooResponsiveLayout.set_menu_mode(false)
	_board.clear_legal_moves()
	_board.set_state(_state)
	_board.set_seat_labels(_seat_display_names)
	_die_label.text = "–"
	_set_roll_ready(true)
	_render_status("Saved game loaded")

func _die_face(value: int) -> String:
	return str(clampi(value, 1, 6))

func _play_roll_visual(final_roll: int) -> void:
	_die_label.pivot_offset = _die_label.size * 0.5
	for _i in range(14):
		_die_label.text = _die_face(_rng.randi_range(1, 6))
		await get_tree().create_timer(0.04).timeout
	_die_label.text = _die_face(final_roll)
	var tween := create_tween()
	tween.tween_property(_die_label, "scale", Vector2(1.30, 1.30), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_die_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished

# ─── Multiplayer (Phase 4c) ───────────────────────────────────────────────────

func _enter_multiplayer_mode() -> void:
	_is_multiplayer = true
	_mp_role    = str(Network.ctx.get("role", "spectator"))
	_mp_my_seat = int(Network.ctx.get("my_seat", -1))
	_mp_waiting_for_opening_roll = bool(Network.ctx.get("awaiting_opening_roll", false))
	_setup_game_menu()

	var seats: Array = Network.ctx.get("seats", [])
	for i in range(4):
		if i < seats.size():
			var seat: Dictionary = seats[i]
			_seat_display_names[i] = str(seat.get("name", PLAYER_NAMES[i]))
			var t: String = str(seat.get("type", "human"))
			if t == "ai":
				_seat_types[i] = str(seat.get("aiProfile", "random"))
			else:
				_seat_types[i] = "human"

	_state = _mp_deserialize_state(Network.ctx.get("game_state", {}))
	var current_player := int(Network.ctx.get("current_player", 0))
	_state.current_player = current_player
	var opening_roll_rounds: Array = Network.ctx.get("opening_roll_rounds", [])

	_win_overlay.visible = false
	_setup_overlay.visible = false
	WahooResponsiveLayout.set_menu_mode(false)
	_board.set_turn_focus_enabled(true)
	_board.set_state(_state)
	_board.set_seat_labels(_seat_display_names)
	_board.clear_legal_moves()
	_die_label.text = "–"
	_turn_number = 1
	_chat_section.visible = true
	_chat_log.clear()
	_chat_input.text = ""

	Network.roll_result.connect(_mp_on_roll_result)
	Network.state_update.connect(_mp_on_state_update)
	Network.chat_received.connect(_mp_on_chat_received)
	Network.game_over_received.connect(_mp_on_game_over)
	Network.player_disconnected.connect(_mp_on_player_disconnected)
	Network.player_reconnected.connect(_mp_on_player_reconnected)
	Network.disconnected_from_server.connect(_mp_on_server_disconnected)

	_mp_set_turn(current_player)
	var opening_summary := _mp_format_opening_roll_summary(opening_roll_rounds)
	if not opening_summary.is_empty():
		_set_status_text(opening_summary + "\n\n" + _status.text)

func _mp_deserialize_state(gs: Dictionary) -> WahooState:
	var s := WahooState.new()
	s.marbles = gs.get("marbles", []).duplicate(true)
	s.current_player = int(gs.get("current_player", 0))
	s.pending_roll = gs.get("pending_roll", null)
	s.center_occupant = gs.get("center_occupant", null)
	s.next_base_exit_marble = gs.get("next_base_exit_marble", [0, 0, 0, 0]).duplicate(true)
	return s

func _mp_format_opening_roll_summary(rounds: Array) -> String:
	if rounds.is_empty():
		return ""
	var lines: PackedStringArray = ["Opening roll:"]
	for round_raw in rounds:
		if not (round_raw is Dictionary):
			continue
		var round: Dictionary = round_raw
		var rolls: Array = round.get("rolls", [])
		var roll_parts: PackedStringArray = []
		for entry_raw in rolls:
			if not (entry_raw is Dictionary):
				continue
			var entry: Dictionary = entry_raw
			var player := int(entry.get("player", 0))
			var roll := int(entry.get("roll", 0))
			roll_parts.append("%s %d" % [_player_label(player), roll])
		if not roll_parts.is_empty():
			lines.append(", ".join(roll_parts))
		var leaders: Array = round.get("leaders", [])
		if leaders.size() > 1:
			var leader_names: PackedStringArray = []
			for leader_raw in leaders:
				leader_names.append(_player_label(int(leader_raw)))
			lines.append("Tie - reroll: %s" % ", ".join(leader_names))
	lines.append("%s starts." % _player_label(_state.current_player))
	return "\n".join(lines)

func _mp_set_turn(player: int) -> void:
	_state.current_player = player
	_board.set_state(_state)
	_board.clear_legal_moves()
	_pending_moves = []
	_pending_roll = null

	if _mp_waiting_for_opening_roll:
		if _mp_role == "host":
			_set_status_text("Opening roll phase - click Roll to determine who starts.")
			_set_roll_ready(true)
		elif _mp_role == "spectator":
			_set_status_text("Spectating - waiting for host to roll for opening player...")
			_set_roll_ready(false)
		else:
			_set_status_text("Waiting for host to roll for opening player...")
			_set_roll_ready(false)
		return

	var is_ai_seat: bool = (_seat_types[player] != "human")
	var is_my_turn: bool = (_mp_role != "spectator" and player == _mp_my_seat)
	var host_acts: bool  = (_mp_role == "host" and is_ai_seat)

	if is_my_turn or host_acts:
		var who: String = _player_label(player) + (" (AI)" if host_acts else "")
		_render_status("%s — click Roll" % who)
		_set_roll_ready(true)
	else:
		var msg: String
		if _mp_role == "spectator":
			msg = "Spectating — %s's turn" % _player_label(player)
		else:
			msg = "Waiting for %s to roll..." % _player_label(player)
		_render_status(msg)
		_set_roll_ready(false)

func _mp_on_roll_result(payload: Dictionary) -> void:
	var player    := int(payload.get("player", 0))
	var roll      := int(payload.get("roll", 1))
	var legal_raw: Array = payload.get("legalMoves", [])
	var is_ai: bool = bool(payload.get("isAI", false))

	_state.current_player = player
	await _play_roll_visual(roll)

	var label: String = _player_label(player) + (" (AI)" if is_ai else "")
	var line: String  = "%s rolled %d" % [label, roll]

	if legal_raw.is_empty():
		_render_status(line + "\nNo legal moves — advancing...")
		return

	var is_my_turn: bool = (_mp_role != "spectator" and player == _mp_my_seat)
	var host_acts: bool  = (_mp_role == "host" and is_ai)

	if host_acts:
		_mp_do_ai_turn(player, roll, legal_raw)
		_render_status(line + "\n%s (AI) is thinking..." % _player_label(player))
	elif is_my_turn:
		_pending_moves = legal_raw.duplicate(true)
		_pending_roll  = roll
		_board.set_legal_moves(_pending_moves, player)
		_render_status(line + "\nSelect a marble to move")
	else:
		_render_status(line + "\nWaiting for %s to move..." % _player_label(player))

func _mp_on_state_update(payload: Dictionary) -> void:
	var gs: Dictionary    = payload.get("gameState", {})
	var current_player    := int(payload.get("currentPlayer", 0))
	var no_legal: bool    = bool(payload.get("noLegalMoves", false))
	var opening_resolved: bool = bool(payload.get("openingResolved", false))
	var opening_rounds: Array = payload.get("openingRollRounds", [])

	_state = _mp_deserialize_state(gs)
	_die_label.text = "–"
	if opening_resolved:
		_mp_waiting_for_opening_roll = false

	if no_legal:
		_set_status_text("No legal moves — %s's turn" % _player_label(current_player))

	_turn_number += 1
	_mp_set_turn(current_player)
	if opening_resolved:
		var summary := _mp_format_opening_roll_summary(opening_rounds)
		if not summary.is_empty():
			_set_status_text(summary + "\n\n" + _status.text)

func _mp_on_chat_received(payload: Dictionary) -> void:
	if not _is_multiplayer:
		return
	var sender: String = str(payload.get("senderName", "?"))
	var text: String = str(payload.get("text", ""))
	var sender_type: String = str(payload.get("senderType", "player"))
	if sender_type == "spectator":
		_chat_log.append_text("[color=#a09080]👁 %s:[/color] %s\n" % [sender.xml_escape(), text.xml_escape()])
	else:
		_chat_log.append_text("[color=#d8c090]%s:[/color] %s\n" % [sender.xml_escape(), text.xml_escape()])

func _on_chat_send() -> void:
	if not _is_multiplayer:
		return
	var text := _chat_input.text.strip_edges()
	if text.is_empty():
		return
	Network.send_chat_message(text)
	_chat_input.text = ""
	_chat_input.grab_focus()

func _mp_on_game_over(payload: Dictionary) -> void:
	_game_over = true
	_mp_disconnect_signals()
	var winner      := int(payload.get("winner", 0))
	var winner_name := str(payload.get("winnerName", _player_label(winner)))
	_win_title.text = "%s Wins!" % winner_name
	_win_title.self_modulate = PLAYER_COLORS[winner]
	_win_subtitle.text = "Game finished on turn %d" % _turn_number
	_win_overlay.visible = true

func _mp_on_player_disconnected(payload: Dictionary) -> void:
	var name: String = str(payload.get("name", "A player"))
	_set_status_text("[color=#c09080]%s disconnected — waiting for reconnect...[/color]" % name)
	_set_roll_ready(false)

func _mp_on_player_reconnected(payload: Dictionary) -> void:
	var name: String = str(payload.get("name", "A player"))
	_set_status_text("%s reconnected." % name)
	_mp_set_turn(_state.current_player)

func _mp_on_server_disconnected() -> void:
	_game_over = true
	_set_roll_ready(false)
	_roll_button.text = "Disconnected"
	_set_status_text("Disconnected from server.")

func _mp_do_ai_turn(player: int, roll: int, legal_moves: Array) -> void:
	_ai_busy = true
	await get_tree().create_timer(1.5).timeout
	if _game_over:
		_ai_busy = false
		return
	var profile_key: String = _seat_types[player]
	var ai_player = _profiles.get(profile_key, null)
	if ai_player == null:
		ai_player = _profiles.get("random", _profiles.values()[0])
	var move: Dictionary = ai_player.choose_move(_state, player, roll, legal_moves)
	_ai_busy = false
	Network.send_submit_move(move)

func _mp_disconnect_signals() -> void:
	var pairs := [
		[Network.roll_result,              Callable(self, "_mp_on_roll_result")],
		[Network.state_update,             Callable(self, "_mp_on_state_update")],
		[Network.chat_received,            Callable(self, "_mp_on_chat_received")],
		[Network.game_over_received,       Callable(self, "_mp_on_game_over")],
		[Network.player_disconnected,      Callable(self, "_mp_on_player_disconnected")],
		[Network.player_reconnected,       Callable(self, "_mp_on_player_reconnected")],
		[Network.disconnected_from_server, Callable(self, "_mp_on_server_disconnected")],
	]
	for pair: Array in pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)

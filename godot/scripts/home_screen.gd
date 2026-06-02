extends Control

const WORDMARK_TEXTURE = preload("res://assets/textures/wahulo_wordmark.png")

# Main buttons
@onready var _brand_title: TextureRect  = $MainCenter/HomePanel/Content/BrandTitle
@onready var _subtitle: Label           = $MainCenter/HomePanel/Content/Subtitle
@onready var _play_solo_btn: Button     = $MainCenter/HomePanel/Content/PlaySoloButton
@onready var _host_game_btn: Button     = $MainCenter/HomePanel/Content/HostGameButton
@onready var _join_btn: Button          = $MainCenter/HomePanel/Content/JoinButton

# Host prompt
@onready var _host_layer: Control       = $HostPromptLayer
@onready var _host_name_field: LineEdit = $HostPromptLayer/Center/HostPanel/HostContent/HostNameField
@onready var _host_error: Label         = $HostPromptLayer/Center/HostPanel/HostContent/HostErrorLabel
@onready var _host_cancel_btn: Button   = $HostPromptLayer/Center/HostPanel/HostContent/HostButtons/HostCancelBtn
@onready var _host_create_btn: Button   = $HostPromptLayer/Center/HostPanel/HostContent/HostButtons/HostCreateBtn

# Join prompt
@onready var _join_layer: Control           = $JoinPromptLayer
@onready var _join_code_field: LineEdit     = $JoinPromptLayer/Center/JoinPanel/JoinContent/JoinCodeField
@onready var _join_name_field: LineEdit     = $JoinPromptLayer/Center/JoinPanel/JoinContent/JoinNameField
@onready var _join_error: Label             = $JoinPromptLayer/Center/JoinPanel/JoinContent/JoinErrorLabel
@onready var _join_cancel_btn: Button       = $JoinPromptLayer/Center/JoinPanel/JoinContent/JoinButtons/JoinCancelBtn
@onready var _join_player_btn: Button       = $JoinPromptLayer/Center/JoinPanel/JoinContent/JoinButtons/JoinAsPlayerBtn
@onready var _join_spectator_btn: Button    = $JoinPromptLayer/Center/JoinPanel/JoinContent/JoinButtons/JoinAsSpectatorBtn

var _pending_action := ""   # "host" | "join_player" | "join_spectator"
var _pending_name   := ""
var _pending_code   := ""

func _ready() -> void:
	_brand_title.texture = WORDMARK_TEXTURE
	_brand_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_brand_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	_play_solo_btn.pressed.connect(_on_play_solo)
	_host_game_btn.pressed.connect(_on_host_game)
	_join_btn.pressed.connect(_on_join)
	_host_cancel_btn.pressed.connect(_close_prompts)
	_host_create_btn.pressed.connect(_on_host_create)
	_join_cancel_btn.pressed.connect(_close_prompts)
	_join_player_btn.pressed.connect(_on_join_as_player)
	_join_spectator_btn.pressed.connect(_on_join_as_spectator)
	_host_name_field.text_submitted.connect(func(_t): _on_host_create())
	_join_name_field.text_submitted.connect(func(_t): _on_join_as_player())

	_apply_theme()
	_check_deep_link()

# --- Main button handlers ---

func _on_play_solo() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_host_game() -> void:
	_host_error.visible = false
	_host_name_field.text = ""
	_host_layer.visible = true
	_host_name_field.grab_focus()

func _on_join() -> void:
	_open_join_prompt("")

func _open_join_prompt(prefill_code: String) -> void:
	_join_error.visible = false
	_join_code_field.text = prefill_code
	_join_name_field.text = ""
	_join_layer.visible = true
	if prefill_code.is_empty():
		_join_code_field.grab_focus()
	else:
		_join_name_field.grab_focus()

# --- Host flow ---

func _on_host_create() -> void:
	var name := _host_name_field.text.strip_edges()
	if name.is_empty():
		_host_error.text = "Please enter a display name."
		_host_error.visible = true
		return
	_pending_action = "host"
	_pending_name = name
	_pending_code = ""
	_host_create_btn.text = "Connecting..."
	_set_prompt_buttons_enabled(false)
	_wire_signals()
	Network.connect_to_relay()

# --- Join flow ---

func _on_join_as_player() -> void:
	_do_join(false)

func _on_join_as_spectator() -> void:
	_do_join(true)

func _do_join(spectator: bool) -> void:
	var code := _join_code_field.text.strip_edges().to_upper()
	var name := _join_name_field.text.strip_edges()
	if code.length() != 6:
		_join_error.text = "Game code must be 6 characters."
		_join_error.visible = true
		return
	if name.is_empty():
		_join_error.text = "Please enter a display name."
		_join_error.visible = true
		return
	_pending_action = "join_spectator" if spectator else "join_player"
	_pending_name = name
	_pending_code = code
	_join_player_btn.text = "Connecting..."
	_set_prompt_buttons_enabled(false)
	_wire_signals()
	Network.connect_to_relay()

# --- Network signal handlers ---

func _wire_signals() -> void:
	if not Network.connected_to_server.is_connected(_on_connected):
		Network.connected_to_server.connect(_on_connected)
	if not Network.connection_failed.is_connected(_on_connection_failed):
		Network.connection_failed.connect(_on_connection_failed)
	if not Network.room_created.is_connected(_on_room_created):
		Network.room_created.connect(_on_room_created)
	if not Network.room_joined.is_connected(_on_room_joined):
		Network.room_joined.connect(_on_room_joined)
	if not Network.spectator_joined_ok.is_connected(_on_spectator_joined_ok):
		Network.spectator_joined_ok.connect(_on_spectator_joined_ok)
	if not Network.join_error.is_connected(_on_join_error):
		Network.join_error.connect(_on_join_error)

func _unwire_signals() -> void:
	var pairs := [
		[Network.connected_to_server,  Callable(self, "_on_connected")],
		[Network.connection_failed,     Callable(self, "_on_connection_failed")],
		[Network.room_created,          Callable(self, "_on_room_created")],
		[Network.room_joined,           Callable(self, "_on_room_joined")],
		[Network.spectator_joined_ok,   Callable(self, "_on_spectator_joined_ok")],
		[Network.join_error,            Callable(self, "_on_join_error")],
	]
	for pair: Array in pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)

func _on_connected() -> void:
	match _pending_action:
		"host":
			Network.send_create_room(_pending_name)
			_host_create_btn.text = "Creating room..."
		"join_player":
			Network.send_join_room(_pending_code, _pending_name)
			_join_player_btn.text = "Joining..."
		"join_spectator":
			Network.send_join_as_spectator(_pending_code, _pending_name)
			_join_spectator_btn.text = "Connecting..."

func _on_connection_failed() -> void:
	_unwire_signals()
	_set_prompt_buttons_enabled(true)
	_reset_prompt_labels()
	if _host_layer.visible:
		_host_error.text = "Could not connect to server."
		_host_error.visible = true
	elif _join_layer.visible:
		_join_error.text = "Could not connect to server."
		_join_error.visible = true

func _on_room_created(payload: Dictionary) -> void:
	_unwire_signals()
	Network.ctx = {
		"role":           "host",
		"game_id":        str(payload.get("gameId", "")),
		"seat":           int(payload.get("seat", 0)),
		"display_name":   _pending_name,
		"seats":          [],
		"spectator_count": 0,
	}
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_room_joined(payload: Dictionary) -> void:
	_unwire_signals()
	Network.ctx = {
		"role":           "player",
		"game_id":        str(payload.get("gameId", "")),
		"seat":           int(payload.get("seat", -1)),
		"display_name":   _pending_name,
		"seats":          payload.get("seats", []),
		"spectator_count": int(payload.get("spectatorCount", 0)),
	}
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_spectator_joined_ok(payload: Dictionary) -> void:
	_unwire_signals()
	Network.ctx = {
		"role":           "spectator",
		"game_id":        str(payload.get("gameId", "")),
		"seat":           -1,
		"display_name":   _pending_name,
		"seats":          [],
		"spectator_count": int(payload.get("spectatorCount", 0)),
	}
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_join_error(payload: Dictionary) -> void:
	_unwire_signals()
	_set_prompt_buttons_enabled(true)
	_reset_prompt_labels()
	_join_error.text = str(payload.get("message", "Failed to join room."))
	_join_error.visible = true

# --- Prompt helpers ---

func _close_prompts() -> void:
	_unwire_signals()
	Network.disconnect_from_relay()
	_host_layer.visible = false
	_join_layer.visible = false
	_set_prompt_buttons_enabled(true)
	_reset_prompt_labels()
	_pending_action = ""

func _set_prompt_buttons_enabled(on: bool) -> void:
	_host_cancel_btn.disabled = not on
	_host_create_btn.disabled = not on
	_join_cancel_btn.disabled = not on
	_join_player_btn.disabled = not on
	_join_spectator_btn.disabled = not on

func _reset_prompt_labels() -> void:
	_host_create_btn.text = "Create Room"
	_join_player_btn.text = "Join"
	_join_spectator_btn.text = "Watch"

# --- Deep link ---

func _check_deep_link() -> void:
	if not OS.has_feature("web"):
		return
	var path: String = JavaScriptBridge.eval("window.location.pathname")
	if path.begins_with("/join/"):
		var code := path.substr(6).strip_edges().to_upper()
		if code.length() == 6:
			_open_join_prompt(code)

# --- Visual theme ---

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

	var prompt_style := panel_style.duplicate()
	prompt_style.content_margin_left = 28
	prompt_style.content_margin_top = 28
	prompt_style.content_margin_right = 28
	prompt_style.content_margin_bottom = 28

	($MainCenter/HomePanel as PanelContainer).add_theme_stylebox_override("panel", panel_style)
	($HostPromptLayer/Center/HostPanel as PanelContainer).add_theme_stylebox_override("panel", prompt_style)
	($JoinPromptLayer/Center/JoinPanel as PanelContainer).add_theme_stylebox_override("panel", prompt_style)

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

	var btn_disabled := btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.19, 0.15, 0.12, 0.74)
	btn_disabled.border_color = Color(0.41, 0.34, 0.28, 0.74)

	var all_buttons: Array = [
		_play_solo_btn, _host_game_btn, _join_btn,
		_host_cancel_btn, _host_create_btn,
		_join_cancel_btn, _join_player_btn, _join_spectator_btn,
	]
	for btn: Button in all_buttons:
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		btn.add_theme_stylebox_override("disabled", btn_disabled)
		btn.add_theme_color_override("font_color", Color(0.97, 0.93, 0.86))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.90))
		btn.add_theme_color_override("font_pressed_color", Color(0.97, 0.93, 0.86))
		btn.add_theme_color_override("font_disabled_color", Color(0.67, 0.62, 0.57))
		btn.add_theme_font_size_override("font_size", 26)

	for field: LineEdit in [_host_name_field, _join_code_field, _join_name_field]:
		field.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
		field.add_theme_color_override("font_placeholder_color", Color(0.62, 0.58, 0.52))

	_subtitle.add_theme_color_override("font_color", Color(0.78, 0.71, 0.61))
	_subtitle.add_theme_font_size_override("font_size", 20)

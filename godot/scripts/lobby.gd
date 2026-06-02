extends Control

const PLAYER_COLORS := [
	Color(0.86, 0.20, 0.17),
	Color(0.16, 0.60, 0.27),
	Color(0.93, 0.75, 0.17),
	Color(0.17, 0.34, 0.78),
]

const AI_PROFILE_ORDER := [
	"random", "swarm", "tortoise", "engineer",
	"balanced", "assassin", "gatekeeper", "gambler", "sprinter",
]
const AI_PROFILE_LABELS := {
	"random":     "Random",
	"swarm":      "Swarm",
	"tortoise":   "Tortoise",
	"engineer":   "Engineer",
	"balanced":   "Balanced",
	"assassin":   "Assassin",
	"gatekeeper": "Gatekeeper",
	"gambler":    "Gambler",
	"sprinter":   "Sprinter",
}

@onready var _code_value: Label               = $ScrollContainer/Center/LobbyPanel/Content/CodeRow/GameCodeValue
@onready var _host_code_buttons: HBoxContainer = $ScrollContainer/Center/LobbyPanel/Content/HostCodeButtons
@onready var _copy_code_btn: Button           = $ScrollContainer/Center/LobbyPanel/Content/HostCodeButtons/CopyCodeBtn
@onready var _copy_link_btn: Button           = $ScrollContainer/Center/LobbyPanel/Content/HostCodeButtons/CopyLinkBtn
@onready var _share_link_label: Label         = $ScrollContainer/Center/LobbyPanel/Content/ShareLinkLabel
@onready var _seat_list: VBoxContainer        = $ScrollContainer/Center/LobbyPanel/Content/SeatList
@onready var _spectator_count_label: Label    = $ScrollContainer/Center/LobbyPanel/Content/SpectatorCountLabel
@onready var _host_controls_section: VBoxContainer = $ScrollContainer/Center/LobbyPanel/Content/HostControlsSection
@onready var _host_seat_controls: VBoxContainer = $ScrollContainer/Center/LobbyPanel/Content/HostControlsSection/HostSeatControls
@onready var _waiting_label: Label            = $ScrollContainer/Center/LobbyPanel/Content/WaitingLabel
@onready var _chat_log: RichTextLabel         = $ScrollContainer/Center/LobbyPanel/Content/ChatSection/ChatLog
@onready var _chat_input: LineEdit            = $ScrollContainer/Center/LobbyPanel/Content/ChatSection/ChatInputRow/ChatInput
@onready var _chat_send_btn: Button           = $ScrollContainer/Center/LobbyPanel/Content/ChatSection/ChatInputRow/ChatSendBtn
@onready var _start_game_btn: Button          = $ScrollContainer/Center/LobbyPanel/Content/ActionRow/StartGameBtn
@onready var _leave_btn: Button               = $ScrollContainer/Center/LobbyPanel/Content/ActionRow/LeaveBtn

var _role := ""
var _game_id := ""
var _my_seat := -1
var _my_name := ""
var _seats: Array = []
var _spectator_count := 0

func _ready() -> void:
	_role            = str(Network.ctx.get("role", "spectator"))
	_game_id         = str(Network.ctx.get("game_id", ""))
	_my_seat         = int(Network.ctx.get("seat", -1))
	_my_name         = str(Network.ctx.get("display_name", ""))
	_spectator_count = int(Network.ctx.get("spectator_count", 0))

	var ctx_seats: Array = Network.ctx.get("seats", [])
	if ctx_seats.is_empty():
		_seats = []
		for i in range(4):
			_seats.append({"index": i, "type": "empty", "name": null, "aiProfile": null})
		if _role == "host" and _my_seat >= 0:
			_seats[_my_seat]["type"] = "human"
			_seats[_my_seat]["name"] = _my_name
	else:
		_seats = ctx_seats.duplicate(true)

	_apply_theme()
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	_code_value.text = _game_id

	if _role == "host":
		_host_code_buttons.visible = true
		_share_link_label.visible = true
		_share_link_label.text = "wahulo.com/join/" + _game_id
		_host_controls_section.visible = true
		_start_game_btn.visible = true
		_copy_code_btn.pressed.connect(_on_copy_code)
		_copy_link_btn.pressed.connect(_on_copy_link)
		_start_game_btn.pressed.connect(_on_start_game)
	else:
		_waiting_label.visible = true

	_leave_btn.pressed.connect(_on_leave)
	_chat_send_btn.pressed.connect(_on_chat_send)
	_chat_input.text_submitted.connect(func(_t): _on_chat_send())

	_refresh_seat_list()
	_refresh_host_controls()
	_refresh_spectator_count()

func _connect_signals() -> void:
	Network.seat_updated.connect(_on_seat_updated)
	Network.chat_received.connect(_on_chat_received)
	Network.spectator_count_changed.connect(_on_spectator_count_changed)
	Network.game_started.connect(_on_game_started)
	Network.player_disconnected.connect(_on_player_disconnected)
	Network.player_reconnected.connect(_on_player_reconnected)
	Network.disconnected_from_server.connect(_on_server_disconnected)

func _disconnect_signals() -> void:
	var pairs := [
		[Network.seat_updated,              Callable(self, "_on_seat_updated")],
		[Network.chat_received,             Callable(self, "_on_chat_received")],
		[Network.spectator_count_changed,   Callable(self, "_on_spectator_count_changed")],
		[Network.game_started,              Callable(self, "_on_game_started")],
		[Network.player_disconnected,       Callable(self, "_on_player_disconnected")],
		[Network.player_reconnected,        Callable(self, "_on_player_reconnected")],
		[Network.disconnected_from_server,  Callable(self, "_on_server_disconnected")],
	]
	for pair: Array in pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)

# --- Seat list ---

func _refresh_seat_list() -> void:
	for child in _seat_list.get_children():
		child.queue_free()

	for i in range(_seats.size()):
		var seat: Dictionary = _seats[i]
		var seat_type: String = str(seat.get("type", "empty"))
		var seat_name: Variant = seat.get("name", null)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.color = PLAYER_COLORS[i]
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 20)

		var tag_lbl := Label.new()
		tag_lbl.add_theme_font_size_override("font_size", 17)

		match seat_type:
			"human":
				name_lbl.text = str(seat_name) if seat_name != null else "Player"
				if i == _my_seat:
					if _role == "host":
						tag_lbl.text = "(You — Host)"
					else:
						tag_lbl.text = "(You)"
					tag_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.60))
				elif i == 0:
					tag_lbl.text = "(Host)"
					tag_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.65))
			"ai":
				var profile: String = str(seat.get("aiProfile", ""))
				var label: String = AI_PROFILE_LABELS.get(profile, profile.capitalize())
				name_lbl.text = label + " AI"
				name_lbl.add_theme_color_override("font_color", Color(0.72, 0.66, 0.58))
			_:
				name_lbl.text = "[Waiting...]"
				name_lbl.add_theme_color_override("font_color", Color(0.54, 0.50, 0.46))

		row.add_child(name_lbl)
		row.add_child(tag_lbl)
		_seat_list.add_child(row)

# --- Host seat controls ---

func _refresh_host_controls() -> void:
	if _role != "host":
		return
	for child in _host_seat_controls.get_children():
		child.queue_free()

	var any_configurable := false
	for i in range(_seats.size()):
		if i == _my_seat:
			continue
		var seat: Dictionary = _seats[i]
		var seat_type: String = str(seat.get("type", "empty"))
		if seat_type == "human":
			continue  # player joined, no dropdown needed

		any_configurable = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var lbl := Label.new()
		lbl.text = "Seat %d:" % (i + 1)
		lbl.custom_minimum_size = Vector2(72, 0)
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(lbl)

		var opt := OptionButton.new()
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.custom_minimum_size = Vector2(0, 44)
		opt.add_item("Wait for player", 0)
		for j in range(AI_PROFILE_ORDER.size()):
			opt.add_item(AI_PROFILE_LABELS[AI_PROFILE_ORDER[j]] + " AI", j + 1)

		var current_profile: String = str(seat.get("aiProfile", ""))
		if seat_type == "ai" and not current_profile.is_empty():
			var idx := AI_PROFILE_ORDER.find(current_profile)
			opt.select(idx + 1 if idx >= 0 else 0)
		else:
			opt.select(0)

		opt.item_selected.connect(_on_seat_option_selected.bind(i))
		_apply_option_button_theme(opt)
		row.add_child(opt)
		_host_seat_controls.add_child(row)

	_host_controls_section.visible = any_configurable
	_update_start_button()

func _update_start_button() -> void:
	if _role != "host":
		return
	var any_empty := false
	for seat: Dictionary in _seats:
		if str(seat.get("type", "empty")) == "empty":
			any_empty = true
			break
	_start_game_btn.disabled = any_empty

# --- Spectator count ---

func _refresh_spectator_count() -> void:
	if _spectator_count <= 0:
		_spectator_count_label.text = ""
	elif _spectator_count == 1:
		_spectator_count_label.text = "👁 1 spectator watching"
	else:
		_spectator_count_label.text = "👁 %d spectators watching" % _spectator_count

# --- Network event handlers ---

func _on_seat_updated(payload: Dictionary) -> void:
	var new_seats: Array = payload.get("seats", [])
	if not new_seats.is_empty():
		_seats = new_seats.duplicate(true)
	_spectator_count = int(payload.get("spectatorCount", _spectator_count))
	_refresh_seat_list()
	_refresh_host_controls()
	_refresh_spectator_count()

func _on_spectator_count_changed(payload: Dictionary) -> void:
	_spectator_count = int(payload.get("count", 0))
	_refresh_spectator_count()

func _on_chat_received(payload: Dictionary) -> void:
	var sender: String = str(payload.get("senderName", "?"))
	var text: String = str(payload.get("text", ""))
	var sender_type: String = str(payload.get("senderType", "player"))
	if sender_type == "spectator":
		_chat_log.append_text("[color=#a09080]👁 %s:[/color] %s\n" % [sender.xml_escape(), text.xml_escape()])
	else:
		_chat_log.append_text("[color=#d8c090]%s:[/color] %s\n" % [sender.xml_escape(), text.xml_escape()])

func _on_player_disconnected(payload: Dictionary) -> void:
	var name: String = str(payload.get("name", "A player"))
	_chat_log.append_text("[color=#b08070]%s disconnected.[/color]\n" % name.xml_escape())

func _on_player_reconnected(payload: Dictionary) -> void:
	var name: String = str(payload.get("name", "A player"))
	_chat_log.append_text("[color=#80b070]%s reconnected.[/color]\n" % name.xml_escape())

func _on_server_disconnected() -> void:
	_chat_log.append_text("[color=#b08070]Disconnected from server.[/color]\n")
	_start_game_btn.disabled = true

func _on_game_started(payload: Dictionary) -> void:
	_disconnect_signals()
	# Phase 4c: replace with multiplayer game scene transition.
	# Store game state for the game scene to read from Network.ctx.
	Network.ctx["game_state"]     = payload.get("gameState", {})
	Network.ctx["current_player"] = int(payload.get("currentPlayer", 0))
	Network.ctx["seats"]          = _seats
	Network.ctx["my_seat"]        = _my_seat
	Network.ctx["my_name"]        = _my_name
	Network.ctx["role"]           = _role
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- Host actions ---

func _on_seat_option_selected(option_idx: int, seat_index: int) -> void:
	if option_idx == 0:
		Network.send_configure_seat(seat_index, "empty")
	else:
		var profile_key: String = AI_PROFILE_ORDER[option_idx - 1]
		Network.send_configure_seat(seat_index, "ai", profile_key)

func _on_start_game() -> void:
	Network.send_start_game()

func _on_copy_code() -> void:
	DisplayServer.clipboard_set(_game_id)
	_copy_code_btn.text = "Copied!"
	get_tree().create_timer(2.0).timeout.connect(func(): _copy_code_btn.text = "Copy Code")

func _on_copy_link() -> void:
	DisplayServer.clipboard_set("https://wahulo.com/join/" + _game_id)
	_copy_link_btn.text = "Copied!"
	get_tree().create_timer(2.0).timeout.connect(func(): _copy_link_btn.text = "Copy Link")

# --- Chat ---

func _on_chat_send() -> void:
	var text := _chat_input.text.strip_edges()
	if text.is_empty():
		return
	Network.send_chat_message(text)
	_chat_input.text = ""
	_chat_input.grab_focus()

# --- Leave ---

func _on_leave() -> void:
	_disconnect_signals()
	Network.disconnect_from_relay()
	Network.ctx = {}
	get_tree().change_scene_to_file("res://scenes/HomeScreen.tscn")

# --- Theme ---

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
	panel_style.content_margin_left = 24
	panel_style.content_margin_top = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_bottom = 24
	($ScrollContainer/Center/LobbyPanel as PanelContainer).add_theme_stylebox_override("panel", panel_style)

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

	for btn: Button in [_copy_code_btn, _copy_link_btn, _chat_send_btn, _leave_btn, _start_game_btn]:
		_apply_button_theme(btn, btn_normal, btn_hover, btn_pressed, btn_disabled)

	var chat_style := StyleBoxFlat.new()
	chat_style.bg_color = Color(0.13, 0.10, 0.08, 0.72)
	chat_style.border_color = Color(0.43, 0.32, 0.23, 0.88)
	chat_style.border_width_left = 1
	chat_style.border_width_top = 1
	chat_style.border_width_right = 1
	chat_style.border_width_bottom = 1
	chat_style.corner_radius_top_left = 8
	chat_style.corner_radius_top_right = 8
	chat_style.corner_radius_bottom_left = 8
	chat_style.corner_radius_bottom_right = 8
	chat_style.content_margin_left = 8
	chat_style.content_margin_top = 6
	chat_style.content_margin_right = 8
	chat_style.content_margin_bottom = 6
	_chat_log.add_theme_stylebox_override("normal", chat_style)
	_chat_log.add_theme_color_override("default_color", Color(0.92, 0.87, 0.78))
	_chat_log.add_theme_font_size_override("normal_font_size", 18)

	_chat_input.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	_chat_input.add_theme_color_override("font_placeholder_color", Color(0.62, 0.58, 0.52))

func _apply_button_theme(btn: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat, disabled: StyleBoxFlat) -> void:
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.97, 0.93, 0.86))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.90))
	btn.add_theme_color_override("font_pressed_color", Color(0.97, 0.93, 0.86))
	btn.add_theme_color_override("font_disabled_color", Color(0.67, 0.62, 0.57))
	btn.add_theme_font_size_override("font_size", 20)

func _apply_option_button_theme(opt: OptionButton) -> void:
	var opt_normal := StyleBoxFlat.new()
	opt_normal.bg_color = Color(0.92, 0.87, 0.78, 0.98)
	opt_normal.border_color = Color(0.34, 0.25, 0.17, 0.96)
	opt_normal.border_width_left = 1
	opt_normal.border_width_top = 1
	opt_normal.border_width_right = 1
	opt_normal.border_width_bottom = 1
	opt_normal.corner_radius_top_left = 6
	opt_normal.corner_radius_top_right = 6
	opt_normal.corner_radius_bottom_left = 6
	opt_normal.corner_radius_bottom_right = 6
	opt_normal.content_margin_left = 8
	opt_normal.content_margin_right = 8
	var opt_hover := opt_normal.duplicate()
	opt_hover.bg_color = Color(0.96, 0.91, 0.82, 0.98)
	opt.add_theme_stylebox_override("normal", opt_normal)
	opt.add_theme_stylebox_override("hover", opt_hover)
	opt.add_theme_color_override("font_color", Color(0.10, 0.08, 0.06))
	opt.add_theme_color_override("font_hover_color", Color(0.10, 0.08, 0.06))
	opt.add_theme_font_size_override("font_size", 18)

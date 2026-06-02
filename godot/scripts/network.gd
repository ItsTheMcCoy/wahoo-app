extends Node

# Switch RELAY_URL to RELAY_URL_PROD before exporting for production.
const RELAY_URL_DEV  := "ws://localhost:8080"
const RELAY_URL_PROD := "wss://wahulo.onrender.com"
const RELAY_URL      := RELAY_URL_DEV

const PING_INTERVAL_SEC := 30.0

# --- Signals emitted when connection state changes ---
signal connected_to_server()
signal disconnected_from_server()
signal connection_failed()

# --- Signals: one per server → client message type ---
signal room_created(payload: Dictionary)
signal room_joined(payload: Dictionary)
signal spectator_joined_ok(payload: Dictionary)
signal seat_updated(payload: Dictionary)
signal join_error(payload: Dictionary)
signal game_started(payload: Dictionary)
signal roll_result(payload: Dictionary)
signal state_update(payload: Dictionary)
signal game_over_received(payload: Dictionary)
signal chat_received(payload: Dictionary)
signal spectator_count_changed(payload: Dictionary)
signal player_disconnected(payload: Dictionary)
signal player_reconnected(payload: Dictionary)
signal server_error(payload: Dictionary)

# Set before navigating to Lobby.tscn; read by lobby.gd on _ready().
var ctx: Dictionary = {}

var _socket    := WebSocketPeer.new()
var _state     := WebSocketPeer.STATE_CLOSED
var _active    := false
var _ping_timer := 0.0

func _process(delta: float) -> void:
	if not _active:
		return

	_socket.poll()
	var new_state := _socket.get_ready_state()

	if new_state != _state:
		var old_state := _state
		_state = new_state
		_on_state_changed(old_state, new_state)

	if _state == WebSocketPeer.STATE_CLOSED:
		_active = false
		return

	if _state == WebSocketPeer.STATE_OPEN:
		_ping_timer += delta
		if _ping_timer >= PING_INTERVAL_SEC:
			_ping_timer = 0.0
			_send_raw({"type": "ping"})

		while _socket.get_available_packet_count() > 0:
			var raw  := _socket.get_packet()
			var text := raw.get_string_from_utf8()
			var msg: Variant = JSON.parse_string(text)
			if msg is Dictionary:
				_dispatch(msg)

# --- Public API ---

func connect_to_relay() -> void:
	if _active:
		return
	_active = true
	_ping_timer = 0.0
	var err := _socket.connect_to_url(RELAY_URL)
	if err != OK:
		_active = false
		connection_failed.emit()

func disconnect_from_relay() -> void:
	if _active:
		_socket.close()

func is_open() -> bool:
	return _state == WebSocketPeer.STATE_OPEN

# --- Send methods (client → server) ---

func send_create_room(host_name: String) -> void:
	_send_raw({"type": "create_room", "hostName": host_name})

func send_join_room(game_id: String, player_name: String) -> void:
	_send_raw({"type": "join_room", "gameId": game_id, "playerName": player_name})

func send_join_as_spectator(game_id: String, spectator_name: String) -> void:
	_send_raw({"type": "join_as_spectator", "gameId": game_id, "spectatorName": spectator_name})

# seatType: "ai" | "empty" — uses seatType (not type) to avoid collision with message type field.
func send_configure_seat(seat: int, seat_type: String, ai_profile: Variant = null) -> void:
	var msg := {"type": "configure_seat", "seat": seat, "seatType": seat_type}
	if ai_profile != null:
		msg["aiProfile"] = str(ai_profile)
	_send_raw(msg)

func send_start_game() -> void:
	_send_raw({"type": "start_game"})

func send_roll_request() -> void:
	_send_raw({"type": "roll_request"})

func send_submit_move(move: Dictionary) -> void:
	_send_raw({
		"type":     "submit_move",
		"marble":   move["marble"],
		"dest":     move["dest"],
		"kind":     move["kind"],
		"captures": move.get("captures", null),
	})

func send_chat_message(text: String) -> void:
	_send_raw({"type": "chat_message", "text": text})

# --- Internals ---

func _send_raw(payload: Dictionary) -> void:
	if _state != WebSocketPeer.STATE_OPEN:
		return
	_socket.send_text(JSON.stringify(payload))

func _on_state_changed(old_state: int, new_state: int) -> void:
	match new_state:
		WebSocketPeer.STATE_OPEN:
			connected_to_server.emit()
		WebSocketPeer.STATE_CLOSED:
			if old_state == WebSocketPeer.STATE_OPEN or old_state == WebSocketPeer.STATE_CLOSING:
				disconnected_from_server.emit()
			else:
				connection_failed.emit()

func _dispatch(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"room_created":        room_created.emit(msg)
		"room_joined":         room_joined.emit(msg)
		"spectator_joined_ok": spectator_joined_ok.emit(msg)
		"seat_updated":        seat_updated.emit(msg)
		"join_error":          join_error.emit(msg)
		"game_started":        game_started.emit(msg)
		"roll_result":         roll_result.emit(msg)
		"state_update":        state_update.emit(msg)
		"game_over":           game_over_received.emit(msg)
		"chat_received":       chat_received.emit(msg)
		"spectator_count":     spectator_count_changed.emit(msg)
		"player_disconnected": player_disconnected.emit(msg)
		"player_reconnected":  player_reconnected.emit(msg)
		"error":               server_error.emit(msg)
		"pong":                pass  # keepalive ack, no action needed

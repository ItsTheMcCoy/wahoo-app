extends Control

const WahooState = preload("res://scripts/wahoo_state.gd")
const WahooRules = preload("res://scripts/wahoo_rules.gd")
const WahooRulesSmoke = preload("res://scripts/wahoo_rules_smoke.gd")
const WahooAI = preload("res://scripts/wahoo_ai.gd")

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

# Profile keys in easiest→hardest order for the setup dropdown (matches play.py PROFILE_DISPLAY_ORDER)
const PROFILE_ORDER := [
	"human", "random", "swarm", "tortoise", "engineer",
	"balanced", "assassin", "gatekeeper", "human_like", "gambler", "sprinter"
]
const PROFILE_LABELS := {
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
@onready var _board = $Root/BoardFrame/BoardView
@onready var _status: RichTextLabel = $Root/SidePanel/Status
@onready var _roll_button: Button = $Root/SidePanel/RollButton
@onready var _end_turn_button: Button = $Root/SidePanel/EndTurnButton
@onready var _win_overlay: ColorRect = $WinOverlay
@onready var _win_title: Label = $WinOverlay/WinPanel/WinContent/WinTitle
@onready var _win_subtitle: Label = $WinOverlay/WinPanel/WinContent/WinSubtitle
@onready var _new_game_button: Button = $WinOverlay/WinPanel/WinContent/NewGameButton
@onready var _setup_overlay: ColorRect = $SetupOverlay
@onready var _start_button: Button = $SetupOverlay/SetupPanel/SetupContent/StartButton
@onready var _seat_option_0: OptionButton = $SetupOverlay/SetupPanel/SetupContent/Seat0Row/Seat0Option
@onready var _seat_option_1: OptionButton = $SetupOverlay/SetupPanel/SetupContent/Seat1Row/Seat1Option
@onready var _seat_option_2: OptionButton = $SetupOverlay/SetupPanel/SetupContent/Seat2Row/Seat2Option
@onready var _seat_option_3: OptionButton = $SetupOverlay/SetupPanel/SetupContent/Seat3Row/Seat3Option
@onready var _seat_name_0: LineEdit = $SetupOverlay/SetupPanel/SetupContent/Seat0Row/Seat0Name
@onready var _seat_name_1: LineEdit = $SetupOverlay/SetupPanel/SetupContent/Seat1Row/Seat1Name
@onready var _seat_name_2: LineEdit = $SetupOverlay/SetupPanel/SetupContent/Seat2Row/Seat2Name
@onready var _seat_name_3: LineEdit = $SetupOverlay/SetupPanel/SetupContent/Seat3Row/Seat3Name

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
var _ai_busy := false
var _show_smoke_summary := false
var _starting_phase := false
var _awaiting_human_starting_roll := false

func _ready() -> void:
	_rng.randomize()
	_roll_button.pressed.connect(_on_roll_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_new_game_button.pressed.connect(_on_new_game_from_win)
	_board.move_selected.connect(_on_board_move_selected)
	_start_button.pressed.connect(_on_start_pressed)
	_smoke_summary = _build_smoke_summary()
	_setup_game_menu()
	_die_label.text = "–"
	_profiles = WahooAI.make_profiles()
	_populate_dropdowns()
	_wire_setup_inputs()
	_refresh_setup_name_fields()
	_setup_overlay.visible = true
	_board.modulate = Color(1.0, 1.0, 1.0, 0.96)

func _populate_dropdowns() -> void:
	var opts := [_seat_option_0, _seat_option_1, _seat_option_2, _seat_option_3]
	for opt in opts:
		opt.clear()
		for key in PROFILE_ORDER:
			opt.add_item(PROFILE_LABELS.get(key, key))

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
		var profile_key: String = PROFILE_ORDER[opts[i].selected]
		var field: LineEdit = fields[i]
		field.visible = profile_key == "human"
		field.placeholder_text = "%s name" % PLAYER_NAMES[i]
		if field.text.is_empty():
			field.text = PLAYER_NAMES[i]

func _on_start_pressed() -> void:
	var opts := _seat_options()
	var fields := _seat_name_fields()
	for i in range(4):
		_seat_types[i] = PROFILE_ORDER[opts[i].selected]
		if _seat_types[i] == "human":
			var entered := String(fields[i].text).strip_edges()
			_seat_display_names[i] = entered if not entered.is_empty() else PLAYER_NAMES[i]
		else:
			_seat_display_names[i] = PROFILE_LABELS.get(_seat_types[i], _seat_types[i])
	_setup_overlay.visible = false
	_new_game()

func _on_new_game_from_win() -> void:
	_win_overlay.visible = false
	_setup_overlay.visible = true
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
	_die_label.text = "–"
	_die_label.scale = Vector2.ONE
	_set_roll_ready(false)
	_roll_button.text = "Roll"
	_status.text = ""
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

	_roll_button.disabled = true
	_board.clear_legal_moves()
	_pending_moves = []
	_pending_roll = null

	var roll := _rng.randi_range(1, 6)
	await _play_roll_visual(roll)
	var player := _state.current_player
	var legal := WahooRules.legal_moves(_state, player, roll)
	var line := "%s rolled %d\n%s" % [_player_label(player), roll, _legal_moves_status_text(legal)]
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
	var line := "%s rolled %d\n%s" % [label, roll, _legal_moves_status_text(legal)]

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
	_status.text = "\n".join(lines)

func _turn_announcement(action: String) -> String:
	return "Turn %d: %s\n%s" % [_turn_number, _player_label(_state.current_player), action]

func _player_label(player: int) -> String:
	return "%s Player" % PLAYER_NAMES[player]

func _advance_to_next_player() -> void:
	_state.current_player = (_state.current_player + 1) % WahooState.NUM_PLAYERS

func _set_roll_ready(ready: bool) -> void:
	_roll_button.disabled = not ready
	_roll_button.text = "Roll"
	_end_turn_button.disabled = true
	if ready and not _game_over and not _ai_busy and not _starting_phase:
		_maybe_ai_turn()

func _set_end_turn_ready() -> void:
	_roll_button.disabled = true
	_end_turn_button.disabled = false

func _on_end_turn_pressed() -> void:
	if _game_over or _ai_busy:
		return
	_end_turn_button.disabled = true
	_advance_to_next_player()
	_turn_number += 1
	_render_status("%s is up next" % _player_label(_state.current_player))
	_set_roll_ready(true)

func _run_starting_roll_phase() -> void:
	var contenders: Array = [0, 1, 2, 3]

	_turn_label.text = ""
	_turn_label.self_modulate = Color.WHITE
	_status.text = "Roll to see who goes first."
	await get_tree().create_timer(1.0).timeout

	while contenders.size() > 1:
		if not _starting_phase:
			return
		var round_rolls: Array = []
		var highest := 0
		var highest_seat := -1

		for player in contenders:
			if not _starting_phase:
				return
			var seat := int(player)
			var name := _seat_display_names[seat]

			_turn_label.text = name
			_turn_label.self_modulate = PLAYER_COLORS[seat]
			_status.text = "%s's turn." % name

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
				highest_seat = seat

			_status.text = "%s rolled a %d." % [name, roll]
			await get_tree().create_timer(0.5).timeout
			if not _starting_phase:
				return

			_status.text = "Highest roll so far: %d by %s." % [highest, _seat_display_names[highest_seat]]
			await get_tree().create_timer(0.65).timeout
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
			_status.text = "Tie between %s!\nThey'll roll again." % ", ".join(parts)
			await get_tree().create_timer(1.0).timeout
			if not _starting_phase:
				return

		contenders = tied

	if not _starting_phase:
		return
	var winner := int(contenders[0])
	_state.current_player = winner
	_starting_phase = false
	var winner_name := _seat_display_names[winner]
	_turn_label.text = winner_name
	_turn_label.self_modulate = PLAYER_COLORS[winner]
	_status.text = "%s goes first!\nPress Roll to start." % winner_name
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

func _legal_moves_status_text(legal: Array) -> String:
	if legal.is_empty():
		return "No legal moves"

	var all_exit_base := true
	for move in legal:
		if String(move.get("kind", "")) != "exit_base":
			all_exit_base = false
			break

	if all_exit_base:
		return "Exit base available"

	return "Legal moves found: %d" % legal.size()

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
	popup.id_pressed.connect(_on_game_menu_id_pressed)
	popup.add_item("Save Game", MENU_SAVE_GAME)
	popup.add_item("Load Saved Game", MENU_LOAD_GAME)
	popup.add_separator()
	popup.add_item("Restart Game", MENU_RESTART_GAME)
	popup.add_item("Exit To Setup", MENU_EXIT_TO_SETUP)
	popup.add_separator()
	popup.add_item("Quit App", MENU_QUIT_APP)

func _on_game_menu_id_pressed(id: int) -> void:
	match id:
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
	_win_overlay.visible = false
	_setup_overlay.visible = true
	_board.clear_legal_moves()
	_set_roll_ready(false)
	_roll_button.text = "Roll"
	_die_label.text = "–"
	_refresh_setup_name_fields()
	_opening_roll_pressed.emit()  # unblock any awaiting starting-roll coroutine

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
	_board.clear_legal_moves()
	_board.set_state(_state)
	_board.set_seat_labels(_seat_display_names)
	_die_label.text = "–"
	_set_roll_ready(true)
	_render_status("Saved game loaded")

func _die_face(value: int) -> String:
	const FACES := ["", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
	return FACES[clampi(value, 1, 6)]

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

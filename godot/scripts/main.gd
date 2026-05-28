extends Control

const WahooState = preload("res://scripts/wahoo_state.gd")
const WahooRules = preload("res://scripts/wahoo_rules.gd")
const WahooRulesSmoke = preload("res://scripts/wahoo_rules_smoke.gd")

const PLAYER_NAMES := ["Red", "Green", "Yellow", "Blue"]
const PLAYER_COLORS := [
    Color(0.86, 0.20, 0.17),
    Color(0.16, 0.60, 0.27),
    Color(0.93, 0.75, 0.17),
    Color(0.17, 0.34, 0.78),
]

@onready var _turn_label: Label = $Root/Header/TurnLabel
@onready var _board = $Root/BoardFrame/BoardView
@onready var _status: RichTextLabel = $Root/Footer/Status
@onready var _roll_button: Button = $Root/Footer/RollButton
@onready var _win_overlay: ColorRect = $WinOverlay
@onready var _win_title: Label = $WinOverlay/WinPanel/WinContent/WinTitle
@onready var _win_subtitle: Label = $WinOverlay/WinPanel/WinContent/WinSubtitle
@onready var _new_game_button: Button = $WinOverlay/WinPanel/WinContent/NewGameButton

var _rng := RandomNumberGenerator.new()
var _state: WahooState
var _smoke_summary := ""
var _pending_moves: Array = []
var _pending_roll: Variant = null
var _turn_number := 1
var _game_over := false

func _ready() -> void:
    _rng.randomize()
    _roll_button.pressed.connect(_on_roll_pressed)
    _new_game_button.pressed.connect(_new_game)
    _board.move_selected.connect(_on_board_move_selected)
    _smoke_summary = _build_smoke_summary()
    _new_game()

func _new_game() -> void:
    _state = WahooState.new_game()
    _pending_moves = []
    _pending_roll = null
    _turn_number = 1
    _game_over = false
    _win_overlay.visible = false
    _board.clear_legal_moves()
    _board.set_state(_state)
    _set_roll_ready(true)
    _render_status(_turn_announcement("Roll to start"))

func _on_roll_pressed() -> void:
    if _game_over or not _pending_moves.is_empty():
        return

    _roll_button.disabled = true
    _board.clear_legal_moves()
    _pending_moves = []
    _pending_roll = null

    var roll := _rng.randi_range(1, 6)
    var player := _state.current_player
    var legal := WahooRules.legal_moves(_state, player, roll)
    var line := "%s rolled %d\nLegal moves found: %d" % [_player_label(player), roll, legal.size()]
    if legal.size() > 0:
        _pending_moves = legal.duplicate(true)
        _pending_roll = roll
        _state.pending_roll = roll
        _board.set_legal_moves(_pending_moves, player)
        line += "\nChoose a highlighted marble or destination"
        _set_roll_ready(false)
    else:
        _state.pending_roll = null
        if roll != 6:
            _advance_to_next_player()
            line += "\nNo legal move; %s is up next" % _player_label(_state.current_player)
            _turn_number += 1
        else:
            line += "\nRolled a 6; %s rolls again" % _player_label(player)
            _turn_number += 1
        _set_roll_ready(true)
    _board.set_state(_state)
    _render_status(line)

func _on_board_move_selected(move: Dictionary) -> void:
    if _game_over or _pending_moves.is_empty() or _pending_roll == null:
        return

    _roll_button.disabled = true
    var player := _state.current_player
    var roll := int(_pending_roll)
    _state.pending_roll = null
    _pending_moves = []
    _pending_roll = null
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
        _show_win_screen(player)
    elif roll == 6:
        line += "\nRolled a 6; %s rolls again" % _player_label(player)
        _turn_number += 1
        _set_roll_ready(true)
    else:
        _advance_to_next_player()
        line += "\n%s is up next" % _player_label(_state.current_player)
        _turn_number += 1
        _set_roll_ready(true)

    _render_status(line)

func _render_status(header: String) -> void:
    _turn_label.text = "Turn %d - %s" % [_turn_number, _player_label(_state.current_player)]
    _turn_label.self_modulate = PLAYER_COLORS[_state.current_player]
    var lines := [
        header,
        "",
        _smoke_summary,
    ]
    _status.text = "\n".join(lines)

func _turn_announcement(action: String) -> String:
    return "Turn %d: %s\n%s" % [_turn_number, _player_label(_state.current_player), action]

func _player_label(player: int) -> String:
    return "%s Player" % PLAYER_NAMES[player]

func _advance_to_next_player() -> void:
    _state.current_player = (_state.current_player + 1) % WahooState.NUM_PLAYERS

func _set_roll_ready(ready: bool) -> void:
    _roll_button.disabled = not ready
    _roll_button.text = "Roll" if ready else "Choose Move"

func _show_win_screen(player: int) -> void:
    _game_over = true
    _set_roll_ready(false)
    _roll_button.text = "Game Over"
    _win_title.text = "%s Wins!" % _player_label(player)
    _win_title.self_modulate = PLAYER_COLORS[player]
    _win_subtitle.text = "Game finished on turn %d" % _turn_number
    _win_overlay.visible = true

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

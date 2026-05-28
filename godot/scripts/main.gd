extends Control

const WahooState = preload("res://scripts/wahoo_state.gd")
const WahooRules = preload("res://scripts/wahoo_rules.gd")
const WahooRulesSmoke = preload("res://scripts/wahoo_rules_smoke.gd")

@onready var _turn_label: Label = $Root/Header/TurnLabel
@onready var _board = $Root/BoardFrame/BoardView
@onready var _status: RichTextLabel = $Root/Footer/Status
@onready var _roll_button: Button = $Root/Footer/RollButton

var _rng := RandomNumberGenerator.new()
var _state: WahooState
var _smoke_summary := ""
var _pending_moves: Array = []
var _pending_roll: Variant = null

func _ready() -> void:
    _rng.randomize()
    _state = WahooState.new_game()
    _roll_button.pressed.connect(_on_roll_pressed)
    _smoke_summary = _build_smoke_summary()
    _board.set_state(_state)
    _render_status("Waiting for first roll")

func _on_roll_pressed() -> void:
    _board.clear_legal_moves()
    _pending_moves = []
    _pending_roll = null

    var roll := _rng.randi_range(1, 6)
    var player := _state.current_player
    var legal := WahooRules.legal_moves(_state, player, roll)
    var line := "Player %d rolled %d\nLegal moves found: %d" % [player + 1, roll, legal.size()]
    if legal.size() > 0:
        _pending_moves = legal.duplicate(true)
        _pending_roll = roll
        _state.pending_roll = roll
        _board.set_legal_moves(_pending_moves, player)
        line += "\nChoose a highlighted marble/destination (tap-to-move next)"
    else:
        _state.pending_roll = null
        _state.current_player = (_state.current_player + 1) % WahooState.NUM_PLAYERS
    _board.set_state(_state)
    _render_status(line)

func _render_status(header: String) -> void:
    _turn_label.text = "Player %d" % (_state.current_player + 1)
    var lines := [
        header,
        "",
        _smoke_summary,
    ]
    _status.text = "\n".join(lines)

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

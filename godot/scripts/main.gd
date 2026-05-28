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

func _ready() -> void:
    _rng.randomize()
    _state = WahooState.new_game()
    _roll_button.pressed.connect(_on_roll_pressed)
    _smoke_summary = _build_smoke_summary()
    _board.set_state(_state)
    _render_status("Waiting for first roll")

func _on_roll_pressed() -> void:
    var roll := _rng.randi_range(1, 6)
    var player := _state.current_player
    var legal := WahooRules.legal_moves(_state, player, roll)
    var line := "Player %d rolled %d\nLegal moves found: %d" % [player + 1, roll, legal.size()]
    if legal.size() > 0:
        WahooRules.apply_move(_state, legal[0])
        line += "\nApplied first legal move: %s" % String(legal[0]["kind"])
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

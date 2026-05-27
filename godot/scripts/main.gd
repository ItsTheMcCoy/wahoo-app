extends Control

const WahooState = preload("res://scripts/wahoo_state.gd")
const WahooRules = preload("res://scripts/wahoo_rules.gd")

@onready var _status: RichTextLabel = $Panel/VBox/Status
@onready var _roll_button: Button = $Panel/VBox/RollButton

var _rng := RandomNumberGenerator.new()
var _state: WahooState

func _ready() -> void:
    _rng.randomize()
    _state = WahooState.new_game()
    _roll_button.pressed.connect(_on_roll_pressed)
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
    _render_status(line)

func _render_status(header: String) -> void:
    _status.text = "%s\n\nCurrent phase goals:\n- Port game_state.py to GDScript\n- Port rules.py to GDScript\n- Recreate rule tests in Godot" % header
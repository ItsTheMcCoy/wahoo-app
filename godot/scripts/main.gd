extends Control

const WahooState = preload("res://scripts/wahoo_state.gd")
const WahooRules = preload("res://scripts/wahoo_rules.gd")

@onready var _status: RichTextLabel = $Panel/VBox/Status
@onready var _roll_button: Button = $Panel/VBox/RollButton

var _rng := RandomNumberGenerator.new()
var _state: WahooState
var _current_player := 0

func _ready() -> void:
    _rng.randomize()
    _state = WahooState.new_game()
    _roll_button.pressed.connect(_on_roll_pressed)
    _render_status("Waiting for first roll")

func _on_roll_pressed() -> void:
    var roll := _rng.randi_range(1, 6)
    var legal := WahooRules.legal_moves(_state, _current_player, roll)
    _render_status("Player %d rolled %d\nLegal moves found: %d" % [_current_player + 1, roll, legal.size()])
    _current_player = (_current_player + 1) % WahooState.NUM_PLAYERS

func _render_status(header: String) -> void:
    _status.text = "%s\n\nCurrent phase goals:\n- Port game_state.py to GDScript\n- Port rules.py to GDScript\n- Recreate rule tests in Godot" % header
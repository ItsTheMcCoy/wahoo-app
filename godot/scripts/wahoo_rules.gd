class_name WahooRules
extends RefCounted

static func legal_moves(_state: WahooState, _player: int, _roll: int) -> Array:
    # Phase 2a bootstrap: return empty until the full rules translation lands.
    return []

static func apply_move(_state: WahooState, _move: Dictionary) -> void:
    # Phase 2a bootstrap: no-op placeholder.
    pass
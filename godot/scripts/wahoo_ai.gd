class_name WahooAI
extends RefCounted

const WahooState = preload("res://scripts/wahoo_state.gd")
const WahooRules = preload("res://scripts/wahoo_rules.gd")

# ---------------------------------------------------------------------------
# Feature constants
# ---------------------------------------------------------------------------

const FEATURE_KEYS := ["DEP", "RUN", "SPR", "CAP", "SAFE", "CTR", "DEN", "FLOW", "HOME", "FIN"]

# ---------------------------------------------------------------------------
# Profile weight constants
# ---------------------------------------------------------------------------

const SPRINTER_WEIGHTS := {
    "DEP": 0.4, "RUN": 1.0, "SPR": 0.2, "CAP": 0.4, "SAFE": 0.2,
    "CTR": 0.9, "DEN": 0.3, "FLOW": 0.4, "HOME": 0.5, "FIN": 0.9
}
const SWARM_WEIGHTS := {
    "DEP": 1.0, "RUN": 0.2, "SPR": 1.0, "CAP": 0.5, "SAFE": 0.4,
    "CTR": 0.4, "DEN": 0.4, "FLOW": 0.8, "HOME": 0.5, "FIN": 0.6
}
const ASSASSIN_WEIGHTS := {
    "DEP": 0.5, "RUN": 0.4, "SPR": 0.4, "CAP": 1.0, "SAFE": 0.2,
    "CTR": 0.5, "DEN": 0.9, "FLOW": 0.5, "HOME": 0.3, "FIN": 0.4
}
const GAMBLER_WEIGHTS := {
    "DEP": 0.7, "RUN": 0.8, "SPR": 0.3, "CAP": 0.6, "SAFE": 0.1,
    "CTR": 1.0, "DEN": 0.6, "FLOW": 0.2, "HOME": 0.4, "FIN": 0.5
}
const TORTOISE_WEIGHTS := {
    "DEP": 0.4, "RUN": 0.3, "SPR": 0.6, "CAP": 0.2, "SAFE": 2.5,
    "CTR": 0.1, "DEN": 0.5, "FLOW": 0.9, "HOME": 0.9, "FIN": 0.8
}
const GATEKEEPER_WEIGHTS := {
    "DEP": 0.5, "RUN": 0.3, "SPR": 0.5, "CAP": 1.0, "SAFE": 2.5,
    "CTR": 0.4, "DEN": 1.0, "FLOW": 0.8, "HOME": 0.5, "FIN": 0.6
}
const ENGINEER_WEIGHTS := {
    "DEP": 0.4, "RUN": 0.4, "SPR": 0.5, "CAP": 0.2, "SAFE": 0.8,
    "CTR": 0.2, "DEN": 0.3, "FLOW": 1.0, "HOME": 1.0, "FIN": 1.0
}
const BALANCED_WEIGHTS := {
    "DEP": 0.6, "RUN": 0.5, "SPR": 0.6, "CAP": 0.6, "SAFE": 0.6,
    "CTR": 0.5, "DEN": 0.6, "FLOW": 0.7, "HOME": 0.7, "FIN": 0.7
}
const HUMAN_LIKE_DEFAULT_WEIGHTS := {
    "DEP": 0.78, "RUN": 0.62, "SPR": 0.48, "CAP": 0.69, "SAFE": 0.61,
    "CTR": 0.61, "DEN": 0.68, "FLOW": 0.74, "HOME": 0.77, "FIN": 0.72
}

# ---------------------------------------------------------------------------
# Phase weights (additive modifiers on top of profile base weights)
# ---------------------------------------------------------------------------

const DEFAULT_PHASE_WEIGHTS := {
    "early": {"DEP": 0.30, "SPR": 0.20},
    "mid":   {"CAP": 0.10, "CTR": 0.10},
    "late":  {"HOME": 0.40, "FIN": 0.50, "SAFE": 0.20},
}

# ---------------------------------------------------------------------------
# Helper functions (module-level statics, callable by outer code and players)
# ---------------------------------------------------------------------------

static func _marble_progress(state, player: int, marble_id: int) -> float:
    var loc: Array = state.marbles[player][marble_id]
    var kind: String = loc[0]
    if kind == "BASE":
        return 0.0
    if kind == "TRACK":
        return float(WahooState.segment_offset(player, int(loc[1]))) / float(WahooState.LOOP_SIZE - 1)
    if kind == "CENTER":
        return 0.65
    if kind == "HOME":
        return 0.85 + (float(loc[1]) / float(WahooState.HOME_SLOTS - 1)) * 0.15
    return 0.0


static func _loc_progress(player: int, loc: Array) -> float:
    var kind: String = loc[0]
    if kind == "BASE":
        return 0.0
    if kind == "TRACK":
        return float(WahooState.segment_offset(player, int(loc[1]))) / float(WahooState.LOOP_SIZE - 1)
    if kind == "CENTER":
        return 0.65
    if kind == "HOME":
        return 0.85 + (float(loc[1]) / float(WahooState.HOME_SLOTS - 1)) * 0.15
    return 0.0


static func compute_exposure(state, player: int, loop_idx: int) -> float:
    var threats := 0
    for opp in range(WahooState.NUM_PLAYERS):
        if opp == player:
            continue
        for roll_val in range(1, 7):
            var src: int = posmod(loop_idx - roll_val, WahooState.LOOP_SIZE)
            var occ: Variant = state.marble_at_track(src)
            if occ == null or int(occ[0]) != opp:
                continue
            var h_dist: int = posmod(WahooState.home_entry(opp) - src, WahooState.LOOP_SIZE)
            if h_dist >= roll_val:
                threats += 1
    return float(threats) / float((WahooState.NUM_PLAYERS - 1) * 6)


static func _self_block_count(state, player: int) -> int:
    var track_offsets: Array = []
    for m in range(4):
        var loc: Array = state.marbles[player][m]
        if loc[0] == "TRACK":
            track_offsets.append(WahooState.segment_offset(player, int(loc[1])))
    track_offsets.sort()
    var blocked := 0
    for i in range(track_offsets.size()):
        for j in range(i + 1, track_offsets.size()):
            var gap: int = track_offsets[j] - track_offsets[i]
            if gap >= 1 and gap <= 5:
                blocked += 1
    return blocked


static func _game_phase(state, player: int) -> String:
    var home_count := 0
    for m in range(4):
        if state.marbles[player][m][0] == "HOME":
            home_count += 1
    if home_count == 0:
        return "early"
    if home_count == 1:
        return "mid"
    return "late"


static func compute_features(state, player: int, roll: int, move: Dictionary, all_moves: Array) -> Dictionary:
    var marble_id: int = int(move["marble"])
    var progress: Array = []
    for m in range(4):
        progress.append(_marble_progress(state, player, m))

    # DEP: exit-base indicator
    var DEP := 1.0 if move["kind"] == "exit_base" else 0.0

    # RUN / SPR: single-runner vs spread
    var sorted_progress := progress.duplicate()
    sorted_progress.sort()
    sorted_progress.reverse()
    var rank: Array = []
    var seen: Array = []
    for v in sorted_progress:
        if v not in seen:
            seen.append(v)
            rank.append(v)
    var marble_rank_idx: int = rank.find(progress[marble_id])
    var RUN := 1.0 - (float(marble_rank_idx) / 3.0)
    var SPR := 1.0 - RUN

    # CAP: capture reward scaled by victim's progress
    var CAP := 0.0
    var captures: Variant = move.get("captures", null)
    if captures != null:
        var cap_p: int = int(captures[0])
        var cap_m: int = int(captures[1])
        CAP = _marble_progress(state, cap_p, cap_m)

    # SAFE: net reduction in capture exposure
    var SAFE := 0.5
    var dest: Array = move["dest"]
    if dest[0] == "TRACK":
        var src_loc: Array = state.marbles[player][marble_id]
        var before := 0.0
        if src_loc[0] == "TRACK":
            before = compute_exposure(state, player, int(src_loc[1]))
        var after := compute_exposure(state, player, int(dest[1]))
        SAFE = clampf((before - after) + 0.5, 0.0, 1.0)

    # CTR: center-entry indicator
    var CTR := 1.0 if move["kind"] == "enter_center" else 0.0

    # DEN: center denial (enter center AND bump an opponent)
    var DEN := 1.0 if (move["kind"] == "enter_center" and captures != null) else 0.0

    # FLOW: self-blocking reduction
    var before_blocks: int = _self_block_count(state, player)
    var s2 = state.clone()
    WahooRules.apply_move(s2, move)
    var after_blocks: int = _self_block_count(s2, player)
    var FLOW := clampf(float(before_blocks - after_blocks) / 3.0 + 0.5, 0.0, 1.0)

    # HOME: home-lane depth reward
    var HOME := 0.0
    if dest[0] == "HOME":
        var slot: int = int(dest[1])
        HOME = float(slot + 1) / float(WahooState.HOME_SLOTS)

    # FIN: finish-over-fight
    var has_home_move := false
    var has_capture_move := false
    for m in all_moves:
        if m["dest"][0] == "HOME":
            has_home_move = true
        if m.get("captures", null) != null:
            has_capture_move = true
    var FIN := 0.5
    if has_home_move and has_capture_move:
        FIN = 1.0 if dest[0] == "HOME" else 0.0

    return {
        "DEP": DEP, "RUN": RUN, "SPR": SPR, "CAP": CAP,
        "SAFE": SAFE, "CTR": CTR, "DEN": DEN,
        "FLOW": FLOW, "HOME": HOME, "FIN": FIN,
    }

# ---------------------------------------------------------------------------
# Player classes
# Inner classes cannot reference WahooAI by name (same-file compile limitation),
# so they access the outer script via a lazy runtime load stored in _ai_ref.
# Godot's resource cache returns the already-compiled script with no re-parse.
# ---------------------------------------------------------------------------

class RandomPlayer:
    func choose_move(_state, _player: int, _roll: int, moves: Array) -> Dictionary:
        return moves[randi() % moves.size()]


class GreedyPlayer:
    var weights: Dictionary
    var phase_weights: Dictionary
    var _ai_ref  # lazy reference to wahoo_ai.gd script, set on first use

    func _init(p_weights: Dictionary, p_phase_weights: Dictionary = {}):
        weights = p_weights
        # Inline default phase weights to avoid referencing outer class at compile time.
        phase_weights = p_phase_weights if not p_phase_weights.is_empty() else {
            "early": {"DEP": 0.30, "SPR": 0.20},
            "mid":   {"CAP": 0.10, "CTR": 0.10},
            "late":  {"HOME": 0.40, "FIN": 0.50, "SAFE": 0.20},
        }

    func _ai() -> GDScript:
        if _ai_ref == null:
            # load() at runtime returns the cached compiled script; no re-parse.
            _ai_ref = load("res://scripts/wahoo_ai.gd")
        return _ai_ref

    func choose_move(state, player: int, roll: int, moves: Array) -> Dictionary:
        # Hard guardrail: take any immediate win unconditionally.
        for move in moves:
            var s2 = state.clone()
            s2.current_player = player
            preload("res://scripts/wahoo_rules.gd").apply_move(s2, move)
            if s2.player_won(player):
                return move

        var phase: String = _ai()._game_phase(state, player)
        var best_score := -INF
        var best_move: Dictionary = moves[0]
        for move in moves:
            var score := _score(state, player, roll, move, moves, phase)
            if score > best_score:
                best_score = score
                best_move = move
        return best_move

    func _score(state, player: int, _roll: int, move: Dictionary, all_moves: Array, phase: String) -> float:
        var features: Dictionary = _ai().compute_features(state, player, _roll, move, all_moves)
        var base := 0.0
        for k in weights:
            base += float(weights[k]) * float(features.get(k, 0.0))
        var phase_mods: Dictionary = phase_weights.get(phase, {})
        var modifier := 0.0
        for k in features:
            modifier += float(phase_mods.get(k, 0.0)) * float(features[k])
        return base + modifier

# ---------------------------------------------------------------------------
# Profile registry
# ---------------------------------------------------------------------------

static func make_profiles() -> Dictionary:
    return {
        "random":     RandomPlayer.new(),
        "sprinter":   GreedyPlayer.new(SPRINTER_WEIGHTS),
        "swarm":      GreedyPlayer.new(SWARM_WEIGHTS),
        "assassin":   GreedyPlayer.new(ASSASSIN_WEIGHTS),
        "gambler":    GreedyPlayer.new(GAMBLER_WEIGHTS),
        "tortoise":   GreedyPlayer.new(TORTOISE_WEIGHTS),
        "gatekeeper": GreedyPlayer.new(GATEKEEPER_WEIGHTS),
        "engineer":   GreedyPlayer.new(ENGINEER_WEIGHTS),
        "balanced":   GreedyPlayer.new(BALANCED_WEIGHTS),
        "human_like": GreedyPlayer.new(HUMAN_LIKE_DEFAULT_WEIGHTS),
    }

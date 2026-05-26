"""
AI player classes and supporting infrastructure for Wahoo.

Build order (per AI_PLAYER_BUILD_PLAN.md):
  1. _marble_progress(), compute_exposure()  ✓
  2. compute_features()                      ✓
  3. RandomPlayer, GreedyPlayer + profiles   ✓
  4. tests/test_ai.py probes 2–6            ← next
  5. play.py per-slot dispatch
  6. selfplay.py
  7. stats.py
"""

from .game_state import (
    GameState,
    LOOP_SIZE,
    HOME_SLOTS,
    NUM_PLAYERS,
    home_entry,
    segment_offset,
)
from .rules import apply_move


def _marble_progress(state: GameState, player: int, marble_id: int) -> float:
    """Return 0.0–1.0 progress value for one marble.

    BASE     → 0.0
    TRACK(i) → segment_offset(player, i) / (LOOP_SIZE - 1)
    CENTER   → 0.65  (heuristic: ~offset 47 of own journey)
    HOME(j)  → 0.85 + (j / (HOME_SLOTS - 1)) * 0.15  (0.85–1.0)
    """
    loc = state.marbles[player][marble_id]
    kind = loc[0]
    if kind == "BASE":
        return 0.0
    if kind == "TRACK":
        return segment_offset(player, loc[1]) / (LOOP_SIZE - 1)
    if kind == "CENTER":
        return 0.65
    if kind == "HOME":
        return 0.85 + (loc[1] / (HOME_SLOTS - 1)) * 0.15
    return 0.0


def compute_exposure(state: GameState, player: int, loop_idx: int) -> float:
    """Fraction of (opponent × roll) pairs that can land exactly on loop_idx.

    For each opponent and each die value 1–6, counts the pair as a threat when:
      - the opponent has a marble at TRACK((loop_idx - roll) % LOOP_SIZE)
      - that marble's walk would not be diverted into its own home stretch
        (home_entry(opp) must not lie on the path from src up to loop_idx)

    Divided by (NUM_PLAYERS - 1) * 6 to normalise to 0.0–1.0.
    Blocking by the opponent's own marbles is not simulated (approximation).
    """
    threats = 0
    for opp in range(NUM_PLAYERS):
        if opp == player:
            continue
        for roll_val in range(1, 7):
            src = (loop_idx - roll_val) % LOOP_SIZE
            occ = state.marble_at_track(src)
            if occ is None or occ[0] != opp:
                continue
            # Diversion check: home_entry(opp) must not be at positions
            # src, src+1, …, src+roll_val-1 (the squares visited before
            # the final landing step).
            h_dist = (home_entry(opp) - src) % LOOP_SIZE
            if h_dist >= roll_val:
                threats += 1
    return threats / ((NUM_PLAYERS - 1) * 6)


def _loc_progress(player: int, loc: tuple) -> float:
    """Progress value for a raw location tuple (same scale as _marble_progress)."""
    kind = loc[0]
    if kind == "BASE":
        return 0.0
    if kind == "TRACK":
        return segment_offset(player, loc[1]) / (LOOP_SIZE - 1)
    if kind == "CENTER":
        return 0.65
    if kind == "HOME":
        return 0.85 + (loc[1] / (HOME_SLOTS - 1)) * 0.15
    return 0.0


def _self_block_count(state: GameState, player: int) -> int:
    """Count own-marble pairs where the trailing marble is 1–5 steps behind
    the leading marble on the loop (within single-die range → blocking)."""
    track_offsets = sorted(
        segment_offset(player, state.marbles[player][m][1])
        for m in range(4)
        if state.marbles[player][m][0] == "TRACK"
    )
    blocked = 0
    for i, off in enumerate(track_offsets):
        for j in range(i + 1, len(track_offsets)):
            gap = track_offsets[j] - off
            if 1 <= gap <= 5:
                blocked += 1
    return blocked


def compute_features(
    state: GameState, player: int, roll: int, move: dict, all_moves: list
) -> dict:
    """Return a 10-key float dict (all values ~0.0–1.0) for one candidate move."""
    marble_id = move["marble"]
    progress = [_marble_progress(state, player, m) for m in range(4)]

    # --- DEP: exit-base indicator ---
    DEP = 1.0 if move["kind"] == "exit_base" else 0.0

    # --- RUN / SPR: single-runner vs spread ---
    dest_progress = _loc_progress(player, move["dest"])
    rank = sorted(set(progress), reverse=True)
    marble_rank_idx = rank.index(progress[marble_id])
    RUN = 1.0 - (marble_rank_idx / 3.0)
    SPR = 1.0 - RUN

    # --- CAP: capture reward scaled by victim's progress ---
    if move["captures"] is None:
        CAP = 0.0
    else:
        cap_p, cap_m = move["captures"]
        CAP = _marble_progress(state, cap_p, cap_m)

    # --- SAFE: net reduction in capture exposure ---
    if move["dest"][0] != "TRACK":
        SAFE = 0.5
    else:
        src_loc = state.marbles[player][marble_id]
        if src_loc[0] == "TRACK":
            before = compute_exposure(state, player, src_loc[1])
        else:
            before = 0.0
        after = compute_exposure(state, player, move["dest"][1])
        SAFE = max(0.0, min(1.0, (before - after) + 0.5))

    # --- CTR: center-entry indicator ---
    CTR = 1.0 if move["kind"] == "enter_center" else 0.0

    # --- DEN: center denial (enter center AND bump an opponent) ---
    DEN = 1.0 if move["kind"] == "enter_center" and move["captures"] is not None else 0.0

    # --- FLOW: self-blocking reduction ---
    before_blocks = _self_block_count(state, player)
    s2 = state.clone()
    apply_move(s2, move)
    after_blocks = _self_block_count(s2, player)
    FLOW = max(0.0, min(1.0, (before_blocks - after_blocks) / 3.0 + 0.5))

    # --- HOME: home-lane depth reward ---
    if move["dest"][0] != "HOME":
        HOME = 0.0
    else:
        slot = move["dest"][1]
        HOME = (slot + 1) / HOME_SLOTS

    # --- FIN: finish-over-fight ---
    home_moves    = [m for m in all_moves if m["dest"][0] == "HOME"]
    capture_moves = [m for m in all_moves if m["captures"] is not None]
    finish_vs_fight = bool(home_moves and capture_moves)
    if not finish_vs_fight:
        FIN = 0.5
    elif move["dest"][0] == "HOME":
        FIN = 1.0
    else:
        FIN = 0.0

    return {
        "DEP": DEP, "RUN": RUN, "SPR": SPR, "CAP": CAP,
        "SAFE": SAFE, "CTR": CTR, "DEN": DEN,
        "FLOW": FLOW, "HOME": HOME, "FIN": FIN,
    }


# ---------------------------------------------------------------------------
# Phase weights (additive modifiers layered on top of profile base weights)
# ---------------------------------------------------------------------------

DEFAULT_PHASE_WEIGHTS = {
    "early": {"DEP": 0.30, "SPR": 0.20},
    "mid":   {"CAP": 0.10, "CTR": 0.10},
    "late":  {"HOME": 0.40, "FIN": 0.50, "SAFE": 0.20},
}


def _game_phase(state: GameState, player: int) -> str:
    home_count = sum(1 for m in range(4) if state.marbles[player][m][0] == "HOME")
    if home_count == 0:
        return "early"
    if home_count == 1:
        return "mid"
    return "late"


# ---------------------------------------------------------------------------
# Profile weight constants
# ---------------------------------------------------------------------------

SPRINTER_WEIGHTS  = {"DEP": 0.4, "RUN": 1.0, "SPR": 0.2, "CAP": 0.4, "SAFE": 0.2, "CTR": 0.9, "DEN": 0.3, "FLOW": 0.4, "HOME": 0.5, "FIN": 0.9}
SWARM_WEIGHTS     = {"DEP": 1.0, "RUN": 0.2, "SPR": 1.0, "CAP": 0.5, "SAFE": 0.4, "CTR": 0.4, "DEN": 0.4, "FLOW": 0.8, "HOME": 0.5, "FIN": 0.6}
ASSASSIN_WEIGHTS  = {"DEP": 0.5, "RUN": 0.4, "SPR": 0.4, "CAP": 1.0, "SAFE": 0.2, "CTR": 0.5, "DEN": 0.9, "FLOW": 0.5, "HOME": 0.3, "FIN": 0.4}
GAMBLER_WEIGHTS   = {"DEP": 0.7, "RUN": 0.8, "SPR": 0.3, "CAP": 0.6, "SAFE": 0.1, "CTR": 1.0, "DEN": 0.6, "FLOW": 0.2, "HOME": 0.4, "FIN": 0.5}
TORTOISE_WEIGHTS  = {"DEP": 0.4, "RUN": 0.3, "SPR": 0.6, "CAP": 0.2, "SAFE": 1.0, "CTR": 0.1, "DEN": 0.5, "FLOW": 0.9, "HOME": 0.9, "FIN": 0.8}
GATEKEEPER_WEIGHTS= {"DEP": 0.5, "RUN": 0.3, "SPR": 0.5, "CAP": 1.0, "SAFE": 0.7, "CTR": 0.4, "DEN": 1.0, "FLOW": 0.8, "HOME": 0.5, "FIN": 0.6}
ENGINEER_WEIGHTS  = {"DEP": 0.4, "RUN": 0.4, "SPR": 0.5, "CAP": 0.2, "SAFE": 0.8, "CTR": 0.2, "DEN": 0.3, "FLOW": 1.0, "HOME": 1.0, "FIN": 1.0}
BALANCED_WEIGHTS  = {"DEP": 0.6, "RUN": 0.5, "SPR": 0.6, "CAP": 0.6, "SAFE": 0.6, "CTR": 0.5, "DEN": 0.6, "FLOW": 0.7, "HOME": 0.7, "FIN": 0.7}


# ---------------------------------------------------------------------------
# Player classes
# ---------------------------------------------------------------------------

import random as _random


class RandomPlayer:
    def choose_move(self, state: GameState, player: int, roll: int, moves: list) -> dict:
        return _random.choice(moves)


class GreedyPlayer:
    def __init__(self, weights: dict, phase_weights: dict | None = None):
        self.weights = weights
        self.phase_weights = phase_weights or DEFAULT_PHASE_WEIGHTS

    def choose_move(self, state: GameState, player: int, roll: int, moves: list) -> dict:
        from .rules import legal_moves as _legal_moves
        # Hard guardrail: take any immediate win unconditionally.
        for move in moves:
            s2 = state.clone()
            apply_move(s2, move)
            if s2.player_won(player):
                return move

        phase = _game_phase(state, player)
        scores = [self._score(state, player, roll, m, moves, phase) for m in moves]
        return moves[scores.index(max(scores))]

    def _score(self, state: GameState, player: int, roll: int, move: dict, all_moves: list, phase: str) -> float:
        features = compute_features(state, player, roll, move, all_moves)
        base = sum(self.weights[k] * features[k] for k in self.weights)
        modifier = sum(self.phase_weights[phase].get(k, 0.0) * features[k] for k in features)
        return base + modifier


# ---------------------------------------------------------------------------
# Profile registry
# ---------------------------------------------------------------------------

PROFILES: dict = {
    "random":    RandomPlayer(),
    "sprinter":  GreedyPlayer(SPRINTER_WEIGHTS),
    "swarm":     GreedyPlayer(SWARM_WEIGHTS),
    "assassin":  GreedyPlayer(ASSASSIN_WEIGHTS),
    "gambler":   GreedyPlayer(GAMBLER_WEIGHTS),
    "tortoise":  GreedyPlayer(TORTOISE_WEIGHTS),
    "gatekeeper":GreedyPlayer(GATEKEEPER_WEIGHTS),
    "engineer":  GreedyPlayer(ENGINEER_WEIGHTS),
    "balanced":  GreedyPlayer(BALANCED_WEIGHTS),
}

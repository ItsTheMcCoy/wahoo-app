"""
Scenario probe suite for AI players (tests/test_ai.py).
See documents/AI_PLAYER_BUILD_PLAN.md §11 for full probe specs.
"""

import pytest
from wahoo.game_state import (
    GameState, loc_base, loc_track, loc_home, loc_center,
    home_entry, base_exit, NUM_PLAYERS, MARBLES_PER_PLAYER,
)
from wahoo.rules import legal_moves
from wahoo.ai import PROFILES, RandomPlayer


def make_state(marbles_by_player, center_occupant=None):
    """Build a GameState with given marble positions; current_player defaults to 0."""
    state = GameState()
    state.marbles = [list(row) for row in marbles_by_player]
    state.center_occupant = center_occupant
    state.current_player = 0
    return state


def _all_base(num_players=NUM_PLAYERS):
    return [[loc_base()] * MARBLES_PER_PLAYER for _ in range(num_players)]


# ---------------------------------------------------------------------------
# Probe 1 — Win guardrail (all profiles must take the immediate win)
# ---------------------------------------------------------------------------

def test_win_guardrail():
    """
    Player 0 has marbles at HOME(1), HOME(2), HOME(3) and one marble on
    TRACK at home_entry(0)=55.  Roll 1 brings it into HOME(0), the only
    free slot — all four marbles end up in HOME, which is a win.

    HOME slots 1,2,3 are all occupied so no marble there can advance
    (each would overshoot or land on a neighbour). HOME(0) is the only
    reachable free slot and entering it completes the win.
    """
    # Marbles in HOME(1),(2),(3): none can advance with roll 1 —
    #   HOME(1)→HOME(2) blocked; HOME(2)→HOME(3) blocked; HOME(3) overshoots.
    # Marble 3 at TRACK(55) = home_entry(0): roll 1 → HOME(0) → all in HOME.
    roll = 1
    he = home_entry(0)  # 55 for player 0

    marbles = _all_base()
    marbles[0] = [loc_home(1), loc_home(2), loc_home(3), loc_track(he)]
    state = make_state(marbles)

    moves = legal_moves(state, 0, roll)
    winning = [m for m in moves if m["dest"] == loc_home(0)]
    assert len(winning) == 1, "Expected exactly one winning move (enter HOME(0))"

    for profile_name, player_obj in PROFILES.items():
        chosen = player_obj.choose_move(state, 0, roll, moves)
        assert chosen == winning[0], (
            f"Profile '{profile_name}' did not take the winning move"
        )

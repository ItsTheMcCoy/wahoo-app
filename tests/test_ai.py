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


# ---------------------------------------------------------------------------
# Probe 2 — Center temptation (shortcut-friendly profiles prefer center)
# ---------------------------------------------------------------------------

def test_center_temptation():
    """
    Player 0 has two marbles in base, one marble at offset 5 from its base
    exit, and one established runner farther along the track.  With roll 1,
    the offset-5 marble can either enter center or advance normally, while
    base marbles can also deploy.

    Shortcut-focused profiles should take the center entry.  Swarm should
    prefer deploying a new marble, and Tortoise should avoid the risky center.
    """
    roll = 1

    marbles = _all_base()
    marbles[0] = [loc_base(), loc_base(), loc_track(5), loc_track(18)]
    state = make_state(marbles)

    moves = legal_moves(state, 0, roll)
    center_move = next(m for m in moves if m["kind"] == "enter_center")

    for profile_name in ["sprinter", "gambler"]:
        chosen = PROFILES[profile_name].choose_move(state, 0, roll, moves)
        assert chosen == center_move, (
            f"Profile '{profile_name}' should prefer entering center"
        )

    swarm_choice = PROFILES["swarm"].choose_move(state, 0, roll, moves)
    assert swarm_choice["kind"] == "exit_base", (
        "Profile 'swarm' should prefer deploying a new marble"
    )

    tortoise_choice = PROFILES["tortoise"].choose_move(state, 0, roll, moves)
    assert tortoise_choice["kind"] != "enter_center", (
        "Profile 'tortoise' should avoid entering center"
    )


# ---------------------------------------------------------------------------
# Probe 3 — Capture vs deploy (Assassin prefers capture)
# ---------------------------------------------------------------------------

def test_capture_vs_deploy():
    """
    Player 0 has two marbles in base, one marble six squares behind an
    opponent, and one established runner. With roll 6, the player can either
    deploy from base or capture the opponent on TRACK(13).

    Capture-focused profiles should take the hit. Swarm should prefer adding
    another marble to the board.
    """
    roll = 6

    marbles = _all_base()
    marbles[0] = [loc_base(), loc_base(), loc_track(7), loc_track(22)]
    marbles[1][0] = loc_track(13)
    state = make_state(marbles)

    moves = legal_moves(state, 0, roll)
    capture_move = next(m for m in moves if m["captures"] is not None)
    assert capture_move["dest"] == loc_track(13)

    assert any(m["kind"] == "exit_base" for m in moves), (
        "Expected at least one deploy move on roll 6"
    )

    for profile_name in ["assassin", "gatekeeper"]:
        chosen = PROFILES[profile_name].choose_move(state, 0, roll, moves)
        assert chosen == capture_move, (
            f"Profile '{profile_name}' should prefer capturing"
        )

    swarm_choice = PROFILES["swarm"].choose_move(state, 0, roll, moves)
    assert swarm_choice["kind"] == "exit_base", (
        "Profile 'swarm' should prefer deploying a new marble"
    )
